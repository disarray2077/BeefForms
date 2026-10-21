using System;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	private void SynchronizeNativeSelection(TextBoxBase editor, StringView text)
	{
		if (editor.Handle == null || mInsertingText) return;
		uint32 nativeStart = 0, nativeEnd = 0;
		Win32.SendMessage(editor.Handle, Win32.EM_GETSEL, (uint*)&nativeStart, (int*)&nativeEnd);
		let start = TextBoxBase.Utf8Offset(text, nativeStart);
		let end = TextBoxBase.Utf8Offset(text, nativeEnd);
		var caretAtStart = start != end && editor.SelectionAnchor == end;
		// EM_GETSEL sorts the endpoints; the visible caret identifies the active end.
		if (start != end && IsFocused(editor) && Win32.GetCaretPos(var caret))
		{
			let position = (uint)(void*)Win32.SendMessage(editor.Handle, Win32.EM_POSFROMCHAR, (uint*)(void*)(uint)nativeStart, null);
			caretAtStart = (int16)(position & 0xFFFF) == caret.x && (int16)((position >> 16) & 0xFFFF) == caret.y;
		}
		editor.NotifySelection(caretAtStart ? end : start, caretAtStart ? start : end);
	}

	private void SynchronizeSelectionAfterMessage(TextBoxBase editor, uint32 message)
	{
		switch (message)
		{
		case Win32.WM_MOUSEMOVE:
			if (HasCapture(editor)) SynchronizeNativeSelection(editor, editor.Text);
		case Win32.WM_CHAR, Win32.WM_KEYDOWN, Win32.WM_KEYUP,
			Win32.WM_LBUTTONDOWN, Win32.WM_LBUTTONUP, Win32.WM_LBUTTONDBLCLK,
			Win32.WM_SETFOCUS, Win32.WM_KILLFOCUS, Win32.WM_TIMER,
			Win32.WM_SETTEXT, Win32.WM_CUT, Win32.WM_PASTE, Win32.WM_CLEAR, Win32.WM_UNDO,
			Win32.WM_IME_COMPOSITION, Win32.WM_IME_ENDCOMPOSITION,
			Win32.EM_SETSEL, Win32.EM_REPLACESEL, Win32.EM_UNDO:
			SynchronizeNativeSelection(editor, editor.Text);
		default:
		}
	}
}
#endif
