namespace System.Windows.Forms;

public class GroupBox : Control 
{
	protected override char8* WindowClassName => Win32.BUTTON_CLASS;
	protected override uint WindowStyle => base.WindowStyle | Win32.BS_GROUPBOX | Win32.WS_GROUP;

    public bool TabStop { get; set; }
}