namespace System.ComponentModel;

public interface IContainer : System.IDisposable
{
    ComponentCollection Components { get; }
    void Add(IComponent component);
    void Remove(IComponent component);
}