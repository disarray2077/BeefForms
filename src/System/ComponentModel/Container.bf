using System.Collections;

using internal System.ComponentModel;

namespace System.ComponentModel;

/// Manages component disposal; component allocations remain owned by their callers.
public class Container : IContainer
{
	private append List<ISite> mSites = .();
	private append List<ISite> mOwnedSites = .() ~ _.ClearAndDeleteItems();
	private append List<ComponentCollection> mCollections = .() ~ _.ClearAndDeleteItems();
	private ComponentCollection mComponents;

	private class ComponentSite : ISite
	{
		private IComponent mComponent;
		private Container mContainer;
		private append String mName = .();
		private bool mHasName;
		public IComponent Component => mComponent;
		public IContainer Container => mContainer;
		public bool DesignMode => false;
		public StringView Name
		{
			get => mHasName ? mName : null;
			set
			{
				mContainer.ValidateName(mComponent, value);
				mName.Set(value);
				mHasName = !value.IsNull;
			}
		}
		public this(IComponent component, Container container, StringView name)
		{
			mComponent = component;
			mContainer = container;
			mName.Set(name);
			mHasName = !name.IsNull;
		}
	}

	public this() {}
	public ~this() { Dispose(); }
	public virtual void Add(IComponent component) => Add(component, null);
	public virtual void Add(IComponent component, StringView name)
	{
		if (component == null || component.Site?.Container == this) return;
		ValidateName(component, name);
		component.Site?.Container?.Remove(component);
		let site = CreateSite(component, name);
		mSites.Add(site);
		mOwnedSites.Add(site);
		mComponents = null;
		component.Site = site;
	}

	protected virtual ISite CreateSite(IComponent component, StringView name) => new ComponentSite(component, this, name);
	protected virtual void ValidateName(IComponent component, StringView name)
	{
		if (component == null) Runtime.FatalError("A component is required");
		if (name.IsNull) return;
		for (let site in mSites)
			if (site.Component != component && !site.Name.IsNull && site.Name.Equals(name, true))
				Runtime.FatalError("Component names must be unique within a container");
	}

	public virtual void Remove(IComponent component)
	{
		let site = component?.Site;
		if (site?.Container != this) return;
		component.Site = null;
		mSites.Remove(site);
		mComponents = null;
	}

	/// Borrowed snapshots remain allocated until the container is deleted.
	public virtual ComponentCollection Components
	{
		get
		{
			if (mComponents == null)
			{
				mComponents = new .();
				for (let site in mSites) mComponents.Add(site.Component);
				mCollections.Add(mComponents);
			}
			return mComponents;
		}
	}

	public void Dispose() => Dispose(true);
	protected virtual void Dispose(bool disposing)
	{
		if (!disposing) return;
		while (!mSites.IsEmpty)
		{
			let site = mSites.PopBack();
			mComponents = null;
			let component = site.Component;
			component.Site = null;
			component.Dispose();
		}
	}
}
