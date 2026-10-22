using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class CallbackLifecycleTests
{
	private enum CloseInput { MouseEnter, MouseDown, DoubleClick, MouseUp, KeyDown, KeyPreview, TextInput, KeyPress }

	private static void TrackClose(Form form, String events)
	{
		form.FormClosing.Add(new (sender, args) =>
		{
			Test.Assert(events == "B" && form.IsHandleCreated && !form.IsDisposed && !form.Disposing);
			events.Append('C');
		});
		form.FormClosed.Add(new (sender, args) =>
		{
			Test.Assert(events == "BC" && !form.IsHandleCreated && !form.IsDisposed && !form.Disposing);
			events.Append('D');
		});
		form.Disposed.Add(new (sender, args) =>
		{
			Test.Assert(events == "BCD" && form.Disposing && !form.IsDisposed);
			Test.Assert(form.Controls.IsEmpty);
			events.Append('S');
		});
	}

	private static void CloseSynchronously(Form form, String events)
	{
		events.Append('B');
		form.Close();
		Test.Assert(events == "BCDS" && !form.IsHandleCreated && form.IsDisposed && !form.Disposing);
		events.Append('R');
	}

	private static void VerifyCloseDuringPaint(ApplicationBackend backend, bool firstFrame)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let parent = new Panel();
		parent.Size = .(200, 140);
		let panel = new Panel();
		panel.Size = .(100, 100);
		let child = new Panel();
		child.Size = .(50, 50);
		panel.Controls.Add(child);
		parent.Controls.Add(panel);
		form.Controls.Add(parent);
		form.Show();
		if (!firstFrame)
		{
			if (let sdl = Application.Backend as SDLBackend) SDLTestInput.Activate(sdl);
#if BF_PLATFORM_WINDOWS
			else Win32.UpdateWindow(panel.Handle);
#endif
		}

		let events = scope String();
		TrackClose(form, events);
		int childPaints = 0;
		child.Paint.Add(new [&] (sender, args) => { childPaints++; });
		panel.Paint.Add(new (sender, args) => { CloseSynchronously(form, events); });
		// Closing must not interrupt application code or the current delegate invocation.
		panel.Paint.Add(new (sender, args) => { events.Append('2'); });
		panel.Invalidate();
		if (let sdl = Application.Backend as SDLBackend)
		{
			Test.Assert(sdl.[Friend]RenderIfNeeded());
			Test.Assert(sdl.GetSession(form) == null);
			Test.Assert(!sdl.[Friend]IsRendering && !sdl.[Friend]RenderIfNeeded());
			Test.Assert(childPaints == 0);
		}
#if BF_PLATFORM_WINDOWS
		else
		{
			Win32.UpdateWindow(panel.Handle);
			Application.Backend.Run(form); // Drain WM_QUIT before the next test.
		}
#endif
		Test.Assert(events == "BCDSR2");
		Test.Assert(!parent.IsHandleCreated && !child.IsHandleCreated);
		Test.Assert(parent.IsDisposed && panel.IsDisposed && child.IsDisposed);
		Test.Assert(Application.CreatedControlCount == 0);
		Application.DoEvents();
	}

	[Test]
	public static void SDLCloseDuringFirstPaintStopsTraversal() => VerifyCloseDuringPaint(.SDL2OpenGL, true);
	[Test]
	public static void SDLCloseDuringLaterPaintStopsTraversal() => VerifyCloseDuringPaint(.SDL2OpenGL, false);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeCloseDuringPaintRemainsSynchronous() => VerifyCloseDuringPaint(.Win32, false);
#endif

	private static void VerifyCloseDuringInput(ApplicationBackend backend, CloseInput kind)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let editor = new TextBox();
		editor.Size = .(160, 30);
		editor.Text = "seed";
		form.Controls.Add(editor);
		form.Show();
		let sdl = Application.Backend as SDLBackend;
		if (sdl != null) SDLTestInput.Activate(sdl);
		editor.Focus();
		editor.SelectAll();
		if (kind == .MouseEnter)
		{
			if (sdl != null) sdl.GetSession(form).Hover(null);
#if BF_PLATFORM_WINDOWS
			else Win32.SendMessage(editor.Handle, Win32.WM_MOUSELEAVE, null, null);
#endif
		}
		if (kind == .MouseUp && sdl != null)
		{
			SDL.Event down = .();
			down.type = .MouseButtonDown;
			down.button.button = 1;
			down.button.clicks = 1;
			down.button.x = 10;
			down.button.y = 10;
			SDLTestInput.SetWindow(ref down, form);
			sdl.[Friend]ProcessEvent(ref down);
		}

		let events = scope String();
		TrackClose(form, events);
		int doubleClicks = 0, keyPresses = 0, targetKeys = 0;
		int parentEnters = 0;
		form.MouseEnter.Add(new [&] (sender, args) => { parentEnters++; });
		editor.MouseDoubleClick.Add(new [&] (sender, args) => { doubleClicks++; });
		editor.KeyDown.Add(new [&] (sender, args) => { targetKeys++; });
		editor.KeyPress.Add(new [&] (sender, args) => { keyPresses++; });
		switch (kind)
		{
		case .MouseEnter: editor.MouseEnter.Add(new (sender, args) => { CloseSynchronously(form, events); });
		case .MouseDown, .DoubleClick: editor.MouseDown.Add(new (sender, args) => { CloseSynchronously(form, events); });
		case .MouseUp: editor.MouseUp.Add(new (sender, args) => { CloseSynchronously(form, events); });
		case .KeyDown: editor.KeyDown.Add(new (sender, args) => { CloseSynchronously(form, events); });
		case .KeyPreview:
			form.KeyPreview = true;
			form.KeyDown.Add(new (sender, args) => { CloseSynchronously(form, events); });
		case .TextInput: editor.TextInput.Add(new (sender, args) => { CloseSynchronously(form, events); });
		case .KeyPress: editor.KeyPress.Add(new (sender, args) => { CloseSynchronously(form, events); });
		}

		let text = scope String(editor.Text);
		if (sdl != null)
		{
			SDL.Event input = .();
			switch (kind)
			{
			case .MouseEnter:
				input.type = .MouseMotion;
				input.motion.x = 10;
				input.motion.y = 10;
			case .MouseDown, .DoubleClick, .MouseUp:
				input.type = kind == .MouseUp ? .MouseButtonUp : .MouseButtonDown;
				input.button.button = 1;
				input.button.clicks = kind == .DoubleClick ? 2 : 1;
				input.button.x = 10;
				input.button.y = 10;
			case .KeyDown, .KeyPreview:
				input.type = .KeyDown;
				input.key.keysym.sym = .BACKSPACE;
			case .TextInput, .KeyPress:
				input.type = .TextInput;
				let typed = "ab";
				Internal.MemCpy(&input.text.text, typed.Ptr, typed.Length);
			}
			SDLTestInput.PushEvent(ref input);
			Application.DoEvents();
			Test.Assert(sdl.GetSession(form) == null);
		}
#if BF_PLATFORM_WINDOWS
		else
		{
			uint32 message;
			switch (kind)
			{
			case .MouseEnter: message = Win32.WM_MOUSEMOVE;
			case .MouseDown: message = Win32.WM_LBUTTONDOWN;
			case .DoubleClick: message = Win32.WM_LBUTTONDBLCLK;
			case .MouseUp: message = Win32.WM_LBUTTONUP;
			case .KeyDown, .KeyPreview: message = Win32.WM_KEYDOWN;
			case .TextInput, .KeyPress: message = Win32.WM_CHAR;
			}
			let key = kind == .TextInput || kind == .KeyPress ? (uint)'a' : (uint)Keys.Back;
			Win32.SendMessage(editor.Handle, message, (uint*)(void*)key, (int*)(void*)((10 << 16) | 10));
			Application.Backend.Run(form);
		}
#endif
		Test.Assert(events == "BCDSR");
		Test.Assert(editor.Text == text && !editor.IsHandleCreated);
		Test.Assert(editor.IsDisposed && !editor.Disposing);
		Test.Assert(doubleClicks == 0);
		Test.Assert(keyPresses == (kind == .KeyPress ? 1 : 0));
		Test.Assert(targetKeys == (kind == .KeyDown ? 1 : 0));
		Test.Assert(kind != .MouseEnter || parentEnters == 0);
		Test.Assert(Application.CreatedControlCount == 0);
	}

	[Test]
	public static void SDLInputClosureStopsDefaultBehavior()
	{
		for (let kind in Enum.GetValues<CloseInput>()) VerifyCloseDuringInput(.SDL2OpenGL, kind);
	}
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeInputClosureStopsDefaultBehavior()
	{
		for (let kind in Enum.GetValues<CloseInput>()) VerifyCloseDuringInput(.Win32, kind);
	}
#endif

	[Test]
	public static void SDLCloseDuringLostFocusDoesNotReenterOrFocusTheTarget()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let first = new TextBox();
		first.Size = .(100, 30);
		let second = new TextBox();
		second.Size = first.Size;
		second.Location = .(0, 40);
		form.Controls.Add(first);
		form.Controls.Add(second);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		first.Focus();
		let events = scope String();
		TrackClose(form, events);
		int gotFocus = 0;
		first.LostFocus.Add(new (sender, args) => { CloseSynchronously(form, events); });
		second.GotFocus.Add(new [&] (sender, args) => { gotFocus++; });
		second.Focus();
		Test.Assert(events == "BCDSR" && gotFocus == 0);
		Test.Assert(backend.GetSession(form) == null);
	}

	private static void VerifyCancelledClose(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(200, 120);
		let editor = new TextBox();
		editor.Size = .(100, 30);
		panel.Controls.Add(editor);
		form.Controls.Add(panel);
		form.Show();
		let sdl = Application.Backend as SDLBackend;
		if (sdl != null) SDLTestInput.Activate(sdl);
		editor.Focus();
		bool cancel = true;
		int closing = 0, closed = 0, paints = 0;
		form.FormClosing.Add(new [&] (sender, args) => { closing++; args.Cancel = cancel; });
		form.FormClosed.Add(new [&] (sender, args) => { closed++; });
		panel.Paint.Add(new [&] (sender, args) =>
		{
			paints++;
			form.Close();
			Test.Assert(form.IsHandleCreated && !form.IsDisposed && !panel.IsDisposed && closed == 0);
		});
		panel.Invalidate();
		if (sdl != null) Test.Assert(sdl.[Friend]RenderIfNeeded());
#if BF_PLATFORM_WINDOWS
		else Win32.UpdateWindow(panel.Handle);
#endif
		Test.Assert(paints == 1 && closing == 1 && form.IsHandleCreated);
		editor.TextInput.Add(new (sender, args) => { form.Close(); });
		if (sdl != null) SDLTestInput.TypeText(sdl, "x");
#if BF_PLATFORM_WINDOWS
		else Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(uint)'x', null);
#endif
		Test.Assert(editor.Text == "x" && closing == 2 && closed == 0);
		Test.Assert(!form.IsDisposed && !editor.IsDisposed && !form.Disposing && !editor.Disposing);
		cancel = false;
		form.Close();
		Test.Assert(closing == 3 && closed == 1 && !form.IsHandleCreated);
		Test.Assert(form.IsDisposed && panel.IsDisposed && editor.IsDisposed);
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32) Application.Backend.Run(form);
#endif
	}

	[Test]
	public static void SDLCancelledCloseAllowsPaintAndDefaultEditing() => VerifyCancelledClose(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeCancelledCloseAllowsPaintAndDefaultEditing() => VerifyCancelledClose(.Win32);
#endif

	private static void VerifyCloseDuringWheel(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(180, 100);
		panel.AutoScroll = true;
		let content = new Panel();
		content.Location = .(0, 400);
		content.Size = .(100, 50);
		panel.Controls.Add(content);
		form.Controls.Add(panel);
		form.Show();
		let events = scope String();
		TrackClose(form, events);
		panel.MouseWheel.Add(new (sender, args) => { CloseSynchronously(form, events); });
		panel.DispatchMouseWheel(scope MouseEventArgs(.None, 0, 10, 10, -120));
		Test.Assert(events == "BCDSR" && panel.ScrollPosition.y == 0);
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32) Application.Backend.Run(form);
#endif
	}

	[Test]
	public static void SDLCloseDuringWheelSkipsScrolling() => VerifyCloseDuringWheel(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeCloseDuringWheelSkipsScrolling() => VerifyCloseDuringWheel(.Win32);
#endif
}
