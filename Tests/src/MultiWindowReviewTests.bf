using System;
using System.Threading;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class MultiWindowReviewTests
{
	private enum ContextOperation { Create, Render, Input }

	private class ExternalContext
	{
		public SDL.Window* Window;
		public SDL.SDL_GLContext Context;
		public this()
		{
			Test.Assert(SDL.InitSubSystem(.Video) == 0);
			SDL.GL_SetAttribute(.GL_CONTEXT_MAJOR_VERSION, 3);
			SDL.GL_SetAttribute(.GL_CONTEXT_MINOR_VERSION, 3);
			SDL.GL_SetAttribute(.GL_CONTEXT_PROFILE_MASK, .GL_CONTEXT_PROFILE_CORE);
			Window = SDL.CreateWindow("External renderer", 0, 0, 64, 64, .OpenGL | .Hidden);
			Test.Assert(Window != null);
			Context = SDL.GL_CreateContext(Window);
			Test.Assert(Context != default);
		}
		public ~this()
		{
			SDL.GL_DeleteContext(Context);
			SDL.DestroyWindow(Window);
			SDL.QuitSubSystem(.Video);
		}
	}

	private static void VerifyContext(ContextOperation operation, bool external)
	{
		Application.UseBackend(.SDL2OpenGL);
		let owner = scope ExternalContext();
		let form = scope Form();
		form.ClientSize = .(200, 100);
		let panel = new Panel(); panel.Size = .(180, 80); form.Controls.Add(panel);
		let backend = (SDLBackend)Application.Backend;
		int paints = 0, downs = 0;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			paints++;
			Test.Assert(SDL.GL_GetCurrentWindow() == form.Handle);
		});
		panel.MouseDown.Add(new [&] (sender, args) =>
		{
			downs++;
			args.Handled = true;
			Test.Assert(SDL.GL_GetCurrentWindow() == form.Handle);
		});
		if (operation != .Create) form.Show();
		let expectedWindow = external ? owner.Window : null;
		SDL.SDL_GLContext expectedContext = external ? owner.Context : default;
		Test.Assert(SDL.GL_MakeCurrent(expectedWindow, expectedContext) == 0);
		switch (operation)
		{
		case .Create: form.Show();
		case .Render:
			Test.Assert(backend.[Friend]RenderIfNeeded());
			Test.Assert(paints == 1);
		case .Input:
			SDL.Event input = .(); input.type = .MouseButtonDown;
			input.button.button = 1; input.button.x = input.button.y = 10;
			SDLTestInput.SetWindow(ref input, form);
			backend.[Friend]ProcessEvent(ref input);
			Test.Assert(downs == 1);
		}
		Test.Assert(SDL.GL_GetCurrentContext() == expectedContext);
		Test.Assert(SDL.GL_GetCurrentWindow() == expectedWindow);
		form.Close();
		Test.Assert(SDL.GL_GetCurrentContext() == expectedContext);
		Test.Assert(SDL.GL_GetCurrentWindow() == expectedWindow);
	}

	[Test] public static void CreationRestoresAnUnboundContext() => VerifyContext(.Create, false);
	[Test] public static void RenderingRestoresAnUnboundContext() => VerifyContext(.Render, false);
	[Test] public static void InputRestoresAnUnboundContext() => VerifyContext(.Input, false);
	[Test] public static void CreationRestoresAnExternalContext() => VerifyContext(.Create, true);
	[Test] public static void RenderingRestoresAnExternalContext() => VerifyContext(.Render, true);
	[Test] public static void InputRestoresAnExternalContext() => VerifyContext(.Input, true);

	private static void VerifyDestroyedContext(bool duringPaint)
	{
		Application.UseBackend(.SDL2OpenGL);
		let previous = scope Form(); let target = scope Form();
		previous.ClientSize = target.ClientSize = .(200, 100);
		let panel = new Panel(); panel.Size = .(180, 80); target.Controls.Add(panel);
		previous.Show(); target.Show();
		let backend = (SDLBackend)Application.Backend;
		backend.GetSession(previous).MakeCurrent();
		if (duringPaint)
		{
			panel.Paint.Add(new (sender, args) => { previous.Close(); });
			backend.[Friend]RenderIfNeeded();
		}
		else
		{
			panel.MouseDown.Add(new (sender, args) => { previous.Close(); args.Handled = true; });
			SDL.Event input = .(); input.type = .MouseButtonDown;
			input.button.button = 1; input.button.x = input.button.y = 10;
			SDLTestInput.SetWindow(ref input, target);
			backend.[Friend]ProcessEvent(ref input);
		}
		Test.Assert(previous.IsDisposed && target.IsHandleCreated);
		Test.Assert(SDL.GL_GetCurrentContext() == default && SDL.GL_GetCurrentWindow() == null);
	}

	[Test] public static void PaintNeverRestoresAnInternallyDestroyedContext() => VerifyDestroyedContext(true);
	[Test] public static void InputNeverRestoresAnInternallyDestroyedContext() => VerifyDestroyedContext(false);

	[Test]
	public static void FrameBudgetsStartAtRunEntryAndIgnoreUnlimitedRendering()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(200, 100);
		let panel = new Panel(); panel.Size = .(180, 80); form.Controls.Add(panel);
		let backend = (SDLBackend)Application.Backend;
		int paints = 0;
		bool checkRunStart = false;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			paints++;
			if (checkRunStart)
			{
				checkRunStart = false;
				Test.Assert(backend.[Friend]mFrames == 0);
			}
		});
		backend.FrameLimit = 0; form.Show();
		let unlimitedFrames = backend.[Friend]mFrames;
		for (int i < 3) { panel.Invalidate(); Application.DoEvents(); }
		Test.Assert(paints == 3 && backend.[Friend]mFrames == unlimitedFrames);
		backend.FrameLimit = 2;
		defer { backend.FrameLimit = 0; }
		// Keep Paint observable on every forced frame without changing renderer policy.
		panel.Paint.Add(new (sender, args) => { panel.Invalidate(); });
		panel.Invalidate();
		checkRunStart = true;
		backend.Run(form);
		Test.Assert(!checkRunStart && backend.[Friend]mFrames == 2);
		checkRunStart = true;
		backend.Run(form);
		Test.Assert(!checkRunStart && backend.[Friend]mFrames == 2);
		backend.FrameLimit = 0;
		Application.DoEvents();
		Test.Assert(backend.[Friend]mFrames == 2);
	}

	[Test]
	public static void OpeningSecondaryWindowsDoesNotRestartTheFrameBudget()
	{
		Application.UseBackend(.SDL2OpenGL);
		let main = scope Form(); let secondary = scope Form();
		main.ClientSize = secondary.ClientSize = .(200, 100);
		let panel = new Panel(); panel.Size = .(180, 80); main.Controls.Add(panel);
		let backend = (SDLBackend)Application.Backend;
		bool opened = false;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			if (!opened && backend.[Friend]mFrames == 2)
			{
				opened = true;
				secondary.Show();
				Test.Assert(backend.[Friend]mFrames == 2);
			}
			panel.Invalidate();
		});
		main.Show();
		backend.FrameLimit = 4;
		defer { backend.FrameLimit = 0; }
		backend.Run(main);
		Test.Assert(opened && secondary.IsHandleCreated && backend.[Friend]mFrames == 4);
	}

	[Test]
	public static void UnknownCaptureTargetsDoNotStealCaptureFromAWindow()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(200, 100);
		let known = new Panel(); known.Size = .(180, 80); form.Controls.Add(known);
		let unknown = scope Panel();
		form.Show(); Application.DoEvents(); known.Capture = true;
		Test.Assert(known.Capture);
		let backend = (SDLBackend)Application.Backend;
		// A detached control can have its logical handle without an SDL window session.
		unknown.CreateHandle();
		Test.Assert(unknown.IsHandleCreated && backend.GetSession(unknown) == null);
		unknown.Capture = true;
		Test.Assert(known.Capture && !unknown.Capture);
		known.Capture = false;
	}

#if BF_PLATFORM_WINDOWS
	[Import("kernel32.dll"), LinkName("GetCurrentThread")]
	private static extern void* GetCurrentThread();
	[Import("kernel32.dll"), LinkName("GetThreadTimes")]
	private static extern int32 GetThreadTimes(void* thread, out uint64 created, out uint64 exited, out uint64 kernel, out uint64 user);

	private static uint64 ThreadCpuTicks()
	{
		Test.Assert(GetThreadTimes(GetCurrentThread(), var created, var exited, var kernel, var user) != 0);
		return kernel + user;
	}

	private static void VerifyLimitedRunWaits(bool minimize)
	{
		Application.UseBackend(.SDL2OpenGL);
		let main = scope Form(); let secondary = scope Form();
		main.ClientSize = secondary.ClientSize = .(200, 100);
		let backend = (SDLBackend)Application.Backend;
		backend.FrameLimit = 0;
		main.Show(); secondary.Show(); Application.DoEvents();
		if (minimize)
		{
			SDL.MinimizeWindow((SDL.Window*)main.Handle);
			SDL.MinimizeWindow((SDL.Window*)secondary.Handle);
			Test.Assert((SDL.GetWindowFlags((SDL.Window*)main.Handle) & (uint32)SDL.WindowFlags.Minimized) != 0);
			Test.Assert((SDL.GetWindowFlags((SDL.Window*)secondary.Handle) & (uint32)SDL.WindowFlags.Minimized) != 0);
		}
		else { main.Hide(); secondary.Hide(); }
		backend.FrameLimit = 1;
		backend.[Friend]mFrames = 0; // Isolate waiting from the frame-accounting regression.
		defer { backend.FrameLimit = 0; }
		let windowID = SDL.GetWindowID((SDL.Window*)main.Handle);
		let wake = scope Thread(new () =>
		{
			Thread.Sleep(350);
			SDL.Event input = .(); input.type = .WindowEvent;
			input.window.windowEvent = .Close; input.window.windowID = windowID;
			SDL.PushEvent(ref input); // SDL's event queue is safe to wake from another thread.
		});
		wake.Start(false);
		defer wake.Join();
		let before = ThreadCpuTicks();
		backend.Run(main);
		let cpu = ThreadCpuTicks() - before;
		Test.Assert(main.IsDisposed && backend.[Friend]mFrames == 0);
		// A blocking wait uses almost no CPU; the old spin consumed the full 350ms.
		Test.Assert(cpu < 150 * 10000);
	}

	[Test] public static void LimitedRunsWaitWhenEveryWindowIsHidden() => VerifyLimitedRunWaits(false);
	[Test] public static void LimitedRunsWaitWhenEveryWindowIsMinimized() => VerifyLimitedRunWaits(true);
#endif

	private class MainForm : Form
	{
		private bool* mDeleted;
		public this(bool* deleted) { mDeleted = deleted; ClientSize = .(200, 100); }
		public ~this() { *mDeleted = true; }
	}

	private static void VerifyRecreation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		bool deleted = false;
		let main = new MainForm(&deleted);
		let secondary = scope Form(); secondary.ClientSize = .(200, 100);
		Application.[Friend]BeginRun(main); secondary.Show();
		main.DestroyHandle(); main.CreateHandle();
		int stops = 0;
		Application.[Friend]RunFrame(scope [&] () => { stops++; });
		Test.Assert(stops == 0 && !deleted && Application.OpenForms.Count == 1 && Application.OpenForms[0] == secondary);
		secondary.DestroyHandle();
		main.Close();
		secondary.CreateHandle();
		Application.[Friend]RunFrame(scope [&] () => { stops++; });
		Test.Assert(stops == 1 && deleted && !secondary.IsDisposed);
		secondary.Dispose();
		Test.Assert(Application.OpenForms.Count == 0 && Application.CreatedControlCount == 0);
	}

	[Test] public static void SDLRawHandleRecreationDoesNotRestoreRegistration() => VerifyRecreation(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeRawHandleRecreationDoesNotRestoreRegistration() => VerifyRecreation(.Win32);
#endif
}
