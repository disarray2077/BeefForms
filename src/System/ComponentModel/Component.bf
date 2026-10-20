namespace System.ComponentModel;

public class Component : IComponent
{
    public ref Event<System.EventHandler> Disposed { get; set; } ~ _.Dispose();
    public virtual ISite Site { get; set; }

	public ~this()
	{
		Disposed.Invoke(this, System.EventArgs.Empty);
	}
}