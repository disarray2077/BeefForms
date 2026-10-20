namespace System.Windows.Forms;

public class Button : ButtonBase
{
	public ref Event<EventHandler> Click { get; set; } ~ _.Dispose();
	public void PerformClick()
	{
		if (CanSelect)
			Click.Invoke(this, .Empty);
	}
}
