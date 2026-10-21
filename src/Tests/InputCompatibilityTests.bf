using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class InputCompatibilityTests
{
	private static void PressTab(Control focused)
	{
		if (let backend = Application.Backend as SDLBackend)
		{
			SDL.Event input = .();
			input.type = .KeyDown;
			input.key.keysym.sym = .TAB;
			SDL.PushEvent(ref input);
			backend.ProcessEvents();
		}
#if BF_PLATFORM_WINDOWS
		else
			Win32.SendMessage(focused.Handle, Win32.WM_KEYDOWN, (uint*)(void*)(uint)Keys.Tab, null);
#endif
	}

	private static void VerifyContainerTabOrder(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 200);
		let group = new Panel();
		group.Size = .(150, 150);
		group.TabIndex = 0;
		let first = new Button();
		first.Size = .(80, 25);
		first.TabIndex = 10;
		let second = new Button();
		second.Size = first.Size;
		second.Location = .(0, 30);
		second.TabIndex = 10;
		group.Controls.Add(first);
		group.Controls.Add(second);
		let outside = new Button();
		outside.Size = first.Size;
		outside.Location = .(180, 0);
		outside.TabIndex = 1;
		form.Controls.Add(group);
		form.Controls.Add(outside);
		form.KeyPreview = true;
		int tabEvents = 0;
		form.KeyDown.Add(new [&] (sender, args) => { tabEvents++; args.Handled = true; });
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		if (let sdl = Application.Backend as SDLBackend) SDLTestInput.Activate(sdl);

		outside.Focus();
		PressTab(outside);
		Test.Assert(second.Focused);
		PressTab(second);
		Test.Assert(first.Focused);
		PressTab(first);
		Test.Assert(outside.Focused);
		first.BringToFront();
		PressTab(outside);
		Test.Assert(first.Focused);
		Test.Assert(Control.NextTabControl(form, first, true) == outside);
		group.Enabled = false;
		outside.Focus();
		PressTab(outside);
		Test.Assert(outside.Focused && tabEvents == 0);
	}

	[Test]
	public static void SDLTabOrderStaysWithinEachContainer() => VerifyContainerTabOrder(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeTabOrderStaysWithinEachContainer() => VerifyContainerTabOrder(.Win32);
#endif

	[Test]
	public static void FormKeyPreviewRunsBeforeTheTargetAndCanCancelIt()
	{
		let form = scope Form();
		let panel = new Panel();
		let editor = new TextBox();
		panel.Controls.Add(editor);
		form.Controls.Add(panel);
		let events = scope String();
		bool cancel = false;
		form.KeyDown.Add(new [&] (sender, args) => { events.Append('F'); args.SuppressKeyPress = cancel; });
		panel.KeyDown.Add(new [&] (sender, args) => events.Append('P'));
		editor.KeyDown.Add(new [&] (sender, args) => events.Append('C'));
		editor.DispatchInput(.KeyDown, scope KeyEventArgs(.A));
		Test.Assert(events == "C");
		events.Clear();
		form.KeyPreview = true;
		editor.DispatchInput(.KeyDown, scope KeyEventArgs(.A));
		Test.Assert(events == "FC");
		events.Clear();
		cancel = true;
		editor.DispatchInput(.KeyDown, scope KeyEventArgs(.A));
		Test.Assert(events == "F");
		form.KeyPress.Add(new (sender, args) => { args.KeyChar = 'b'; });
		let accepted = scope String();
		editor.FilterTextInput("a", accepted);
		Test.Assert(accepted == "b");
	}
}
