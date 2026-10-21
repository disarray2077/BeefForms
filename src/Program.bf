using System;
using System.Windows.Forms;
using BeefForms.Backends;
using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms
{
	class Program
	{
		public static int Main(String[] args)
		{
			let capturePath = scope String();
			for (let arg in args)
				if (arg == "--sdl")
					Application.UseBackend(.SDL2OpenGL);
			if (let backend = Application.Backend as SDLBackend)
				for (let arg in args)
				{
					if (arg.StartsWith("--frames="))
						backend.FrameLimit = int.Parse(.(arg, 9)).GetValueOrDefault();
					if (arg.StartsWith("--capture="))
					{
						capturePath.Set(.(arg, 10));
						backend.CapturePath = capturePath;
					}
				}
			Application.EnableVisualStyles();
			Application.SetCompatibleTextRenderingDefault(defaultValue: false);
			Application.Run(new DownloaderMockForm());
			return 0;
		}
	}
}
