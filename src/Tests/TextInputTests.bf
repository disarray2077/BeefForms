using System;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class TextInputTests
{
	private class FilteringTextBox : TextBox
	{
		public String Events = new .() ~ delete _;
		public this()
		{
			TextChanged.Add(new (sender, args) => ((FilteringTextBox)sender).Events.Append('C'));
		}
		protected override void OnTextInput(TextInputEventArgs args)
		{
			base.OnTextInput(args);
			Events.Append('T');
			if (args.Text == "a") args.Text.Set("xy");
			if (args.Text == "%") args.Handled = true;
		}
		protected override void OnKeyPress(KeyPressEventArgs args)
		{
			base.OnKeyPress(args);
			Events.Append('K');
			if (args.KeyChar == 'x') args.KeyChar = 'z';
			if (args.KeyChar == '\u{1F600}') args.KeyChar = 'q';
			if (args.KeyChar == '!') args.Handled = true;
		}
	}

	private static void TypeText(TextBox editor, String text)
	{
		if (let backend = Application.Backend as SDLBackend)
			SDLTestInput.TypeText(backend, text);
#if BF_PLATFORM_WINDOWS
		else
		{
			let units = text.ToScopedNativeWChar!();
			for (var cursor = units; *cursor != 0; cursor++)
				Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(uint)(*cursor), null);
		}
#endif
	}

	private static void VerifyTextFiltering(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new FilteringTextBox();
		editor.Size = .(200, 30);
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		if (let sdl = Application.Backend as SDLBackend) SDLTestInput.Activate(sdl);
		editor.Focus();
		editor.Events.Clear();

		TypeText(editor, "a");
		Test.Assert(editor.Text == "zy" && editor.Events == "TKKC");
		editor.Events.Clear();
		TypeText(editor, "%");
		Test.Assert(editor.Text == "zy" && editor.Events == "T");
		editor.Events.Clear();
		TypeText(editor, "😀");
		Test.Assert(editor.Text == "zyq" && editor.Events == "TKC");
		editor.Events.Clear();
		TypeText(editor, "!");
		Test.Assert(editor.Text == "zyq" && editor.Events == "TK");
	}

	[Test]
	public static void SDLTextEventsFilterBeforeEditing() => VerifyTextFiltering(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void Win32TextEventsFilterBeforeEditing() => VerifyTextFiltering(.Win32);
#endif
}
