using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class ApplicationTests
{
	[Test]
	public static void DoEventsPumpsInputAndPaintAndReturnsWhenIdle()
	{
		Application.UseBackend(.SDL2OpenGL);
		Application.DoEvents(); // No window yet.
		let form = scope Form();
		form.ClientSize = .(200, 100);
		let editor = new TextBox();
		editor.Size = .(150, 25);
		let panel = new Panel();
		panel.Size = .(200, 100);
		panel.Controls.Add(editor);
		form.Controls.Add(panel);
		int paints = 0;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			paints++;
			Application.DoEvents(); // Nested calls must not reenter painting.
		});
		form.Show();
		Test.Assert(paints == 0);
		Application.DoEvents();
		Test.Assert(paints == 1);
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		editor.Focus();
		SDL.Event input = .();
		input.type = .TextInput;
		input.text.text[0] = (uint8)'x';
		SDLTestInput.PushEvent(ref input);
		Application.DoEvents();
		Test.Assert(editor.Text == "x");
		let painted = paints;
		Application.DoEvents();
		Test.Assert(paints == painted);
		panel.Invalidate();
		Application.DoEvents();
		Test.Assert(paints == painted + 1);
		input = .();
		input.type = .Quit;
		SDLTestInput.PushEvent(ref input);
		Application.DoEvents();
		Test.Assert(!form.IsHandleCreated);
		Application.DoEvents(); // A callback may still run after Close.
	}

	[Test]
	public static void SDLFontPathIsCopiedAndCanBeReset()
	{
		let path = scope String("custom.ttf");
		Application.SDLFontPath = path;
		path.Clear();
		Test.Assert(Application.SDLFontPath == "custom.ttf");
		Application.SDLFontPath = "";
		Test.Assert(Application.SDLFontPath.IsEmpty);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeDoEventsPaintsAndPreservesExplicitQuitForRun()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(200, 100);
		let panel = new Panel();
		panel.Size = .(100, 50);
		form.Controls.Add(panel);
		form.Show();
		Application.DoEvents();
		int paints = 0;
		panel.Paint.Add(new [&] (sender, args) => { paints++; });
		panel.Invalidate();
		Application.DoEvents();
		Test.Assert(paints == 1);
		Win32.PostQuitMessage(0);
		Application.DoEvents();
		Application.Backend.Run(form); // Must still see the queued WM_QUIT.
		Test.Assert(form.IsHandleCreated);
		form.Close();
	}
#endif

	[Test]
	public static void BackendCanChangeAfterCreatedControlsAreDisposed()
	{
		Application.UseBackend(.SDL2OpenGL);
		{
			let form = scope Form();
			form.ClientSize = .(200, 100);
			let button = new Button();
			button.Size = .(80, 25);
			form.Controls.Add(button);
			form.Show();
			form.Close();
		}
		Application.UseBackend(.SDL2OpenGL);
	}
}
