using System;
using System.Windows.Forms;
using System.Drawing;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	private void RecreateEditor(TextBoxBase editor)
	{
		let focused = IsFocused(editor);
		editor.RecreateHandle();
		if (focused && !editor.IsDisposingOrDisposed) FocusControl(editor);
	}

	public override Size MeasureText(Control control, Size proposedSize)
	{
		let window = control.GetHandle();
		let context = Win32.GetDC(window);
		defer Win32.ReleaseDC(window, context);
		let font = GetNativeFont(control);
		let previous = Win32.SelectObject(context, font.Handle);
		defer Win32.SelectObject(context, previous);
		if (control.Text.IsEmpty) return .(0, font.Height);
		let padding = (control is Label) ? (font.Height + 5) / 6 * 2 : 0;
		let width = proposedSize.width > 0 ? Math.Max(1, proposedSize.width - padding) : 0;
		Win32.RECT bounds = .(0, 0, width, 0);
		let editor = control as TextBoxBase;
		let singleLine = editor != null && !editor.Multiline;
		let flags = Win32.DT_CALCRECT | (editor != null ? Win32.DT_NOPREFIX : 0) |
			(singleLine ? Win32.DT_SINGLELINE : (width > 0 ? Win32.DT_WORDBREAK : 0));
		Win32.DrawText(context, control.Text.ToScopedNativeWChar!(), -1, ref bounds, flags);
		return .(bounds.right + padding, bounds.bottom);
	}

	public override Size MeasureText(Control control)
	{
		let context = Win32.GetDC(control.GetHandle());
		defer Win32.ReleaseDC(control.GetHandle(), context);
		let font = GetNativeFont(control).Handle;
		let previous = Win32.SelectObject(context, font);
		defer Win32.SelectObject(context, previous);
		Win32.RECT bounds = .(0, 0, 0, 0);
		Win32.DrawText(context, control.Text.ToScopedNativeWChar!(), -1, ref bounds, Win32.DT_CALCRECT);
		if (control is Label && !control.Text.IsEmpty) bounds.right += (GetNativeFont(control).Height + 5) / 6 * 2;
		return .(bounds.right, bounds.bottom);
	}

	private char16 mHighSurrogate;
	private Control mSurrogateControl;
	private bool mInsertingText;
	private bool mInsertedTextChanged;

	private void NotifyNativeText(Control control, bool forceNotification = true)
	{
		if (mInsertingText)
		{
			mInsertedTextChanged = true;
			return;
		}
		if (control is TextBoxBase && ((TextBoxBase)control).UpdatingText) return;
		let length = Win32.GetWindowTextLength(control.GetHandle());
		let buffer = scope char16[length + 1] (?);
		let copied = Win32.GetWindowText(control.GetHandle(), buffer.Ptr, (int32)buffer.Count);
		let text = scope String(Span<char16>(buffer.Ptr, copied));
		if (let editor = control as TextBoxBase)
			SynchronizeNativeSelection(editor, text);
		control.NotifyText(text, forceNotification);
	}

	private void ApplyCharacter(Control control, char32 character, int32* lParam)
	{
		let window = control.GetHandle();
		let snapshot = control.HandleGeneration;
		let accepted = scope String();
		if (character < ' ')
		{
			let press = scope KeyPressEventArgs(character);
			control.DispatchInput(.KeyPress, press);
			if (!press.Handled) accepted.Append(press.KeyChar);
		}
		else
		{
			let text = scope String()..Append(character);
			control.FilterTextInput(text, accepted);
		}
		if (accepted.IsEmpty || control.GetHandle() != window || !control.IsCurrentHandle(snapshot)) return;
		// Publish one text change after the accepted text has reached the native editor.
		mInsertingText = true;
		mInsertedTextChanged = false;
		let units = accepted.ToScopedNativeWChar!();
		for (var cursor = units; *cursor != 0; cursor++)
		{
			if (control.GetHandle() != window || !control.IsCurrentHandle(snapshot)) break;
			DefaultCharacter(control, window, *cursor, lParam);
		}
		mInsertingText = false;
		let changed = mInsertedTextChanged;
		mInsertedTextChanged = false;
		if (control.GetHandle() == window && control.IsCurrentHandle(snapshot) && control is TextBoxBase) NotifyNativeText(control, changed);
	}

	private static void DefaultCharacter(Control control, void* window, char16 character, int32* lParam)
	{
		if (control is Form)
			Win32.DefWindowProc(window, Win32.WM_CHAR, (uint32*)(void*)(uint)character, lParam);
		else
			Win32.DefSubclassProc(window, Win32.WM_CHAR, (uint32*)(void*)(uint)character, lParam);
	}

	private bool HandleCharacter(Control control, char16 character, int32* lParam)
	{
		if (mSuppressChars) return true;
		// Wait for the complete character so handlers can reject the entire surrogate pair.
		if (character >= '\u{D800}' && character <= '\u{DBFF}')
		{
			mHighSurrogate = character;
			mSurrogateControl = control;
			return true;
		}
		let high = mHighSurrogate;
		let pending = mSurrogateControl;
		mHighSurrogate = 0;
		mSurrogateControl = null;
		if (character >= '\u{DC00}' && character <= '\u{DFFF}' && high != 0 && pending == control)
		{
			let scalar = (char32)(0x10000 + ((uint32)(high - '\u{D800}') << 10) + (uint32)(character - '\u{DC00}'));
			ApplyCharacter(control, scalar, lParam);
			return true;
		}
		ApplyCharacter(control, character, lParam);
		return true;
	}
}
#endif
