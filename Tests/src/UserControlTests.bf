using System;
using System.Drawing;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class UserControlTests
{
	private class CustomControl : UserControl
	{
		public int Loads;
		public int Paints;

		protected override void OnLoad(EventArgs args)
		{
			Loads++;
			base.OnLoad(args);
		}

		protected override void OnPaint(PaintEventArgs args)
		{
			Paints++;
			base.OnPaint(args);
		}
	}

	[Test]
	public static void DefaultsMatchWinFormsWithoutCreatingHandles()
	{
		let control = scope UserControl();
		ContainerControl container = control;
		Test.Assert(container.Size == .(150, 150) && control.ClientSize == .(150, 150));
		Test.Assert(control.Visible && control.Enabled && control.TabStop && control.CanSelect);
		Test.Assert(!control.AutoSize && control.AutoSizeMode == .GrowOnly && !control.AutoScroll);
		Test.Assert(control.BorderStyle == .None && control.AutoScaleMode == .Inherit);
		Test.Assert(!control.Created && !control.IsHandleCreated && control.Controls.IsEmpty);
	}

	private static void VerifyCreation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(400, 250);
		let control = new CustomControl();
		let child = new Button();
		child.Size = .(80, 25);
		control.Controls.Add(child);
		let hidden = new CustomControl();
		hidden.Hide();
		form.Controls.Add(control);
		form.Controls.Add(hidden);
		let order = scope String();
		control.Load.Add(new (sender, args) =>
		{
			Test.Assert(child.Created && child.IsHandleCreated && control.Created && control.IsHandleCreated);
			Test.Assert(control.Loads == 1 && sender == control);
			order.Append('U');
		});
		form.Load.Add(new (sender, args) => order.Append('F'));
		Test.Assert(control.Loads == 0 && hidden.Loads == 0);
		form.Show();
		Test.Assert(order == "UF" && control.Loads == 1 && hidden.Loads == 0);
		control.CreateControl();
		control.Hide();
		control.Show();
		Test.Assert(control.Loads == 1);
		hidden.Show();
		Test.Assert(hidden.Loads == 1 && hidden.Created);
		form.Close();
		Application.Backend.Run(form);
		Test.Assert(control.IsDisposed && child.IsDisposed && hidden.IsDisposed);
	}

	private static void VerifySizing(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let host = scope Control();
		host.Size = .(600, 400);
		let control = new UserControl();
		let child = new Control();
		child.Location = .(10, 15);
		child.Size = .(40, 20);
		control.Controls.Add(child);
		host.Controls.Add(control);
		Test.Assert(control.PreferredSize == .(50, 35));
		control.AutoSize = true;
		Test.Assert(control.Size == .(150, 150));
		control.AutoSizeMode = .GrowAndShrink;
		Test.Assert(control.Size == .(50, 35));
		child.Size = .(220, 170);
		Test.Assert(control.Size == .(230, 185));
		control.BorderStyle = .FixedSingle;
		Test.Assert(control.PreferredSize == .(232, 187) && control.Size == .(232, 187));
		child.Hide();
		Test.Assert(control.Size == .(2, 2));
		control.AutoSize = false;
		Test.Assert(control.Size == .(150, 150));
	}

	private static void VerifyPaintingAndChildEvents(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 240);
		let control = new CustomControl();
		control.Text = "Container metadata, not a caption";
		let button = new Button();
		button.Size = .(80, 25);
		control.Controls.Add(button);
		form.Controls.Add(control);
		int paints = 0, clicks = 0;
		control.Paint.Add(new [&] (sender, args) =>
		{
			Test.Assert(sender == control && !control.NeedsPaint);
			paints++;
		});
		button.Click.Add(new [&] (sender, args) => clicks++);
		form.Show();
		control.Invalidate();
#if BF_DEPENDS_BEEFFORMS_SDL
		if (let sdl = Application.Backend as SDLBackend)
			Test.Assert(sdl.[Friend]RenderIfNeeded());
#endif
#if BF_PLATFORM_WINDOWS
		if (backend == .Win32)
		{
			Win32.UpdateWindow(control.Handle);
			Win32.SendMessage(control.Handle, Win32.WM_COMMAND, null, (int*)button.Handle);
			Test.Assert(clicks == 1);
		}
#endif
		Test.Assert(paints > 0 && control.Paints == paints);
		button.PerformClick();
		Test.Assert(clicks == (backend == .Win32 ? 2 : 1));
		form.Close();
		Application.Backend.Run(form);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeContainerStylesAndBorders()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		let control = new UserControl();
		form.Controls.Add(control);
		form.Show();
		delegate uint(int32) style = scope (index) => (uint)(void*)Win32.GetWindowLongPtr(control.Handle, index);
		Test.Assert((style(Win32.GWL_EXSTYLE) & Win32.WS_EX_CONTROLPARENT) != 0);
		Test.Assert((style(Win32.GWL_STYLE) & Win32.WS_TABSTOP) != 0);
		Test.Assert((style(Win32.GWL_STYLE) & Win32.WS_CHILD) != 0);
		Test.Assert(control.ClientSize == .(150, 150));
		control.BorderStyle = .FixedSingle;
		Test.Assert((style(Win32.GWL_STYLE) & Win32.WS_BORDER) != 0 && control.ClientSize == .(148, 148));
		control.BorderStyle = .Fixed3D;
		Test.Assert((style(Win32.GWL_STYLE) & Win32.WS_BORDER) == 0);
		Test.Assert((style(Win32.GWL_EXSTYLE) & Win32.WS_EX_CLIENTEDGE) != 0);
		control.BorderStyle = .None;
		Test.Assert((style(Win32.GWL_EXSTYLE) & Win32.WS_EX_CLIENTEDGE) == 0 && control.ClientSize == .(150, 150));
		form.Close();
		Application.Backend.Run(form);
	}

	[Test]
	public static void NativeCreationAndLoad()
	{
		VerifyCreation(.Win32);
	}

	[Test]
	public static void NativeContentSizing()
	{
		VerifySizing(.Win32);
	}

	[Test]
	public static void NativePaintingAndChildEvents()
	{
		VerifyPaintingAndChildEvents(.Win32);
	}
#endif

#if BF_DEPENDS_BEEFFORMS_SDL
	[Test]
	public static void SDLCreationAndLoad()
	{
		VerifyCreation(.SDL2OpenGL);
	}

	[Test]
	public static void SDLContentSizing()
	{
		VerifySizing(.SDL2OpenGL);
	}

	[Test]
	public static void SDLPaintingAndChildEvents()
	{
		VerifyPaintingAndChildEvents(.SDL2OpenGL);
	}
#endif
}
