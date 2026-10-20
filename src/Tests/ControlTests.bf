using System;
using System.Windows.Forms;

using internal System.Windows.Forms;

namespace BeefForms.Tests;

class ControlTests
{
	[Test]
	public static void AnchorsFollowParentSize()
	{
		let parent = scope Control();
		parent.Size = .(200, 100);
		let child = new Control();
		child.Location = .(10, 10);
		child.Size = .(180, 80);
		child.Anchor = .Top | .Bottom | .Left | .Right;
		parent.Controls.Add(child);
		parent.Size = .(300, 150);
		Test.Assert(child.Location.x == 10 && child.Location.y == 10);
		Test.Assert(child.Size.width == 280 && child.Size.height == 130);
		parent.Size = .(200, 100);
		Test.Assert(child.Size.width == 180 && child.Size.height == 80);
	}

	[Test]
	public static void SelectionAndDeletionPreserveUTF8()
	{
		let editor = scope TextBox();
		editor.Text = "café";
		editor.SetCaret(editor.Text.Length, false);
		editor.DeleteText(true);
		Test.Assert(editor.Text == "caf");
		editor.Select(0, 3);
		editor.ReplaceSelection("hello");
		Test.Assert(editor.Text == "hello" && editor.Caret == 5);
		editor.ReadOnly = true;
		editor.SelectAll();
		editor.ReplaceSelection("changed");
		Test.Assert(editor.Text == "hello");
	}
}
