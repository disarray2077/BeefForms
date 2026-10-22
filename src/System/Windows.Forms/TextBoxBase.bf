

using System.Text;

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
		get => Utf16Offset(Text, SelectionByteStart);
		set
		{
			if (value < 0) Runtime.FatalError("SelectionStart must not be negative");
			Select(value, SelectionLength);
		}
	}
	public int SelectionLength
	{
		get => Utf16Offset(Text, SelectionByteStart + SelectionByteLength) - SelectionStart;
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

	public override String Text
	{
		get => base.Text;
		set
		{
			let text = value ?? String.Empty;
			if (Text == text) return;
			// Created WinForms editors reset selection; unrealized editors retain UTF-16 positions.
			let anchor = IsHandleCreated ? 0 : Utf8Offset(text, Utf16Offset(Text, mAnchor));
			let caret = IsHandleCreated ? 0 : Utf8Offset(text, Utf16Offset(Text, mCaret));
			CommitText(text, anchor, caret);
		}
	}

	private void CommitText(StringView text, int anchor, int caret, bool forceNotification = false)
	{
		let changed = SetTextValue(text);
		mAnchor = CharacterBoundary(anchor);
		mCaret = CharacterBoundary(caret);
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
		mAnchor = Utf8Offset(Text, position);
		mCaret = Utf8Offset(Text, position + Math.Clamp(length, -position, textLength - position));
		UpdateBackend(.Selection);
	}
	public void SelectAll() => Select(0, UTF16.GetEncodedLen(Text));

	internal void SetCaret(int position, bool extend)
	{
		mCaret = CharacterBoundary(position);
		if (!extend)
			mAnchor = mCaret;
		UpdateBackend(.Selection);
	}

	internal void NotifySelection(int anchor, int caret)
	{
		mAnchor = anchor;
		mCaret = caret;
	}

	internal static int Utf16Offset(StringView text, int utf8Offset) =>
		UTF16.GetEncodedLen(text.Substring(0, utf8Offset));

	internal static int Utf8Offset(StringView text, int utf16Offset)
	{
		int units = 0, bytes = 0;
		for (let character in text.DecodedChars)
		{
			let length = UTF16.GetEncodedLength(character);
			// Keep whole characters when an index falls between a surrogate pair.
			if (units + length > utf16Offset) break;
			units += length;
			bytes += UTF8.GetEncodedLength(character);
		}
		return bytes;
	}

	private int CharacterBoundary(int position)
	{
		var result = Math.Clamp(position, 0, Text.Length);
		while (result > 0 && result < Text.Length && ((uint8)Text[result] & 0xC0) == 0x80)
			result--;
		return result;
	}

	internal int AdjacentPosition(int position, bool forward)
	{
		var result = position + (forward ? 1 : -1);
		while (result > 0 && result < Text.Length && ((uint8)Text[result] & 0xC0) == 0x80)
			result += forward ? 1 : -1;
		return Math.Clamp(result, 0, Text.Length);
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
			let adjacent = AdjacentPosition(mCaret, !backward);
			if (adjacent == mCaret) return;
			mAnchor = mCaret;
			mCaret = adjacent;
		}
		ReplaceSelection("");
	}
}
