namespace BeefForms.Backends;

static
{
	private static mixin DeleteDictionaryValues(var container)
	{
		if (container != null)
		{
			for (let entry in container)
				delete entry.value;
		}
	}

	private static mixin DeleteDictionaryKeysAndValues(var container)
	{
		if (container != null)
		{
			for (let entry in container)
			{
				delete entry.key;
				delete entry.value;
			}
		}
	}
}

