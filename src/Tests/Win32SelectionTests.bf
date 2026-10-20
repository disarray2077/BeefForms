using System;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

#if BF_PLATFORM_WINDOWS
class Win32SelectionTests
{
	[Test]
	public static void NativeSelectionConvertsUTF8AndUTF16Offsets()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new TextBox();
		editor.Size = .(200, 30);
		editor.Text = "aé😀z";
		editor.Select(1, 6);
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		let selection = (uint)(void*)Win32.SendMessage(editor.Handle, Win32.EM_GETSEL, null, null);
		Test.Assert((selection & 0xFFFF) == 1 && (selection >> 16) == 4);
		Test.Assert(editor.SelectionStart == 1 && editor.SelectionLength == 6);
		editor.Focus();
		editor.Select(3, 0);
		Win32.SendMessage(editor.Handle, Win32.WM_KEYDOWN, (uint*)(void*)(uint)Keys.Left, null);
		Test.Assert(editor.SelectionStart == 1 && editor.SelectionLength == 0);
		Win32.SendMessage(editor.Handle, Win32.EM_SETSEL, (uint*)(void*)2, (int*)(void*)4);
		Test.Assert(editor.SelectionStart == 3 && editor.SelectionLength == 4);
	}

	[Test]
	public static void NativeMouseSelectionUpdatesTheSharedSelection()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new TextBox();
		editor.Size = .(200, 30);
		editor.Text = "aé😀z";
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		let start = Win32.SendMessage(editor.Handle, Win32.EM_POSFROMCHAR, (uint*)(void*)1, null);
		let end = Win32.SendMessage(editor.Handle, Win32.EM_POSFROMCHAR, (uint*)(void*)4, null);
		Win32.SendMessage(editor.Handle, Win32.WM_LBUTTONDOWN, (uint*)(void*)1, start);
		Win32.SendMessage(editor.Handle, Win32.WM_MOUSEMOVE, (uint*)(void*)1, end);
		Win32.SendMessage(editor.Handle, Win32.WM_LBUTTONUP, null, end);
		Test.Assert(editor.SelectionStart == 1 && editor.SelectionLength == 6);
		Win32.SendMessage(editor.Handle, Win32.WM_LBUTTONDOWN, (uint*)(void*)1, end);
		Win32.SendMessage(editor.Handle, Win32.WM_MOUSEMOVE, (uint*)(void*)1, start);
		Win32.SendMessage(editor.Handle, Win32.WM_LBUTTONUP, null, start);
		Test.Assert(editor.Caret == 1 && editor.SelectionAnchor == 7);
	}

	[Test]
	public static void TextChangedObservesTheUpdatedSelection()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new TextBox();
		editor.Size = .(200, 30);
		editor.Text = "aé😀z";
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		int changes = 0;
		editor.TextChanged.Add(new [&] (sender, args) =>
		{
			changes++;
			Test.Assert(editor.SelectionStart == editor.Text.Length && editor.SelectionLength == 0);
		});
		editor.SelectAll();
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(uint)'X', null);
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)8, null);
		Test.Assert(changes == 2 && editor.Text.IsEmpty);
	}
}
#endif
