using System;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

#if BF_PLATFORM_WINDOWS
class Win32BackendTests
{
	[Test]
	public static void NativeTextEditingSurvivesRepaint()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new TextBox();
		editor.Size = .(200, 30);
		editor.Text = "abc";
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		editor.Select(1, 0);
		editor.Invalidate();
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(int)'X', null);
		Test.Assert(editor.Text == "aXbc");
		let selection = (uint)(void*)Win32.SendMessage(editor.Handle, Win32.EM_GETSEL, null, null);
		Test.Assert((selection & 0xFFFF) == 2 && (selection >> 16) == 2);
		editor.ReadOnly = true;
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(int)'Y', null);
		Test.Assert(editor.Text == "aXbc");
	}
}
#endif
