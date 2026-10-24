namespace System.ComponentModel;

public class ComponentCollection : System.Collections.ReadOnlyCollectionBase<IComponent>
{
	public this() {}
	public this(Span<IComponent> components) { InnerList.AddRange(components); }
	internal void Add(IComponent component) => InnerList.Add(component);
	public virtual IComponent this[int index] => InnerList[index];
	public virtual IComponent this[StringView name]
	{
		get
		{
			if (name.IsNull) return null;
			for (let component in InnerList)
				if (component?.Site != null && !component.Site.Name.IsNull && component.Site.Name.Equals(name, true))
					return component;
			return null;
		}
	}
	public void CopyTo(IComponent[] array, int index) => InnerList.CopyTo(array, index);
}
