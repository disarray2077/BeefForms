using System;
using System.Collections;

namespace BeefForms.Backends;

static
{
	internal static mixin ToScopedArray<T, TCollection>(TCollection source)
		where TCollection : IEnumerable<T>
		where TCollection : var
	{
		T[] items;
		if (source.Count <= 16)
			items = scope:mixin T[source.Count](?);
		else
		{
			items = new T[source.Count](?);
			defer:mixin delete items;
		}
		int index = 0;
		for (let item in source)
			items[index++] = item;
		items
	}

	internal static mixin ToScopedArray<T, TCollection>(TCollection source)
		where TCollection : IEnumerable<T>
		where TCollection : var
		where T : RefCounted
	{
		T[] items;
		if (source.Count <= 16)
			items = scope:mixin T[source.Count](?);
		else
		{
			items = new T[source.Count](?);
			defer:mixin delete items;
		}
		int index = 0;
		for (let item in source)
		{
			item.AddRef();
			items[index++] = item;
		}
		static void ReleaseAll<T>(T[] source) where T : RefCounted { for (let item in source) item.ReleaseRef(); }
		defer:mixin ReleaseAll<T>(items);
		items
	}
}
