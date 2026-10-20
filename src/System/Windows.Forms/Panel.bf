namespace System.Windows.Forms;

public class Panel : ScrollableControl
{
	protected override bool CanSelectCore() => false;
	protected internal override void NotifyPaint()
	{
		base.NotifyPaint();
		Paint.Invoke(this, scope .());
	}

	public ref Event<PaintEventHandler> Paint { get; set; } ~ _.Dispose();
}
