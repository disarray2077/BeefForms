using System;
using System.Windows.Forms;
using BeefForms.Backends;
using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class LabelTests
{
	private static void VerifyLayout(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 180);
		let message = new Label();
		message.Size = .(280, 60);
		message.Text = "No downloads yet.\nEnter a URL to start.";
		message.TextAlign = .MiddleCenter;
		let title = new Label();
		title.Location = .(0, 70);
		title.Size = .(120, 25);
		title.AutoEllipsis = true;
		title.Text = "https://example.com/a-very-long-download-path";
		form.Controls.Add(message);
		form.Controls.Add(title);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		if (let sdl = Application.Backend as SDLBackend)
		{
			sdl.FrameLimit = 1;
			sdl.Run(form);
			SDLTestInput.AssertNoGLError(form);
		}
#if BF_PLATFORM_WINDOWS
		else
		{
			Win32.UpdateWindow(message.Handle);
			Win32.UpdateWindow(title.Handle);
		}
#endif
		Test.Assert(message.Text == "No downloads yet.\nEnter a URL to start." && title.Text.EndsWith("path"));
	}
	[Test]
	public static void SDLLabelsRenderAlignedAndEllipsizedText() => VerifyLayout(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeLabelsRenderAlignedAndEllipsizedText() => VerifyLayout(.Win32);
#endif
}
