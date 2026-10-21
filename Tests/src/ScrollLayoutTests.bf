using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class ScrollLayoutTests
{
	[Test]
	public static void RemovingAndReparentingChildrenUpdatesScrollBounds()
	{
		let first = scope Panel();
		first.Size = .(100, 100);
		first.AutoScroll = true;
		let second = scope Panel();
		second.Size = .(100, 100);
		second.AutoScroll = true;
		let child = new Control();
		child.Location = .(0, 500);
		child.Size = .(50, 30);
		first.Controls.Add(child);
		first.ScrollPosition = .(0, 100);
		first.Controls.Remove(child);
		Test.Assert(child.Parent == null && !first.VerticalScrollVisible && first.ScrollPosition.y == 0);
		first.Controls.Add(child);
		first.ScrollPosition = .(0, 100);
		second.Controls.Add(child);
		Test.Assert(first.Controls.IsEmpty && !first.VerticalScrollVisible && first.ScrollPosition.y == 0);
		Test.Assert(child.Parent == second && second.VerticalScrollVisible);
		second.ScrollPosition = .(0, 100);
		second.Controls.Clear();
		Test.Assert(child.Parent == null && !second.VerticalScrollVisible && second.ScrollPosition.y == 0);
		delete child;
	}

	[Test]
	public static void ScrollingRefreshesHoverWithoutMouseMotion()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(160, 100);
		panel.AutoScroll = true;
		panel.AutoScrollMinSize = .(100, 200);
		let first = new Button();
		first.Size = .(100, 40);
		let second = new Button();
		second.Location = .(0, 60);
		second.Size = first.Size;
		panel.Controls.Add(first);
		panel.Controls.Add(second);
		form.Controls.Add(panel);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		SDL.Event input = .();
		input.type = .MouseMotion;
		input.motion.x = 20;
		input.motion.y = 20;
		SDL.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(first.IsMouseOver);
		int leaves = 0, enters = 0;
		first.MouseLeave.Add(new [&] (sender, args) => { leaves++; });
		second.MouseEnter.Add(new [&] (sender, args) => { enters++; });

		panel.ScrollPosition = .(0, 60);
		Test.Assert(!first.IsMouseOver && second.IsMouseOver && leaves == 1 && enters == 1);
		input = .();
		input.type = .MouseWheel;
		input.wheel.mouseX = 20;
		input.wheel.mouseY = 20;
		input.wheel.y = 1;
		SDL.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(first.IsMouseOver && !second.IsMouseOver);
	}

	private static void VerifyAutoSizeLabel(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(80, 80);
		panel.AutoScroll = true;
		let label = new Label();
		label.AutoSize = true;
		label.Text = "A label wider than the panel";
		panel.Controls.Add(label);
		form.Controls.Add(panel);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		let measured = Application.Backend.MeasureText(label);
		Test.Assert(label.Size.width == measured.width && label.Size.height == measured.height);
		Test.Assert(panel.HorizontalScrollVisible && panel.ScrollContentSize.width == label.Size.width);
		label.Text = "x";
		Test.Assert(!panel.HorizontalScrollVisible && label.Size.width < panel.ViewportSize.width);
		label.Text = "";
		Test.Assert(label.Size.width == 0 && panel.ScrollContentSize.width == 0);
	}

	[Test]
	public static void SDLAutoSizeLabelsExtendScrollBounds() => VerifyAutoSizeLabel(.SDL2OpenGL);

	private static void VerifyInheritedFont(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		form.Font = new System.Drawing.Font("Segoe UI", 9);
		let label = new Label();
		label.AutoSize = true;
		label.Text = "Text";
		form.Controls.Add(label);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		let before = label.Size;
		form.Font = new System.Drawing.Font("Segoe UI", 24);
		Test.Assert(label.Size.width > before.width && label.Size.height > before.height);
	}
	[Test]
	public static void InheritedFontChangesResizeAutoSizeLabels() => VerifyInheritedFont(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeInheritedFontChangesResizeAutoSizeLabels() => VerifyInheritedFont(.Win32);
	[Test]
	public static void NativeAutoSizeLabelsExtendScrollBounds() => VerifyAutoSizeLabel(.Win32);

	[Test]
	public static void NativeFormViewportExcludesScrollbarsOnce()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(200, 120);
		let child = new Button();
		child.Location = .(150, 70);
		child.Size = .(30, 20);
		child.Anchor = .Right | .Bottom;
		form.Controls.Add(child);
		form.AutoScroll = true;
		form.AutoScrollMinSize = .(400, 300);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		Win32.GetClientRect(form.Handle, var client);
		Test.Assert(form.ViewportSize.width == client.right && form.ViewportSize.height == client.bottom);
		Test.Assert(child.Location.x == 150 && child.Location.y == 70);
		let bars = Application.Backend.GetScrollBarSize(form);
		let dpi = Win32.GetDpiForWindow(form.Handle);
		Test.Assert(bars.width == Win32.GetSystemMetricsForDpi(Win32.SM_CXVSCROLL, dpi));
		Test.Assert(bars.height == Win32.GetSystemMetricsForDpi(Win32.SM_CYHSCROLL, dpi));
		form.ScrollPosition = .(int32.MaxValue, int32.MaxValue);
		Test.Assert(form.ScrollPosition.x == 400 - client.right && form.ScrollPosition.y == 300 - client.bottom);
		form.ClientSize = .(600, 400);
		Test.Assert(!form.HorizontalScrollVisible && !form.VerticalScrollVisible);
		Test.Assert(form.ScrollPosition.x == 0 && form.ScrollPosition.y == 0);
		form.ClientSize = .(100, 80);
		Win32.GetClientRect(form.Handle, out client);
		Test.Assert(form.ViewportSize.width == client.right && form.ViewportSize.height == client.bottom);
	}

	[Test]
	public static void ReparentingCreatedChildrenMovesTheirNativeHandles()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let first = new Panel();
		first.Size = .(100, 100);
		first.AutoScroll = true;
		let second = new Panel();
		second.Location = .(150, 0);
		second.Size = first.Size;
		second.AutoScroll = true;
		let child = new Button();
		child.Location = .(0, 200);
		child.Size = .(50, 30);
		first.Controls.Add(child);
		form.Controls.Add(first);
		form.Controls.Add(second);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		second.Controls.Add(child);
		Test.Assert(Win32.GetParent(child.Handle) == second.Handle);
		Test.Assert(!first.VerticalScrollVisible && second.VerticalScrollVisible);
		second.Controls.Clear();
		Test.Assert(!child.IsHandleCreated && child.Handle == null && child.Parent == null);
		delete child;
	}
#endif
}
