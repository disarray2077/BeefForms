using System;
using System.Collections;
using System.Drawing;
using System.Windows.Forms;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

extension SDLWindowSession
{
	private Control HitTest(Control control, int x, int y)
	{
		if (control.IsDisposingOrDisposed || !control.IsHandleCreated || !control.IsEffectivelyEnabled || !control.IsEffectivelyVisible ||
			x < 0 || y < 0 || x >= control.Size.width || y >= control.Size.height)
			return null;
		int32 border = (control is Form) ? 0 : control.BorderWidth;
		if (x < border || y < border || x >= border + control.ViewportSize.width || y >= border + control.ViewportSize.height)
			return control;
		for (int i = control.Controls.Count - 1; i >= 0; i--)
		{
			let child = control.Controls[i];
			if (let found = HitTest(child, x - border - child.Location.x + control.ContentOffset.x, y - border - child.Location.y + control.ContentOffset.y))
				return found;
		}
		return control;
	}

	public bool IsFocused(Control control) => mActive && mFocused == control;

	private void PrepareEditorFocus()
	{
		if (let editor = mFocused as TextBoxBase)
		{
			editor.RestartCaretBlink(SDL.GetTicks64());
			editor.RequestCaretReveal();
		}
	}

	public bool HasCapture(Control control) => mCaptured == control;
	public void SetCapture(Control control, bool capture)
	{
		if (!capture && mCaptured != control)
			return;
		mCaptured = capture ? control : null;
		mAutomaticCapture = false;
		SDL.CaptureMouse(capture ? .True : .False);
	}

	public bool FocusControl(Control control)
	{
		if (!control.CanSelect)
			return false;
		Focus(control);
		return true;
	}

	internal void ReleaseCapture()
	{
		if (mCaptured != null) SetCapture(mCaptured, false);
	}

	internal void Deactivate() => SetActive(false);

	private void Focus(Control control)
	{
		if (mFocused == control) return;
		let snapshot = mWindowGeneration;
		mFocusGeneration.Advance();
		let transition = mFocusGeneration;
		let previous = mFocused;
		// Clear first: closing from LostFocus must not notify this control recursively.
		mFocused = null;
		if (mActive) previous?.NotifyFocus(false);
		if (!mWindowGeneration.IsCurrent(snapshot) || !mFocusGeneration.IsCurrent(transition)) return;
		if (control != null && !IsCurrentControl(control, snapshot)) return;
		mFocused = control;
		RequestRedraw();
		UpdateTextInput();
		if (mActive)
		{
			PrepareEditorFocus();
			mFocused?.NotifyFocus(true);
		}
	}

	private void SetActive(bool active)
	{
		if (!active)
		{
			mSuppressTextInput = false;
			mPressed = null;
			if (mCaptured != null) SetCapture(mCaptured, false);
		}
		if (mActive == active) return;
		mActive = active;
		RequestRedraw();
		UpdateTextInput();
		if (active) PrepareEditorFocus();
		mFocused?.NotifyFocus(active);
	}

	private void UpdateTextInput()
	{
		if (mActive && mFocused is TextBoxBase)
		{
			SDL.StartTextInput();
			let point = mFocused.LocalToRootPoint(.(0, 0));
			SDL.Rect input = .(point.x, point.y, mFocused.Size.width, mFocused.Size.height);
			SDL.SetTextInputRect(&input);
		}
		else if (SDL.GetKeyboardFocus() == mWindow || SDL.GetKeyboardFocus() == null)
			SDL.StopTextInput();
	}

	internal void Hover(Control control)
	{
		let previous = mHovered;
		if (previous == control) return;
		mHovered = control;
		RequestRedraw();
		Control.UpdateMouseOver(previous, control);
	}

	private void UpdateHover()
	{
		Hover(mPointerInside && mForm != null ? HitTest(mForm, mPointerPosition.x, mPointerPosition.y) : null);
	}

	private void UpdateHover(int32 x, int32 y)
	{
		mPointerPosition = .(x, y);
		mPointerInside = true;
		UpdateHover();
	}

	private void AdvanceFocus(bool backward)
	{
		if (let next = Control.NextTabControl(mForm, mFocused, backward)) Focus(next);
	}

	private static MouseButtons MouseButton(uint8 button)
	{
		switch (button)
		{
		case 1: return .Left;
		case 2: return .Middle;
		case 3: return .Right;
		case 4: return .XButton1;
		case 5: return .XButton2;
		default: return .None;
		}
	}

	internal void ProcessEvent(ref SDL.Event input)
	{
		let snapshot = mWindowGeneration;
		if (!IsCurrentWindow(snapshot)) return;
		switch (input.type)
		{
		case .Quit: mForm.Close();
		case .WindowEvent:
			switch (input.window.windowEvent)
			{
			case .Close: mForm.Close();
			case .Exposed:
				if (!mHandledExposureTimestamp.HasValue || (int32)(input.window.timestamp &- mHandledExposureTimestamp.Value) > 0)
					InvalidateTree(mForm);
			case .SizeChanged: UpdateFormSize();
			case .Shown, .Hidden, .Minimized, .Restored, .DISPLAY_CHANGED: RequestRedraw();
			case .Moved: mForm.NotifyMove(GetFormLocation());
			case .Focus_lost: SetActive(false);
			case .FocusGained: SetActive(true);
			case .Enter:
				SDL.GetMouseState(var x, var y);
				UpdateHover(x, y);
			case .Leave:
				mPointerInside = false;
				Hover(null);
			default:
			}
		case .MouseMotion:
			UpdateHover(input.motion.x, input.motion.y);
			if (!IsCurrentWindow(snapshot)) break;
			let target = mCaptured ?? mHovered;
			if (target != null)
			{
				let handleSnapshot = target.HandleGeneration;
				let point = target.RootToLocalPoint(.(input.motion.x, input.motion.y));
				let args = scope MouseEventArgs(.None, 0, point.x, point.y);
				target.DispatchInput(.MouseMove, args);
				if (!IsCurrentControl(target, snapshot, handleSnapshot)) break;
				if (!args.Handled)
					if (let editor = mPressed as TextBoxBase)
					{
						let position = editor.RootToLocalPoint(.(input.motion.x, input.motion.y));
						editor.SetCaret(mBackend.TextService.HitText(editor, position.x, position.y), true);
					}
			}
		case .MouseButtonDown:
			UpdateHover(input.button.x, input.button.y);
			if (!IsCurrentWindow(snapshot)) break;
			let target = mCaptured ?? mHovered;
			if (target == null) break;
			let handleSnapshot = target.HandleGeneration;
			let point = target.RootToLocalPoint(.(input.button.x, input.button.y));
			let args = scope MouseEventArgs(MouseButton(input.button.button), input.button.clicks, point.x, point.y);
			target.DispatchInput(.MouseDown, args);
			if (!IsCurrentControl(target, snapshot, handleSnapshot)) break;
			if (!target.IsEffectivelyVisible || !target.IsEffectivelyEnabled) break;
			if (args.Clicks >= 2 && !args.Handled)
				target.DispatchInput(.MouseDoubleClick, args);
			if (!IsCurrentControl(target, snapshot, handleSnapshot)) break;
			if (args.Button == .Left && !args.Handled)
			{
				mPressed = target;
				RequestRedraw();
				if (target != mForm && target.CanSelect) Focus(target);
				if (!IsCurrentControl(target, snapshot, handleSnapshot)) break;
				if (mCaptured == null)
				{
					mBackend.SetCapture(target, true);
					mAutomaticCapture = true;
				}
				if (let editor = target as TextBoxBase)
				{
					if (args.Clicks >= 2) editor.SelectAll();
					else editor.SetCaret(mBackend.TextService.HitText(editor, point.x, point.y), (SDL.GetModState() & .SHIFT) != 0);
				}
			}
		case .MouseButtonUp:
			UpdateHover(input.button.x, input.button.y);
			if (!IsCurrentWindow(snapshot)) break;
			let hit = mHovered;
			let target = mCaptured ?? hit;
			if (target == null) break;
			let handleSnapshot = target.HandleGeneration;
			let point = target.RootToLocalPoint(.(input.button.x, input.button.y));
			let args = scope MouseEventArgs(MouseButton(input.button.button), input.button.clicks, point.x, point.y);
			target.DispatchInput(.MouseUp, args);
			if (!IsCurrentControl(target, snapshot, handleSnapshot)) break;
			if (args.Button == .Left)
			{
				let pressed = mPressed;
				mPressed = null;
				if (pressed != null) RequestRedraw();
				if (mAutomaticCapture && mCaptured == pressed) SetCapture(mCaptured, false);
				if (!args.Handled && hit == pressed)
					if (let button = hit as ButtonBase)
						button.PerformClick();
			}
		case .MouseWheel:
			int32 x, y;
			if (mWheelHasPosition)
			{
				x = input.wheel.mouseX;
				y = input.wheel.mouseY;
			}
			else
				SDL.GetMouseState(out x, out y);
			UpdateHover(x, y);
			if (!IsCurrentWindow(snapshot)) break;
			let target = mHovered;
			if (target != null)
			{
				let point = target.RootToLocalPoint(.(x, y));
				let direction = input.wheel.direction == 1 ? -120 : 120;
				let args = scope MouseEventArgs(.None, 0, point.x, point.y, (int32)(input.wheel.y * direction), (int32)(input.wheel.x * direction));
				target.DispatchMouseWheel(args);
			}
		case .TextInput:
			if (!mActive || mSuppressTextInput) break;
			let target = mFocused ?? mForm;
			let handleSnapshot = target.HandleGeneration;
			if (!target.IsEffectivelyEnabled || !target.IsEffectivelyVisible) break;
			let text = scope String((char8*)&input.text.text);
			let accepted = scope String();
			target.FilterTextInput(text, accepted);
			if (!IsCurrentControl(target, snapshot, handleSnapshot)) break;
			if (let editor = target as TextBoxBase)
				if (!accepted.IsEmpty) editor.ReplaceSelection(accepted);
		case .KeyDown:
			if (!mActive) break;
			let target = mFocused ?? mForm;
			let handleSnapshot = target.HandleGeneration;
			if (!target.IsEffectivelyEnabled || !target.IsEffectivelyVisible) break;
			if (input.key.keysym.sym == .TAB)
			{
				AdvanceFocus((input.key.keysym.mod & .SHIFT) != 0);
				mSuppressTextInput = true;
				break;
			}
			let args = scope KeyEventArgs(TranslateKey(input.key));
			target.DispatchInput(.KeyDown, args);
			if (!IsCurrentControl(target, snapshot, handleSnapshot)) break;
			mSuppressTextInput = args.SuppressKeyPress;
			if (!args.Handled && !args.SuppressKeyPress)
				DefaultKeyDown(input.key);
		case .KeyUp:
			if (!mActive) break;
			let target = mFocused ?? mForm;
			let handleSnapshot = target.HandleGeneration;
			if (!target.IsEffectivelyEnabled || !target.IsEffectivelyVisible) break;
			let args = scope KeyEventArgs(TranslateKey(input.key));
			target.DispatchInput(.KeyUp, args);
			if (!IsCurrentControl(target, snapshot, handleSnapshot)) break;
			mSuppressTextInput = false;
		default:
		}
	}

	private static Keys TranslateKey(SDL.KeyboardEvent key)
	{
		let code = key.keysym.sym;
		Keys result = .None;
		if (code >= .A && code <= .Z)
			result = (Keys)((int32)code - (int32)SDL.Keycode.A + (int32)Keys.A);
		else if (code >= .Num0 && code <= .Num9)
			result = (Keys)((int32)code);
		else if (code >= .F1 && code <= .F12)
			result = (Keys)((int32)code - (int32)SDL.Keycode.F1 + (int32)Keys.F1);
		else
			switch (code)
			{
			case .BACKSPACE: result = .Back;
			case .TAB: result = .Tab;
			case .RETURN: result = .Enter;
			case .ESCAPE: result = .Escape;
			case .SPACE: result = .Space;
			case .DELETE: result = .Delete;
			case .INSERT: result = .Insert;
			case .HOME: result = .Home;
			case .END: result = .End;
			case .LEFT: result = .Left;
			case .RIGHT: result = .Right;
			case .UP: result = .Up;
			case .DOWN: result = .Down;
			case .PAGEUP: result = .PageUp;
			case .PAGEDOWN: result = .PageDown;
			default:
			}
		if ((key.keysym.mod & .SHIFT) != 0) result |= .Shift;
		if ((key.keysym.mod & .CTRL) != 0) result |= .Control;
		if ((key.keysym.mod & .ALT) != 0) result |= .Alt;
		return result;
	}

	private void DefaultKeyDown(SDL.KeyboardEvent key)
	{
		let shift = (key.keysym.mod & .SHIFT) != 0;
		let ctrl = (key.keysym.mod & .CTRL) != 0;
		let symbol = key.keysym.sym;
		if (mFocused == null || !mFocused.IsEffectivelyEnabled || !mFocused.IsEffectivelyVisible)
			return;
		if (let button = mFocused as ButtonBase)
		{
			if ((symbol == .SPACE || (symbol == .RETURN && button is Button)) && key.isRepeat == 0)
				button.PerformClick();
			return;
		}
		if (!(mFocused is TextBoxBase))
			return;
		let editor = (TextBoxBase)mFocused;
		if (ctrl)
		{
			switch (symbol)
			{
			case .A: editor.SelectAll();
			case .HOME: editor.SetCaret(0, shift);
			case .END: editor.SetCaret(editor.Text.Length, shift);
			case .C, .X:
				if (editor.SelectionByteLength > 0)
				{
					let text = scope String(editor.Text, editor.SelectionByteStart, editor.SelectionByteLength);
					SDL.SetClipboardText(text);
					if (symbol == .X) editor.ReplaceSelection("");
				}
			case .V:
				let clipboard = SDL.GetClipboardText();
				if (clipboard != null)
				{
					let text = scope String(clipboard);
					SDL.free(clipboard);
					if (!editor.Multiline)
					{
						text.Replace("\n", "");
						text.Replace("\r", "");
					}
					editor.ReplaceSelection(text);
				}
			default:
			}
			return;
		}
		switch (symbol)
		{
		case .BACKSPACE:
			let snapshot = mWindowGeneration;
			let handleSnapshot = editor.HandleGeneration;
			let press = scope KeyPressEventArgs('\b');
			editor.DispatchInput(.KeyPress, press);
			if (!IsCurrentControl(editor, snapshot, handleSnapshot) || press.Handled) return;
			if (press.KeyChar == '\b') editor.DeleteText(true);
			else if (press.KeyChar >= ' ') editor.ReplaceSelection(scope String()..Append(press.KeyChar));
		case .DELETE: editor.DeleteText(false);
		case .LEFT, .RIGHT:
			let forward = symbol == .RIGHT;
			let position = !shift && editor.SelectionByteLength > 0
				? editor.SelectionByteStart + (forward ? editor.SelectionByteLength : 0)
				: TextEncodingHelper.AdjacentPosition(editor.Text, editor.Caret, forward, editor.Multiline);
			editor.SetCaret(position, shift);
		case .HOME, .END:
			editor.SetCaret(symbol == .HOME
				? (editor.Multiline ? editor.Text.LineStart(editor.Caret) : 0)
				: (editor.Multiline ? editor.Text.LineEnd(editor.Caret) : editor.Text.Length), shift);
		case .UP, .DOWN:
			if (!editor.Multiline) return;
			let position = mBackend.TextService.TextPosition(editor, editor.Caret);
			let delta = symbol == .DOWN ? 1 : -1;
			editor.SetCaret(mBackend.TextService.HitText(editor, position.x + SDLTextService.EditorTextInset - editor.BorderWidth - editor.ScrollX,
				position.y + delta * mBackend.TextService.LineHeight(editor) + SDLTextService.EditorTextInset - editor.BorderWidth - editor.ScrollY), shift);
		case .RETURN:
			let snapshot = mWindowGeneration;
			let handleSnapshot = editor.HandleGeneration;
			let press = scope KeyPressEventArgs('\r');
			editor.DispatchInput(.KeyPress, press);
			if (!IsCurrentControl(editor, snapshot, handleSnapshot) || press.Handled) return;
			if (press.KeyChar >= ' ') editor.ReplaceSelection(scope String()..Append(press.KeyChar));
			else if (editor.Multiline && (press.KeyChar == '\r' || press.KeyChar == '\n')) editor.ReplaceSelection(editor.LineBreak);
		default:
		}
	}
}
