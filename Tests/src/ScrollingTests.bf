using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class ScrollingTests
{
	[Test]
	public static void ScrollRangeTracksContentAndForwardsWheelInputAtTheLimit()
	{
		let outer = scope Panel();
		outer.Size = .(200, 100);
		outer.AutoScroll = true;
		let inner = new Panel();
		inner.Size = .(150, 200);
		inner.AutoScroll = true;
		inner.AutoScrollMinSize = .(100, 400);
		outer.Controls.Add(inner);

		let wheel = scope MouseEventArgs(.None, 0, 10, 10, -120);
		inner.DispatchMouseWheel(wheel);
		Test.Assert(inner.ScrollPosition.y == 48 && outer.ScrollPosition.y == 0);
		inner.ScrollPosition = .(0, int32.MaxValue);
		wheel.Handled = false;
		inner.DispatchMouseWheel(wheel);
		Test.Assert(outer.ScrollPosition.y == 48);
		inner.AutoScrollMinSize = .(0, 0);
		Test.Assert(inner.ScrollPosition.y == 0 && !inner.VerticalScrollVisible);
	}

	[Test]
	public static void SDLScrollsHitTargetsAndDragsTheThumb()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(300, 200);
		let panel = new Panel();
		panel.Location = .(10, 10);
		panel.Size = .(160, 120);
		panel.AutoScroll = true;
		let button = new Button();
		button.Location = .(5, 180);
		button.Size = .(80, 30);
		int clicks = 0;
		button.Click.Add(new [&] (sender, args) => { clicks++; });
		panel.Controls.Add(button);
		form.Controls.Add(panel);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		backend.ProcessEvents();
		panel.ScrollPosition = .(0, 150);

		SDL.Event input = .();
		input.type = .MouseButtonDown;
		input.button.button = 1;
		input.button.x = 20;
		input.button.y = 110;
		SDLTestInput.PushEvent(ref input);
		input.type = .MouseButtonUp;
		SDLTestInput.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(clicks == 1 && button.Location.y == 180);

		panel.ScrollPosition = .(0, 0);
		let thumb = panel.ScrollThumb(false);
		input.type = .MouseButtonDown;
		input.button.x = 10 + thumb.X + 2;
		input.button.y = 10 + thumb.Y + 2;
		SDLTestInput.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(panel.Capture);
		input = .();
		input.type = .MouseMotion;
		input.motion.x = 10 + thumb.X + 2;
		input.motion.y = 110;
		SDLTestInput.PushEvent(ref input);
		input = .();
		input.type = .MouseButtonUp;
		input.button.button = 1;
		input.button.x = 10 + thumb.X + 2;
		input.button.y = 110;
		SDLTestInput.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(panel.ScrollPosition.y > 0 && !panel.Capture);
		backend.FrameLimit = 1;
		backend.Run(form);
	}

#if BF_PLATFORM_WINDOWS
	private class PaintTrackingProgressBar : ProgressBar
	{
		public int PaintCount;
		protected internal override void NotifyPaint()
		{
			base.NotifyPaint();
			PaintCount++;
		}
	}

	[Test]
	public static void NativeScrollingPreservesVisibleMarqueeContents()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 200);
		let panel = new Panel();
		panel.Size = .(200, 140);
		panel.AutoScroll = true;
		panel.AutoScrollMinSize = .(100, 400);
		let row = new Panel();
		row.Location = .(5, 60);
		row.Size = .(150, 70);
		let progress = new PaintTrackingProgressBar();
		progress.Size = .(120, 20);
		progress.Style = .Marquee;
		progress.MarqueeAnimationSpeed = 60000;
		row.Controls.Add(progress);
		panel.Controls.Add(row);
		form.Controls.Add(panel);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		Win32.RedrawWindow(form.Handle, null, null, Win32.RDW_INVALIDATE | Win32.RDW_ERASE | Win32.RDW_ALLCHILDREN | Win32.RDW_UPDATENOW);

		let paints = progress.PaintCount;
		Win32.GetWindowRect(progress.Handle, var before);
		panel.ScrollPosition = .(0, 16);
		Win32.RedrawWindow(panel.Handle, null, null, Win32.RDW_ALLCHILDREN | Win32.RDW_UPDATENOW);
		Win32.GetWindowRect(progress.Handle, var after);
		Test.Assert(after.top == before.top - 16 && progress.PaintCount == paints);
	}

	[Test]
	public static void NativePanelsReceiveMouseInputAcrossTheirClientAndScrollbars()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 200);
		let panel = new Panel();
		panel.Size = .(160, 120);
		panel.AutoScroll = true;
		panel.AutoScrollMinSize = .(400, 500);
		let label = new Label();
		label.Text = "Download";
		label.Location = .(10, 10);
		label.Size = .(80, 20);
		panel.Controls.Add(label);
		form.Controls.Add(panel);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		function int*(int32 x, int32 y) packedPoint = (x, y) => (int*)(void*)(int)((y << 16) | (x & 0xFFFF));
		Win32.GetWindowRect(panel.Handle, var bounds);
		let clientPoint = packedPoint(bounds.left + 5, bounds.top + 5);
		let verticalPoint = packedPoint(bounds.right - 8, bounds.bottom - 40);
		let horizontalPoint = packedPoint(bounds.right - 40, bounds.bottom - 8);
		Test.Assert((int)(void*)Win32.SendMessage(panel.Handle, Win32.WM_NCHITTEST, null, clientPoint) == Win32.HTCLIENT);
		Test.Assert((int)(void*)Win32.SendMessage(panel.Handle, Win32.WM_NCHITTEST, null, verticalPoint) == Win32.HTVSCROLL);
		Test.Assert((int)(void*)Win32.SendMessage(panel.Handle, Win32.WM_NCHITTEST, null, horizontalPoint) == Win32.HTHSCROLL);
		Win32.GetWindowRect(label.Handle, out bounds);
		Test.Assert((int)(void*)Win32.SendMessage(label.Handle, Win32.WM_NCHITTEST, null, packedPoint(bounds.left + 5, bounds.top + 5)) == Win32.HTCLIENT);

		Win32.SendMessage(label.Handle, Win32.WM_MOUSEWHEEL, (uint*)(void*)(-120 << 16), clientPoint);
		Test.Assert(panel.ScrollPosition.y > 0);
		panel.ScrollPosition = .(0, 0);
		// Release the press inside DefWindowProc's native scrollbar tracking loop.
		Win32.PostMessage(panel.Handle, Win32.WM_LBUTTONUP, null, clientPoint);
		Win32.SendMessage(panel.Handle, Win32.WM_NCLBUTTONDOWN, (uint*)(void*)Win32.HTVSCROLL, verticalPoint);
		Test.Assert(panel.ScrollPosition.y > 0);
		Win32.PostMessage(panel.Handle, Win32.WM_LBUTTONUP, null, clientPoint);
		Win32.SendMessage(panel.Handle, Win32.WM_NCLBUTTONDOWN, (uint*)(void*)Win32.HTHSCROLL, horizontalPoint);
		Test.Assert(panel.ScrollPosition.x > 0);
	}

	[Test]
	public static void NativePanelsShowScrollbarsOnlyForEnabledOverflow()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(400, 240);
		let plain = new Panel();
		plain.Size = .(160, 120);
		let scrolling = new Panel();
		scrolling.Location = .(180, 0);
		scrolling.Size = plain.Size;
		scrolling.AutoScroll = true;
		form.Controls.Add(plain);
		form.Controls.Add(scrolling);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		function uint(Control) scrollStyles = (control) =>
			(uint)(void*)Win32.GetWindowLongPtr(control.Handle, Win32.GWL_STYLE) & (Win32.WS_HSCROLL | Win32.WS_VSCROLL);
		Test.Assert(scrollStyles(plain) == 0 && scrollStyles(scrolling) == 0);
		let child = new Button();
		child.Location = .(0, 200);
		child.Size = .(50, 20);
		scrolling.Controls.Add(child);
		Test.Assert(scrollStyles(scrolling) == Win32.WS_VSCROLL);
		scrolling.AutoScroll = false;
		Test.Assert(scrollStyles(scrolling) == 0);
		scrolling.AutoScroll = true;
		Test.Assert(scrollStyles(scrolling) == Win32.WS_VSCROLL);
		child.Location = .(200, 200);
		Test.Assert(scrollStyles(scrolling) == (Win32.WS_HSCROLL | Win32.WS_VSCROLL));
		child.Location = .(0, 0);
		Test.Assert(scrollStyles(scrolling) == 0);
	}

	[Test]
	public static void NativeScrollbarsMoveChildrenWithoutChangingTheirLocation()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(300, 200);
		let panel = new Panel();
		panel.Size = .(160, 120);
		panel.AutoScroll = true;
		let child = new Button();
		child.Location = .(5, 180);
		child.Size = .(80, 30);
		panel.Controls.Add(child);
		form.Controls.Add(panel);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }

		Win32.GetWindowRect(child.Handle, var before);
		Win32.SendMessage(panel.Handle, Win32.WM_VSCROLL, (uint*)(void*)1, null);
		Win32.GetWindowRect(child.Handle, var after);
		Test.Assert(panel.ScrollPosition.y == 16 && after.top == before.top - 16);
		Test.Assert(child.Location.y == 180);
		let beforeWheel = panel.ScrollPosition.y;
		Win32.SendMessage(child.Handle, Win32.WM_MOUSEWHEEL, (uint*)(void*)(-120 << 16), null);
		Test.Assert(panel.ScrollPosition.y > beforeWheel);
		panel.AutoScroll = false;
		Test.Assert(panel.ScrollPosition.y == 0 && !panel.VerticalScrollVisible);
		Win32.GetWindowRect(child.Handle, out after);
		Test.Assert(after.top == before.top);
	}
#endif
}
