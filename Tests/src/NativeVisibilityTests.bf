using System;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

#if BF_PLATFORM_WINDOWS
class NativeVisibilityTests
{
	private static void VerifyDestroyedChildVisibility(bool initiallyHidden)
	{
		Application.UseBackend(.Win32);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let panel = new Panel(); form.Controls.Add(panel);
		let child = new Control(); panel.Controls.Add(child);
		let hidden = new Control(); hidden.Hide(); panel.Controls.Add(hidden);
		form.Show();
		if (initiallyHidden) panel.Hide();
		let events = scope String();
		int hiddenChanges = 0;
		bool handlePresentWhenHidden = false;
		panel.VisibleChanged.Add(new [&] (sender, args) =>
		{
			events.Append(panel.Visible ? 'P' : 'H');
			if (!panel.Visible) handlePresentWhenHidden = panel.Created && panel.IsHandleCreated && child.IsHandleCreated;
		});
		child.VisibleChanged.Add(new (sender, args) => { events.Append(child.Visible ? 'C' : 'h'); });
		hidden.VisibleChanged.Add(new [&] (sender, args) => { hiddenChanges++; });
		Test.Assert(Win32.DestroyWindow(panel.Handle));
		Test.Assert(!panel.Visible && !child.Visible && !panel.IsHandleCreated && !child.IsHandleCreated);
		Test.Assert(!panel.LocallyVisible && child.LocallyVisible && !hidden.LocallyVisible);
		Test.Assert(events == (initiallyHidden ? "" : "H") && hiddenChanges == 0);
		if (!initiallyHidden) Test.Assert(handlePresentWhenHidden);
		Test.Assert(panel.Handle != null && panel.IsHandleCreated && !panel.Visible && !panel.Created);
		panel.CreateControl();
		Test.Assert(!child.IsHandleCreated && !hidden.IsHandleCreated);
		Test.Assert(events == (initiallyHidden ? "" : "H"));
		panel.Show();
		Test.Assert(panel.Visible && child.Visible && panel.Created && child.IsHandleCreated);
		Test.Assert(!hidden.Visible && !hidden.IsHandleCreated && hiddenChanges == 0);
		Test.Assert(events == (initiallyHidden ? "PC" : "HPC"));
		form.Dispose();
		Test.Assert(Application.CreatedControlCount == 0 && Application.OpenForms.Count == 0);
	}

	[Test] public static void DestroyedVisibleChildStaysHiddenUntilShown() => VerifyDestroyedChildVisibility(false);
	[Test] public static void DestroyedHiddenChildDoesNotRepeatVisibilityNotifications() => VerifyDestroyedChildVisibility(true);

	[Test]
	public static void DestroyingTheFormPreservesItsControlsVisibilitySettings()
	{
		Application.UseBackend(.Win32);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let panel = new Panel(); form.Controls.Add(panel);
		let child = new Control(); panel.Controls.Add(child);
		int changes = 0, loads = 0;
		form.Load.Add(new [&] (sender, args) => { loads++; });
		form.Show();
		form.VisibleChanged.Add(new [&] (sender, args) => { changes++; });
		panel.VisibleChanged.Add(new [&] (sender, args) => { changes++; });
		child.VisibleChanged.Add(new [&] (sender, args) => { changes++; });
		Test.Assert(Win32.DestroyWindow(form.Handle));
		Test.Assert(form.Visible && panel.Visible && child.Visible && changes == 0);
		Test.Assert(!form.IsHandleCreated && !panel.IsHandleCreated && !child.IsHandleCreated);
		Test.Assert(form.Handle != null && !form.Created && !panel.IsHandleCreated && changes == 0);
		form.Hide(); form.Show();
		Test.Assert(form.Created && panel.Created && child.Created && loads == 1);
		form.Dispose();
		Test.Assert(Application.CreatedControlCount == 0 && Application.OpenForms.Count == 0);
	}

	[Test]
	public static void NativeHideAndShowSynchronizeVisibilityWithoutDuplicateEvents()
	{
		Application.UseBackend(.Win32);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let panel = new Panel(); form.Controls.Add(panel);
		let child = new Control(); panel.Controls.Add(child);
		form.Show();
		let events = scope String();
		panel.VisibleChanged.Add(new (sender, args) => { events.Append(panel.Visible ? 'P' : 'H'); });
		child.VisibleChanged.Add(new (sender, args) => { events.Append(child.Visible ? 'C' : 'h'); });
		Win32.ShowWindow(panel.Handle, Win32.SW_HIDE);
		Test.Assert(!panel.Visible && !child.Visible && events == "H");
		Win32.ShowWindow(panel.Handle, Win32.SW_SHOW);
		Test.Assert(panel.Visible && child.Visible && events == "HPC");
		events.Clear();
		panel.Hide(); panel.Show();
		Test.Assert(events == "HPC");
		form.Dispose();
	}

	[Test]
	public static void DestroyingAStandaloneControlPreservesItsLocalVisibility()
	{
		Application.UseBackend(.Win32);
		let panel = scope Panel();
		let child = new Control(); panel.Controls.Add(child);
		let handle = panel.Handle;
		let events = scope String();
		panel.VisibleChanged.Add(new (sender, args) => { events.Append(panel.Visible ? 'P' : 'H'); });
		child.VisibleChanged.Add(new (sender, args) => { events.Append(child.Visible ? 'C' : 'h'); });
		Test.Assert(Win32.DestroyWindow(handle));
		Test.Assert(panel.Visible && child.Visible && events == "PC");
		Test.Assert(!panel.IsHandleCreated && !child.IsHandleCreated);
		Test.Assert(panel.Handle != null && panel.Created && child.IsHandleCreated && events == "PC");
	}

	[Test]
	public static void NativeVisibilityCallbackCanDisposeTheForm()
	{
		Application.UseBackend(.Win32);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let panel = new Panel(); form.Controls.Add(panel);
		form.Show();
		panel.VisibleChanged.Add(new (sender, args) => { if (!panel.Visible) form.Dispose(); });
		Win32.ShowWindow(panel.Handle, Win32.SW_HIDE);
		Test.Assert(form.IsDisposed && panel.IsDisposed && !panel.IsHandleCreated);
		Test.Assert(Application.CreatedControlCount == 0 && Application.OpenForms.Count == 0);
	}
}
#endif
