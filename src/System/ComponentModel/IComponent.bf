namespace System.ComponentModel;

public interface IComponent : System.IDisposable
{
	ISite Site { get; set; }
	ref Event<System.EventHandler> Disposed { get; set; }
}
