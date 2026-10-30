using System;
using System.Threading;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class FormShownTests
{
	private class ShownForm : Form
	{
		public String Order;
		public int ShownCalls;
		public bool RaiseShown = true;
		public bool RaiseLoad = true;

		protected override void OnLoad(EventArgs args)
		{
			if (RaiseLoad)
				base.OnLoad(args);
		}

		protected override void OnShown(EventArgs args)
		{
			ShownCalls++;
			Order.Append('O');
			if (RaiseShown)
				base.OnShown(args);
			Order.Append('Z');
		}
	}

	private static void VerifyOrdering(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		for (let precreate in scope bool[](false, true))
		{
			for (let raiseShown in scope bool[](true, false))
			{
				let order = scope String();
				let form = scope ShownForm();
				form.Order = order;
				form.RaiseShown = raiseShown;
				form.ClientSize = .(240, 140);
				let child = new Button();
				child.Size = .(100, 30);
				form.Controls.Add(child);
				let uiThread = Thread.CurrentThreadId;
				form.Load.Add(new (sender, args) =>
				{
					order.Append('L');
					form.BeginInvoke(new () => order.Append('A'));
				});
				form.VisibleChanged.Add(new (sender, args) => order.Append(form.Visible ? 'V' : 'H'));
				form.Shown.Add(new (sender, args) =>
				{
					Test.Assert(sender == form && Thread.CurrentThreadId == uiThread);
					Test.Assert(form.Visible && form.Created && child.Created && child.IsHandleCreated);
					order.Append('E');
				});
				if (precreate)
					Test.Assert(form.Handle != null);
				form.Show();
				order.Append('R');
				Test.Assert(order == "LVR" && form.ShownCalls == 0);
				Application.DoEvents();
				Test.Assert(order == (raiseShown ? "LVRAOEZ" : "LVRAOZ") && form.ShownCalls == 1);
				order.Clear();
				form.Hide();
				form.Show();
				form.CreateControl();
				Application.DoEvents();
				Test.Assert(order == "HV" && form.ShownCalls == 1);
				form.Close();
				Application.Backend.Run(form);
			}
		}
	}

	private static void VerifySuppressedLoad(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let order = scope String();
		let form = scope ShownForm();
		form.Order = order;
		form.RaiseLoad = false;
		form.Load.Add(new (sender, args) => order.Append('L'));
		form.Shown.Add(new (sender, args) => order.Append('E'));
		form.Show();
		Application.DoEvents();
		form.Hide();
		form.Show();
		Application.DoEvents();
		Test.Assert(order.IsEmpty && form.ShownCalls == 0);
		form.Close();
		Application.Backend.Run(form);
	}

	private static void VerifyClosureCancelsShown(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		for (let closeDuringLoad in scope bool[](false, true))
		{
			let form = scope Form();
			int shown = 0;
			form.Shown.Add(new [&] (sender, args) => shown++);
			if (closeDuringLoad)
				form.Load.Add(new (sender, args) => form.Close());
			form.Show();
			if (!closeDuringLoad)
				form.Close();
			Application.DoEvents();
			Test.Assert(shown == 0 && form.IsDisposed && !form.IsHandleCreated);
			Application.Backend.Run(form);
		}
	}

	private static void VerifyHiddenAndRecreatedForms(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		for (let recreate in scope bool[](false, true))
		{
			let form = scope Form();
			int shown = 0, loads = 0;
			form.Load.Add(new [&] (sender, args) => loads++);
			form.Shown.Add(new [&] (sender, args) =>
			{
				Test.Assert(form.Visible == recreate);
				shown++;
			});
			form.Show();
			if (recreate)
				form.RecreateHandle();
			else
				form.Hide();
			Application.DoEvents();
			Test.Assert(shown == 1 && loads == 1);
			form.Close();
			Application.Backend.Run(form);
		}
	}

	private static void VerifyRunCanCloseFromShown(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = new Form();
		int shown = 0;
		bool timedOut = false;
		let watchdog = scope System.Windows.Forms.Timer();
		watchdog.Interval = 3000;
		watchdog.Tick.Add(new [&] (sender, args) =>
		{
			timedOut = true;
			form.Close();
		});
		form.Shown.Add(new [&] (sender, args) =>
		{
			shown++;
			form.Close();
		});
		watchdog.Start();
		defer watchdog.Stop();
		Application.Run(form);
		Test.Assert(shown == 1 && !timedOut && Application.OpenForms.Count == 0 && Application.CreatedControlCount == 0);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeShownFollowsLoadCallbacksOnceAndSupportsOverrides()
	{
		VerifyOrdering(.Win32);
	}

	[Test]
	public static void NativeSuppressingBaseOnLoadSuppressesShown()
	{
		VerifySuppressedLoad(.Win32);
	}

	[Test]
	public static void NativeClosingBeforeDispatchCancelsShown()
	{
		VerifyClosureCancelsShown(.Win32);
	}

	[Test]
	public static void NativePendingShownSurvivesHidingAndHandleRecreation()
	{
		VerifyHiddenAndRecreatedForms(.Win32);
	}

	[Test]
	public static void NativeApplicationRunExitsCleanlyFromShown()
	{
		VerifyRunCanCloseFromShown(.Win32);
	}
#endif

#if BF_DEPENDS_BEEFFORMS_SDL
	[Test]
	public static void SDLShownFollowsLoadCallbacksOnceAndSupportsOverrides()
	{
		VerifyOrdering(.SDL2OpenGL);
	}

	[Test]
	public static void SDLSuppressingBaseOnLoadSuppressesShown()
	{
		VerifySuppressedLoad(.SDL2OpenGL);
	}

	[Test]
	public static void SDLClosingBeforeDispatchCancelsShown()
	{
		VerifyClosureCancelsShown(.SDL2OpenGL);
	}

	[Test]
	public static void SDLPendingShownSurvivesHidingAndHandleRecreation()
	{
		VerifyHiddenAndRecreatedForms(.SDL2OpenGL);
	}

	[Test]
	public static void SDLApplicationRunExitsCleanlyFromShown()
	{
		VerifyRunCanCloseFromShown(.SDL2OpenGL);
	}
#endif
}
