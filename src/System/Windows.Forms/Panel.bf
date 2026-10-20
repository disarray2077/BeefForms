namespace System.Windows.Forms;

public class Panel : ScrollableControl
{
	protected override char8* WindowClassName => Win32.STATIC_CLASS;

    public ref Event<PaintEventHandler> Paint { get; set; } ~ _.Dispose();
}