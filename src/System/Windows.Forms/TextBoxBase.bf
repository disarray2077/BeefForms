

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public class TextBoxBase : Control
{
	public this() { TabStop = true; }
	private bool mReadOnly;
	public bool ReadOnly
	{
		get => mReadOnly;
		set { mReadOnly = value; UpdateBackend(.ReadOnly); }
	}
	public int SelectionStart
	{
		get => Math.Min(mCaret, mAnchor);
		set
		{
			if (value < 0) Runtime.FatalError("SelectionStart must not be negative");
			Select(value, SelectionLength);
		}
	}
	public int SelectionLength
	{
		get => Math.Abs(mCaret - mAnchor);
		set
		{
			if (value < 0) Runtime.FatalError("SelectionLength must not be negative");
			Select(SelectionStart, value);
		}
	}
	internal int Caret => mCaret;
	internal int SelectionAnchor => mAnchor;
	internal int32 ScrollX;
	internal int32 ScrollY;
	private int mCaret;
	private int mAnchor;

	public override String Text
	{
		get => base.Text;
		set
		{
			base.Text = value;
			mCaret = CharacterBoundary(mCaret);
			mAnchor = CharacterBoundary(mAnchor);
			UpdateBackend(.Selection);
		}
	}

	public void Select(int start, int length)
	{
		let position = Math.Clamp(start, 0, Text.Length);
		mAnchor = CharacterBoundary(position);
		mCaret = CharacterBoundary(position + Math.Clamp(length, -position, Text.Length - position));
		UpdateBackend(.Selection);
	}
	public void SelectAll() => Select(0, Text.Length);

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
		let start = SelectionStart;
		let text = scope String();
		text.Append(Text, 0, start);
		text.Append(value);
		text.Append(Text, start + SelectionLength);
		Text = text;
		mCaret = start + value.Length;
		mAnchor = mCaret;
		UpdateBackend(.Selection);
	}

	internal void DeleteText(bool backward)
	{
		if (ReadOnly)
			return;
		if (SelectionLength == 0)
		{
			mAnchor = mCaret;
			mCaret = AdjacentPosition(mCaret, !backward);
		}
		ReplaceSelection("");
	}
}
