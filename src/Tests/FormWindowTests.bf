using System;
using System.Windows.Forms;
using SDL2;
using BeefForms.Backends;
using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class FormWindowTests
{
	private static void VerifyClosing(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 180);
		let editor = new TextBox();
		editor.Size = .(150, 25);
		form.Controls.Add(editor);
		bool pending = true;
		int requests = 0, closed = 0;
		form.FormClosing.Add(new [&] (sender, args) => { requests++; args.Cancel = pending; });
		form.FormClosed.Add(new [&] (sender, args) => { closed++; Test.Assert(!form.IsHandleCreated && !editor.IsHandleCreated); });
		form.Show();
		if (let sdl = Application.Backend as SDLBackend)
		{
			SDLTestInput.Activate(sdl);
			SDL.Event input = .();
			input.type = .WindowEvent;
			input.window.windowEvent = .Close;
			SDL.PushEvent(ref input);
			sdl.ProcessEvents();
		}
#if BF_PLATFORM_WINDOWS
		else Win32.SendMessage(form.Handle, Win32.WM_CLOSE, null, null);
#endif
		Test.Assert(requests == 1 && closed == 0 && form.IsHandleCreated);
		pending = false;
		form.Close();
		form.Close();
		Application.Backend.Run(form);
		Test.Assert(requests == 2 && closed == 1 && Application.CreatedControlCount == 0);
	}
	[Test]
	public static void SDLCloseCanBeDeferredUntilWorkCompletes() => VerifyClosing(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeCloseCanBeDeferredUntilWorkCompletes() => VerifyClosing(.Win32);
#endif

	private static void VerifyCloseDuringLoad(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(200, 120);
		form.Load.Add(new (sender, args) => ((Form)sender).Close());
		form.Show();
		Application.Backend.Run(form);
		Test.Assert(!form.IsHandleCreated);
	}
	[Test]
	public static void SDLFormCanCloseDuringLoad() => VerifyCloseDuringLoad(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeFormCanCloseDuringLoad() => VerifyCloseDuringLoad(.Win32);
#endif

	private static void VerifyMinimumSize(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(200, 100);
		form.MinimumSize = .(640, 360);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		form.ClientSize = .(100, 80);
		if (let sdl = Application.Backend as SDLBackend)
		{
			let window = (SDL.Window*)form.Handle;
			SDL.GetWindowSize(window, var width, var height);
			SDL.GetWindowBordersSize(window, var top, var left, var bottom, var right);
			Test.Assert(width + left + right >= 640 && height + top + bottom >= 360);
		}
#if BF_PLATFORM_WINDOWS
		else
		{
			Win32.GetWindowRect(form.Handle, var bounds);
			Test.Assert(bounds.right - bounds.left >= 640 && bounds.bottom - bounds.top >= 360);
			Win32.MINMAXINFO limits = .();
			Win32.SendMessage(form.Handle, Win32.WM_GETMINMAXINFO, null, (int*)(void*)&limits);
			Test.Assert(limits.minTrackSize.x >= 640 && limits.minTrackSize.y >= 360);
		}
#endif
	}
	[Test]
	public static void SDLWindowEnforcesMinimumSize() => VerifyMinimumSize(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeWindowEnforcesMinimumSize() => VerifyMinimumSize(.Win32);
#endif
}
