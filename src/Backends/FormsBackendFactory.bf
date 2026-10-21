using System;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class FormsBackendFactory
{
	public static FormsBackendFactory Instance
	{
		get
		{
			static FormsBackendFactory instance = null;
			if (instance == null)
				instance = new .();
			return instance;
		}
	}

#if BF_PLATFORM_WINDOWS
	public FormsBackend CreateDefaultBackend() => CreateWin32Backend();

	public FormsBackend CreateWin32Backend()
	{
		return new Win32Backend();
	}

	public virtual FormsBackend CreateSDLBackend()
		=> Runtime.FatalError("The SDL backend requires a dependency on BeefForms.SDL");
#else
	public FormsBackend CreateDefaultBackend() => CreateSDLBackend();

	public extern FormsBackend CreateSDLBackend();
#endif
}
