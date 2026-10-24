using System;
using System.Windows.Forms;
using BeefForms.Backends;

using internal BeefForms.Backends;

namespace BeefForms.Tests;

class CreationCompatibilityTests
{
	private enum CreationMutation { RemoveSelf, ReorderSelf, DeleteNext }

	private class CreationCallbackControl : Control
	{
		public Action Creating ~ delete _;
		protected override void OnCreateControl()
		{
			base.OnCreateControl();
			Creating?.Invoke();
		}
	}

	private static void VerifyMutationDuringCreation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		for (let mutation in scope CreationMutation[](.RemoveSelf, .ReorderSelf, .DeleteNext))
		{
			let form = scope Form(); form.ClientSize = .(240, 120);
			let first = new CreationCallbackControl();
			let second = new Control();
			let third = new Control();
			form.Controls.Add(first); form.Controls.Add(second); form.Controls.Add(third);
			defer { if (mutation == .RemoveSelf) delete first; }
			bool readyAtLoad = false;
			form.Load.Add(new [&] (sender, args) =>
			{
				readyAtLoad = third.Created && third.IsHandleCreated &&
					(mutation == .DeleteNext || (second.Created && second.IsHandleCreated));
			});
			first.Creating = new () =>
			{
				switch (mutation)
				{
				case .RemoveSelf: form.Controls.Remove(first);
				case .ReorderSelf: first.BringToFront();
				case .DeleteNext: delete second;
				}
			};
			form.Show();
			Test.Assert(readyAtLoad);
			Test.Assert(third.Created && third.IsHandleCreated);
			if (mutation != .DeleteNext) Test.Assert(second.Created && second.IsHandleCreated);
			Test.Assert(form.Created && form.IsHandleCreated);
			form.Close();
		}
	}

	[Test] public static void SDLChildCreationToleratesCollectionMutation() => VerifyMutationDuringCreation(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeChildCreationToleratesCollectionMutation() => VerifyMutationDuringCreation(.Win32);

	[Test]
	public static void NativeStandalonePanelHandleMatchesDotNetCreation()
	{
		Application.UseBackend(.Win32);
		for (let visible in scope bool[](true, false))
		{
			let panel = scope Panel(); panel.Visible = visible;
			let child = new Control(); panel.Controls.Add(child);
			Test.Assert(panel.Handle != null && panel.IsHandleCreated);
			Test.Assert(panel.Created == visible && child.Created == visible && child.IsHandleCreated == visible);
		}
	}
#endif

	private static void VerifyFirstShowOrdering(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		for (let createHandle in scope bool[](false, true))
		{
			let form = scope Form(); form.ClientSize = .(240, 120);
			let child = new Control(); form.Controls.Add(child);
			if (createHandle) Test.Assert(form.Handle != null);
			let events = scope String();
			bool readyAtVisibility = false;
			form.Load.Add(new (sender, args) => { events.Append('L'); });
			form.VisibleChanged.Add(new [&] (sender, args) =>
			{
				if (!form.Visible) return;
				events.Append('V');
				readyAtVisibility = form.Created && form.IsHandleCreated && child.Created && child.IsHandleCreated;
			});
			form.Show();
			Test.Assert(events == "LV" && readyAtVisibility);
			form.Close();
		}
	}

	[Test] public static void SDLFirstShowLoadsBeforeVisibilityChanges() => VerifyFirstShowOrdering(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeFirstShowLoadsBeforeVisibilityChanges() => VerifyFirstShowOrdering(.Win32);
#endif

	private static void VerifyHideAndShowDuringLoad(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let events = scope String();
		form.Load.Add(new (sender, args) =>
		{
			events.Append('L');
			form.Hide();
			form.Show();
		});
		form.VisibleChanged.Add(new (sender, args) => { events.Append(form.Visible ? 'V' : 'H'); });
		form.Show();
		// .NET 9.0.4 also emits the outer visible notification after the nested Show.
		Test.Assert(events == "LHVV");
		Test.Assert(form.Visible && form.Created && form.IsHandleCreated && Application.OpenForms.Count == 1);
		form.Close();
	}

	[Test] public static void SDLHideAndShowDuringLoadMatchesDotNetNotifications() => VerifyHideAndShowDuringLoad(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeHideAndShowDuringLoadMatchesDotNetNotifications() => VerifyHideAndShowDuringLoad(.Win32);

	[Test]
	public static void NativeAttachingAPrecreatedControlUpdatesItsNativeParent()
	{
		Application.UseBackend(.Win32);
		let form = scope Form(); form.ClientSize = .(240, 120);
		form.Show();
		let child = new Control(); child.Size = .(80, 30);
		let handle = child.Handle;
		form.Controls.Add(child);
		Test.Assert(child.Created && child.Handle == handle);
		Test.Assert(Win32.GetParent(handle) == form.Handle);
		form.Close();
	}
#endif

	private static void VerifyHideDuringFirstVisibility(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let child = new Control(); form.Controls.Add(child);
		let events = scope String();
		bool first = true;
		form.Load.Add(new (sender, args) => { events.Append('L'); });
		form.VisibleChanged.Add(new [&] (sender, args) =>
		{
			events.Append(form.Visible ? 'V' : 'H');
			if (form.Visible && first)
			{
				first = false;
				form.Hide();
			}
		});
		form.Show();
		Test.Assert(events == "LVHV");
		Test.Assert(form.Visible && form.Created && form.IsHandleCreated && child.IsHandleCreated);
		Test.Assert(Application.OpenForms.Count == 1);
		form.Show();
		Test.Assert(events == "LVHV");
		form.Close();
	}

	[Test] public static void SDLHideDuringFirstVisibilityKeepsTheFormCreated() => VerifyHideDuringFirstVisibility(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeHideDuringFirstVisibilityKeepsTheFormCreated() => VerifyHideDuringFirstVisibility(.Win32);
#endif

	private class CloseParentOnCreation : Control
	{
		protected override void OnCreateControl()
		{
			base.OnCreateControl();
			FindForm().Close();
		}
	}

	private static void VerifyCloseDuringChildCreation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let child = new CloseParentOnCreation(); form.Controls.Add(child);
		form.Controls.Add(new Control());
		int loads = 0, layoutsAfterClose = 0;
		form.Load.Add(new [&] (sender, args) => { loads++; });
		form.Layout.Add(new [&] (sender, args) => { if (form.IsDisposed) layoutsAfterClose++; });
		form.Show();
		Test.Assert(form.IsDisposed && child.IsDisposed && !form.IsHandleCreated);
		Test.Assert(loads == 0 && layoutsAfterClose == 0 && Application.OpenForms.Count == 0);
	}

	[Test] public static void SDLCloseDuringChildCreationSkipsLoadAndRegistration() => VerifyCloseDuringChildCreation(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeCloseDuringChildCreationSkipsLoadAndRegistration() => VerifyCloseDuringChildCreation(.Win32);
#endif

	private static void VerifyCloseDuringInitialLayout(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let child = new Control(); form.Controls.Add(child);
		int loads = 0;
		form.Load.Add(new [&] (sender, args) => { loads++; });
		form.Layout.Add(new (sender, args) =>
		{
			if (child.Created) form.Close();
		});
		form.Show();
		Test.Assert(form.IsDisposed && !form.IsHandleCreated);
		Test.Assert(loads == 0 && Application.OpenForms.Count == 0);
	}

	[Test] public static void SDLCloseDuringInitialLayoutSkipsLoadAndRegistration() => VerifyCloseDuringInitialLayout(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeCloseDuringInitialLayoutSkipsLoadAndRegistration() => VerifyCloseDuringInitialLayout(.Win32);
#endif

	private static void VerifyCloseDuringRestoredVisibility(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		int shows = 0, loads = 0;
		form.Load.Add(new [&] (sender, args) => { loads++; });
		form.VisibleChanged.Add(new [&] (sender, args) =>
		{
			if (!form.Visible) return;
			shows++;
			if (shows == 1) form.Hide();
			else form.Close();
		});
		form.Show();
		Test.Assert(shows == 2 && loads == 1 && form.IsDisposed && !form.IsHandleCreated);
		Test.Assert(Application.OpenForms.Count == 0);
	}

	[Test] public static void SDLCloseDuringRestoredVisibilityStopsShowing() => VerifyCloseDuringRestoredVisibility(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeCloseDuringRestoredVisibilityStopsShowing() => VerifyCloseDuringRestoredVisibility(.Win32);
#endif

	private static void VerifyHandleOnly(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let child = new Control(); form.Controls.Add(child);
		int loads = 0;
		form.Load.Add(new [&] (sender, args) => { loads++; });
		Test.Assert(!form.Visible && !form.Created && !form.IsHandleCreated);
		form.CreateControl();
		Test.Assert(!form.IsHandleCreated);
		Test.Assert(form.Handle != null);
		Test.Assert(form.IsHandleCreated && !form.Created && !child.IsHandleCreated);
		Test.Assert(loads == 0 && Application.OpenForms.Count == 0);
		form.Show();
		Test.Assert(form.Created && child.Created && child.IsHandleCreated);
		Test.Assert(loads == 1 && Application.OpenForms.Count == 1);
		form.Close();
	}

	[Test] public static void SDLHiddenFormHandleDoesNotCreateChildrenOrLoad() => VerifyHandleOnly(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeHiddenFormHandleDoesNotCreateChildrenOrLoad() => VerifyHandleOnly(.Win32);
#endif

	private static void VerifyVisibleChildren(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let visible = new Control(); form.Controls.Add(visible);
		let hidden = new Panel(); hidden.Hide(); form.Controls.Add(hidden);
		let nested = new Control(); hidden.Controls.Add(nested);
		int loads = 0;
		form.Load.Add(new [&] (sender, args) =>
		{
			loads++;
			Test.Assert(form.Created && visible.IsHandleCreated);
			Test.Assert(!hidden.IsHandleCreated && !nested.IsHandleCreated);
			Test.Assert(Application.OpenForms.Count == 1 && Application.OpenForms[0] == form);
		});
		form.Show();
		hidden.Show();
		Test.Assert(hidden.Created && nested.Created && hidden.IsHandleCreated && nested.IsHandleCreated);
		Test.Assert(loads == 1);
		form.Close();
	}

	[Test] public static void SDLShowingHiddenChildrenCreatesTheirSubtree() => VerifyVisibleChildren(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeShowingHiddenChildrenCreatesTheirSubtree() => VerifyVisibleChildren(.Win32);
#endif

	private static void VerifyLateChildren(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let handle = form.Handle;
		let child = new Panel(); form.Controls.Add(child);
		let nested = new Control(); child.Controls.Add(nested);
		Test.Assert(!child.IsHandleCreated && !nested.IsHandleCreated);
		form.Show();
		Test.Assert(form.Handle == handle && child.IsHandleCreated && nested.IsHandleCreated);
		let hidden = new Control(); hidden.Hide(); form.Controls.Add(hidden);
		Test.Assert(!hidden.IsHandleCreated);
		hidden.Show();
		Test.Assert(hidden.IsHandleCreated);
		form.Close();
	}

	[Test] public static void SDLChildrenAddedToHiddenHandleWaitUntilShown() => VerifyLateChildren(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeChildrenAddedToHiddenHandleWaitUntilShown() => VerifyLateChildren(.Win32);
#endif

	private static void VerifyClosedHandles(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let child = new Control(); form.Controls.Add(child);
		form.Show();
		int closed = 0;
		form.FormClosed.Add(new [&] (sender, args) =>
		{
			closed++;
			Test.Assert(form.IsHandleCreated && child.IsHandleCreated);
			Test.Assert(!form.IsDisposed && !child.IsDisposed);
			Test.Assert(Application.OpenForms.Count == 0);
		});
		form.Close();
		Test.Assert(closed == 1 && form.IsDisposed && child.IsDisposed);
		Test.Assert(!form.IsHandleCreated && !child.IsHandleCreated);
	}

	[Test] public static void SDLFormClosedRunsBeforeHandleDestruction() => VerifyClosedHandles(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeFormClosedRunsBeforeHandleDestruction() => VerifyClosedHandles(.Win32);
#endif

	private static void VerifyRawRecreation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let child = new Control(); form.Controls.Add(child);
		int loads = 0;
		form.Load.Add(new [&] (sender, args) => { loads++; });
		form.Show();
		form.[Friend]DestroyHandle();
		Test.Assert(!form.IsHandleCreated && !form.Created && !child.IsHandleCreated);
		Test.Assert(Application.OpenForms.Count == 0);
		let handle = form.Handle;
		Test.Assert(form.IsHandleCreated && !form.Created && !child.IsHandleCreated);
		form.Show();
		Test.Assert(!form.Created && Application.OpenForms.Count == 0);
		form.Hide(); form.Show();
		Test.Assert(form.Handle == handle && form.Created && child.IsHandleCreated);
		Test.Assert(loads == 1 && Application.OpenForms.Count == 1);
		form.Close();
	}

	[Test] public static void SDLRawFormRecreationRequiresVisibilityTransition() => VerifyRawRecreation(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeRawFormRecreationRequiresVisibilityTransition() => VerifyRawRecreation(.Win32);

	[Test]
	public static void NativeChildHandleDoesNotCreateItsHiddenAncestors()
	{
		Application.UseBackend(.Win32);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let panel = new Panel(); form.Controls.Add(panel);
		let child = new Control(); panel.Controls.Add(child);
		let handle = child.Handle;
		Test.Assert(handle != null && child.IsHandleCreated && !child.Created);
		Test.Assert(!form.IsHandleCreated && !panel.IsHandleCreated && Application.OpenForms.Count == 0);
		form.Show();
		Test.Assert(form.IsHandleCreated && panel.IsHandleCreated && child.Handle == handle && child.Created);
		form.Close();
	}
#endif

	[Test]
	public static void ClosingAnUncreatedFormOnlyDisposesIt()
	{
		let form = scope Form();
		int closing = 0, closed = 0, disposed = 0;
		form.FormClosing.Add(new [&] (sender, args) => { closing++; });
		form.FormClosed.Add(new [&] (sender, args) => { closed++; });
		form.Disposed.Add(new [&] (sender, args) => { disposed++; });
		form.Close();
		Test.Assert(closing == 0 && closed == 0 && disposed == 1 && form.IsDisposed);
	}
}
