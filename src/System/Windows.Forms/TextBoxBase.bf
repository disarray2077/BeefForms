using System.Text;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public class TextBoxBase : Control
{
	private bool mMultiline;
	private int32 mRequestedHeight;
	public ref Event<EventHandler> MultilineChanged { get; set; } ~ _.Dispose();

	protected virtual void OnMultilineChanged(EventArgs args)
	{
		MultilineChanged.Invoke(this, args);
	}

	protected internal virtual StringView LineBreak => "\r\n";
	public virtual bool Multiline
	{
		get => mMultiline;
		set
		{
			if (mMultiline == value)
				return;
			mMultiline = value;
			{
				let updating = UpdatingText;
				UpdatingText = true;
				defer { UpdatingText = updating; }
				UpdateBackend(.Multiline);
			}
			if (IsDisposingOrDisposed)
				return;
			let height = AutoSize && !Multiline ? Application.Backend.GetTextBoxHeight(this) : mRequestedHeight;
			SetLayoutBounds(Location, .(Size.width, height), true);
			base.UpdateAutoSize();
			OnMultilineChanged(.Empty);
		}
	}

	protected override void RestoreSpecifiedSize()
	{
		SetLayoutBounds(Location, .(Size.width, mRequestedHeight), true);
	}

	protected internal override bool SelfAutoSize => true;

	public override System.Drawing.Size GetPreferredSize(System.Drawing.Size proposedSize)
	{
		let border = BorderWidth * 2;
		System.Drawing.Size constraints = .(proposedSize.width > border ? proposedSize.width - border : 0,
			proposedSize.height > border ? proposedSize.height - border : 0);
		let text = Application.Backend.MeasureText(this, Multiline ? constraints : default);
		return .(text.width + border, Math.Max(text.height + border,
			Application.Backend.GetTextBoxHeight(this)));
	}

	protected override void UpdateAutoSize()
	{
		if (AutoSize && !Multiline)
			SetLayoutBounds(Location, .(Size.width, Application.Backend.GetTextBoxHeight(this)), true);
		base.UpdateAutoSize();
	}

	public this()
	{
		TabStop = true;
		BorderStyle = .Fixed3D;
		AutoSize = true;
		mRequestedHeight = Size.height;
	}

	public override System.Drawing.Size Size
	{
		get => base.Size;
		set
		{
			mRequestedHeight = value.height;
			var size = value;
			if (AutoSize && !Multiline)
				size.height = Application.Backend.GetTextBoxHeight(this);
			base.Size = size;
		}
	}

	private bool mReadOnly;
	public bool ReadOnly
	{
		get => mReadOnly;
		set
		{
			mReadOnly = value;
			UpdateBackend(.ReadOnly);
		}
	}
	/// Selection positions and lengths use UTF-16 code units.
	public int SelectionStart
	{
		get => TextEncodingHelper.ToUtf16Offset(Text, SelectionByteStart);
		set
		{
			if (value < 0)
				Runtime.FatalError("SelectionStart must not be negative");
			Select(value, SelectionLength);
		}
	}
	public int SelectionLength
	{
		get => TextEncodingHelper.ToUtf16Offset(Text, SelectionByteStart + SelectionByteLength) - SelectionStart;
		set
		{
			if (value < 0)
				Runtime.FatalError("SelectionLength must not be negative");
			Select(SelectionStart, value);
		}
	}
	internal int SelectionByteStart => Math.Min(mCaret, mAnchor);
	internal int SelectionByteLength => Math.Abs(mCaret - mAnchor);
	internal int Caret => mCaret;
	internal int SelectionAnchor => mAnchor;
	private int mCaret;
	private int mAnchor;
	private int mCachedAnchorUtf16;
	private int mCachedCaretUtf16;
	internal bool UpdatingText { get; private set; }

	public override StringView Text
	{
		get => base.Text;
		set
		{
			let text = value;
			if (Text == text)
				return;
			// Created WinForms editors reset selection; unrealized editors retain UTF-16 positions.
			let anchor = IsHandleCreated ? 0 : TextEncodingHelper.ToUtf8Offset(text, mCachedAnchorUtf16);
			let caret = IsHandleCreated ? 0 : TextEncodingHelper.ToUtf8Offset(text, mCachedCaretUtf16);
			CommitText(text, anchor, caret, preserveSelection: !IsHandleCreated);
		}
	}

	private void CommitText(StringView text, int anchor, int caret, bool forceNotification = false, bool preserveSelection = false)
	{
		let changed = SetTextValue(text);
		mAnchor = TextEncodingHelper.CharacterBoundary(Text, anchor);
		mCaret = TextEncodingHelper.CharacterBoundary(Text, caret);
		if (!preserveSelection)
			CacheSelection();
		UpdatingText = true;
		if (changed)
			UpdateBackend(.Text);
		UpdateBackend(.Selection);
		UpdatingText = false;
		// No selection writes after notification: reentrant handlers own their final state.
		if (changed || forceNotification)
			NotifyTextChanged();
	}

	/// Selects text by UTF-16 indices; positions inside surrogate pairs snap to the character's start.
	public void Select(int start, int length)
	{
		let textLength = UTF16.GetEncodedLen(Text);
		let position = Math.Clamp(start, 0, textLength);
		mAnchor = TextEncodingHelper.ToUtf8Offset(Text, position);
		mCaret = TextEncodingHelper.ToUtf8Offset(Text, position + Math.Clamp(length, -position, textLength - position));
		CacheSelection();
		UpdateBackend(.Selection);
	}

	public void SelectAll()
	{
		Select(0, UTF16.GetEncodedLen(Text));
	}

	internal void SetCaret(int position, bool extend)
	{
		mCaret = TextEncodingHelper.CharacterBoundary(Text, position);
		if (!extend)
			mAnchor = mCaret;
		CacheSelection();
		UpdateBackend(.Selection);
	}

	internal void NotifySelection(int anchor, int caret, StringView text)
	{
		mAnchor = anchor;
		mCaret = caret;
		CacheSelection(text);
	}

	private void CacheSelection()
	{
		CacheSelection(Text);
	}

	private void CacheSelection(StringView text)
	{
		mCachedAnchorUtf16 = TextEncodingHelper.ToUtf16Offset(text, mAnchor);
		mCachedCaretUtf16 = TextEncodingHelper.ToUtf16Offset(text, mCaret);
	}

	protected internal override void CreateHandle()
	{
		base.CreateHandle();
		if (IsHandleCreated)
			CacheSelection();
	}

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
			let adjacent = TextEncodingHelper.AdjacentPosition(Text, mCaret, !backward, Multiline);
			if (adjacent == mCaret)
				return;
			mAnchor = mCaret;
			mCaret = adjacent;
		}
		ReplaceSelection("");
	}
}
