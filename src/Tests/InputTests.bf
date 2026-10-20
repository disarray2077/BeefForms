using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class InputTests
{
	private class Probe : Control
	{
		public bool ConsumeMouse;
		public int MouseCalls, Moves, KeyUps;
		public int32 LastX, LastY, WheelDelta;
		public Keys LastKey;

		protected override void OnMouseDown(MouseEventArgs args)
		{
			base.OnMouseDown(args);
			MouseCalls++;
			LastX = args.X;
			LastY = args.Y;
			args.Handled = ConsumeMouse;
		}
		protected override void OnMouseMove(MouseEventArgs args) { base.OnMouseMove(args); Moves++; }
		protected override void OnMouseWheel(MouseEventArgs args) { base.OnMouseWheel(args); WheelDelta = args.Delta; }
		protected override void OnKeyDown(KeyEventArgs args) { base.OnKeyDown(args); LastKey = args.KeyData; }
		protected override void OnKeyUp(KeyEventArgs args) { base.OnKeyUp(args); KeyUps++; }
	}

	private class FilteredTextBox : TextBox
	{
		protected override void OnKeyPress(KeyPressEventArgs args)
		{
			base.OnKeyPress(args);
			if (args.KeyChar == '!') args.Handled = true;
		}
		protected override void OnKeyDown(KeyEventArgs args)
		{
			base.OnKeyDown(args);
			if (args.KeyCode == .Back) args.Handled = true;
		}
	}

	[Test]
	public static void MouseEventsBubbleInParentCoordinates()
	{
		let parent = scope Probe();
		parent.Size = .(200, 100);
		let child = new Probe();
		child.Location = .(30, 40);
		child.Size = .(50, 20);
		parent.Controls.Add(child);
		let args = scope MouseEventArgs(.Right, 1, 2, 3);
		child.DispatchInput(.MouseDown, args);
		Test.Assert(args.Source == child && args.X == 2 && args.Y == 3);
		Test.Assert(parent.MouseCalls == 1 && parent.LastX == 32 && parent.LastY == 43);
		child.ConsumeMouse = true;
		child.DispatchInput(.MouseDown, args);
		Test.Assert(parent.MouseCalls == 1 && args.Handled);
	}

	[Test]
	public static void GenericControlsReceiveFocusCaptureAndWheelInput()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(300, 200);
		let probe = new Probe();
		probe.Location = .(10, 10);
		probe.Size = .(100, 100);
		form.Controls.Add(probe);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		backend.ProcessEvents();
		Test.Assert(probe.Focus() && probe.Focused);
		probe.Capture = true;
		SDL.Event input = .();
		input.type = .MouseMotion;
		input.motion.x = 250;
		input.motion.y = 150;
		SDL.PushEvent(ref input);
		input = .();
		input.type = .MouseWheel;
		input.wheel.mouseX = 20;
		input.wheel.mouseY = 20;
		input.wheel.y = 1;
		SDL.PushEvent(ref input);
		input = .();
		input.type = .KeyDown;
		input.key.keysym.sym = .A;
		input.key.keysym.mod = .LCtrl;
		SDL.PushEvent(ref input);
		input.type = .KeyUp;
		SDL.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(probe.Capture && probe.Moves > 0 && probe.WheelDelta == 120);
		Test.Assert(probe.LastKey == (.A | .Control) && probe.KeyUps == 1);
		probe.Capture = false;
		Test.Assert(!probe.Capture);
	}

	[Test]
	public static void InputHandlersCanCancelDefaultEditing()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new FilteredTextBox();
		editor.Size = .(200, 30);
		form.Controls.Add(editor);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		backend.ProcessEvents();
		editor.Focus();
		SDL.Event input = .();
		input.type = .TextInput;
		Internal.MemCpy(&input.text.text, "B!".Ptr, 2);
		SDL.PushEvent(ref input);
		input = .();
		input.type = .KeyDown;
		input.key.keysym.sym = .BACKSPACE;
		SDL.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(editor.Text == "B");
	}
}
