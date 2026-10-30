namespace System.Windows.Forms;

public class UserControl : ContainerControl
{
	public ref Event<EventHandler> Load { get; set; } ~ _.Dispose();

	public AutoSizeMode AutoSizeMode
	{
		get => GetAutoSizeMode();
		set => SetAutoSizeMode(value);
	}

	public this()
	{
		Size = .(150, 150);
		TabStop = true;
		AutoScaleMode = .Inherit;
	}

	protected override void OnCreateControl()
	{
		base.OnCreateControl();
		OnLoad(.Empty);
	}

	protected virtual void OnLoad(EventArgs args)
	{
		Load.Invoke(this, args);
	}
}
