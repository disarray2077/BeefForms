using System;
using System.Drawing;
using System.Windows.Forms;

using internal System.Windows.Forms;

namespace BeefForms.Tests;

class ControlTests
{
	private class TrackedFont : Font
	{
		private int* mDestroyed;
		public this(int* destroyed) : base("Segoe UI", 9) { mDestroyed = destroyed; }
		public ~this() { (*mDestroyed)++; }
	}

	[Test]
	public static void AssignedFontsSurviveOtherOwners()
	{
		int destroyed = 0;
		let first = new Control();
		let second = new Control();
		first.Font = new TrackedFont(&destroyed);
		second.Font = first.Font;
		first.Font = new TrackedFont(&destroyed);
		Test.Assert(destroyed == 0 && second.Font.FamilyName == "Segoe UI");
		delete first;
		Test.Assert(destroyed == 1 && second.Font.Size == 9);
		delete second;
		Test.Assert(destroyed == 2);

		let parent = scope Control();
		parent.Font = new TrackedFont(&destroyed);
		{
			let child = scope Control();
			child.Font = parent.Font;
		}
		Test.Assert(destroyed == 2 && parent.Font.Size == 9);
	}

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

	[Test]
	public static void VisibilityAndEnabledInheritWithoutChangingLocalState()
	{
		let parent = scope Panel();
		let button = new Button();
		parent.Controls.Add(button);
		int clicks = 0;
		button.Click.Add(new [&] (sender, args) => { clicks++; });
		parent.Visible = false;
		Test.Assert(!button.Visible && !button.CanSelect);
		button.PerformClick();
		parent.Visible = true;
		parent.Enabled = false;
		Test.Assert(!button.Enabled);
		button.PerformClick();
		parent.Enabled = true;
		button.TabStop = false;
		button.PerformClick();
		Test.Assert(button.Visible && button.Enabled && clicks == 1);
		button.Visible = false;
		button.Enabled = false;
		parent.Hide();
		parent.Show();
		parent.Enabled = false;
		parent.Enabled = true;
		Test.Assert(!button.Visible && !button.Enabled);
	}

	[Test]
	public static void PublicSelectionUsesUTF16AndKeepsCharacterBoundaries()
	{
		let editor = scope TextBox();
		editor.Text = "aé😀z";
		editor.SelectionStart = 1;
		editor.SelectionLength = 3;
		Test.Assert(editor.SelectionStart == 1 && editor.SelectionLength == 3);
		editor.ReplaceSelection("x");
		Test.Assert(editor.Text == "axz");
		editor.Text = "aé😀z";
		editor.Select(3, 0);
		Test.Assert(editor.SelectionStart == 2 && editor.SelectionLength == 0);
		editor.Select(2, 2);
		editor.ReplaceSelection("x");
		Test.Assert(editor.Text == "aéxz");
		editor.SetCaret(3, false);
		editor.Text = "éé";
		Test.Assert(editor.SelectionStart == 1);
		editor.DeleteText(true);
		Test.Assert(editor.Text == "é");
		editor.SelectionStart = int.MaxValue;
		editor.SelectionLength = int.MaxValue;
		Test.Assert(editor.SelectionStart == 1 && editor.SelectionLength == 0);
	}

	[Test]
	public static void SelectionStartCountsAccentedCharactersOnce()
	{
		let editor = scope TextBox();
		editor.Text = "aéb";
		editor.SelectionStart = 2;
		editor.SelectionLength = 0;
		editor.ReplaceSelection("x");
		Test.Assert(editor.Text == "aéxb" && editor.SelectionStart == 3);
	}

}
