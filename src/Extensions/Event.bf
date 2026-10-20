namespace System;

public extension Event<T>
{
	public implicit void operator+=(T e) mut
	{
		Add(e);
	}

	public implicit void operator-=(T e) mut
	{
		Remove(e, true).IgnoreError();
	}
}