using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class SDLBackendTests
{
	[Test]
	public static void BorderedPanelsOffsetMouseTargetsToTheirClientArea()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let panel = new Panel();
		panel.Location = .(10, 10);
		panel.Size = .(200, 100);
		panel.BorderStyle = .Fixed3D;
		let button = new Button();
		button.Size = .(100, 25);
		panel.Controls.Add(button);
		form.Controls.Add(panel);
		int clicks = 0;
		button.Click.Add(new [&] (sender, args) => { clicks++; });
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		PushClick(10, 10);
		backend.ProcessEvents();
		Test.Assert(clicks == 0);
		PushClick(12, 12);
		backend.ProcessEvents();
		Test.Assert(clicks == 1);
	}

	private class TestForm : Form
	{
		public int Clicks;
		public TextBox Input = new .();
		public ProgressBar Progress = new .();
		public Panel Group = new .();

		public this()
		{
			Text = "BeefForms SDL/OpenGL";
			ClientSize = .(400, 240);
			let button = new Button();
			button.Text = "Advance";
			button.Location = .(10, 10);
			button.Size = .(120, 30);
			button.Click.Add(new => Clicked);
			Controls.Add(button);
			Input.Location = .(10, 60);
			Input.Size = .(200, 26);
			Input.Anchor = .Top | .Left | .Right;
			Input.TabIndex = 1;
			Controls.Add(Input);
			Group.Location = .(220, 60);
			Group.Size = .(160, 60);
			Group.Anchor = .Top | .Right;
			Controls.Add(Group);
			let nested = new Button();
			nested.Text = "Nested";
			nested.Location = .(10, 10);
			nested.Size = .(110, 30);
			nested.TabIndex = 2;
			nested.Click.Add(new => Clicked);
			Group.Controls.Add(nested);
			let disabled = new Button();
			disabled.Location = .(10, 100);
			disabled.Size = .(120, 30);
			disabled.Enabled = false;
			disabled.Click.Add(new => Clicked);
			Controls.Add(disabled);
			Progress.Location = .(10, 160);
			Progress.Size = .(370, 24);
			Controls.Add(Progress);
		}

		private void Clicked(Object sender, EventArgs args)
		{
			Clicks++;
			Progress.Value += 25;
		}
	}

	private static void PushClick(int32 x, int32 y)
	{
		SDL.Event input = .();
		input.type = .MouseButtonDown;
		input.button.button = 1;
		input.button.x = x;
		input.button.y = y;
		SDL.PushEvent(ref input);
		input.type = .MouseButtonUp;
		SDL.PushEvent(ref input);
	}

	private static void PushKey(SDL.Keycode key, SDL.KeyMod modifiers = .None)
	{
		SDL.Event input = .();
		input.type = .KeyDown;
		input.key.keysym.sym = key;
		input.key.keysym.mod = modifiers;
		SDL.PushEvent(ref input);
	}

	[Test]
	public static void DesktopInputAndResize()
	{
		Application.UseBackend(.SDL2OpenGL);
		{
			let form = new TestForm();
			defer delete form;
			form.Show();
			let backend = (SDLBackend)Application.Backend;
			backend.FrameLimit = 2;
			SDLTestInput.Activate(backend);
			PushClick(20, 20);
			PushClick(240, 80);
			PushClick(20, 110);
			PushClick(20, 70);
			backend.ProcessEvents();
			SDL.Event input = .();
			input.type = .TextInput;
			Internal.MemCpy(&input.text.text, "Beef".Ptr, 4);
			SDL.PushEvent(ref input);
			PushKey(.LEFT);
			PushKey(.BACKSPACE);
			PushKey(.TAB);
			PushKey(.SPACE);
			SDL.SetWindowSize((SDL.Window*)form.Handle, 500, 300);
			backend.ProcessEvents();
			form.Location = .(80, 90);
			backend.Run(form);
			Test.Assert(form.Input.Text == "Bef");
			Test.Assert(form.Clicks == 3 && form.Progress.Value == 75);
			Test.Assert(form.Input.Size.width == 300 && form.Group.Location.x == 320);
			SDL.GetWindowPosition((SDL.Window*)form.Handle, var actualX, var actualY);
			SDL.GetWindowBordersSize((SDL.Window*)form.Handle, var top, var left, var bottom, var right);
			Test.Assert(form.Location.x == actualX - left && form.Location.y == actualY - top);
			Test.Assert(GL.glGetError() == GL.GL_NO_ERROR);
		}
#if BF_PLATFORM_WINDOWS
		Application.UseBackend(.Win32);
#else
		Application.UseBackend(.SDL2OpenGL);
#endif
	}
}
