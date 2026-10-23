using System.Text;
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
	internal int32 ScrollX;
	internal int32 ScrollY;
	private int mCaret;
	private int mAnchor;
	internal bool UpdatingText { get; private set; }

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
