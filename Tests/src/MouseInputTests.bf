using System;
using System.Windows.Forms;
using SDL2;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class MouseInputTests
{
	private class ClickForm : Form
	{
		public int Downs, DoubleClicks;
		public int32 DownClicks, DoubleClickCount, MoveClicks = -1, WheelClicks = -1;
		public bool CancelDown;
		protected override void OnMouseDown(MouseEventArgs args)
		{
			base.OnMouseDown(args);
			Downs++;
			DownClicks = args.Clicks;
			args.Handled = CancelDown;
		}
		protected override void OnMouseDoubleClick(MouseEventArgs args)
		{
			base.OnMouseDoubleClick(args);
			DoubleClicks++;
			DoubleClickCount = args.Clicks;
		}
		protected override void OnMouseMove(MouseEventArgs args) { base.OnMouseMove(args); MoveClicks = args.Clicks; }
		protected override void OnMouseWheel(MouseEventArgs args) { base.OnMouseWheel(args); WheelClicks = args.Clicks; }
	}

	private static void DoubleClick(ClickForm form)
	{
		if (let backend = Application.Backend as SDLBackend)
		{
			SDL.Event input = .();
			input.type = .MouseButtonDown;
			input.button.button = 1;
			input.button.clicks = 2;
			input.button.x = 20;
			input.button.y = 20;
			SDLTestInput.PushEvent(ref input);
			input.type = .MouseButtonUp;
			SDLTestInput.PushEvent(ref input);
			backend.ProcessEvents();
		}
#if BF_PLATFORM_WINDOWS
		else
			Win32.SendMessage(form.Handle, Win32.WM_LBUTTONDBLCLK, (uint*)(void*)1, (int*)(void*)0x00140014);
#endif
	}

	private static void VerifyDoubleClick(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope ClickForm();
		form.ClientSize = .(240, 160);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		if (let sdl = Application.Backend as SDLBackend) SDLTestInput.Activate(sdl);
#if BF_PLATFORM_WINDOWS
		else Test.Assert((Win32.GetClassLong(form.Handle, Win32.GCL_STYLE) & Win32.CS_DBLCLKS) != 0);
#endif
		DoubleClick(form);
		Test.Assert(form.Downs == 1 && form.DoubleClicks == 1 && form.DownClicks == 2 && form.DoubleClickCount == 2);
		form.CancelDown = true;
		DoubleClick(form);
		Test.Assert(form.Downs == 2 && form.DoubleClicks == 1);
	}

	[Test]
	public static void SDLDoubleClickIncludesMouseDown() => VerifyDoubleClick(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeDoubleClickIncludesMouseDown() => VerifyDoubleClick(.Win32);

	[Test]
	public static void NativeMovementAndWheelHaveNoClicks()
	{
		Application.UseBackend(.Win32);
		let form = scope ClickForm();
		form.ClientSize = .(240, 160);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		Win32.SendMessage(form.Handle, Win32.WM_MOUSEMOVE, null, null);
		Win32.SendMessage(form.Handle, Win32.WM_MOUSEWHEEL, (uint*)(void*)(120 << 16), null);
		Test.Assert(form.MoveClicks == 0 && form.WheelClicks == 0);
	}
#endif
}
