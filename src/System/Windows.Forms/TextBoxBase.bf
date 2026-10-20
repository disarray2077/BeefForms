

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
	public int SelectionStart => Math.Min(mCaret, mAnchor);
	public int SelectionLength => Math.Abs(mCaret - mAnchor);
	internal int Caret => mCaret;
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
			mCaret = Math.Min(mCaret, Text.Length);
			mAnchor = Math.Min(mAnchor, Text.Length);
		}
	}

	public void Select(int start, int length)
	{
		mAnchor = Math.Clamp(start, 0, Text.Length);
		mCaret = Math.Clamp(start + length, 0, Text.Length);
		UpdateBackend(.Selection);
	}
	public void SelectAll() => Select(0, Text.Length);

	internal void SetCaret(int position, bool extend)
	{
		mCaret = Math.Clamp(position, 0, Text.Length);
		if (!extend)
			mAnchor = mCaret;
		UpdateBackend(.Selection);
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
