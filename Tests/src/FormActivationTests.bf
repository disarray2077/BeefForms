using System;
using System.Threading;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class FormActivationTests
{
	private static void AssertActive(Form form)
	{
#if BF_DEPENDS_BEEFFORMS_SDL
		if (Application.Backend is SDLBackend)
		{
			let deadline = SDL2.SDL.GetTicks64() + 1000;
			while (SDL2.SDL.GetKeyboardFocus() != (SDL2.SDL.Window*)form.Handle && SDL2.SDL.GetTicks64() < deadline)
			{
				Application.DoEvents();
				SDL2.SDL.Delay(1);
			}
			Test.Assert(SDL2.SDL.GetKeyboardFocus() == (SDL2.SDL.Window*)form.Handle);
			return;
		}
#endif
#if BF_PLATFORM_WINDOWS
		Test.Assert(Win32.GetActiveWindow() == form.Handle);
#endif
	}

	private static void VerifyInactiveForms(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		int loads = 0, shown = 0, visibilityChanges = 0;
		form.Load.Add(new [&] (sender, args) => loads++);
		form.Shown.Add(new [&] (sender, args) => shown++);
		form.VisibleChanged.Add(new [&] (sender, args) => visibilityChanges++);
		form.Activate();
		Test.Assert(!form.IsHandleCreated && !form.Visible);
		let handle = form.Handle;
		form.Activate();
		Test.Assert(form.Handle == handle && !form.Visible);
		Application.DoEvents();
		Test.Assert(loads == 0 && shown == 0 && visibilityChanges == 0);
		form.Show();
		Application.DoEvents();
		form.Hide();
		let changesAfterHiding = visibilityChanges;
		form.Activate();
		Application.DoEvents();
		Test.Assert(!form.Visible && form.Handle == handle && visibilityChanges == changesAfterHiding);
		Test.Assert(loads == 1 && shown == 1);
		form.Close();
		form.Activate();
		Test.Assert(form.IsDisposed && !form.IsHandleCreated);
		Application.Backend.Run(form);
		let disposed = scope Form();
		disposed.Dispose();
		disposed.Activate();
		Test.Assert(disposed.IsDisposed && !disposed.IsHandleCreated);
	}

	private static void VerifyActivation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let owner = scope Form();
		let child = scope Form();
		let button = new Button();
		button.Size = .(100, 30);
		child.Controls.Add(button);
		owner.Show();
		child.Show(owner);
		Application.DoEvents();
		Application.DoEvents();
		let ownerHandle = owner.Handle;
		let childHandle = child.Handle;
		owner.Activate();
		Application.DoEvents();
		AssertActive(owner);
		child.Activate();
		Application.DoEvents();
		AssertActive(child);
		Test.Assert(button.Focus());
		child.Activate();
		Application.DoEvents();
		AssertActive(child);
		Test.Assert(button.Focused);
		Test.Assert(owner.Handle == ownerHandle && child.Handle == childHandle);
		Test.Assert(owner.Visible && child.Visible && child.Owner == owner && child.Parent == null);
		owner.Close();
		Application.Backend.Run(owner);
	}

	private static void VerifyIllegalThreadAccess(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let previous = Control.CheckForIllegalCrossThreadCalls;
		Control.CheckForIllegalCrossThreadCalls = true;
		defer
		{
			Control.CheckForIllegalCrossThreadCalls = previous;
		}
		let form = scope Form();
		form.Show();
		let worker = scope Thread(new () => form.Activate());
		worker.Start(false);
		worker.Join();
		form.Close();
		Application.Backend.Run(form);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeActivationDoesNotShowOrCreateForms()
	{
		VerifyInactiveForms(.Win32);
	}

	[Test]
	public static void NativeActivationSwitchesWindowsAndPreservesFocusedChildren()
	{
		VerifyActivation(.Win32);
	}

	[Test(ShouldFail = true)]
	public static void NativeWorkerActivationIsRejected()
	{
		VerifyIllegalThreadAccess(.Win32);
	}
#endif

#if BF_DEPENDS_BEEFFORMS_SDL
	[Test]
	public static void SDLActivationDoesNotShowOrCreateForms()
	{
		VerifyInactiveForms(.SDL2OpenGL);
	}

	[Test]
	public static void SDLActivationSwitchesWindowsAndPreservesFocusedChildren()
	{
		VerifyActivation(.SDL2OpenGL);
	}

	[Test(ShouldFail = true)]
	public static void SDLWorkerActivationIsRejected()
	{
		VerifyIllegalThreadAccess(.SDL2OpenGL);
	}
#endif
}
