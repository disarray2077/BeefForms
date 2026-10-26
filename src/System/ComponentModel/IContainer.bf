namespace System.ComponentModel;

public interface IContainer : System.IDisposable
{
	ComponentCollection Components { get; }

	void Add(IComponent component);
	void Add(IComponent component, StringView name);
	void Remove(IComponent component);
}
