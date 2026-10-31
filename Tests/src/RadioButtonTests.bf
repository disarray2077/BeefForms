using System;
using System.Windows.Forms;
using SDL2;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class RadioButtonTests
{
	[Test]
	public static void DefaultsAndCheckedChangedMatchRadioButtonBehavior()
	{
		let parent = scope Panel();
		let first = new RadioButton();
		let second = new RadioButton();
		Test.Assert(!first.Checked && first.AutoCheck && !first.TabStop && first.Size == .(104, 24));
		parent.Controls.Add(first);
		parent.Controls.Add(second);
		let events = scope String();
		first.Checked = true;
		first.CheckedChanged.Add(new (sender, args) =>
		{
			Test.Assert(!first.Checked && second.Checked);
			events.Append('A');
		});
		second.CheckedChanged.Add(new (sender, args) =>
		{
			Test.Assert(second.Checked && !first.Checked);
			events.Append('B');
		});
		second.Click.Add(new (sender, args) => events.Append('C'));
		second.PerformClick();
		second.PerformClick();
		Test.Assert(events == "ABCC" && second.TabStop && !first.TabStop);
	}

	[Test]
	public static void ManualRadioButtonsAndSeparateParentsAreIndependent()
	{
		let parent = scope Panel();
		let otherParent = scope Panel();
		let first = new RadioButton();
		let second = new RadioButton();
		let separate = new RadioButton();
		parent.Controls.Add(first);
		parent.Controls.Add(second);
		otherParent.Controls.Add(separate);
		second.Checked = true;
		separate.Checked = true;
		first.AutoCheck = false;
		first.Checked = true;
		Test.Assert(first.Checked && second.Checked && separate.Checked && !first.TabStop);
		first.PerformClick();
		Test.Assert(first.Checked && second.Checked);
		first.AutoCheck = true;
		Test.Assert(first.Checked && !second.Checked && separate.Checked && first.TabStop);
		second.Checked = true;
		Test.Assert(!first.Checked && second.Checked && separate.Checked);
	}

	[Test]
	public static void AddingPrecheckedRadiosDoesNotChangeTheirState()
	{
		let parent = scope Panel();
		let first = new RadioButton();
		let second = new RadioButton();
		first.Checked = true;
		second.Checked = true;
		parent.Controls.Add(first);
		parent.Controls.Add(second);
		first.Checked = true;
		Test.Assert(first.Checked && second.Checked);
		first.Checked = false;
		first.Checked = true;
		Test.Assert(first.Checked && !second.Checked);
	}

	[Test]
	public static void GroupChangesTolerateRemovalDuringCheckedChanged()
	{
		let parent = scope Panel();
		let first = new RadioButton();
		let second = new RadioButton();
		let detached = scope RadioButton();
		parent.Controls.Add(first);
		parent.Controls.Add(second);
		parent.Controls.Add(detached);
		first.Checked = true;
		first.CheckedChanged.Add(new (sender, args) => parent.Controls.Remove(detached));
		second.Checked = true;
		Test.Assert(second.Checked && !first.Checked && detached.Parent == null);
	}

	[Test]
	public static void TabTraversalUsesExplicitAndCheckedTabStops()
	{
		let parent = scope Panel();
		let before = new Button();
		before.TabIndex = 0;
		let first = new RadioButton();
		first.TabIndex = 1;
		let second = new RadioButton();
		second.TabIndex = 2;
		let after = new Button();
		after.TabIndex = 3;
		parent.Controls.Add(before);
		parent.Controls.Add(first);
		parent.Controls.Add(second);
		parent.Controls.Add(after);
		Test.Assert(Control.NextTabControl(parent, before, false) == after);
		Test.Assert(Control.NextTabControl(parent, after, true) == before);
		first.TabStop = true;
		Test.Assert(Control.NextTabControl(parent, before, false) == first);
		first.Checked = true;
		second.Checked = true;
		Test.Assert(!first.TabStop && second.TabStop);
		Test.Assert(Control.NextTabControl(parent, before, false) == second);
		second.Checked = false;
		Test.Assert(!first.TabStop && !second.TabStop);
		Test.Assert(Control.NextTabControl(parent, before, false) == after);
	}

	private static void Key(RadioButton radio, Keys key)
	{
		if (let backend = Application.Backend as SDLBackend)
		{
			SDL.Event input = .();
			input.type = .KeyDown;
			input.key.keysym.sym = key == .Space ? .SPACE : .RIGHT;
			SDLTestInput.PushEvent(ref input, radio.FindForm());
			backend.ProcessEvents();
		}
#if BF_PLATFORM_WINDOWS
		else
		{
			Win32.SendMessage(radio.Handle, Win32.WM_KEYDOWN, (uint*)(void*)(int)key, null);
			Win32.SendMessage(radio.Handle, Win32.WM_KEYUP, (uint*)(void*)(int)key, null);
		}
#endif
	}

	private static void AssertNativeCheck(RadioButton radio)
	{
#if BF_PLATFORM_WINDOWS
		if (Application.Backend.Type == .Win32)
		{
			Test.Assert((int)(void*)Win32.SendMessage(radio.Handle, Win32.BM_GETCHECK, null, null) == (radio.Checked ? 1 : 0));
			Test.Assert(((uint)(void*)Win32.GetWindowLongPtr(radio.Handle, Win32.GWL_STYLE) & 0xF) == Win32.BS_RADIOBUTTON);
		}
#endif
	}

	private static void VerifyInput(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 160);
		let first = new RadioButton();
		first.Text = "First option";
		first.TabIndex = 0;
		let skipped = new RadioButton();
		skipped.Enabled = false;
		skipped.TabIndex = 1;
		skipped.Location = .(0, 35);
		let second = new RadioButton();
		second.Text = "Second option";
		second.TabIndex = 2;
		second.Location = .(0, 70);
		form.Controls.Add(first);
		form.Controls.Add(skipped);
		form.Controls.Add(second);
		form.Show();
		if (let sdl = Application.Backend as SDLBackend)
			SDLTestInput.Activate(sdl);
		Test.Assert(Control.NextTabControl(form, null, false) == null);
		first.TabStop = true;
		Test.Assert(Control.NextTabControl(form, null, false) == first);
		Test.Assert(first.Focus());
		Key(first, .Space);
		Test.Assert(first.Checked && !second.Checked);
		AssertNativeCheck(first);
		Key(first, .Right);
		Test.Assert(!first.Checked && second.Checked && second.Focused);
		Test.Assert(Control.NextTabControl(form, null, false) == second);
		AssertNativeCheck(first);
		AssertNativeCheck(second);
		Key(second, .Space);
		Test.Assert(second.Checked);
		Key(second, .Right);
		Test.Assert(first.Checked && first.Focused && !second.Checked);
		second.AutoCheck = false;
		second.PerformClick();
		Test.Assert(first.Checked && !second.Checked);
		second.Enabled = false;
		second.Checked = true;
		second.PerformClick();
		Test.Assert(first.Checked && second.Checked);
		AssertNativeCheck(second);
		if (let sdl = Application.Backend as SDLBackend)
		{
			sdl.FrameLimit = 1;
			sdl.Run(form);
			SDLTestInput.AssertNoGLError(form);
		}
		form.Close();
		Application.Backend.Run(form);
	}

	private static void VerifyMouse(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let radio = new RadioButton();
		form.Controls.Add(radio);
		form.Show();
		if (let sdl = Application.Backend as SDLBackend)
		{
			SDLTestInput.Activate(sdl);
			SDL.Event input = .();
			input.type = .MouseButtonDown;
			input.button.button = 1;
			input.button.x = 8;
			input.button.y = 8;
			SDLTestInput.PushEvent(ref input);
			input.type = .MouseButtonUp;
			SDLTestInput.PushEvent(ref input);
			sdl.ProcessEvents();
		}
#if BF_PLATFORM_WINDOWS
		else
		{
			Win32.SendMessage(radio.Handle, Win32.WM_LBUTTONDOWN, (uint*)(void*)1, (int*)(void*)0x00080008);
			Win32.SendMessage(radio.Handle, Win32.WM_LBUTTONUP, null, (int*)(void*)0x00080008);
		}
#endif
		Test.Assert(radio.Checked);
		AssertNativeCheck(radio);
		form.Close();
		Application.Backend.Run(form);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeRadioMouseActivation()
	{
		VerifyMouse(.Win32);
	}

	[Test]
	public static void NativeRadioKeyboardAndCheckedState()
	{
		VerifyInput(.Win32);
	}
#endif

#if BF_DEPENDS_BEEFFORMS_SDL
	[Test]
	public static void SDLRadioMouseActivation()
	{
		VerifyMouse(.SDL2OpenGL);
	}

	[Test]
	public static void SDLRadioKeyboardAndRendering()
	{
		VerifyInput(.SDL2OpenGL);
	}
#endif
}
