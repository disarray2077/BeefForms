using System;
using System.ComponentModel;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class ControlLifetimeTests
{
	[Test]
	public static void UncreatedControlsAcceptInputUntilDisposed()
	{
		let form = scope Form();
		let panel = new Panel();
		let editor = new TextBox();
		form.Controls.Add(panel);
		panel.Controls.Add(editor);
		int presses = 0, disposals = 0;
		editor.KeyPress.Add(new [&] (sender, args) => { presses++; });
		editor.Disposed.Add(new [&] (sender, args) => { disposals++; });
		let accepted = scope String();
		editor.FilterTextInput("a", accepted);
		Test.Assert(accepted == "a" && presses == 1);
		Test.Assert(!editor.IsHandleCreated && !editor.Disposing && !editor.IsDisposed);
		form.Close();
		Test.Assert(form.IsDisposed && panel.IsDisposed && editor.IsDisposed && disposals == 1);
		accepted.Clear();
		editor.FilterTextInput("b", accepted);
		Test.Assert(accepted.IsEmpty && presses == 1);
		form.Dispose();
		Test.Assert(disposals == 1);
	}

	[Test]
	public static void DisposeMarksTheSubtreeWithoutDeletingObjects()
	{
		let parent = scope Panel();
		let child = new Panel();
		let editor = new TextBox();
		parent.Controls.Add(child);
		child.Controls.Add(editor);
		let events = scope String();
		editor.Disposed.Add(new (sender, args) =>
		{
			Test.Assert(editor.Disposing && !editor.IsDisposed);
			Test.Assert(parent.Disposing && child.Disposing);
			events.Append('E');
			parent.Dispose(); // Reentrant disposal must not restart the cascade.
		});
		child.Disposed.Add(new (sender, args) =>
		{
			Test.Assert(child.Disposing && !child.IsDisposed && editor.IsDisposed);
			events.Append('C');
		});
		parent.Disposed.Add(new (sender, args) =>
		{
			Test.Assert(parent.Disposing && !parent.IsDisposed && child.IsDisposed);
			events.Append('P');
		});
		parent.Dispose();
		Test.Assert(events == "ECP" && parent.IsDisposed && child.IsDisposed && editor.IsDisposed);
		Test.Assert(!parent.Disposing && !child.Disposing && !editor.Disposing);
		Test.Assert(parent.Controls.Contains(child) && child.Controls.Contains(editor));
		parent.Dispose();
		child.Dispose();
		Test.Assert(events == "ECP");
	}

	[Test]
	public static void ComponentDisposalIsIdempotentAcrossDelete()
	{
		let component = new Component();
		int disposals = 0;
		component.Disposed.Add(new [&] (sender, args) => { disposals++; });
		IComponent reference = component;
		reference.Dispose();
		reference.Dispose();
		Test.Assert(disposals == 1);
		delete component;
		Test.Assert(disposals == 1);
	}

	[Test]
	public static void DisposedControlEventsAreNotRepeatedByDelete()
	{
		let control = new Control();
		int disposals = 0;
		control.Disposed.Add(new [&] (sender, args) => { disposals++; });
		control.Dispose();
		Test.Assert(control.IsDisposed && !control.Disposing && disposals == 1);
		delete control;
		Test.Assert(disposals == 1);
	}

	private static void VerifyDisposeDuringLoad(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		form.Controls.Add(new TextBox());
		form.Load.Add(new (sender, args) => { form.Dispose(); });
		form.Show();
		Test.Assert(form.IsDisposed && form.Controls[0].IsDisposed && !form.IsHandleCreated);
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32) Application.Backend.Run(form);
#endif
	}

	[Test]
	public static void SDLDisposeDuringLoadDoesNotShowTheForm() => VerifyDisposeDuringLoad(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeDisposeDuringLoadDoesNotShowTheForm() => VerifyDisposeDuringLoad(.Win32);
#endif

	[Test]
	public static void SDLDisposeDuringPaintSkipsDisposedSubtreesOnLaterFrames()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(100, 100);
		let editor = new TextBox();
		editor.Size = .(90, 30);
		panel.Controls.Add(editor);
		let sibling = new Panel();
		sibling.Location = .(120, 0);
		sibling.Size = panel.Size;
		form.Controls.Add(panel);
		form.Controls.Add(sibling);
		int paints = 0, siblingPaints = 0;
		panel.Paint.Add(new [&] (sender, args) => { paints++; panel.Dispose(); });
		sibling.Paint.Add(new [&] (sender, args) => { siblingPaints++; });
		form.Show();
		Application.DoEvents();
		Test.Assert(paints == 1 && siblingPaints == 1 && panel.IsDisposed && editor.IsDisposed);
		Test.Assert(form.IsHandleCreated && !form.IsDisposed && !editor.CanSelect);
		let backend = (SDLBackend)Application.Backend;
		Test.Assert(backend.[Friend]HitTest(form, 10, 10) == form);
		Test.Assert(Control.NextTabControl(form, null, false) == null);
		panel.Invalidate();
		sibling.Invalidate();
		form.Invalidate();
		Application.DoEvents();
		Test.Assert(paints == 1 && siblingPaints >= 2 && form.IsHandleCreated);
		form.Close();
	}

	private static void VerifyDisposeDuringInput(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let editor = new TextBox();
		editor.Size = .(120, 30);
		editor.Text = "seed";
		form.Controls.Add(editor);
		form.Show();
		let sdl = Application.Backend as SDLBackend;
		if (sdl != null) SDLTestInput.Activate(sdl);
		editor.Focus();
		editor.SelectAll();
		int presses = 0;
		editor.KeyPress.Add(new [&] (sender, args) => { presses++; });
		editor.TextInput.Add(new (sender, args) => { editor.Dispose(); });
		if (sdl != null) SDLTestInput.TypeText(sdl, "ab");
#if BF_PLATFORM_WINDOWS
		else Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(uint)'a', null);
#endif
		Test.Assert(editor.IsDisposed && !editor.Disposing && !editor.IsHandleCreated);
		Test.Assert(editor.Text == "seed" && presses == 0);
		Test.Assert(form.IsHandleCreated && !form.IsDisposed && Application.CreatedControlCount == 1);
		form.Close();
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32) Application.Backend.Run(form);
#endif
	}

	[Test]
	public static void SDLDisposeDuringInputStopsEditingWithoutClosingTheForm() => VerifyDisposeDuringInput(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeDisposeDuringInputStopsEditingWithoutClosingTheForm() => VerifyDisposeDuringInput(.Win32);
#endif

	private static void VerifyHandleLifetime(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let first = new Panel();
		first.Size = .(100, 120);
		let second = new Panel();
		second.Location = .(120, 0);
		second.Size = first.Size;
		let editor = new TextBox();
		editor.Size = .(90, 30);
		first.Controls.Add(editor);
		form.Controls.Add(first);
		form.Controls.Add(second);
		form.Show();
		int disposals = 0, keys = 0;
		editor.Disposed.Add(new [&] (sender, args) => { disposals++; });
		editor.KeyDown.Add(new [&] (sender, args) => { keys++; });
		Test.Assert(editor.IsHandleCreated && !editor.IsDisposed);

		editor.DestroyHandle();
		Test.Assert(!editor.IsHandleCreated && !editor.IsDisposed && !editor.Disposing && disposals == 0);
		editor.CreateHandle();
		Test.Assert(editor.IsHandleCreated && !editor.IsDisposed);

		first.Controls.Remove(editor);
		Test.Assert(editor.Parent == null && !editor.IsHandleCreated && !editor.IsDisposed && disposals == 0);
		second.Controls.Add(editor);
		Test.Assert(editor.Parent == second && editor.IsHandleCreated && !editor.IsDisposed);
		first.Controls.Add(editor);
		Test.Assert(editor.Parent == first && editor.IsHandleCreated && !editor.IsDisposed);
		first.Controls.Clear();
		Test.Assert(editor.Parent == null && !editor.IsHandleCreated && !editor.IsDisposed && disposals == 0);
		second.Controls.Add(editor);
		editor.DispatchInput(.KeyDown, scope KeyEventArgs(.A));
		Test.Assert(keys == 1);

		form.Close();
		Test.Assert(editor.IsDisposed && !editor.IsHandleCreated && disposals == 1);
		editor.DispatchInput(.KeyDown, scope KeyEventArgs(.A));
		Test.Assert(keys == 1);
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32) Application.Backend.Run(form);
#endif
	}

	[Test]
	public static void SDLHandleDestructionRemovalAndReparentingDoNotDispose() => VerifyHandleLifetime(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeHandleDestructionRemovalAndReparentingDoNotDispose() => VerifyHandleLifetime(.Win32);
#endif
}
