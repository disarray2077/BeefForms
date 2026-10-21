using System;
using System.Windows.Forms;
using SDL2;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class SDLInputTests
{
	private class FocusTextBox : TextBox
	{
		public int Gains, Losses;
		protected override void OnGotFocus(EventArgs args) { base.OnGotFocus(args); Gains++; }
		protected override void OnLostFocus(EventArgs args) { base.OnLostFocus(args); Losses++; }
		protected override void OnKeyDown(KeyEventArgs args)
		{
			base.OnKeyDown(args);
			if (args.KeyCode == .A) args.SuppressKeyPress = true;
		}
	}

	[Test]
	public static void FocusAndTextInputResumeAfterWindowActivation()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new FocusTextBox();
		editor.Size = .(200, 30);
		form.Controls.Add(editor);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		editor.Focus();
		editor.Capture = true;
		SDL.Event key = .();
		key.type = .KeyDown;
		key.key.keysym.sym = .A;
		SDL.PushEvent(ref key);
		backend.ProcessEvents();

		SDLTestInput.SetActive(backend, false);
		Test.Assert(!editor.Focused && !editor.Capture && SDL.IsTextInputActive() == .False);
		SDLTestInput.SetActive(backend, true);
		Test.Assert(editor.Focused && SDL.IsTextInputActive() == .True);
		SDLTestInput.TypeText(backend, "a");
		Test.Assert(editor.Text == "a" && editor.Gains == 2 && editor.Losses == 1);
	}

	[Test]
	public static void ExplicitCaptureSurvivesButtonRelease()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let control = new Control();
		control.Size = .(200, 100);
		form.Controls.Add(control);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		SDL.Event mouse = .();
		mouse.type = .MouseButtonUp;
		mouse.button.button = 1;
		mouse.button.x = 20;
		mouse.button.y = 20;
		control.Capture = true;
		SDL.PushEvent(ref mouse);
		backend.ProcessEvents();
		Test.Assert(control.Capture);
		control.Capture = false;

		mouse.type = .MouseButtonDown;
		SDL.PushEvent(ref mouse);
		backend.ProcessEvents();
		Test.Assert(control.Capture);
		control.Capture = true;
		mouse.type = .MouseButtonUp;
		SDL.PushEvent(ref mouse);
		backend.ProcessEvents();
		Test.Assert(control.Capture);
		control.Capture = false;

		mouse.type = .MouseButtonDown;
		SDL.PushEvent(ref mouse);
		mouse.type = .MouseButtonUp;
		SDL.PushEvent(ref mouse);
		backend.ProcessEvents();
		Test.Assert(!control.Capture);
	}
	[Test]
	public static void ClickingNonSelectableControlsPreservesTextFocus()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(300, 200);
		let editor = new FocusTextBox();
		editor.Size = .(200, 30);
		let label = new Label();
		label.Location = .(0, 40);
		label.Size = .(100, 30);
		let panel = new Panel();
		panel.Location = .(0, 80);
		panel.Size = .(100, 50);
		form.Controls.Add(editor);
		form.Controls.Add(label);
		form.Controls.Add(panel);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		editor.Focus();
		for (let y in scope int32[](50, 90))
		{
			SDL.Event mouse = .();
			mouse.type = .MouseButtonDown;
			mouse.button.button = 1;
			mouse.button.x = 10;
			mouse.button.y = y;
			SDL.PushEvent(ref mouse);
			mouse.type = .MouseButtonUp;
			SDL.PushEvent(ref mouse);
			backend.ProcessEvents();
			Test.Assert(editor.Focused && editor.Losses == 0);
		}
		SDLTestInput.TypeText(backend, "b");
		Test.Assert(editor.Text == "b");
	}

}
