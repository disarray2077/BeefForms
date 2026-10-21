using System;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

#if BF_PLATFORM_WINDOWS
class Win32BackendTests
{
	[Test]
	public static void NativeTextBoxBordersMatchTheirStyleAndUpdateTheClientArea()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new TextBox();
		editor.Size = .(200, 30);
		form.Controls.Add(editor);
		Test.Assert(editor.BorderStyle == .Fixed3D);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		function uint(Control, int32) nativeStyle = (control, index) => (uint)(void*)Win32.GetWindowLongPtr(control.Handle, index);
		Test.Assert((nativeStyle(editor, Win32.GWL_EXSTYLE) & Win32.WS_EX_CLIENTEDGE) != 0);
		Test.Assert((nativeStyle(editor, Win32.GWL_STYLE) & Win32.WS_BORDER) == 0);
		Win32.GetClientRect(editor.Handle, var initialClient);

		editor.BorderStyle = .FixedSingle;
		Test.Assert((nativeStyle(editor, Win32.GWL_STYLE) & Win32.WS_BORDER) != 0);
		Test.Assert((nativeStyle(editor, Win32.GWL_EXSTYLE) & Win32.WS_EX_CLIENTEDGE) == 0);
		editor.BorderStyle = .None;
		Test.Assert((nativeStyle(editor, Win32.GWL_STYLE) & Win32.WS_BORDER) == 0);
		Win32.GetClientRect(editor.Handle, var borderlessClient);
		Test.Assert(borderlessClient.right == editor.Size.width && borderlessClient.right > initialClient.right);
		editor.BorderStyle = .Fixed3D;
		Win32.GetClientRect(editor.Handle, var restoredClient);
		Test.Assert(restoredClient.right == initialClient.right);
	}

	private class FilteredTextBox : TextBox
	{
		protected override void OnKeyPress(KeyPressEventArgs args)
		{
			base.OnKeyPress(args);
			if (args.KeyChar == 'Y') args.Handled = true;
		}
	}
	[Test]
	public static void NativeTextEditingSurvivesRepaint()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new FilteredTextBox();
		editor.Size = .(200, 30);
		editor.Text = "abc";
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		editor.Select(1, 0);
		editor.Invalidate();
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(int)'X', null);
		Test.Assert(editor.Text == "aXbc");
		Test.Assert(editor.SelectionStart == 2 && editor.SelectionLength == 0);
		let selection = (uint)(void*)Win32.SendMessage(editor.Handle, Win32.EM_GETSEL, null, null);
		Test.Assert((selection & 0xFFFF) == 2 && (selection >> 16) == 2);
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(int)'Y', null);
		Test.Assert(editor.Text == "aXbc");
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)8, null);
		Test.Assert(editor.Text == "abc" && editor.SelectionStart == 1 && editor.SelectionLength == 0);
		editor.ReadOnly = true;
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(int)'Z', null);
		Test.Assert(editor.Text == "abc");
	}
}
#endif
