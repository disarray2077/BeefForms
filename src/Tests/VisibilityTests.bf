using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class VisibilityTests
{
	[Test]
	public static void SDLHitTestingFollowsVisibilityAndStacking()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(200, 120);
		let first = new Button();
		first.Text = "First";
		first.Location = .(20, 20);
		first.Size = .(100, 30);
		let second = new Button();
		second.Text = "Second";
		second.Location = first.Location;
		second.Size = first.Size;
		int firstClicks = 0, secondClicks = 0;
		first.Click.Add(new [&] (sender, args) => { firstClicks++; });
		second.Click.Add(new [&] (sender, args) => { secondClicks++; });
		panel.Controls.Add(first);
		panel.Controls.Add(second);
		form.Controls.Add(panel);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		function void() click = () =>
		{
			SDL.Event input = .();
			input.type = .MouseButtonDown;
			input.button.button = 1;
			input.button.x = 30;
			input.button.y = 30;
			SDL.PushEvent(ref input);
			input.type = .MouseButtonUp;
			SDL.PushEvent(ref input);
		};

		click();
		backend.ProcessEvents();
		Test.Assert(secondClicks == 1 && firstClicks == 0);
		first.BringToFront();
		click();
		backend.ProcessEvents();
		Test.Assert(firstClicks == 1);
		first.SendToBack();
		click();
		backend.ProcessEvents();
		Test.Assert(secondClicks == 2);
		second.Hide();
		click();
		backend.ProcessEvents();
		Test.Assert(firstClicks == 2);

		first.Focus();
		first.Capture = true;
		panel.Hide();
		Test.Assert(!first.IsEffectivelyVisible && !first.Focused && !first.Capture && !first.Focus());
		click();
		backend.ProcessEvents();
		Test.Assert(firstClicks == 2 && secondClicks == 2);
		panel.Show();
		Test.Assert(first.IsEffectivelyVisible && !second.IsEffectivelyVisible);
		first.Focus();
		SDL.Event tab = .();
		tab.type = .KeyDown;
		tab.key.keysym.sym = .TAB;
		SDL.PushEvent(ref tab);
		backend.ProcessEvents();
		Test.Assert(first.Focused && !second.Focus());
		backend.FrameLimit = 1;
		backend.Run(form);
	}

	[Test]
	public static void HiddenChildrenDoNotExtendTheScrollRange()
	{
		let panel = scope Panel();
		panel.Size = .(100, 100);
		panel.AutoScroll = true;
		let child = new Control();
		child.Location = .(0, 200);
		child.Size = .(50, 20);
		panel.Controls.Add(child);
		panel.ScrollPosition = .(0, 100);
		child.Hide();
		Test.Assert(!panel.VerticalScrollVisible && panel.ScrollPosition.y == 0);
		child.Show();
		Test.Assert(panel.VerticalScrollVisible);
		panel.Hide();
		panel.PerformLayout();
		panel.Show();
		Test.Assert(panel.VerticalScrollVisible);
	}

	[Test]
	public static void InheritedVisibilityChangesNotifyVisibleDescendants()
	{
		let parent = scope Panel();
		let panel = new Panel();
		let child = new Button();
		let hidden = new Button();
		hidden.Hide();
		panel.Controls.Add(child);
		panel.Controls.Add(hidden);
		parent.Controls.Add(panel);
		int panelChanges = 0, childChanges = 0, hiddenChanges = 0;
		panel.VisibleChanged.Add(new [&] (sender, args) => { panelChanges++; });
		child.VisibleChanged.Add(new [&] (sender, args) => { childChanges++; });
		hidden.VisibleChanged.Add(new [&] (sender, args) => { hiddenChanges++; });
		parent.Hide();
		parent.Show();
		Test.Assert(panelChanges == 2 && childChanges == 2 && hiddenChanges == 0);
		Test.Assert(child.Visible && !hidden.Visible);
		parent.Hide();
		child.Hide();
		child.Show();
		Test.Assert(childChanges == 3);
		parent.Show();
		Test.Assert(childChanges == 4 && hiddenChanges == 0);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeVisibilityAndStackingFollowTheControlTree()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(200, 120);
		let first = new Button();
		first.Size = .(100, 30);
		let second = new Button();
		second.Size = first.Size;
		second.Visible = false;
		panel.Controls.Add(first);
		panel.Controls.Add(second);
		form.Controls.Add(panel);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		Test.Assert(!Win32.IsWindowVisible(second.Handle));
		second.Show();
		first.BringToFront();
		Test.Assert(Win32.GetWindow(panel.Handle, 5) == first.Handle);
		first.SendToBack();
		Test.Assert(Win32.GetWindow(panel.Handle, 5) == second.Handle);
		second.Focus();
		second.Capture = true;
		panel.Hide();
		Test.Assert(!Win32.IsWindowVisible(second.Handle) && !second.Focused && !second.Capture);
		panel.Show();
		Test.Assert(Win32.IsWindowVisible(second.Handle));
	}
#endif
}
