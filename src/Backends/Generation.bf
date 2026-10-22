namespace BeefForms.Backends;

internal struct Generation
{
	private uint64 mValue;

	public void Advance() mut
	{
		mValue++;
	}

	public bool IsCurrent(Generation snapshot)
	{
		return mValue == snapshot.mValue;
	}
}
