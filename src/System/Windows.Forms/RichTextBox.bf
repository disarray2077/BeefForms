namespace System.Windows.Forms;

public class RichTextBox : TextBoxBase
{
	public this()
	{
		AutoSize = false;
		Multiline = true;
	}

	protected internal override StringView LineBreak => "\n";
}
