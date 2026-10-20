namespace System.Windows.Forms;

public class RichTextBox : TextBoxBase
{
	protected override char8* WindowClassName => Win32.EDIT_CLASS;
	protected override uint WindowStyle
	{
		get
		{
			uint style = base.WindowStyle | Win32.ES_MULTILINE | Win32.ES_AUTOVSCROLL | Win32.WS_VSCROLL;
			if (ReadOnly)
			{
				style |= Win32.ES_READONLY;
			}
			return style;
		}
	}
}