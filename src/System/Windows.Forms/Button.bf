namespace System.Windows.Forms;

public class Button : ButtonBase
{
	protected override char8* WindowClassName => Win32.BUTTON_CLASS;
	protected override uint WindowStyle => base.WindowStyle | Win32.BS_PUSHBUTTON;

    public ref Event<EventHandler> Click { get; set; } ~ _.Dispose();
}