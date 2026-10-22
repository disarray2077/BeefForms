using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;
using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class CheckBoxTests
{
	[Test]
	public static void CheckedChangesBeforeClickAndAutoCheckCanBeDisabled()
	{
		let check = scope CheckBox();
		let events = scope String();
		check.CheckedChanged.Add(new [&] (sender, args) => events.Append('S'));
		check.Click.Add(new [&] (sender, args) => { Test.Assert(check.Checked); events.Append('C'); });
		check.PerformClick();
		Test.Assert(events == "SC");
		check.AutoCheck = false;
		check.PerformClick();
		Test.Assert(events == "SCC" && check.Checked);
	}

	private static void VerifyInput(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let check = new CheckBox();
		check.Text = "Save to file";
		check.Size = .(200, 25);
		form.Controls.Add(check);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		if (let sdl = Application.Backend as SDLBackend)
		{
			SDLTestInput.Activate(sdl);
			SDL.Event input = .();
			input.type = .MouseButtonDown;
			input.button.button = 1;
			input.button.x = 10;
			input.button.y = 10;
			SDLTestInput.PushEvent(ref input);
			input.type = .MouseButtonUp;
			SDLTestInput.PushEvent(ref input);
			sdl.ProcessEvents();
			Test.Assert(check.Checked);
			input = .();
			input.type = .KeyDown;
			input.key.keysym.sym = .SPACE;
			SDLTestInput.PushEvent(ref input);
			sdl.ProcessEvents();
			Test.Assert(!check.Checked);
			sdl.FrameLimit = 1;
			sdl.Run(form);
		}
#if BF_PLATFORM_WINDOWS
		else
		{
			Win32.SendMessage(check.Handle, Win32.WM_LBUTTONDOWN, (uint*)(void*)1, (int*)(void*)0x000A000A);
			Win32.SendMessage(check.Handle, Win32.WM_LBUTTONUP, null, (int*)(void*)0x000A000A);
			Test.Assert(check.Checked && (int)(void*)Win32.SendMessage(check.Handle, Win32.BM_GETCHECK, null, null) == 1);
			check.Checked = false;
			Test.Assert((int)(void*)Win32.SendMessage(check.Handle, Win32.BM_GETCHECK, null, null) == 0);
			check.Enabled = false;
			Test.Assert(Win32.IsWindowEnabled(check.Handle) == 0);
		}
#endif
	}
	[Test]
	public static void SDLCheckBoxSupportsMouseAndKeyboard() => VerifyInput(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeCheckBoxSynchronizesCheckedAndEnabled() => VerifyInput(.Win32);
#endif
}
