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
		SDL.PushEvent(ref input);
		input.type = .MouseButtonUp;
		SDL.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(clicks == 1 && button.Location.y == 180);

		panel.ScrollPosition = .(0, 0);
		let thumb = panel.ScrollThumb(false);
		input.type = .MouseButtonDown;
		input.button.x = 10 + thumb.X + 2;
		input.button.y = 10 + thumb.Y + 2;
		SDL.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(panel.Capture);
		input = .();
		input.type = .MouseMotion;
		input.motion.x = 10 + thumb.X + 2;
		input.motion.y = 110;
		SDL.PushEvent(ref input);
		input = .();
		input.type = .MouseButtonUp;
		input.button.button = 1;
		input.button.x = 10 + thumb.X + 2;
		input.button.y = 110;
		SDL.PushEvent(ref input);
		backend.ProcessEvents();
		Test.Assert(panel.ScrollPosition.y > 0 && !panel.Capture);
		backend.FrameLimit = 1;
		backend.Run(form);
	}

#if BF_PLATFORM_WINDOWS
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
	}
#endif
}
