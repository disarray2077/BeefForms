using System;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

#if BF_PLATFORM_WINDOWS
class Win32TextTests
{
	private class UnicodeTextBox : TextBox
	{
		public char32 LastCharacter;
		public int TextInputs;
		public bool RejectSupplementary;

		protected override void OnKeyPress(KeyPressEventArgs args)
		{
			base.OnKeyPress(args);
			LastCharacter = args.KeyChar;
			if (RejectSupplementary && args.KeyChar > '\u{FFFF}') args.Handled = true;
		}
		protected override void OnTextInput(TextInputEventArgs args)
		{
			base.OnTextInput(args);
			TextInputs++;
		}
	}

	[Test]
	public static void NativeUnicodeTextRoundTrips()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		form.Text = "Janela — café 😀";
		let editor = new TextBox();
		editor.Size = .(200, 30);
		editor.Text = "café 😀";
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		char16[64] buffer = ?;
		let titleLength = Win32.GetWindowText(form.Handle, &buffer, buffer.Count);
		Test.Assert(scope String(Span<char16>(&buffer, titleLength)) == form.Text);
		let textLength = Win32.GetWindowText(editor.Handle, &buffer, buffer.Count);
		Test.Assert(scope String(Span<char16>(&buffer, textLength)) == "café 😀");
		Win32.SetWindowText(editor.Handle, "更新 😀".ToScopedNativeWChar!());
		Test.Assert(editor.Text == "更新 😀");
		editor.Text = "ação 🎉";
		let changedLength = Win32.GetWindowText(editor.Handle, &buffer, buffer.Count);
		Test.Assert(scope String(Span<char16>(&buffer, changedLength)) == editor.Text);
	}

	[Test]
	public static void NativeSupplementaryCharacterInputIsCancellable()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new UnicodeTextBox();
		editor.Size = .(200, 30);
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		int changes = 0;
		editor.TextChanged.Add(new [&] (sender, args) => { changes++; });

		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)0xE9, null);
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)0xD83D, null);
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)0xDE00, null);
		Test.Assert(editor.Text == "é😀" && editor.LastCharacter == '\u{1F600}');
		Test.Assert(editor.TextInputs == 2 && changes == 2);
		editor.RejectSupplementary = true;
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)0xD83D, null);
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)0xDE00, null);
		Test.Assert(editor.Text == "é😀" && changes == 2);
	}
}
#endif
