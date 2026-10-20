namespace System.Windows.Forms;

public class Panel : ScrollableControl
{
	public ref Event<PaintEventHandler> Paint { get; set; } ~ _.Dispose();
}
