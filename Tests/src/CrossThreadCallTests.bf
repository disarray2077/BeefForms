using System;
using System.Diagnostics;
using System.Threading;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class CrossThreadCallTests
{
	private enum IllegalAccess
	{
		Handle,
		UncreatedChildHandle,
		Text
	}

	[Test]
	public static void DiagnosticsDefaultToDebuggerAttachment()
	{
		Test.Assert(Control.CheckForIllegalCrossThreadCalls == Debug.IsDebuggerPresent);
	}

	private static void VerifyIllegalAccess(ApplicationBackend backend, IllegalAccess access)
	{
		Application.UseBackend(backend);
		let previous = Control.CheckForIllegalCrossThreadCalls;
		Control.CheckForIllegalCrossThreadCalls = true;
		defer { Control.CheckForIllegalCrossThreadCalls = previous; }
		let form = scope Form();
		form.ClientSize = .(240, 140);
		let control = new Button();
		control.Name = "worker-target";
		control.Size = .(100, 30);
		control.Visible = access != .UncreatedChildHandle;
		form.Controls.Add(control);
		form.Show();
		let worker = scope Thread(new () =>
		{
			switch (access)
			{
			case .Handle, .UncreatedChildHandle:
				Test.Assert(control.Handle != null);
			case .Text:
				control.Text = "Illegal update";
			}
		});
		worker.Start(false);
		worker.Join();
		form.Close();
		Application.Backend.Run(form);
	}

	private static void VerifyDisabledDiagnostics(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let previous = Control.CheckForIllegalCrossThreadCalls;
		Control.CheckForIllegalCrossThreadCalls = false;
		defer { Control.CheckForIllegalCrossThreadCalls = previous; }
		let form = scope Form();
		let control = new Button();
		control.Size = .(100, 30);
		form.Controls.Add(control);
		form.Show();
		let expected = control.Handle;
		void* actual = null;
		let worker = scope Thread(new [&] () => actual = control.Handle);
		worker.Start(false);
		Test.Assert(worker.Join(3000) && actual == expected);
		Control.CheckForIllegalCrossThreadCalls = true;
		Test.Assert(control.Handle == expected && !control.InvokeRequired);
		form.Close();
		Application.Backend.Run(form);
	}

	private static void VerifySafeCalls(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let previous = Control.CheckForIllegalCrossThreadCalls;
		Control.CheckForIllegalCrossThreadCalls = true;
		defer { Control.CheckForIllegalCrossThreadCalls = previous; }
		let form = scope Form();
		form.ClientSize = .(240, 140);
		let control = new Button();
		control.Size = .(100, 30);
		form.Controls.Add(control);
		form.Show();
		let expected = control.Handle;
		let done = scope WaitEvent();
		int callbacks = 0;
		let worker = scope Thread(new [&] () =>
		{
			Test.Assert(control.IsHandleCreated && control.InvokeRequired);
			let detached = scope Control();
			Test.Assert(!detached.InvokeRequired && !detached.IsHandleCreated);
			detached.Text = "No handle or UI owner";
			control.BeginInvoke(new [&] () =>
			{
				Test.Assert(!control.InvokeRequired && control.Handle == expected);
				control.Text = "Dispatched update";
				callbacks++;
			});
			let result = control.Invoke<int>(scope [&] () =>
			{
				Test.Assert(control.Handle == expected && control.Text == "Dispatched update");
				return callbacks;
			});
			Test.Assert(result case .Ok(1));
			done.Set(true);
		});
		worker.Start(false);
		let deadline = TimerScheduler.Now + 3000;
		while (!done.WaitFor(0) && TimerScheduler.Now < deadline)
		{
			Application.DoEvents();
			Thread.Sleep(1);
		}
		let completed = done.WaitFor(0);
		if (!completed)
			Application.DispatcherCore.Shutdown();
		Test.Assert(worker.Join(3000) && completed && callbacks == 1);
		form.Close();
		Application.Backend.Run(form);
	}

#if BF_PLATFORM_WINDOWS
	[Test(ShouldFail = true)]
	public static void NativeWorkerHandleAccessIsRejected()
	{
		VerifyIllegalAccess(.Win32, .Handle);
	}

	[Test(ShouldFail = true)]
	public static void NativeWorkerHandleCreationUsesTheAncestorsThread()
	{
		VerifyIllegalAccess(.Win32, .UncreatedChildHandle);
	}

	[Test(ShouldFail = true)]
	public static void NativeWorkerTextUpdatesAreRejected()
	{
		VerifyIllegalAccess(.Win32, .Text);
	}

	[Test]
	public static void NativeDiagnosticsCanBeDisabled()
	{
		VerifyDisabledDiagnostics(.Win32);
	}

	[Test]
	public static void NativeDispatchRemainsUsable()
	{
		VerifySafeCalls(.Win32);
	}
#endif

#if BF_DEPENDS_BEEFFORMS_SDL
	[Test(ShouldFail = true)]
	public static void SDLWorkerHandleAccessIsRejected()
	{
		VerifyIllegalAccess(.SDL2OpenGL, .Handle);
	}

	[Test(ShouldFail = true)]
	public static void SDLWorkerHandleCreationUsesTheAncestorsThread()
	{
		VerifyIllegalAccess(.SDL2OpenGL, .UncreatedChildHandle);
	}

	[Test(ShouldFail = true)]
	public static void SDLWorkerTextUpdatesAreRejected()
	{
		VerifyIllegalAccess(.SDL2OpenGL, .Text);
	}

	[Test]
	public static void SDLDiagnosticsCanBeDisabled()
	{
		VerifyDisabledDiagnostics(.SDL2OpenGL);
	}

	[Test]
	public static void SDLDispatchRemainsUsable()
	{
		VerifySafeCalls(.SDL2OpenGL);
	}
#endif
}
