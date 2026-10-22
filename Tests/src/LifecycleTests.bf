using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class LifecycleTests
{
	private static int sLoopStops;

	private class OwnedForm : Form
	{
		private bool* mDeleted;
		public this(bool* deleted) { mDeleted = deleted; ClientSize = .(240, 160); }
		public ~this() { *mDeleted = true; }
	}

	private static void StopScheduledLoop()
	{
		Test.Assert(!Application.[Friend]sProcessingEvents);
		Test.Assert(Application.[Friend]sRunning && Application.[Friend]sMainForm != null);
		Test.Assert(!Application.[Friend]sMainForm.IsHandleCreated);
		sLoopStops++;
	}

	[Test]
	public static void ScheduledFrameReleasesTheMainFormAfterPaintUnwinds()
	{
		Application.UseBackend(.SDL2OpenGL);
		bool deleted = false;
		sLoopStops = 0;
		let form = new OwnedForm(&deleted);
		let panel = new Panel();
		panel.Size = .(100, 100);
		form.Controls.Add(panel);
		int paints = 0;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			paints++;
			form.Close();
			Test.Assert(form.IsDisposed && !deleted && Application.[Friend]sRunning);
			// A nested scheduled frame must not delete the form underneath this callback.
			Application.[Friend]RunFrame(=> StopScheduledLoop);
			Test.Assert(!deleted && sLoopStops == 0);
		});
		Application.[Friend]BeginRun(form);
		Test.Assert(paints == 0 && !deleted);
		Application.[Friend]RunFrame(=> StopScheduledLoop);
		Test.Assert(paints == 1 && deleted && sLoopStops == 1);
		Test.Assert(Application.[Friend]sMainForm == null && !Application.[Friend]sRunning);
		Test.Assert(Application.CreatedControlCount == 0);
		Application.[Friend]RunFrame(=> StopScheduledLoop);
		Test.Assert(sLoopStops == 1);
	}

	[Test]
	public static void ScheduledFrameKeepsOwnershipUntilClosureIsAccepted()
	{
		Application.UseBackend(.SDL2OpenGL);
		bool deleted = false, cancel = true;
		sLoopStops = 0;
		let form = new OwnedForm(&deleted);
		form.FormClosing.Add(new [&] (sender, args) => { args.Cancel = cancel; });
		Application.[Friend]BeginRun(form);
		form.Close();
		Application.[Friend]RunFrame(=> StopScheduledLoop);
		Test.Assert(!deleted && sLoopStops == 0 && Application.[Friend]sMainForm == form);
		Test.Assert(Application.[Friend]sRunning);
		cancel = false;
		form.Close();
		Test.Assert(!deleted);
		Application.[Friend]RunFrame(=> StopScheduledLoop);
		Test.Assert(deleted && sLoopStops == 1 && !Application.[Friend]sRunning);
		Test.Assert(Application.[Friend]sMainForm == null);
	}

	[Test]
	public static void RunReleasesTheMainFormClosedDuringLoadAndCanRunAgain()
	{
		Application.UseBackend(.SDL2OpenGL);
		for (int i < 2)
		{
			bool deleted = false;
			let form = new OwnedForm(&deleted);
			form.Load.Add(new (sender, args) => { ((Form)sender).Close(); });
			Application.Run(form);
			Test.Assert(deleted && !Application.[Friend]sRunning);
			Test.Assert(Application.[Friend]sMainForm == null && Application.CreatedControlCount == 0);
		}
	}

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
			if (paints == 1)
			{
				Test.Assert((SDL.GetWindowFlags((SDL.Window*)form.Handle) & (uint32)SDL.WindowFlags.Hidden) != 0);
				panel.Invalidate();
			}
		});
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		Test.Assert(paints == 0);
		Test.Assert((SDL.GetWindowFlags((SDL.Window*)form.Handle) & (uint32)SDL.WindowFlags.Hidden) != 0);
		Test.Assert(backend.[Friend]RenderIfNeeded());
		Test.Assert(paints == 1);
		Test.Assert((SDL.GetWindowFlags((SDL.Window*)form.Handle) & (uint32)SDL.WindowFlags.Shown) != 0);
		Test.Assert(backend.[Friend]RenderIfNeeded());
		Test.Assert(paints == 2);
		Test.Assert(!backend.[Friend]RenderIfNeeded());
	}

	[Test]
	public static void SDLHideCancelsPendingShow()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let backend = (SDLBackend)Application.Backend;
		form.Show();
		form.Hide();
		Test.Assert(!backend.[Friend]RenderIfNeeded());
		Test.Assert((SDL.GetWindowFlags((SDL.Window*)form.Handle) & (uint32)SDL.WindowFlags.Hidden) != 0);
		form.Show();
		Test.Assert(backend.[Friend]RenderIfNeeded());
		Test.Assert((SDL.GetWindowFlags((SDL.Window*)form.Handle) & (uint32)SDL.WindowFlags.Shown) != 0);
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
