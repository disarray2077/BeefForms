using System;
using System.Collections;

namespace BeefForms.Backends;

static
{
	private static mixin ToScopedArray<T>(List<T> source)
	{
		T[] sessions;
		if (source.Count <= 16)
		    sessions = scope:mixin T[source.Count](?);
		else
		{
		    sessions = new T[source.Count](?);
		    defer:mixin delete sessions;
		}
		for (let session in source)
			sessions[@session.Index] = session;
		sessions
	}

	private static mixin ToScopedArray<T>(List<T> source) where T : RefCounted
	{
		T[] sessions;
		if (source.Count <= 16)
		    sessions = scope:mixin T[source.Count](?);
		else
		{
		    sessions = new T[source.Count](?);
		    defer:mixin delete sessions;
		}
		for (let session in source)
		{
			session.AddRef();
			sessions[@session.Index] = session;
		}
		static void ReleaseAll<T>(T[] source) where T : RefCounted { for (let session in source) session.ReleaseRef(); }
		defer:mixin ReleaseAll<T>(sessions);
		sessions
	}
}