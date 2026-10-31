using System;
using System.Drawing;
using System.Windows.Forms;

namespace BeefForms.Tests;

class TableLayoutTests
{
	private static Control Add(TableLayoutPanel table, Size size)
	{
		let child = new Control();
		child.Margin = .Empty;
		child.Size = size;
		child.Anchor = .Top | .Left | .Right;
		table.Controls.Add(child);
		return child;
	}

	[Test]
	public static void CollidingCellRequestsMoveToAvailableCells()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(100, 60);
		table.ColumnCount = 2;
		table.RowCount = 2;
		table.GrowStyle = .FixedSize;
		table.ColumnStyles.Add(.(.Absolute, 50));
		table.RowStyles.Add(.(.Absolute, 30));
		let first = new Control();
		first.Margin = .Empty;
		let second = new Control();
		second.Margin = .Empty;
		table.SetCellPosition(first, .(0, 0));
		table.SetCellPosition(second, .(0, 0));
		table.Controls.Add(first);
		table.Controls.Add(second);
		let automatic = Add(table, .(10, 10));
		Test.Assert(second.Location == .(0, 0) && first.Location == .(50, 0));
		Test.Assert(automatic.Location == .(0, 30));
		Test.Assert(table.GetCellPosition(first) == .(0, 0));
	}

	[Test]
	public static void ExtraStylesDoNotCreateColumnsOrRows()
	{
		let table = scope TableLayoutPanel();
		table.ColumnCount = 2;
		for (int i < 3)
			table.ColumnStyles.Add(.(.Absolute, 50));
		Add(table, .(10, 20));
		Add(table, .(10, 20));
		let third = Add(table, .(10, 20));
		Test.Assert(third.Location == .(0, 20));

		let sideways = scope TableLayoutPanel();
		sideways.RowCount = 2;
		sideways.GrowStyle = .AddColumns;
		for (int i < 3)
			sideways.RowStyles.Add(.(.Absolute, 30));
		Add(sideways, .(10, 20));
		let second = Add(sideways, .(10, 20));
		let last = Add(sideways, .(10, 20));
		Test.Assert(second.Location == .(10, 0) && last.Location == .(0, 30));
	}

	[Test]
	public static void SpansAreClippedToTheBoundedDimension()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(200, 100);
		table.ColumnCount = 2;
		let wide = new Control();
		wide.Margin = .Empty;
		wide.Size = .(20, 20);
		wide.Anchor = .Top | .Left | .Right;
		table.SetCellPosition(wide, .(0, 0));
		table.SetColumnSpan(wide, 3);
		table.Controls.Add(wide);
		let below = Add(table, .(20, 20));
		Test.Assert(wide.Size.width == 200 && below.Location == .(0, 20));
		Test.Assert(table.GetColumnSpan(wide) == 3);

		let sideways = scope TableLayoutPanel();
		sideways.Size = .(200, 100);
		sideways.RowCount = 2;
		sideways.GrowStyle = .AddColumns;
		let tall = new Control();
		tall.Margin = .Empty;
		tall.Size = .(20, 20);
		tall.Anchor = .Top | .Bottom | .Left;
		sideways.SetCellPosition(tall, .(0, 0));
		sideways.SetRowSpan(tall, 3);
		sideways.Controls.Add(tall);
		let beside = Add(sideways, .(20, 20));
		Test.Assert(tall.Size.height == 100 && beside.Location == .(20, 0));
		Test.Assert(sideways.GetRowSpan(tall) == 3);
	}

	[Test]
	public static void FinalAbsoluteTracksReceiveUnusedSpaceLikeWinForms()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(400, 200);
		table.ColumnCount = 2;
		table.RowCount = 2;
		table.ColumnStyles.Add(.(.Absolute, 50));
		table.ColumnStyles.Add(.(.Absolute, 50));
		table.RowStyles.Add(.(.Absolute, 50));
		table.RowStyles.Add(.(.Absolute, 50));
		for (int i < 4)
		{
			let child = Add(table, .(10, 10));
			child.Anchor = .Top | .Bottom | .Left | .Right;
		}
		Test.Assert(table.Controls[0].Size == .(50, 50));
		Test.Assert(table.Controls[1].Size == .(350, 50));
		Test.Assert(table.Controls[2].Size == .(50, 150));
		Test.Assert(table.PreferredSize == .(100, 100));
	}

	[Test]
	public static void PercentageSpansDistributeTheirInitialRequirementsAcrossTracks()
	{
		for (let firstWeight in scope float[](50, 25))
		{
			let table = scope TableLayoutPanel();
			table.Size = .(400, 200);
			table.ColumnCount = 2;
			table.ColumnStyles.Add(.(.Percent, firstWeight));
			table.ColumnStyles.Add(.(.Percent, 100 - firstWeight));
			let child = new Control();
			child.Margin = .Empty;
			child.Size = .(200, 20);
			table.SetColumnSpan(child, 2);
			table.Controls.Add(child);
			Test.Assert(table.PreferredSize == .(firstWeight == 50 ? 200 : 400, 20));
		}
	}

	[Test]
	public static void PercentageRowSpansDoNotDoubleThePreferredHeight()
	{
		let table = scope TableLayoutPanel();
		table.RowCount = 2;
		table.RowStyles.Add(.(.Percent, 50));
		table.RowStyles.Add(.(.Percent, 50));
		let child = new Control();
		child.Margin = .Empty;
		child.Size = .(20, 200);
		table.SetRowSpan(child, 2);
		table.Controls.Add(child);
		Test.Assert(table.PreferredSize == .(20, 200));
	}

	[Test]
	public static void AnchoredTablesMeasureWrappingRowsUsingTheProposedWidth()
	{
		let host = scope Panel();
		host.Size = .(500, 500);
		let table = new TableLayoutPanel();
		table.Size = .(400, 200);
		table.ColumnCount = 1;
		table.ColumnStyles.Add(.(.Percent, 100));
		table.Anchor = .Top | .Left | .Right;
		host.Controls.Add(table);
		let child = new WrappingControl();
		child.Margin = .Empty;
		child.AutoSizeMode = .GrowAndShrink;
		child.AutoSize = true;
		table.Controls.Add(child);
		let bounds = child.Size;
		Test.Assert(table.GetPreferredSize(.(100, 0)) == .(100, 60));
		Test.Assert(table.GetPreferredSize(.(240, 0)) == .(240, 20));
		Test.Assert(child.Size == bounds);
	}

	private static void AddToFixedTable(TableLayoutPanelCellPosition position, int32 columnSpan = 1, int32 rowSpan = 1)
	{
		let table = scope TableLayoutPanel();
		table.ColumnCount = 1;
		table.RowCount = 1;
		table.GrowStyle = .FixedSize;
		let child = new Control();
		child.Margin = .Empty;
		table.SetCellPosition(child, position);
		table.SetColumnSpan(child, columnSpan);
		table.SetRowSpan(child, rowSpan);
		table.Controls.Add(child);
	}

	[Test(ShouldFail = true)]
	public static void FixedSizeRejectsOutOfRangeColumns()
	{
		AddToFixedTable(.(3, 0));
	}
	[Test(ShouldFail = true)]
	public static void FixedSizeRejectsOutOfRangeRows()
	{
		AddToFixedTable(.(0, 3));
	}
	[Test(ShouldFail = true)]
	public static void FixedSizeRejectsColumnSpansBeyondItsBounds()
	{
		AddToFixedTable(.(0, 0), 2);
	}
	[Test(ShouldFail = true)]
	public static void FixedSizeRejectsRowSpansBeyondItsBounds()
	{
		AddToFixedTable(.(0, 0), 1, 2);
	}

	[Test]
	public static void CellSettingsFollowTheChildWhenItMovesBetweenTables()
	{
		let first = scope TableLayoutPanel();
		let second = scope TableLayoutPanel();
		let child = new Control();
		child.Margin = .Empty;
		first.SetCellPosition(child, .(1, 2));
		first.SetColumnSpan(child, 2);
		first.SetRowSpan(child, 3);
		first.Controls.Add(child);
		second.Controls.Add(child);
		Test.Assert(first.Controls.IsEmpty && child.Parent == second);
		Test.Assert(second.GetCellPosition(child) == .(1, 2));
		Test.Assert(second.GetColumnSpan(child) == 2 && second.GetRowSpan(child) == 3);
		let other = new Control();
		other.Margin = .Empty;
		second.Controls.Add(other);
		Test.Assert(second.GetCellPosition(other) == .(-1, -1));
		Test.Assert(second.GetColumnSpan(other) == 1 && second.GetRowSpan(other) == 1);
	}

	[Test]
	public static void PercentageColumnsResizeWithoutChangingRequestedSizes()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(400, 200);
		table.ColumnCount = 2;
		table.ColumnStyles.Add(.(.Percent, 25));
		table.ColumnStyles.Add(.(.Percent, 75));
		let first = Add(table, .(30, 20));
		let second = Add(table, .(60, 40));
		let third = Add(table, .(50, 30));
		Test.Assert(first.Size == .(100, 20) && second.Location == .(100, 0) && second.Size == .(300, 40));
		Test.Assert(third.Location == .(0, 40));
		table.Size = .(800, 200);
		Test.Assert(first.Size.width == 200 && second.Size.width == 600);
		Test.Assert(table.PreferredSize == .(200, 70));
		table.Size = .(400, 200);
		Test.Assert(first.Size.width == 100 && table.PreferredSize == .(200, 70));
	}

	[Test]
	public static void AbsoluteAndAutoColumnsAndSpansContributeToMeasurement()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(400, 200);
		table.ColumnCount = 2;
		table.ColumnStyles.Add(.(.Absolute, 80));
		table.ColumnStyles.Add(.(.AutoSize));
		let first = Add(table, .(30, 20));
		let second = Add(table, .(60, 40));
		let wide = new Control();
		wide.Margin = .Empty;
		wide.Size = .(200, 30);
		wide.Anchor = .Top | .Left | .Right;
		table.SetCellPosition(wide, .(0, 1));
		table.SetColumnSpan(wide, 2);
		table.Controls.Add(wide);
		Test.Assert(first.Size.width == 80 && second.Location.x == 80 && second.Size.width == 320);
		Test.Assert(wide.Location == .(0, 40) && wide.Size == .(400, 30));
		Test.Assert(table.PreferredSize == .(200, 70));
		table.ColumnStyles[0] = .(.Absolute, 100);
		Test.Assert(second.Location.x == 100 && second.Size.width == 300);
	}

	[Test]
	public static void RowSpansAndCellAnchoringUseTheAllocatedRectangle()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(400, 200);
		table.ColumnCount = 2;
		table.ColumnStyles.Add(.(.Percent, 50));
		table.ColumnStyles.Add(.(.Percent, 50));
		table.RowStyles.Add(.(.Absolute, 30));
		table.RowStyles.Add(.(.Percent, 100));
		let tall = new Control();
		tall.Margin = .Empty;
		tall.Size = .(50, 120);
		tall.Anchor = .Top | .Bottom | .Left | .Right;
		table.SetCellPosition(tall, .(0, 0));
		table.SetRowSpan(tall, 2);
		table.Controls.Add(tall);
		let top = Add(table, .(20, 10));
		let bottom = Add(table, .(20, 10));
		bottom.Anchor = .Right | .Bottom;
		Test.Assert(tall.Size == .(200, 200));
		Test.Assert(top.Location == .(200, 0));
		Test.Assert(bottom.Location == .(380, 190) && bottom.Size == .(20, 10));
	}

	[Test]
	public static void GrowthAndExplicitCellsReserveSpaceBeforeAutomaticPlacement()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(200, 100);
		table.RowCount = 2;
		table.GrowStyle = .AddColumns;
		let first = Add(table, .(30, 20));
		let second = Add(table, .(40, 30));
		let third = Add(table, .(50, 10));
		Test.Assert(second.Location == .(50, 0) && third.Location == .(0, 30));
		table.SuspendLayout();
		table.SetCellPosition(third, .(0, 0));
		table.ResumeLayout(true);
		Test.Assert(third.Location == .(0, 0) && first.Location == .(50, 0) && second.Location == .(0, 20));
		third.Hide();
		Test.Assert(first.Location == .(0, 0) && second.Location == .(0, 20));
		table.Controls.Remove(first);
		delete first;
		Test.Assert(second.Location == .(0, 0));
	}

	private class WrappingControl : Panel
	{
		public override Size GetPreferredSize(Size proposedSize)
		{
			let width = proposedSize.width > 0 ? Math.Min(240, proposedSize.width) : 240;
			return .(width, ((240 + width - 1) / width) * 20);
		}
	}

	[Test]
	public static void AutomaticRowsMeasureUsingTheirAllocatedColumnWidth()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(100, 100);
		table.ColumnStyles.Add(.(.Percent, 100));
		let child = new WrappingControl();
		child.Margin = .Empty;
		child.AutoSizeMode = .GrowAndShrink;
		child.AutoSize = true;
		child.Anchor = .Top | .Left | .Right;
		table.Controls.Add(child);
		Test.Assert(child.Size == .(100, 60));
		table.Size = .(200, 100);
		Test.Assert(child.Size == .(200, 40));
		Test.Assert(table.PreferredSize == .(240, 20) && child.Size == .(200, 40));
	}

	[Test]
	public static void ScrollingAndRemovingRowsKeepTheColumnFitted()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(200, 60);
		table.AutoScroll = true;
		table.ColumnStyles.Add(.(.Percent, 100));
		Add(table, .(20, 30));
		Add(table, .(20, 30));
		let last = Add(table, .(20, 30));
		Test.Assert(table.VerticalScrollVisible && !table.HorizontalScrollVisible);
		Test.Assert(last.Location == .(0, 60));
		table.ScrollPosition = .(0, 30);
		table.Controls.Remove(last);
		delete last;
		Test.Assert(!table.VerticalScrollVisible && table.ScrollPosition.y == 0);
		Test.Assert(table.Controls[0].Size.width == 200);
	}

	[Test]
	public static void LayoutCallbacksCanAddAnotherRow()
	{
		let table = scope TableLayoutPanel();
		table.Size = .(200, 100);
		table.ColumnStyles.Add(.(.Percent, 100));
		let first = Add(table, .(20, 30));
		bool added = false;
		first.SizeChanged.Add(new [&] (sender, args) =>
		{
			if (!added)
			{
				added = true;
				Add(table, .(20, 40));
			}
		});
		table.Size = .(300, 100);
		Test.Assert(table.Controls.Count == 2 && table.Controls[1].Location == .(0, 30));
		Test.Assert(table.Controls[1].Size.width == 300);
	}
}
