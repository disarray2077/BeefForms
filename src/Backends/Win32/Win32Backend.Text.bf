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
	private bool mCompletingSurrogate;

	private void NotifyNativeText(Control control)
	{
		if (mCompletingSurrogate) return;
		let length = Win32.GetWindowTextLength(control.Handle);
		let buffer = scope char16[length + 1] (?);
		let copied = Win32.GetWindowText(control.Handle, buffer.Ptr, (int32)buffer.Count);
		let text = scope String(Span<char16>(buffer.Ptr, copied));
		if (let editor = control as TextBoxBase)
			SynchronizeNativeSelection(editor, text);
		control.NotifyText(text);
	}

	private bool DispatchCharacter(Control control, char32 character)
	{
		let args = scope KeyPressEventArgs(character);
		control.DispatchInput(.KeyPress, args);
		if (args.Handled) return true;
		if (character >= ' ')
		{
			let text = scope String()..Append(character);
			let input = scope TextInputEventArgs(text);
			control.DispatchInput(.TextInput, input);
			return input.Handled;
		}
		return false;
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
			if (DispatchCharacter(control, scalar)) return true;
			// Publish text only after both UTF-16 code units have reached the native editor.
			mCompletingSurrogate = true;
			DefaultCharacter(control, high, lParam);
			DefaultCharacter(control, character, lParam);
			mCompletingSurrogate = false;
			if (control is TextBoxBase) NotifyNativeText(control);
			return true;
		}
		return DispatchCharacter(control, character);
	}
}
#endif
