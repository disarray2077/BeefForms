using System;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

#if BF_PLATFORM_WINDOWS
class GroupBoxTests
{
	[Test]
	public static void NativeGroupBoxHostsChildInputAndPreservesFocus()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 220);
		let group = new GroupBox();
		group.Text = "Options";
		group.Location = .(10, 10);
		group.Size = .(260, 180);
		let button = new Button();
		button.Location = .(20, 30);
		button.Size = .(100, 25);
		let editor = new TextBox();
		editor.Location = .(20, 70);
		editor.Size = .(160, 25);
		editor.TabIndex = 1;
		group.Controls.Add(button);
		group.Controls.Add(editor);
		form.Controls.Add(group);
		int clicks = 0;
		button.Click.Add(new [&] (sender, args) => { clicks++; });
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		Test.Assert(Win32.GetParent(button.Handle) == group.Handle && Win32.GetParent(editor.Handle) == group.Handle);
		Win32.SendMessage(button.Handle, Win32.WM_LBUTTONDOWN, (uint*)(void*)1, (int*)(void*)0x000A000A);
		Win32.SendMessage(button.Handle, Win32.WM_LBUTTONUP, null, (int*)(void*)0x000A000A);
		Test.Assert(clicks == 1);
		editor.Focus();
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(int)'x', null);
		Test.Assert(editor.Text == "x");
		Win32.SendMessage(group.Handle, Win32.WM_LBUTTONDOWN, (uint*)(void*)1, (int*)(void*)0x008C00DC);
		Win32.SendMessage(group.Handle, Win32.WM_LBUTTONUP, null, (int*)(void*)0x008C00DC);
		Test.Assert(editor.Focused && !group.Focused);
		Win32.SendMessage(editor.Handle, Win32.WM_KEYDOWN, (uint*)(void*)(uint)Keys.Tab, null);
		Test.Assert(button.Focused);
	}

	[Test]
	public static void NativeGroupBoxHitTestingAndErasureTreatItAsAContainer()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 220);
		let group = new GroupBox();
		group.Size = .(260, 180);
		form.Controls.Add(group);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		Win32.GetWindowRect(group.Handle, var bounds);
		let point = ((bounds.top + 100) << 16) | ((bounds.left + 100) & 0xFFFF);
		let hit = (int)(void*)Win32.SendMessage(group.Handle, Win32.WM_NCHITTEST, null, (int*)(void*)(int)point);
		Test.Assert(hit == Win32.HTCLIENT);
		let context = Win32.GetDC(group.Handle);
		defer Win32.ReleaseDC(group.Handle, context);
		Test.Assert((int)(void*)Win32.SendMessage(group.Handle, Win32.WM_ERASEBKGND, (uint*)context, null) == 1);
	}
}
#endif
