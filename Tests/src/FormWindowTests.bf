using System;
using System.Windows.Forms;
using SDL2;
using BeefForms.Backends;
using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class FormWindowTests
{
	private static void VerifyWindowSize(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.Size = .(800, 520);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		Test.Assert(form.Size.width == 800 && form.Size.height == 520);
		Test.Assert(form.ClientSize.width < form.Size.width && form.ClientSize.height < form.Size.height);
		let frame = System.Drawing.Size(form.Size.width - form.ClientSize.width, form.Size.height - form.ClientSize.height);
		form.ClientSize = .(320, 180);
		Test.Assert(form.ClientSize.width == 320 && form.ClientSize.height == 180);
		Test.Assert(form.Size.width == 320 + frame.width && form.Size.height == 180 + frame.height);
		form.Size = .(800, 520);
		Test.Assert(form.ClientSize.width == 800 - frame.width && form.ClientSize.height == 520 - frame.height);
	}
	[Test]
	public static void SDLWindowAndClientSizesAreDistinct() => VerifyWindowSize(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeWindowAndClientSizesAreDistinct() => VerifyWindowSize(.Win32);
#endif

	private static void VerifyStartPosition(ApplicationBackend backend, FormStartPosition position)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(320, 180);
		form.Location = .(80, 90);
		form.StartPosition = position;
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		if (position == .CenterScreen)
		{
			let area = Application.Backend.GetScreenWorkingArea();
			Test.Assert(form.Location.x == area.X + (area.Width - form.Size.width) / 2);
			Test.Assert(form.Location.y == area.Y + (area.Height - form.Size.height) / 2);
		}
		else
			Test.Assert(form.Location.x == 80 && form.Location.y == 90);
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32)
		{
			Win32.GetWindowRect(form.Handle, var bounds);
			Test.Assert(bounds.left == form.Location.x && bounds.top == form.Location.y);
		}
		else
#endif
		{
			SDL.GetWindowPosition((SDL.Window*)form.Handle, var x, var y);
			SDL.GetWindowBordersSize((SDL.Window*)form.Handle, var top, var left, var bottom, var right);
			Test.Assert(x - left == form.Location.x && y - top == form.Location.y);
		}
		form.Location = .(100, 120);
		form.Hide();
		form.Show();
		Test.Assert(form.Location.x == 100 && form.Location.y == 120);
	}
	[Test]
	public static void SDLFormsCenterTheirOuterBounds() => VerifyStartPosition(.SDL2OpenGL, .CenterScreen);
	[Test]
	public static void SDLFormsHonorManualInitialPositions() => VerifyStartPosition(.SDL2OpenGL, .Manual);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeFormsCenterTheirOuterBounds() => VerifyStartPosition(.Win32, .CenterScreen);
	[Test]
	public static void NativeFormsHonorManualInitialPositions() => VerifyStartPosition(.Win32, .Manual);
#endif

	private static void VerifyTextBoxHeight(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(320, 180);
		let editor = new TextBox();
		editor.Size = .(200, 50);
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		let original = editor.Size.height;
		Test.Assert(original < 50);
		editor.Font = new System.Drawing.Font("Segoe UI", 18);
		Test.Assert(editor.Size.height > original);
		editor.AutoSize = false;
		editor.Size = .(200, 50);
		Test.Assert(editor.Size.height == 50);
	}
	[Test]
	public static void SDLTextBoxHeightFollowsItsFont() => VerifyTextBoxHeight(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeTextBoxHeightFollowsItsFont() => VerifyTextBoxHeight(.Win32);
#endif

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
		form.FormClosed.Add(new [&] (sender, args) => { closed++; Test.Assert(form.IsHandleCreated && editor.IsHandleCreated); });
		form.Show();
		if (let sdl = Application.Backend as SDLBackend)
		{
			SDLTestInput.Activate(sdl);
			SDL.Event input = .();
			input.type = .WindowEvent;
			input.window.windowEvent = .Close;
			SDLTestInput.PushEvent(ref input);
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
		if (Application.Backend is SDLBackend)
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
