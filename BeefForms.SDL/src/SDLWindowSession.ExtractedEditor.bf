using System;
using System.Windows.Forms;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

extension SDLWindowSession
{
	internal void ApplyExtractedDraft(TextBoxBase editor, StringView original, StringView draft)
	{
		let window = mWindowGeneration;
		let handle = editor.HandleGeneration;
		if (!IsCurrentControl(editor, window, handle) || editor.ReadOnly ||
			!editor.IsEffectivelyEnabled || !editor.IsEffectivelyVisible || editor.Text != original)
			return;

		let text = scope String();
		for (int i = 0; i < draft.Length; i++)
		{
			let character = draft[i];
			if (character == '\r' || character == '\n')
			{
				if (character == '\r' && i + 1 < draft.Length && draft[i + 1] == '\n')
					i++;
				if (editor.Multiline)
					text.Append(editor.LineBreak);
			}
			else
				text.Append(character);
		}
		if (original == text)
			return;

		int start = 0;
		while (start < original.Length && start < text.Length && original[start] == text[start])
			start++;
		start = TextEncodingHelper.CharacterBoundary(original, start);
		int oldEnd = original.Length, newEnd = text.Length;
		while (oldEnd > start && newEnd > start && original[oldEnd - 1] == text[newEnd - 1])
		{
			oldEnd--;
			newEnd--;
		}
		while (oldEnd < original.Length && ((uint8)original[oldEnd] & 0xC0) == 0x80)
		{
			oldEnd++;
			newEnd++;
		}

		let accepted = scope String();
		if (newEnd == start)
		{
			let press = scope KeyPressEventArgs('\b');
			editor.DispatchInput(.KeyPress, press);
			if (press.Handled)
				return;
			if (press.KeyChar != '\b')
				accepted.Append(press.KeyChar);
		}
		else
		{
			editor.FilterTextInput(.(text, start, newEnd - start), accepted);
			if (accepted.IsEmpty)
				return;
		}

		if (!IsCurrentControl(editor, window, handle) || editor.ReadOnly ||
			!editor.IsEffectivelyEnabled || !editor.IsEffectivelyVisible || editor.Text != original)
			return;
		editor.SetCaret(start, false);
		editor.SetCaret(oldEnd, true);
		editor.ReplaceSelection(accepted);
	}

#if BF_PLATFORM_WASM
	[CLink]
	private static extern void BeefForms_InstallTextEditor(void* context,
		function void(void*, float, float) open, function void(void*, char8*) done, function void(void*) cancel);
	[CLink]
	private static extern void BeefForms_UninstallTextEditor(void* context);
	[CLink]
	private static extern void BeefForms_OpenTextEditor(char8* text, int32 multiline, int32 start, int32 length);
	[CLink]
	private static extern void BeefForms_CloseTextEditor();

	private void InstallExtractedEditor()
	{
		BeefForms_InstallTextEditor(Internal.UnsafeCastToPtr(this), => OpenExtractedEditor, => FinishExtractedEditor, => DismissExtractedEditor);
	}

	private void UninstallExtractedEditor()
	{
		CancelExtractedEditor();
		BeefForms_UninstallTextEditor(Internal.UnsafeCastToPtr(this));
	}

	private void CancelExtractedEditor()
	{
		mExtractedEditor = null;
		mExtractedOriginal.Clear();
		BeefForms_CloseTextEditor();
	}

	private static void OpenExtractedEditor(void* context, float x, float y)
	{
		let session = (SDLWindowSession)Internal.UnsafeCastToObject(context);
		using (session.Retain())
		{
			let window = session.mWindowGeneration;
			if (!session.IsCurrentWindow(window))
				return;
			SDL.GetWindowSize(session.mWindow, var width, var height);
			let editor = session.HitTest(session.mForm, (int)(x * width), (int)(y * height)) as TextBoxBase;
			if (editor == null || editor.ReadOnly)
				return;
			let handle = editor.HandleGeneration;
			session.Focus(editor);
			if (!session.IsCurrentControl(editor, window, handle) || editor.ReadOnly ||
				!editor.IsEffectivelyVisible || !editor.IsEffectivelyEnabled)
				return;
			session.ReleaseCapture();
			session.mPressed = null;
			session.mExtractedEditor = editor;
			session.mExtractedHandle = handle;
			session.mExtractedOriginal.Set(editor.Text);
			BeefForms_OpenTextEditor(editor.Text.ToScopeCStr!(), editor.Multiline ? 1 : 0,
				(int32)editor.SelectionStart, (int32)editor.SelectionLength);
		}
	}

	private static void FinishExtractedEditor(void* context, char8* draft)
	{
		let session = (SDLWindowSession)Internal.UnsafeCastToObject(context);
		using (session.Retain())
		{
			let editor = session.mExtractedEditor;
			let handle = session.mExtractedHandle;
			let original = scope String(session.mExtractedOriginal);
			session.CancelExtractedEditor();
			if (editor != null && editor.IsCurrentHandle(handle))
				session.ApplyExtractedDraft(editor, original, .(draft));
		}
	}

	private static void DismissExtractedEditor(void* context)
	{
		let session = (SDLWindowSession)Internal.UnsafeCastToObject(context);
		using (session.Retain())
		{
			session.CancelExtractedEditor();
		}
	}
#endif
}
