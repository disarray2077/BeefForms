using System;
using System.Drawing;
using System.Windows;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class FlowLayoutTests
{
	private static FlowLayoutPanel CreatePanel()
	{
		let panel = new FlowLayoutPanel();
		panel.Margin = .Empty;
		panel.Size = .(100, 45);
		for (let size in scope Size[](.(60, 20), .(50, 30), .(40, 10)))
		{
			let child = new Control();
			child.Margin = .Empty;
			child.Size = size;
			panel.Controls.Add(child);
		}
		return panel;
	}

	private static void VerifyDirections(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 200);
		let panel = CreatePanel();
		form.Controls.Add(panel);
		Test.Assert(panel.FlowDirection == .LeftToRight && panel.WrapContents);
		form.Show();
		for (let direction in scope FlowDirection[](.LeftToRight, .TopDown, .RightToLeft, .BottomUp))
		{
			for (let wrap in scope bool[](false, true))
			{
				panel.FlowDirection = direction;
				panel.WrapContents = wrap;
				Point[3] expected = default;
				switch (direction)
				{
				case .LeftToRight:
					expected = wrap ? .(.(0, 0), .(0, 20), .(50, 20)) : .(.(0, 0), .(60, 0), .(110, 0));
				case .TopDown:
					expected = wrap ? .(.(0, 0), .(60, 0), .(60, 30)) : .(.(0, 0), .(0, 20), .(0, 50));
				case .RightToLeft:
					expected = wrap ? .(.(40, 0), .(50, 20), .(10, 20)) : .(.(40, 0), .(-10, 0), .(-50, 0));
				case .BottomUp:
					expected = wrap ? .(.(0, 25), .(60, 15), .(60, 5)) : .(.(0, 25), .(0, -5), .(0, -15));
				}
				for (int i < 3)
				{
					Test.Assert(panel.Controls[i].Location == expected[i]);
					Test.Assert(panel.Controls[i].IsHandleCreated);
				}
			}
		}
		form.Close();
		Application.Backend.Run(form);
	}

	private static void VerifyReflow(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let panel = CreatePanel();
		defer delete panel;
		let first = panel.Controls[0];
		let second = panel.Controls[1];
		let third = panel.Controls[2];
		panel.Size = .(150, 45);
		Test.Assert(third.Location == .(110, 0));
		panel.Size = .(149, 45);
		Test.Assert(third.Location == .(0, 30));
		panel.SuspendLayout();
		panel.FlowDirection = .TopDown;
		panel.WrapContents = false;
		first.Size = .(20, 10);
		third.Hide();
		panel.ResumeLayout(false);
		Test.Assert(second.Location == .(60, 0));
		panel.PerformLayout();
		Test.Assert(second.Location == .(0, 10));
		third.Show();
		Test.Assert(third.Location == .(0, 40));
		panel.WrapContents = true;
		Test.Assert(third.Location == .(50, 0));
		panel.Controls.Remove(second);
		defer delete second;
		Test.Assert(third.Location == .(0, 10));
		panel.Hide();
		panel.PerformLayout();
		Test.Assert(third.Location == .(0, 10));
	}

	private static void VerifyMeasurement(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let panel = CreatePanel();
		defer delete panel;
		let second = panel.Controls[1].Location;
		Test.Assert(panel.PreferredSize == .(150, 30));
		Test.Assert(panel.GetPreferredSize(.(100, 45)) == .(90, 50));
		Test.Assert(panel.Controls[1].Location == second && !panel.IsHandleCreated);
		panel.WrapContents = false;
		Test.Assert(panel.GetPreferredSize(.(100, 45)) == .(150, 30));
		panel.FlowDirection = .TopDown;
		Test.Assert(panel.PreferredSize == .(60, 60));
		panel.WrapContents = true;
		Test.Assert(panel.GetPreferredSize(.(100, 45)) == .(110, 40));
		panel.BorderStyle = .FixedSingle;
		Test.Assert(panel.PreferredSize == .(62, 62));
	}

	private static void VerifyNestedAutoSize(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let outer = scope FlowLayoutPanel();
		outer.Size = .(200, 150);
		outer.FlowDirection = .TopDown;
		outer.WrapContents = false;
		let inner = new FlowLayoutPanel();
		inner.Margin = .Empty;
		inner.AutoSizeMode = .GrowAndShrink;
		inner.AutoSize = true;
		let first = new Control();
		first.Margin = .Empty;
		first.Size = .(20, 10);
		let second = new Control();
		second.Margin = .Empty;
		second.Size = .(30, 15);
		inner.Controls.Add(first);
		inner.Controls.Add(second);
		outer.Controls.Add(inner);
		let next = new Control();
		next.Margin = .Empty;
		next.Size = .(20, 20);
		outer.Controls.Add(next);
		Test.Assert(inner.Size == .(50, 15) && second.Location == .(20, 0) && next.Location == .(0, 15));
		first.Size = .(40, 25);
		Test.Assert(inner.Size == .(70, 25) && second.Location == .(40, 0) && next.Location == .(0, 25));
		first.Hide();
		Test.Assert(inner.Size == .(30, 15) && second.Location == .(0, 0) && next.Location == .(0, 15));
	}

	private static void VerifyScrolling(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 200);
		let panel = new FlowLayoutPanel();
		panel.Margin = .Empty;
		panel.Size = .(100, 60);
		panel.FlowDirection = .TopDown;
		panel.WrapContents = false;
		panel.AutoScroll = true;
		for (int i < 3)
		{
			let child = new Control();
			child.Margin = .Empty;
			child.Size = .(60, 40);
			panel.Controls.Add(child);
		}
		form.Controls.Add(panel);
		form.Show();
		Test.Assert(panel.VerticalScrollVisible && !panel.HorizontalScrollVisible);
		Test.Assert(panel.Controls[2].Location == .(0, 80));
		panel.ScrollPosition = .(0, 60);
		Test.Assert(panel.ScrollPosition.y == 60 && panel.Controls[2].Location == .(0, 80));
		while (!panel.Controls.IsEmpty)
			delete panel.Controls[0];
		panel.SuspendLayout();
		panel.Size = .(100, 45);
		panel.FlowDirection = .LeftToRight;
		panel.WrapContents = true;
		for (let size in scope Size[](.(60, 20), .(50, 30), .(40, 10)))
		{
			let child = new Control();
			child.Margin = .Empty;
			child.Size = size;
			panel.Controls.Add(child);
		}
		panel.ResumeLayout(true);
		Test.Assert(panel.VerticalScrollVisible && !panel.HorizontalScrollVisible);
		Test.Assert(panel.Controls[1].Location == .(0, 20) && panel.Controls[2].Location == .(0, 50));
		form.Close();
		Application.Backend.Run(form);
	}

	private static void VerifyMutations(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let panel = CreatePanel();
		defer delete panel;
		let first = panel.Controls[0];
		let second = panel.Controls[1];
		let third = panel.Controls[2];
		bool changed = false;
		first.LocationChanged.Add(new [&] (sender, args) =>
		{
			if (changed)
				return;
			changed = true;
			delete second;
			panel.FlowDirection = .TopDown;
		});
		panel.FlowDirection = .RightToLeft;
		Test.Assert(changed && panel.Controls.Count == 2 && panel.FlowDirection == .TopDown);
		Test.Assert(first.Location == .(0, 0) && third.Location == .(0, 20));
		first.Size = .(120, 20);
		panel.FlowDirection = .LeftToRight;
		Test.Assert(first.Location == .(0, 0) && third.Location == .(0, 20));
	}

	[Test(ShouldFail = true)]
	public static void InvalidDirectionIsRejected()
	{
		let panel = scope FlowLayoutPanel();
		panel.FlowDirection = (FlowDirection)4;
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeFlowDirectionsAndWrapping()
	{
		VerifyDirections(.Win32);
	}
	[Test]
	public static void NativeReflowAndSuspension()
	{
		VerifyReflow(.Win32);
	}
	[Test]
	public static void NativeFlowPreferredSize()
	{
		VerifyMeasurement(.Win32);
	}
	[Test]
	public static void NativeNestedFlowAutoSize()
	{
		VerifyNestedAutoSize(.Win32);
	}
	[Test]
	public static void NativeFlowScrolling()
	{
		VerifyScrolling(.Win32);
	}
	[Test]
	public static void NativeFlowCallbackMutations()
	{
		VerifyMutations(.Win32);
	}
#endif

#if BF_DEPENDS_BEEFFORMS_SDL
	[Test]
	public static void SDLFlowDirectionsAndWrapping()
	{
		VerifyDirections(.SDL2OpenGL);
	}
	[Test]
	public static void SDLReflowAndSuspension()
	{
		VerifyReflow(.SDL2OpenGL);
	}
	[Test]
	public static void SDLFlowPreferredSize()
	{
		VerifyMeasurement(.SDL2OpenGL);
	}
	[Test]
	public static void SDLNestedFlowAutoSize()
	{
		VerifyNestedAutoSize(.SDL2OpenGL);
	}
	[Test]
	public static void SDLFlowScrolling()
	{
		VerifyScrolling(.SDL2OpenGL);
	}
	[Test]
	public static void SDLFlowCallbackMutations()
	{
		VerifyMutations(.SDL2OpenGL);
	}
#endif
}
