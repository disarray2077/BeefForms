using System;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	private char16 mHighSurrogate;
	private Control mSurrogateControl;
	private bool mInsertingText;

	private void NotifyNativeText(Control control)
	{
		if (mInsertingText) return;
		let length = Win32.GetWindowTextLength(control.Handle);
		let buffer = scope char16[length + 1] (?);
		let copied = Win32.GetWindowText(control.Handle, buffer.Ptr, (int32)buffer.Count);
		let text = scope String(Span<char16>(buffer.Ptr, copied));
		if (let editor = control as TextBoxBase)
			SynchronizeNativeSelection(editor, text);
		control.NotifyText(text);
	}

	private void ApplyCharacter(Control control, char32 character, int32* lParam)
	{
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
		if (accepted.IsEmpty) return;
		// Publish one text change after the accepted text has reached the native editor.
		mInsertingText = true;
		let units = accepted.ToScopedNativeWChar!();
		for (var cursor = units; *cursor != 0; cursor++)
			DefaultCharacter(control, *cursor, lParam);
		mInsertingText = false;
		if (control is TextBoxBase) NotifyNativeText(control);
	}

	private static void DefaultCharacter(Control control, char16 character, int32* lParam)
	{
		if (control is Form)
			Win32.DefWindowProc(control.Handle, Win32.WM_CHAR, (uint32*)(void*)(uint)character, lParam);
		else
			Win32.DefSubclassProc(control.Handle, Win32.WM_CHAR, (uint32*)(void*)(uint)character, lParam);
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
