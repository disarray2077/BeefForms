using System.Text;
using System.Drawing;
using System.Windows;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public class TextBoxBase : Control
{
	public this() { TabStop = true; BorderStyle = .Fixed3D; AutoSize = true; }
	public override System.Drawing.Size Size
	{
		get => base.Size;
		set
		{
			var size = value;
			if (AutoSize && !(this is RichTextBox))
				size.height = Application.Backend.GetTextBoxHeight(this);
			base.Size = size;
		}
	}

	private bool mReadOnly;
	public bool ReadOnly
	{
		get => mReadOnly;
		set { mReadOnly = value; UpdateBackend(.ReadOnly); }
	}
	/// Selection positions and lengths use UTF-16 code units.
	public int SelectionStart
	{
		get => TextEncodingHelper.ToUtf16Offset(Text, SelectionByteStart);
		set
		{
			if (value < 0) Runtime.FatalError("SelectionStart must not be negative");
			Select(value, SelectionLength);
		}
	}
	public int SelectionLength
	{
		get => TextEncodingHelper.ToUtf16Offset(Text, SelectionByteStart + SelectionByteLength) - SelectionStart;
		set
		{
			if (value < 0) Runtime.FatalError("SelectionLength must not be negative");
			Select(SelectionStart, value);
		}
	}
	internal int SelectionByteStart => Math.Min(mCaret, mAnchor);
	internal int SelectionByteLength => Math.Abs(mCaret - mAnchor);
	internal int Caret => mCaret;
	internal int SelectionAnchor => mAnchor;
	internal int32 ScrollX { get; private set; }
	internal int32 ScrollY { get; private set; }
	private bool mScrollValidationPending = true;
	private bool mCaretRevealPending;
	private uint64 mCaretBlinkStartedAt;
	private const uint64 CaretVisibleDuration = 550;
	private const uint64 CaretBlinkPeriod = 1000;
	private int mCaret;
	private int mAnchor;
	internal bool UpdatingText { get; private set; }

	internal bool NeedsScrollPreparation => mScrollValidationPending || mCaretRevealPending;
	internal void InvalidateScroll() => mScrollValidationPending = true;
	internal void RequestCaretReveal() => mCaretRevealPending = true;
	internal void RestartCaretBlink(uint64 now) => mCaretBlinkStartedAt = now;
	private uint64 CaretPhase(uint64 now) => (Math.Max(now, mCaretBlinkStartedAt) - mCaretBlinkStartedAt) % CaretBlinkPeriod;
	internal bool IsCaretVisible(uint64 now) => CaretPhase(now) < CaretVisibleDuration;
	internal uint64 GetNextCaretTick(uint64 now)
	{
		let phase = CaretPhase(now);
		return now + (phase < CaretVisibleDuration ? CaretVisibleDuration - phase : CaretBlinkPeriod - phase);
	}

	// Explicit scrolling takes precedence over an outstanding caret reveal.
	internal void SetScrollOffset(Point offset)
	{
		ScrollX = Math.Max(0, offset.x);
		ScrollY = Math.Max(0, offset.y);
		mCaretRevealPending = false;
		InvalidateScroll();
		UpdateBackend(.Scroll);
	}

	internal void PrepareScroll(Point caret, int32 lineHeight, Size viewport, Size content, Size trailingMargin, bool focused)
	{
		if (focused && mCaretRevealPending)
		{
			ScrollX = Math.Max(caret.x - viewport.width + trailingMargin.width, Math.Min(ScrollX, caret.x));
			ScrollY = Math.Max(caret.y + lineHeight - viewport.height + trailingMargin.height, Math.Min(ScrollY, caret.y));
		}
		ScrollX = Math.Clamp(ScrollX, 0, Math.Max(0, content.width + trailingMargin.width - viewport.width));
		ScrollY = Math.Clamp(ScrollY, 0, Math.Max(0, content.height + trailingMargin.height - viewport.height));
		mScrollValidationPending = false;
		mCaretRevealPending = false;
	}

	public override StringView Text
	{
		get => base.Text;
		set
		{
			let text = value;
			if (Text == text) return;
			// Created WinForms editors reset selection; unrealized editors retain UTF-16 positions.
			let anchor = IsHandleCreated ? 0 : TextEncodingHelper.ToUtf8Offset(text, TextEncodingHelper.ToUtf16Offset(Text, mAnchor));
			let caret = IsHandleCreated ? 0 : TextEncodingHelper.ToUtf8Offset(text, TextEncodingHelper.ToUtf16Offset(Text, mCaret));
			CommitText(text, anchor, caret);
		}
	}

	private void CommitText(StringView text, int anchor, int caret, bool forceNotification = false)
	{
		let changed = SetTextValue(text);
		mAnchor = TextEncodingHelper.CharacterBoundary(Text, anchor);
		mCaret = TextEncodingHelper.CharacterBoundary(Text, caret);
		UpdatingText = true;
		if (changed) UpdateBackend(.Text);
		UpdateBackend(.Selection);
		UpdatingText = false;
		// No selection writes after notification: reentrant handlers own their final state.
		if (changed || forceNotification) NotifyTextChanged();
	}

	/// Selects text by UTF-16 indices; positions inside surrogate pairs snap to the character's start.
	public void Select(int start, int length)
	{
		let textLength = UTF16.GetEncodedLen(Text);
		let position = Math.Clamp(start, 0, textLength);
		mAnchor = TextEncodingHelper.ToUtf8Offset(Text, position);
		mCaret = TextEncodingHelper.ToUtf8Offset(Text, position + Math.Clamp(length, -position, textLength - position));
		UpdateBackend(.Selection);
	}
	public void SelectAll() => Select(0, UTF16.GetEncodedLen(Text));

	internal void SetCaret(int position, bool extend)
	{
		mCaret = TextEncodingHelper.CharacterBoundary(Text, position);
		if (!extend)
			mAnchor = mCaret;
		UpdateBackend(.Selection);
	}

	internal void NotifySelection(int anchor, int caret)
	{
		mAnchor = anchor;
		mCaret = caret;
	}

	internal int AdjacentPosition(int position, bool forward) => TextEncodingHelper.AdjacentPosition(Text, position, forward);

	internal void ReplaceSelection(StringView value)
	{
		if (ReadOnly)
			return;
		let start = SelectionByteStart;
		let text = scope String();
		text.Append(Text, 0, start);
		text.Append(value);
		text.Append(Text, start + SelectionByteLength);
		let caret = start + value.Length;
		CommitText(text, caret, caret, true);
	}

	internal void DeleteText(bool backward)
	{
		if (ReadOnly)
			return;
		if (SelectionByteLength == 0)
		{
			let adjacent = AdjacentPosition(mCaret, !backward);
			if (adjacent == mCaret) return;
			mAnchor = mCaret;
			mCaret = adjacent;
		}
		ReplaceSelection("");
	}
}
