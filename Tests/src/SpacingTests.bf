using System;
using System.Drawing;
using System.Windows.Forms;
using BeefForms.Backends;

namespace BeefForms.Tests;

class SpacingTests
{
	[Test]
	public static void SpacingDefaultsAndNegativeValuesMatchWinForms()
	{
		let control = scope Control();
		Test.Assert(control.Padding == .Empty && control.Margin == Padding(3));
		control.Padding = .(-1, 2, -3, 4);
		control.Margin = .(-1, 2, -3, 4);
		Test.Assert(control.Padding == Padding(0, 2, 0, 4) && control.Margin == control.Padding);
	}

	private static void VerifyLabelPadding(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let label = scope Label();
		label.Text = "A padded label";
		let natural = label.PreferredSize;
		label.Padding = .(5, 7, 11, 13);
		Test.Assert(label.PreferredSize == .(natural.width + 16, natural.height + 20));
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeLabelPreferredSizeIncludesPadding()
	{
		VerifyLabelPadding(.Win32);
	}
#endif
#if BF_DEPENDS_BEEFFORMS_SDL
	[Test]
	public static void SDLLabelPreferredSizeIncludesPadding()
	{
		VerifyLabelPadding(.SDL2OpenGL);
	}
#endif

	[Test]
	public static void ChecklistSpacingSurvivesResizing()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(600, 304);
		table.ColumnCount = 1;
		table.Padding = .(12, 10, 28, 10);
		table.ColumnStyles.Add(.(.Percent, 100));
		for (int32 i < 3)
		{
			let child = new CheckBox();
			child.Size = .(0, 30);
			child.Margin = .(0, 0, 0, 4);
			child.Anchor = .Top | .Left | .Right;
			table.Controls.Add(child);
			Test.Assert(child.Location == .(12, 10 + i * 34) && child.Size == .(560, 30));
		}
		Test.Assert(table.PreferredSize == .(40, 122));
		table.Size = .(800, 304);
		Test.Assert(table.Controls[0].Location == .(12, 10) && table.Controls[0].Size == .(760, 30));
	}

	[Test]
	public static void TableSpansIncludeMarginsAndChangesRelayoutChildren()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(200, 100);
		table.ColumnCount = 2;
		table.Padding = .(5, 7, 11, 13);
		table.ColumnStyles.Add(.(.Percent, 50));
		table.ColumnStyles.Add(.(.Percent, 50));
		let child = new Control();
		child.Size = .(30, 20);
		child.Margin = .(2, 3, 4, 5);
		child.Anchor = .Top | .Left | .Right;
		table.SetColumnSpan(child, 2);
		table.Controls.Add(child);
		Test.Assert(child.Location == .(7, 10) && child.Size == .(178, 20));
		Test.Assert(table.PreferredSize == .(52, 48));
		child.Margin = .(4, 5, 6, 7);
		Test.Assert(child.Location == .(9, 12) && child.Size == .(174, 20));
	}

	[Test]
	public static void FlowWrappingAndReverseDirectionsRespectSpacing()
	{
		let flow = scope FlowLayoutPanel();
		flow.Size = .(100, 100);
		flow.Padding = .(5, 7, 11, 13);
		for (int32 i < 3)
		{
			let child = new Control();
			child.Size = .(30, 20);
			child.Margin = .(2, 3, 4, 5);
			flow.Controls.Add(child);
		}
		Test.Assert(flow.Controls[0].Location == .(7, 10) && flow.Controls[1].Location == .(43, 10));
		Test.Assert(flow.Controls[2].Location == .(7, 38) && flow.PreferredSize == .(124, 48));
		flow.FlowDirection = .RightToLeft;
		Test.Assert(flow.Controls[0].Location == .(55, 10));
		flow.FlowDirection = .BottomUp;
		Test.Assert(flow.Controls[0].Location == .(7, 62));
	}

	[Test]
	public static void PaddingUpdatesAnchorDistancesWithoutChangingClientSize()
	{
		let panel = scope Panel();
		panel.Size = .(200, 100);
		let child = new Control();
		child.Location = .(10, 10);
		child.Size = .(30, 20);
		child.Anchor = .Top | .Bottom | .Left | .Right;
		panel.Controls.Add(child);
		panel.Padding = .(5, 7, 11, 13);
		Test.Assert(child.Location == .(15, 17) && child.Size == .(14, 0));
		Test.Assert(panel.ClientSize == .(200, 100) && panel.DisplayRectangle == Rectangle(5, 7, 184, 80));
		panel.Size = .(250, 150);
		Test.Assert(child.Location == .(15, 17) && child.Size == .(64, 50));
	}

	[Test]
	public static void MarginChangesResizeNestedAutoSizedPanelsImmediately()
	{
		let host = scope Panel();
		host.Size = .(1000, 800);
		let outer = new Panel();
		outer.AutoSizeMode = .GrowAndShrink;
		outer.AutoSize = true;
		let inner = new Panel();
		inner.Margin = .Empty;
		inner.AutoSizeMode = .GrowAndShrink;
		inner.AutoSize = true;
		let child = new Control();
		child.Size = .(50, 20);
		child.Margin = .Empty;
		inner.Controls.Add(child);
		outer.Controls.Add(inner);
		host.Controls.Add(outer);
		Test.Assert(inner.Size == .(50, 20) && outer.Size == .(50, 20));
		child.Margin = .(0, 0, 10, 15);
		Test.Assert(inner.Size == .(60, 35) && outer.Size == .(60, 35));
		child.Margin = .Empty;
		Test.Assert(inner.Size == .(50, 20) && outer.Size == .(50, 20));
	}

	private static void VerifyOrdinaryPanelScrollMargins(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let panel = scope Panel();
		panel.Size = .(100, 50);
		panel.AutoScroll = true;
		let child = new Control();
		child.Size = .(50, 60);
		child.Margin = .(0, 0, 0, 20);
		panel.Controls.Add(child);
		panel.ScrollPosition = .(0, 1000);
		Test.Assert(panel.PreferredSize == .(50, 80));
		Test.Assert(panel.ScrollPosition.y == 10);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeOrdinaryPanelScrollExtentsExcludeChildMarginsLikeWinForms()
	{
		VerifyOrdinaryPanelScrollMargins(.Win32);
	}
#endif
#if BF_DEPENDS_BEEFFORMS_SDL
	[Test]
	public static void SDLOrdinaryPanelScrollExtentsExcludeChildMarginsLikeWinForms()
	{
		VerifyOrdinaryPanelScrollMargins(.SDL2OpenGL);
	}
#endif

	[Test]
	public static void ScrollingIncludesTheFinalMarginAndPadding()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(200, 60);
		table.Padding = .(12, 10, 28, 10);
		table.ColumnCount = 1;
		table.ColumnStyles.Add(.(.Percent, 100));
		table.AutoScroll = true;
		for (int32 i < 3)
		{
			let child = new Control();
			child.Size = .(0, 30);
			child.Margin = .(0, 0, 0, 4);
			child.Anchor = .Top | .Left | .Right;
			table.Controls.Add(child);
		}
		table.ScrollPosition = .(0, 1000);
		Test.Assert(table.VerticalScrollVisible && !table.HorizontalScrollVisible);
		Test.Assert(table.ScrollPosition.y == 62);
	}
}
