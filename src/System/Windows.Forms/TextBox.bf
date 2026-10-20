namespace System.Windows.Forms;

public class TextBox : TextBoxBase
{
    protected override char8* WindowClassName => Win32.EDIT_CLASS;
    protected override uint WindowStyle => base.WindowStyle | Win32.ES_AUTOHSCROLL;
}