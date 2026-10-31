using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

extension Application
{
	public new static void UseBackend(ApplicationBackend backend)
	{
		UseBackend(backend, render: false);
	}

	public static void UseBackend(ApplicationBackend backend, bool render)
	{
		[NoExtension]UseBackend(backend);
		if (let sdl = Backend as SDLBackend)
			sdl.RenderingEnabled = render;
	}
}
