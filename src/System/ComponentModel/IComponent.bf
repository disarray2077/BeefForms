namespace System.ComponentModel;

public interface IComponent
{
    ISite Site { get; set; }
    ref Event<System.EventHandler> Disposed { get; set; }
}