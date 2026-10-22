using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class MultiWindowTests
{
	private class OwnedForm : Form
	{
		private bool* mDeleted;
		public this(bool* deleted) { mDeleted = deleted; ClientSize = .(240, 140); }
		public ~this() { *mDeleted = true; }
	}

	private static void VerifyIndependentWindows(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let main = scope Form();
		let secondary = scope Form();
		main.ClientSize = .(260, 140);
		secondary.ClientSize = .(180, 110);
		main.Show();
		secondary.Show();
		Test.Assert(main.Handle != secondary.Handle);
		main.Text = "main title";
		secondary.Text = "secondary title";
		secondary.ClientSize = .(210, 130);
		Test.Assert(main.ClientSize.width == 260 && main.ClientSize.height == 140);
		Test.Assert(secondary.ClientSize.width == 210 && secondary.ClientSize.height == 130);
		if (backend == .SDL2OpenGL)
		{
			Test.Assert(StringView(SDL.GetWindowTitle((SDL.Window*)main.Handle)) == "main title");
			Test.Assert(StringView(SDL.GetWindowTitle((SDL.Window*)secondary.Handle)) == "secondary title");
		}
		int closes = 0;
		secondary.FormClosed.Add(new [&] (sender, args) => { closes++; });
		secondary.Close();
		Test.Assert(secondary.IsDisposed && closes == 1 && main.IsHandleCreated && !main.IsDisposed);
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32)
		{
			Win32.MSG message = ?;
			Test.Assert(Win32.PeekMessage(out message, null, Win32.WM_QUIT, Win32.WM_QUIT, Win32.PM_REMOVE) == 0);
		}
#endif
		Application.DoEvents();
		main.ClientSize = .(300, 150);
		Test.Assert(main.ClientSize.width == 300 && main.ClientSize.height == 150);
	}

	[Test]
	public static void SDLWindowsHaveIndependentBoundsTitlesAndLifetimes() => VerifyIndependentWindows(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeSecondaryClosureDoesNotPostQuit() => VerifyIndependentWindows(.Win32);
#endif

	private static void QueueClose(Form form, ApplicationBackend backend)
	{
		if (backend == .SDL2OpenGL)
		{
			SDL.Event input = .();
			input.type = .WindowEvent;
			input.window.windowEvent = .Close;
			SDLTestInput.PushEvent(ref input, form);
		}
#if BF_PLATFORM_WINDOWS
		else Win32.PostMessage(form.Handle, Win32.WM_CLOSE, null, null);
#endif
	}

	private static void VerifyRun(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		if (let sdl = Application.Backend as SDLBackend) sdl.FrameLimit = 0;
		bool deleted = false, cancel = true;
		let main = new OwnedForm(&deleted);
		let secondary = scope Form();
		let survivor = scope Form();
		secondary.ClientSize = survivor.ClientSize = .(180, 100);
		int attempts = 0, closed = 0, survivorClosing = 0, survivorClosed = 0, survivorDisposed = 0;
		main.FormClosing.Add(new [&] (sender, args) => { attempts++; args.Cancel = cancel; });
		main.FormClosed.Add(new [&] (sender, args) => { closed++; });
		survivor.FormClosing.Add(new [&] (sender, args) => { survivorClosing++; });
		survivor.FormClosed.Add(new [&] (sender, args) => { survivorClosed++; });
		survivor.Disposed.Add(new [&] (sender, args) => { survivorDisposed++; Test.Assert(!deleted); });
		main.Load.Add(new [&] (sender, args) =>
		{
			secondary.Show();
			secondary.Close();
			survivor.Show();
			main.Close();
			Test.Assert(attempts == 1 && closed == 0 && main.IsHandleCreated && survivor.IsHandleCreated);
			cancel = false;
			QueueClose(main, backend);
		});
		Application.Run(main);
		Test.Assert(attempts == 2 && closed == 1 && deleted);
		Test.Assert(survivor.IsDisposed && !survivor.IsHandleCreated);
		Test.Assert(survivorClosing == 0 && survivorClosed == 0 && survivorDisposed == 1);
		Test.Assert(Application.CreatedControlCount == 0 && Application.[Friend]sOpenForms.IsEmpty);
		Test.Assert(!Application.[Friend]sRunning && Application.[Friend]sMainForm == null);
	}

	[Test]
	public static void SDLRunExitsOnMainClosureAndDisposesRemainingWindows() => VerifyRun(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeRunExitsOnMainClosureAndDisposesRemainingWindows() => VerifyRun(.Win32);
#endif

	private static void Dispatch(SDLBackend backend, Form form, ref SDL.Event input)
	{
		SDLTestInput.SetWindow(ref input, form);
		backend.[Friend]ProcessEvent(ref input);
	}

	private static void Activate(SDLBackend backend, Form form)
	{
		SDL.Event input = .();
		input.type = .WindowEvent;
		input.window.windowEvent = .FocusGained;
		Dispatch(backend, form, ref input);
	}

	private static void Type(SDLBackend backend, Form form, char8 text)
	{
		SDL.Event input = .();
		input.type = .TextInput;
		input.text.text[0] = (uint8)text;
		Dispatch(backend, form, ref input);
	}

	[Test]
	public static void SDLInputAndCaptureAreRoutedToTheirWindow()
	{
		Application.UseBackend(.SDL2OpenGL);
		let first = scope Form(); let second = scope Form();
		first.ClientSize = second.ClientSize = .(200, 100);
		let a = new TextBox(); let b = new TextBox();
		a.Size = b.Size = .(150, 25);
		first.Controls.Add(a); second.Controls.Add(b);
		first.Show(); second.Show();
		Application.DoEvents();
		let backend = (SDLBackend)Application.Backend;
		Activate(backend, first); a.Focus(); Type(backend, first, 'a');
		Activate(backend, second); b.Focus(); Type(backend, second, 'b');
		Type(backend, first, 'x'); // Inactive windows must not accept keyboard input.
		Test.Assert(a.Text == "a" && b.Text == "b" && !a.Focused && b.Focused);
		SDL.Event key = .(); key.type = .KeyDown; key.key.keysym.sym = .BACKSPACE;
		Dispatch(backend, second, ref key);
		Test.Assert(a.Text == "a" && b.Text.IsEmpty);
		a.Capture = true; b.Capture = true;
		Test.Assert(!a.Capture && b.Capture);
		int aDowns = 0, bDowns = 0;
		a.MouseDown.Add(new [&] (sender, args) => { aDowns++; args.Handled = true; });
		b.MouseDown.Add(new [&] (sender, args) => { bDowns++; args.Handled = true; });
		SDL.Event down = .(); down.type = .MouseButtonDown; down.button.button = 1; down.button.x = down.button.y = 10;
		Dispatch(backend, first, ref down); Dispatch(backend, second, ref down);
		Test.Assert(aDowns == 1 && bDowns == 1);
		let staleID = SDL.GetWindowID((SDL.Window*)first.Handle);
		first.Close();
		down.button.windowID = staleID;
		backend.[Friend]ProcessEvent(ref down);
		Type(backend, second, 'c');
		Test.Assert(aDowns == 1 && bDowns == 1 && b.Text == "c" && second.IsHandleCreated);
	}

	[Test]
	public static void SDLQueuedEventsContinueAfterSecondaryClosure()
	{
		Application.UseBackend(.SDL2OpenGL);
		let main = scope Form(); let secondary = scope Form();
		main.ClientSize = secondary.ClientSize = .(200, 100);
		let editor = new TextBox(); editor.Size = .(150, 25); main.Controls.Add(editor);
		main.Show(); secondary.Show(); Application.DoEvents();
		editor.Focus();
		QueueClose(secondary, .SDL2OpenGL);
		SDL.Event active = .(); active.type = .WindowEvent; active.window.windowEvent = .FocusGained;
		SDLTestInput.PushEvent(ref active, main);
		SDL.Event text = .(); text.type = .TextInput; text.text.text[0] = (uint8)'q';
		SDLTestInput.PushEvent(ref text, main);
		Application.DoEvents();
		Test.Assert(secondary.IsDisposed && main.IsHandleCreated && editor.Text == "q");
	}

	[Test]
	public static void SDLReparentingBetweenWindowsUpdatesInputAndRenderingOwnership()
	{
		Application.UseBackend(.SDL2OpenGL);
		let first = scope Form(); let second = scope Form();
		first.ClientSize = second.ClientSize = .(200, 100);
		let editor = new TextBox(); editor.Size = .(150, 25); first.Controls.Add(editor);
		first.Show(); second.Show(); Application.DoEvents();
		let backend = (SDLBackend)Application.Backend;
		second.Controls.Add(editor);
		Test.Assert(backend.GetSession(editor) == backend.GetSession(second));
		first.Close(); Activate(backend, second); editor.Focus(); Type(backend, second, 'r');
		Application.DoEvents();
		Test.Assert(editor.Text == "r" && editor.IsHandleCreated);
		SDLTestInput.AssertNoGLError(second);
	}

	[Test]
	public static void SDLClosingAnotherWindowDuringPaintRestoresTheRenderingContext()
	{
		Application.UseBackend(.SDL2OpenGL);
		let first = scope Form(); let second = scope Form();
		first.ClientSize = second.ClientSize = .(200, 100);
		let a = new Panel(); let b = new Panel();
		a.Size = b.Size = .(180, 80); first.Controls.Add(a); second.Controls.Add(b);
		first.Show(); second.Show();
		let backend = (SDLBackend)Application.Backend;
		int paints = 0, secondPaints = 0;
		b.Paint.Add(new [&] (sender, args) => { secondPaints++; });
		a.Paint.Add(new [&] (sender, args) =>
		{
			paints++;
			Test.Assert(SDL.GL_GetCurrentWindow() == first.Handle);
			second.Close();
			Test.Assert(SDL.GL_GetCurrentWindow() == first.Handle);
		});
		Application.DoEvents();
		Test.Assert(paints == 1 && secondPaints == 0 && second.IsDisposed && first.IsHandleCreated);
		SDLTestInput.AssertNoGLError(first);
		a.Invalidate(); Application.DoEvents();
		Test.Assert(paints == 2);
		SDLTestInput.AssertNoGLError(first);
		Test.Assert(backend.[Friend]mSessions.Count == 1);
	}

	[Test]
	public static void SDLClosingTheFirstWindowDuringPaintStillRendersTheSecond()
	{
		Application.UseBackend(.SDL2OpenGL);
		let first = scope Form(); let second = scope Form();
		first.ClientSize = second.ClientSize = .(200, 100);
		let a = new Panel(); let b = new Panel();
		a.Size = b.Size = .(180, 80); first.Controls.Add(a); second.Controls.Add(b);
		int secondPaints = 0;
		a.Paint.Add(new (sender, args) => { first.Close(); });
		b.Paint.Add(new [&] (sender, args) =>
		{
			secondPaints++;
			Test.Assert(SDL.GL_GetCurrentWindow() == second.Handle);
		});
		first.Show(); second.Show(); Application.DoEvents();
		Test.Assert(first.IsDisposed && second.IsHandleCreated && secondPaints == 1);
		SDLTestInput.AssertNoGLError(second);
	}

	[Test]
	public static void SDLCreatingAndClosingAWindowDuringPaintPreservesTheOriginalFrame()
	{
		Application.UseBackend(.SDL2OpenGL);
		let first = scope Form(); let second = scope Form();
		first.ClientSize = second.ClientSize = .(200, 100);
		let panel = new Panel(); panel.Size = .(180, 80); first.Controls.Add(panel);
		int paints = 0;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			paints++; second.Show();
			Test.Assert(SDL.GL_GetCurrentWindow() == first.Handle);
			second.Close();
			Test.Assert(SDL.GL_GetCurrentWindow() == first.Handle);
		});
		first.Show(); Application.DoEvents();
		Test.Assert(paints == 1 && first.IsHandleCreated && second.IsDisposed);
		SDLTestInput.AssertNoGLError(first);
	}

	[Test]
	public static void ScheduledFramesKeepRunningAfterSecondaryClosureAndCleanUpOnMainClosure()
	{
		Application.UseBackend(.SDL2OpenGL);
		bool deleted = false;
		let main = new OwnedForm(&deleted);
		let secondary = scope Form(); let survivor = scope Form();
		secondary.ClientSize = survivor.ClientSize = .(180, 100);
		Application.[Friend]BeginRun(main);
		secondary.Show(); secondary.Close();
		int stops = 0;
		Application.[Friend]RunFrame(scope [&] () => { stops++; });
		Test.Assert(stops == 0 && !deleted && Application.[Friend]sRunning);
		survivor.Show(); main.Close();
		Test.Assert(!deleted && survivor.IsHandleCreated);
		Application.[Friend]RunFrame(scope [&] () => { stops++; });
		Test.Assert(stops == 1 && deleted && survivor.IsDisposed && !survivor.IsHandleCreated);
		Test.Assert(Application.CreatedControlCount == 0 && Application.[Friend]sOpenForms.IsEmpty);
	}
}
