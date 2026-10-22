using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class LifecycleReviewTests
{
	private static void VerifyDisposedChildBeforeShow(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let disposed = new Panel();
		defer delete disposed;
		let descendant = new TextBox();
		disposed.Controls.Add(descendant);
		let live = new TextBox();
		live.Size = .(100, 30);
		form.Controls.Add(disposed);
		form.Controls.Add(live);
		disposed.Dispose();
		form.Show();
		Test.Assert(form.IsHandleCreated && live.IsHandleCreated);
		Test.Assert(disposed.IsDisposed && !disposed.IsHandleCreated && descendant.IsDisposed && !descendant.IsHandleCreated);
		Test.Assert(disposed.Parent == null && descendant.Parent == null && disposed.Controls.IsEmpty);
		Test.Assert(form.Controls.Count == 1 && form.Controls[0] == live);
		Test.Assert(Application.CreatedControlCount == 2);
		form.Close();
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32) Application.Backend.Run(form);
#endif
	}

	[Test]
	public static void SDLShowAfterChildDisposal() => VerifyDisposedChildBeforeShow(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeShowAfterChildDisposal() => VerifyDisposedChildBeforeShow(.Win32);
#endif

	private static void VerifyParentRecreation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let parent = new Panel();
		parent.Size = .(200, 120);
		let disposed = new TextBox();
		defer delete disposed;
		let live = new TextBox();
		live.Size = .(100, 30);
		parent.Controls.Add(disposed);
		parent.Controls.Add(live);
		form.Controls.Add(parent);
		form.Show();
		disposed.Dispose();
		parent.DestroyHandle();
		parent.CreateHandle();
		Test.Assert(parent.IsHandleCreated && live.IsHandleCreated && !parent.IsDisposed && !live.IsDisposed);
		Test.Assert(disposed.IsDisposed && !disposed.IsHandleCreated && Application.CreatedControlCount == 3);
		Test.Assert(disposed.Parent == null && parent.Controls.Count == 1 && parent.Controls[0] == live);
		form.Close();
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32) Application.Backend.Run(form);
#endif
	}

	[Test]
	public static void SDLParentRecreationAfterChildDisposal() => VerifyParentRecreation(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeParentRecreationAfterChildDisposal() => VerifyParentRecreation(.Win32);
#endif

	[Test]
	public static void DisposalContinuesWhenFirstChildRemovesItself()
	{
		let parent = new Panel();
		let first = new Control();
		let second = new Control();
		let third = new Control();
		parent.Controls.Add(first);
		parent.Controls.Add(second);
		parent.Controls.Add(third);
		int firstDisposals = 0, secondDisposals = 0, thirdDisposals = 0;
		first.Disposed.Add(new [&] (sender, args) => { firstDisposals++; parent.Controls.Remove(first); });
		second.Disposed.Add(new [&] (sender, args) => { secondDisposals++; });
		third.Disposed.Add(new [&] (sender, args) => { thirdDisposals++; });
		parent.Dispose();
		Test.Assert(first.Parent == null && second.IsDisposed && third.IsDisposed);
		Test.Assert(firstDisposals == 1 && secondDisposals == 1 && thirdDisposals == 1);
		delete parent;
		Test.Assert(firstDisposals == 1 && secondDisposals == 1 && thirdDisposals == 1);
	}

	private static void Recreate(Control control)
	{
		control.DestroyHandle();
		control.CreateHandle();
	}

	private static void VerifyTextRecreation(ApplicationBackend backend, bool duringKeyPress)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let editor = new TextBox();
		editor.Size = .(160, 30);
		editor.Text = "seed";
		form.Controls.Add(editor);
		form.Show();
		let sdl = Application.Backend as SDLBackend;
		if (sdl != null) SDLTestInput.Activate(sdl);
		editor.Focus();
		editor.SelectAll();
		int presses = 0, recreations = 0;
		editor.KeyPress.Add(new [&] (sender, args) => { presses++; });
		if (duringKeyPress)
			editor.KeyPress.Add(new [&] (sender, args) => { recreations++; Recreate(editor); });
		else
			editor.TextInput.Add(new [&] (sender, args) => { recreations++; Recreate(editor); });
		if (sdl != null) SDLTestInput.TypeText(sdl, "ab");
#if BF_PLATFORM_WINDOWS
		else Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(uint)'a', null);
#endif
		Test.Assert(recreations == 1 && presses == (duringKeyPress ? 1 : 0));
		Test.Assert(editor.IsHandleCreated && !editor.IsDisposed && editor.Text == "seed");
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32)
		{
			char16[32] text = .();
			Win32.GetWindowText(editor.Handle, &text, text.Count);
			Test.Assert(scope String(&text) == "seed");
		}
#endif
		form.Close();
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32) Application.Backend.Run(form);
#endif
	}

	[Test]
	public static void SDLRecreationInTextInputStopsOldInput() => VerifyTextRecreation(.SDL2OpenGL, false);
	[Test]
	public static void SDLRecreationInKeyPressStopsOldInput() => VerifyTextRecreation(.SDL2OpenGL, true);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeRecreationInTextInputStopsOldInput() => VerifyTextRecreation(.Win32, false);
	[Test]
	public static void NativeRecreationInKeyPressStopsOldInput() => VerifyTextRecreation(.Win32, true);
#endif

	private static void VerifyMouseRecreation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let editor = new TextBox();
		editor.Size = .(160, 30);
		form.Controls.Add(editor);
		form.Show();
		let sdl = Application.Backend as SDLBackend;
		if (sdl != null) SDLTestInput.Activate(sdl);
		int downs = 0, doubles = 0;
		editor.MouseDown.Add(new [&] (sender, args) => { downs++; Recreate(editor); });
		editor.MouseDoubleClick.Add(new [&] (sender, args) => { doubles++; });
		if (sdl != null)
		{
			SDL.Event input = .();
			input.type = .MouseButtonDown;
			input.button.button = 1;
			input.button.clicks = 2;
			input.button.x = 10;
			input.button.y = 10;
			sdl.[Friend]ProcessEvent(ref input);
		}
#if BF_PLATFORM_WINDOWS
		else Win32.SendMessage(editor.Handle, Win32.WM_LBUTTONDBLCLK, (uint*)(void*)1, (int*)(void*)((10 << 16) | 10));
#endif
		Test.Assert(downs == 1 && doubles == 0 && editor.IsHandleCreated && !editor.IsDisposed);
		Test.Assert(!editor.Capture);
		form.Close();
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32) Application.Backend.Run(form);
#endif
	}

	[Test]
	public static void SDLRecreationInMouseDownStopsDoubleClick() => VerifyMouseRecreation(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeRecreationInMouseDownStopsDoubleClick() => VerifyMouseRecreation(.Win32);
#endif
}
