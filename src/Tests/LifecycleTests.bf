using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class LifecycleTests
{
	private static void VerifyLoad(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		int loads = 0;
		form.Load.Add(new [&] (sender, args) =>
		{
			loads++;
			Test.Assert(form.IsHandleCreated);
			if (backend == .SDL2OpenGL) Test.Assert((SDL.GetWindowFlags((SDL.Window*)form.Handle) & (uint32)SDL.WindowFlags.Shown) == 0);
#if BF_PLATFORM_WINDOWS
			if (backend == .Win32) Test.Assert(!Win32.IsWindowVisible(form.Handle));
#endif
		});
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		form.Hide();
		form.Show();
		form.Show();
		Test.Assert(loads == 1);
	}

	[Test]
	public static void SDLLoadsOnceBeforeShowing() => VerifyLoad(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeLoadsOnceBeforeShowing() => VerifyLoad(.Win32);
#endif

	[Test]
	public static void SDLRepaintsOnlyWhenInvalidated()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(100, 100);
		form.Controls.Add(panel);
		int paints = 0;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			paints++;
			if (paints == 1) panel.Invalidate();
		});
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		panel.Invalidate();
		Test.Assert(paints == 0);
		backend.FrameLimit = 4;
		backend.Run(form);
		Test.Assert(paints == 2);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeInvalidationDispatchesPanelPaint()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(100, 100);
		form.Controls.Add(panel);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		Win32.UpdateWindow(panel.Handle);
		int paints = 0;
		panel.Paint.Add(new [&] (sender, args) => { paints++; });
		panel.Invalidate();
		Test.Assert(paints == 0);
		Win32.UpdateWindow(panel.Handle);
		Test.Assert(paints == 1);
		Win32.UpdateWindow(panel.Handle);
		Test.Assert(paints == 1);
	}
#endif
}
