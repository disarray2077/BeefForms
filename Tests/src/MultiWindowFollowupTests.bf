using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class MultiWindowFollowupTests
{
	private static void StopLoop() {}
	private static void Activate(SDLBackend backend, Form form)
	{
		SDL.Event input = .(); input.type = .WindowEvent; input.window.windowEvent = .FocusGained;
		SDLTestInput.SetWindow(ref input, form);
		backend.[Friend]ProcessEvent(ref input);
	}

	private static void VerifyReentrantChild(bool reparent, bool mouseLeave)
	{
		Application.UseBackend(.SDL2OpenGL);
		let first = scope Form(); let second = scope Form();
		first.ClientSize = second.ClientSize = .(200, 100);
		let editor = new TextBox(); editor.Size = .(150, 25); first.Controls.Add(editor);
		first.Show(); second.Show(); Application.DoEvents();
		let backend = (SDLBackend)Application.Backend;
		Activate(backend, first); editor.Focus();
		int callbacks = 0;
		EventHandler recreate = new [&] (sender, args) =>
		{
			if (++callbacks != 1) return;
			if (reparent) second.Controls.Add(editor);
			else editor.CreateHandle();
		};
		if (mouseLeave)
		{
			SDL.Event motion = .(); motion.type = .MouseMotion; motion.motion.x = motion.motion.y = 10;
			SDLTestInput.SetWindow(ref motion, first); backend.[Friend]ProcessEvent(ref motion);
			editor.MouseLeave.Add(recreate);
		}
		else editor.LostFocus.Add(recreate);
		editor.DestroyHandle();
		let expected = reparent ? second : first;
		Test.Assert(callbacks == 1 && editor.IsHandleCreated && editor.Parent == expected);
		Test.Assert(backend.GetSession(editor) == backend.GetSession(expected));
		Activate(backend, expected); editor.Focus();
		SDL.Event text = .(); text.type = .TextInput; text.text.text[0] = (uint8)'r';
		SDLTestInput.SetWindow(ref text, expected); backend.[Friend]ProcessEvent(ref text);
		Test.Assert(editor.Text == "r");
	}

	[Test] public static void LostFocusRecreationKeepsTheNewAssociation() => VerifyReentrantChild(false, false);
	[Test] public static void LostFocusReparentingKeepsTheNewAssociation() => VerifyReentrantChild(true, false);
	[Test] public static void MouseLeaveRecreationKeepsTheNewAssociation() => VerifyReentrantChild(false, true);
	[Test] public static void MouseLeaveReparentingKeepsTheNewAssociation() => VerifyReentrantChild(true, true);

	[Test]
	public static void FormRecreationFromLostFocusKeepsItsNewNativeWindow()
	{
		Application.UseBackend(.SDL2OpenGL, render: true);
		let form = scope Form(); form.ClientSize = .(200, 100); form.Show();
		let backend = (SDLBackend)Application.Backend;
		Activate(backend, form); form.Focus();
		let oldID = SDL.GetWindowID((SDL.Window*)form.Handle);
		int callbacks = 0;
		form.LostFocus.Add(new [&] (sender, args) => { if (++callbacks != 1) return; form.CreateHandle(); backend.Show(form); });
		form.DestroyHandle();
		Test.Assert(callbacks == 1 && form.IsHandleCreated && form.Handle != null);
		let session = backend.GetSession(form);
		Test.Assert(session != null && session.mWindow == form.Handle);
		Test.Assert(SDL.GetWindowID((SDL.Window*)form.Handle) != oldID && backend.[Friend]mSessions.Count == 1);
		Application.DoEvents(); SDLTestInput.AssertNoGLError(form);
	}

	[Test]
	public static void MakeCurrentRebindsTheSessionWindowWhenItsContextWasBorrowed()
	{
		Application.UseBackend(.SDL2OpenGL, render: true);
		let form = scope Form(); form.ClientSize = .(200, 100);
		let panel = new Panel(); panel.Size = .(180, 80); form.Controls.Add(panel); form.Show();
		let backend = (SDLBackend)Application.Backend;
		let session = backend.GetSession(form);
		let foreign = SDL.CreateWindow("Compatible external window", 0, 0, 64, 64, .OpenGL | .Hidden);
		Test.Assert(foreign != null);
		defer { SDL.GL_MakeCurrent(null, default); SDL.DestroyWindow(foreign); }
		Test.Assert(SDL.GL_MakeCurrent(foreign, session.mContext) == 0);
		int paints = 0;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			paints++;
			Test.Assert(SDL.GL_GetCurrentContext() == session.mContext && SDL.GL_GetCurrentWindow() == form.Handle);
		});
		backend.[Friend]RenderIfNeeded();
		Test.Assert(paints == 1 && SDL.GL_GetCurrentContext() == session.mContext && SDL.GL_GetCurrentWindow() == foreign);
	}

	private class OwnedForm : Form
	{
		private bool* mDeleted;
		public this(bool* deleted) { mDeleted = deleted; ClientSize = .(200, 100); }
		public ~this() { *mDeleted = true; }
	}

	[Test]
	public static void SDLQuitCancellationDoesNotPartiallyCloseOrDisposeWindows()
	{
		Application.UseBackend(.SDL2OpenGL);
		bool deleted = false, cancel = true;
		let main = new OwnedForm(&deleted);
		let other = scope Form(); other.ClientSize = .(200, 100);
		Application.[Friend]BeginRun(main); other.Show();
		defer
		{
			if (Application.[Friend]sRunning)
			{
				cancel = false; other.Close(); main.Close();
				Application.[Friend]RunFrame(=> StopLoop);
			}
		}
		int closed = 0, disposed = 0;
		main.FormClosed.Add(new [&] (sender, args) => { closed++; });
		other.FormClosed.Add(new [&] (sender, args) => { closed++; });
		main.Disposed.Add(new [&] (sender, args) => { disposed++; });
		other.Disposed.Add(new [&] (sender, args) => { disposed++; });
		other.FormClosing.Add(new [&] (sender, args) => { args.Cancel = cancel; });
		SDL.Event quit = .(); quit.type = .Quit;
		let backend = (SDLBackend)Application.Backend;
		backend.[Friend]ProcessEvent(ref quit);
		Test.Assert(main.IsHandleCreated && other.IsHandleCreated && !deleted && closed == 0 && disposed == 0);
		int stops = 0;
		Application.[Friend]RunFrame(scope [&] () => { stops++; });
		Test.Assert(stops == 0 && Application.[Friend]sRunning && !deleted);
		cancel = false; backend.[Friend]ProcessEvent(ref quit);
		Test.Assert(closed == 2 && disposed == 2 && !deleted);
		Application.[Friend]RunFrame(scope [&] () => { stops++; });
		Test.Assert(stops == 1 && deleted);
	}

	private static void VerifyHandleFreeSecondary(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		bool deleted = false;
		let main = new OwnedForm(&deleted);
		let other = scope Form(); other.ClientSize = .(200, 100);
		Application.[Friend]BeginRun(main); other.Show(); other.DestroyHandle(); main.Close();
		Application.[Friend]RunFrame(=> StopLoop);
		// Explicit DestroyHandle (without a recreation operation) behaves this way in .NET too.
		Test.Assert(deleted && !other.IsHandleCreated && !other.IsDisposed && Application.OpenForms.Count == 0);
	}

	private static void TrackExit(Form form, String events, char8 closing, char8 closed, char8 disposed)
	{
		form.FormClosing.Add(new (sender, args) =>
		{
			Test.Assert(args.CloseReason == .ApplicationExitCall);
			events.Append(closing);
		});
		form.FormClosed.Add(new (sender, args) =>
		{
			Test.Assert(args.CloseReason == .ApplicationExitCall);
			events.Append(closed);
		});
		form.Disposed.Add(new (sender, args) => { events.Append(disposed); });
	}

	private static void VerifyExitPhases(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let first = scope Form(); let second = scope Form(); let third = scope Form();
		first.ClientSize = second.ClientSize = third.ClientSize = .(200, 100);
		first.Show(); second.Show(); third.Show();
		let events = scope String();
		TrackExit(first, events, '1', 'a', 'A');
		TrackExit(second, events, '2', 'b', 'B');
		TrackExit(third, events, '3', 'c', 'C');
		bool cancel = true;
		second.FormClosing.Add(new [&] (sender, args) => { args.Cancel = cancel; });
		third.FormClosing.Add(new (sender, args) => { Application.Exit(); });
		Application.Exit();
		Test.Assert(events == "32" && first.IsHandleCreated && second.IsHandleCreated && third.IsHandleCreated);
		Test.Assert(!first.IsDisposed && !second.IsDisposed && !third.IsDisposed && !Application.[Friend]sExiting);
		cancel = false; events.Clear(); Application.Exit();
		Test.Assert(events == "321cbaCBA" && first.IsDisposed && second.IsDisposed && third.IsDisposed);
		Test.Assert(Application.OpenForms.Count == 0 && Application.CreatedControlCount == 0);
	}

	[Test] public static void SDLApplicationExitUsesCancelableClosingThenClosedAndDisposalPhases() => VerifyExitPhases(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeApplicationExitUsesCancelableClosingThenClosedAndDisposalPhases() => VerifyExitPhases(.Win32);
#endif

	[Test]
	public static void AWindowAddedDuringExitPreflightCanCancelTheWholeExit()
	{
		Application.UseBackend(.SDL2OpenGL);
		let first = scope Form(); let second = scope Form(); let added = scope Form();
		first.ClientSize = second.ClientSize = added.ClientSize = .(200, 100);
		first.Show(); second.Show();
		bool cancel = true;
		int addedQueries = 0, firstQueries = 0;
		first.FormClosing.Add(new [&] (sender, args) => { firstQueries++; });
		second.FormClosing.Add(new (sender, args) => { if (!added.IsHandleCreated) added.Show(); });
		added.FormClosing.Add(new [&] (sender, args) => { addedQueries++; args.Cancel = cancel; });
		Application.Exit();
		Test.Assert(addedQueries == 1 && firstQueries == 0 && first.IsHandleCreated && second.IsHandleCreated && added.IsHandleCreated);
		cancel = false; Application.Exit();
		Test.Assert(addedQueries == 2 && firstQueries == 1 && first.IsDisposed && second.IsDisposed && added.IsDisposed);
	}

	[Test]
	public static void ExitPreflightToleratesAnotherWindowBeingDisposed()
	{
		Application.UseBackend(.SDL2OpenGL);
		let first = scope Form(); let second = scope Form();
		first.ClientSize = second.ClientSize = .(200, 100); first.Show(); second.Show();
		int firstQueries = 0, closed = 0;
		first.FormClosing.Add(new [&] (sender, args) => { firstQueries++; });
		second.FormClosing.Add(new (sender, args) => { first.Dispose(); });
		second.FormClosed.Add(new [&] (sender, args) => { closed++; });
		Application.Exit();
		Test.Assert(firstQueries == 0 && closed == 1 && first.IsDisposed && second.IsDisposed);
		Test.Assert(Application.OpenForms.Count == 0);
	}

	[Test] public static void SDLExplicitlyDestroyedSecondaryMatchesDotNetTeardown() => VerifyHandleFreeSecondary(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeExplicitlyDestroyedSecondaryMatchesDotNetTeardown() => VerifyHandleFreeSecondary(.Win32);
#endif
}
