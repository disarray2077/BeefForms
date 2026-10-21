namespace System.Windows.Forms;

public class ButtonBase : Control
{
	public this() { TabStop = true; }
	public bool UseVisualStyleBackColor { get; set; }
	public ref Event<EventHandler> Click { get; set; } ~ _.Dispose();
	public void PerformClick()
	{
		if (CanSelect) OnClick(.Empty);
	}
	protected virtual void OnClick(EventArgs args) => Click.Invoke(this, args);
}
