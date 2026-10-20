using System;
using System.Collections;
using System.Drawing;
using System.Windows.Forms;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

extension SDLBackend
{
	private Control HitTest(Control control, int x, int y)
	{
		if (!control.IsEffectivelyEnabled || x < 0 || y < 0 || x >= control.Size.width || y >= control.Size.height)
			return null;
		for (int i = control.Controls.Count - 1; i >= 0; i--)
		{
			let child = control.Controls[i];
			if (let found = HitTest(child, x - child.Location.x, y - child.Location.y))
				return found;
		}
		return control;
	}

	private static Point PositionIn(Control control, int x, int y)
	{
		var current = control;
		var result = Point((.)x, (.)y);
		while (current.Parent != null)
		{
			result.x -= current.Location.x;
			result.y -= current.Location.y;
			current = current.Parent;
		}
		return result;
	}

	private void Focus(Control control)
	{
		mFocused = (control is Button || control is TextBoxBase) ? control : null;
		if (let editor = mFocused as TextBoxBase)
		{
			SDL.StartTextInput();
			let point = PositionIn(editor, 0, 0);
			SDL.Rect input = .(-point.x, -point.y, editor.Size.width, editor.Size.height);
			SDL.SetTextInputRect(&input);
		}
		else
			SDL.StopTextInput();
	}

	private static void CollectFocusable(Control control, List<Control> controls)
	{
		if (!control.IsEffectivelyEnabled)
			return;
		if (control.TabIndex >= 0 && (control is Button || control is TextBoxBase))
			controls.Add(control);
		for (let child in control.Controls)
			CollectFocusable(child, controls);
	}

	private void AdvanceFocus(bool backward)
	{
		let controls = scope List<Control>();
		CollectFocusable(mForm, controls);
		controls.Sort(scope (a, b) => a.TabIndex <=> b.TabIndex);
		if (controls.IsEmpty)
			return;
		let index = controls.IndexOf(mFocused);
		let next = index < 0 ? (backward ? controls.Count - 1 : 0)
			: (index + controls.Count + (backward ? -1 : 1)) % controls.Count;
		Focus(controls[next]);
	}

	private void ProcessEvent(ref SDL.Event input)
	{
		switch (input.type)
		{
		case .Quit: mRunning = false;
		case .WindowEvent:
			switch (input.window.windowEvent)
			{
			case .Close: mRunning = false;
			case .SizeChanged: mForm.NotifyResize(GetClientSize(mForm));
			case .Moved:
				SDL.GetWindowPosition(mWindow, var x, var y);
				mForm.NotifyMove(.(x, y));
			case .Focus_lost: mPressed = null; SDL.StopTextInput();
			case .FocusGained: Focus(mFocused);
			default:
			}
		case .MouseMotion:
			mHovered = HitTest(mForm, input.motion.x, input.motion.y);
			if (let editor = mPressed as TextBoxBase)
			{
				let point = PositionIn(editor, input.motion.x, input.motion.y);
				editor.SetCaret(mRenderer.HitText(editor, point.x, point.y), true);
			}
		case .MouseButtonDown:
			if (input.button.button == 1)
			{
				mPressed = HitTest(mForm, input.button.x, input.button.y);
				mHovered = mPressed;
				Focus(mPressed);
				SDL.CaptureMouse(.True);
				if (let editor = mFocused as TextBoxBase)
				{
					let point = PositionIn(editor, input.button.x, input.button.y);
					if (input.button.clicks >= 2)
						editor.SelectAll();
					else
						editor.SetCaret(mRenderer.HitText(editor, point.x, point.y), (SDL.GetModState() & .SHIFT) != 0);
				}
			}
		case .MouseButtonUp:
			if (input.button.button == 1)
			{
				let target = HitTest(mForm, input.button.x, input.button.y);
				let pressed = mPressed;
				mPressed = null;
				SDL.CaptureMouse(.False);
				if (target == pressed)
					if (let button = target as Button)
						button.PerformClick();
			}
		case .TextInput:
			if (let editor = mFocused as TextBoxBase)
				if (editor.IsEffectivelyEnabled)
					editor.ReplaceSelection(scope String((char8*)&input.text.text));
		case .KeyDown: KeyDown(input.key);
		default:
		}
	}

	private void KeyDown(SDL.KeyboardEvent key)
	{
		let shift = (key.keysym.mod & .SHIFT) != 0;
		let ctrl = (key.keysym.mod & .CTRL) != 0;
		let symbol = key.keysym.sym;
		if (symbol == .TAB)
		{
			AdvanceFocus(shift);
			return;
		}
		if (mFocused == null || !mFocused.IsEffectivelyEnabled)
			return;
		if (let button = mFocused as Button)
		{
			if ((symbol == .RETURN || symbol == .SPACE) && key.isRepeat == 0)
				button.PerformClick();
			return;
		}
		let editor = (TextBoxBase)mFocused;
		if (ctrl)
		{
			switch (symbol)
			{
			case .A: editor.SelectAll();
			case .C, .X:
				if (editor.SelectionLength > 0)
				{
					let text = scope String(editor.Text, editor.SelectionStart, editor.SelectionLength);
					SDL.SetClipboardText(text);
					if (symbol == .X) editor.ReplaceSelection("");
				}
			case .V:
				let clipboard = SDL.GetClipboardText();
				if (clipboard != null)
				{
					let text = scope String(clipboard);
					SDL.free(clipboard);
					if (!(editor is RichTextBox))
						{ text.Replace("\n", ""); text.Replace("\r", ""); }
					editor.ReplaceSelection(text);
				}
			default:
			}
			return;
		}
		switch (symbol)
		{
		case .BACKSPACE: editor.DeleteText(true);
		case .DELETE: editor.DeleteText(false);
		case .LEFT, .RIGHT:
			let forward = symbol == .RIGHT;
			let position = !shift && editor.SelectionLength > 0
				? editor.SelectionStart + (forward ? editor.SelectionLength : 0)
				: editor.AdjacentPosition(editor.Caret, forward);
			editor.SetCaret(position, shift);
		case .HOME, .END:
			let start = editor.Text.LastIndexOf('\n', Math.Max(0, editor.Caret - 1)) + 1;
			let end = editor.Text.IndexOf('\n', editor.Caret);
			editor.SetCaret(symbol == .HOME ? start : end < 0 ? editor.Text.Length : end, shift);
		case .UP, .DOWN:
			let position = mRenderer.TextPosition(editor, editor.Caret);
			let delta = symbol == .DOWN ? 1 : -1;
			editor.SetCaret(mRenderer.HitText(editor, position.x + 4 - editor.ScrollX,
				position.y + delta * mRenderer.LineHeight(editor) + 4 - editor.ScrollY), shift);
		case .RETURN:
			if (editor is RichTextBox) editor.ReplaceSelection("\n");
		default:
		}
	}
}
