using System.Collections;
using System.Drawing;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public enum TableLayoutPanelGrowStyle
{
	FixedSize,
	AddRows,
	AddColumns
}

public struct TableLayoutPanelCellPosition : this(int32 Column, int32 Row);

public class TableLayoutPanel : Panel
{
	protected internal override bool SupportsChildAnchoring => false;

	private class LayoutInfo
	{
		public TableLayoutPanelCellPosition Position = .(-1, -1);
		public int32 ColumnSpan = 1;
		public int32 RowSpan = 1;
	}

	private struct Cell : this(Control Child, int32 Column, int32 Row, int32 Columns, int32 Rows);

	private struct Track
	{
		public SizeType Kind;
		public float Value;
		public int32 Size;
		public int32 Offset;
	}

	private int32 mColumnCount, mRowCount;
	private TableLayoutPanelGrowStyle mGrowStyle = .AddRows;
	private bool mArranging, mLayoutRequested;
	public readonly TableLayoutStyleCollection<ColumnStyle> ColumnStyles ~ delete _;
	public readonly TableLayoutStyleCollection<RowStyle> RowStyles ~ delete _;

	public this()
	{
		ColumnStyles = new .(this);
		RowStyles = new .(this);
	}

	public int32 ColumnCount
	{
		get => mColumnCount;
		set
		{
			if (value < 0)
				Runtime.FatalError("ColumnCount must not be negative");
			mColumnCount = value;
			PerformLayout();
		}
	}
	public int32 RowCount
	{
		get => mRowCount;
		set
		{
			if (value < 0)
				Runtime.FatalError("RowCount must not be negative");
			mRowCount = value;
			PerformLayout();
		}
	}
	public TableLayoutPanelGrowStyle GrowStyle
	{
		get => mGrowStyle;
		set
		{
			if ((uint)value > (uint)TableLayoutPanelGrowStyle.AddColumns)
				Runtime.FatalError("GrowStyle must be a valid table growth direction");
			mGrowStyle = value;
			PerformLayout();
		}
	}

	public TableLayoutPanelCellPosition GetCellPosition(Control child)
		=> GetLayoutInfo(child).Position;

	public void SetCellPosition(Control child, TableLayoutPanelCellPosition position)
	{
		if (position.Column < -1 || position.Row < -1)
			Runtime.FatalError("Cell coordinates must be -1 or nonnegative");
		GetLayoutInfo(child).Position = position;
		PerformLayout();
	}

	public int32 GetColumn(Control child)
		=> GetLayoutInfo(child).Position.Column;

	public void SetColumn(Control child, int32 column)
	{
		SetCellPosition(child, .(column, GetLayoutInfo(child).Position.Row));
	}

	public int32 GetRow(Control child)
		=> GetLayoutInfo(child).Position.Row;

	public void SetRow(Control child, int32 row)
	{
		SetCellPosition(child, .(GetLayoutInfo(child).Position.Column, row));
	}

	public int32 GetColumnSpan(Control child)
		=> GetLayoutInfo(child).ColumnSpan;

	public void SetColumnSpan(Control child, int32 span)
	{
		if (span < 1)
			Runtime.FatalError("Column span must be positive");
		GetLayoutInfo(child).ColumnSpan = span;
		PerformLayout();
	}

	public int32 GetRowSpan(Control child)
		=> GetLayoutInfo(child).RowSpan;

	public void SetRowSpan(Control child, int32 span)
	{
		if (span < 1)
			Runtime.FatalError("Row span must be positive");
		GetLayoutInfo(child).RowSpan = span;
		PerformLayout();
	}

	public override void PerformLayout()
	{
		if (LayoutSuspended)
		{
			base.PerformLayout();
			return;
		}
		if (mArranging)
		{
			mLayoutRequested = true;
			return;
		}
		mArranging = true;
		defer { mArranging = false; }
		for (int pass < MaxLayoutPasses)
		{
			mLayoutRequested = false;
			let viewport = ViewportSize;
			base.PerformLayout();
			if (IsDisposingOrDisposed || (!mLayoutRequested && ViewportSize == viewport))
				break;
		}
	}

	protected internal override void ChildBoundsChanged()
	{
		PerformLayout();
	}

	protected override void LayoutChildren()
	{
		LayoutTable(Padding.SubtractFrom(ViewportSize), true);
	}

	public override Size GetPreferredSize(Size proposedSize)
	{
		if (IsDisposingOrDisposed)
			return Size;
		let border = BorderWidth * 2;
		let content = LayoutTable(.(Math.Max(0, proposedSize.width - border - Padding.Horizontal), Math.Max(0, proposedSize.height - border - Padding.Vertical)), false);
		return .(content.width + border + Padding.Horizontal, content.height + border + Padding.Vertical);
	}

	private static LayoutInfo GetLayoutInfo(Control child)
	{
		if (child.mLayoutData == null)
			child.mLayoutData = new LayoutInfo();
		return (LayoutInfo)child.mLayoutData;
	}

	private static Size GetElementSize(Control child, Size proposedSize)
		=> child.AutoSize && !child.SelfAutoSize ? child.GetAutoSize(proposedSize, child.SpecifiedSize) : child.SpecifiedSize;

	private static bool IsFree(List<Cell> placed, Cell proposed)
	{
		for (let cell in placed)
		{
			if (proposed.Column < cell.Column + cell.Columns && cell.Column < proposed.Column + proposed.Columns &&
				proposed.Row < cell.Row + cell.Rows && cell.Row < proposed.Row + proposed.Rows)
				return false;
		}
		return true;
	}

	private static Cell AdvanceCell(List<Cell> placed, Cell cell, int32 columns)
	{
		var cell;
		while (true)
		{
			if (cell.Column + cell.Columns > columns && cell.Column > 0)
			{
				cell.Column = 0;
				cell.Row++;
			}
			// Only earlier rows' spans are reserved; later rows are assigned as the cursor advances.
			let occupied = Cell(cell.Child, cell.Column, cell.Row, Math.Min(cell.Columns, columns), 1);
			if (IsFree(placed, occupied))
				return cell;
			cell.Column++;
		}
	}

	private static bool TryPlaceCells(List<Cell> cells, List<int> fixedCells, List<int> flowCells,
		int32 columns, int32 maximumRows, out int32 usedRows)
	{
		List<Cell> placed = scope .();
		List<int> order = scope .();
		int fixedIndex = 0, flowIndex = 0;
		int32 column = 0, row = 0;
		usedRows = 0;
		while (fixedIndex < fixedCells.Count || flowIndex < flowCells.Count)
		{
			Cell next = default;
			let hasFixed = fixedIndex < fixedCells.Count;
			let hasFlow = flowIndex < flowCells.Count;
			let requested = hasFixed ? cells[fixedCells[fixedIndex]] : default(Cell);
			if (hasFlow)
			{
				next = cells[flowCells[flowIndex]];
				next.Column = column;
				next.Row = row;
				next = AdvanceCell(placed, next, columns);
			}
			let flowFitsBeforeFixed = hasFlow && (!hasFixed ||
				((next.Row < requested.Row ||
				(next.Row == requested.Row && next.Column + Math.Min(next.Columns, columns) <= requested.Column)) &&
				requested.Row >= row && IsFree(placed, requested)));
			int index;
			if (flowFitsBeforeFixed)
				index = flowCells[flowIndex++];
			else
			{
				index = fixedCells[fixedIndex++];
				next = requested;
				if (column >= columns)
				{
					column = 0;
					row++;
				}
				next.Column = Math.Min(next.Column, columns - 1);
				next.Row = Math.Min(next.Row, maximumRows - 1);
				if (row > next.Row)
					next.Column = column;
				else if (row == next.Row)
					next.Column = Math.Max(next.Column, column);
				next.Row = Math.Max(next.Row, row);
				next = AdvanceCell(placed, next, columns);
			}
			if (next.Row >= maximumRows)
				return false;
			next.Columns = Math.Min(next.Columns, columns - next.Column);
			next.Rows = Math.Min(next.Rows, maximumRows - next.Row);
			placed.Add(next);
			order.Add(index);
			column = next.Column + next.Columns;
			row = next.Row;
			usedRows = Math.Max(usedRows, row + next.Rows);
		}
		for (let cell in placed)
			cells[order[@cell.Index]] = cell;
		return true;
	}

	private void PlaceCells(List<Cell> cells, out int32 columns, out int32 rows)
	{
		List<int> fixedCells = scope .();
		List<int> flowCells = scope .();
		int64 requiredCells = 0;
		int32 minimumColumns = 0, minimumRows = 0;
		for (let cell in cells)
		{
			requiredCells += (int64)cell.Columns * cell.Rows;
			if (cell.Column >= 0 && cell.Row >= 0)
			{
				fixedCells.Add(@cell.Index);
				minimumColumns = Math.Max(minimumColumns, cell.Column + cell.Columns);
				minimumRows = Math.Max(minimumRows, cell.Row + cell.Rows);
			}
			else
				flowCells.Add(@cell.Index);
		}
		fixedCells.Sort(scope (a, b) =>
		{
			let first = cells[a];
			let second = cells[b];
			if (first.Row != second.Row)
				return first.Row <=> second.Row;
			if (first.Column != second.Column)
				return first.Column <=> second.Column;
			// Resolve equal requests deterministically, with later controls first.
			return b <=> a;
		});
		if (mGrowStyle == .FixedSize && (requiredCells > (int64)mColumnCount * mRowCount ||
			minimumColumns > mColumnCount || minimumRows > mRowCount))
			Runtime.FatalError("Table cannot expand when GrowStyle is FixedSize");
		let boundedRows = mGrowStyle != .AddRows && mRowCount > 0;
		rows = Math.Max(1, mRowCount);
		if (mGrowStyle == .AddColumns && boundedRows)
			columns = Math.Max(minimumColumns, (int32)((requiredCells + rows - 1) / rows));
		else if (mGrowStyle == .AddColumns)
			columns = minimumColumns;
		else
			columns = mColumnCount > 0 ? mColumnCount : minimumColumns;
		columns = Math.Max(1, columns);
		int32 usedRows;
		while (!TryPlaceCells(cells, fixedCells, flowCells, columns, boundedRows ? rows : int32.MaxValue, out usedRows))
		{
			if (mGrowStyle != .AddColumns)
				Runtime.FatalError("Table cannot expand when GrowStyle is FixedSize");
			columns++;
		}
		rows = Math.Max(rows, usedRows);
		if (mGrowStyle == .AddColumns)
			columns = Math.Max(columns, mColumnCount);
	}

	private static Track MakeTrack(SizeType kind, float value)
	{
		if ((uint)kind > (uint)SizeType.Percent || value < 0 || value.IsNaN || value.IsInfinity)
			Runtime.FatalError("Table track sizes must be finite and nonnegative");
		return .() { Kind = kind, Value = value, Size = kind == .Absolute ? (int32)value : 0 };
	}

	private static int32 TrackExtent(Span<Track> tracks, int start, int count)
	{
		int32 size = 0;
		for (int i = start; i < start + count; i++)
			size += tracks[i].Size;
		return size;
	}

	private static void RequireSpace(Span<Track> tracks, int start, int count, int32 size)
	{
		let extra = size - TrackExtent(tracks, start, count);
		if (extra <= 0)
			return;
		int32 uninitialized = 0;
		for (int i = start; i < start + count; i++)
		{
			if (tracks[i].Kind != .Absolute && tracks[i].Size == 0)
				uninitialized++;
		}
		if (uninitialized > 0)
		{
			// WinForms shares a span's deficit among its uninitialized non-absolute tracks.
			let average = extra / uninitialized;
			var remaining = extra;
			for (int i = start; i < start + count; i++)
			{
				if (tracks[i].Kind != .Absolute && tracks[i].Size == 0)
				{
					tracks[i].Size = --uninitialized == 0 ? remaining : average;
					remaining -= tracks[i].Size;
				}
			}
			return;
		}
		int target = -1;
		for (int i = start; i < start + count; i++)
		{
			if (tracks[i].Kind == .Percent)
				target = i;
		}
		if (target < 0)
		{
			for (int i = start; i < start + count; i++)
			{
				if (tracks[i].Kind == .AutoSize)
					target = i;
			}
		}
		if (target >= 0)
			tracks[target].Size += extra;
	}

	private static int32 SizeTracks(Span<Track> tracks, int32 available, bool arrange, bool constrain)
	{
		double weight = 0;
		int32 fixedSize = 0;
		for (let track in tracks)
		{
			if (track.Kind == .Percent && track.Value > 0)
			{
				weight += track.Value;
			}
			else
				fixedSize += track.Size;
		}
		int32 space = constrain ? Math.Max(0, available - fixedSize) : 0;
		if (!constrain)
		{
			for (let track in tracks)
			{
				if (track.Kind == .Percent && track.Value > 0)
					space = Math.Max(space, (int32)Math.Ceiling(track.Size * weight / track.Value));
			}
		}
		int32 offset = 0, assigned = 0;
		double usedWeight = 0;
		for (var track in tracks)
		{
			if (track.Kind == .Percent && track.Value > 0)
			{
				usedWeight += track.Value;
				let end = (int32)(space * usedWeight / weight);
				track.Size = end - assigned;
				assigned = end;
			}
			if (arrange && @track.Index == tracks.Length - 1)
				track.Size = Math.Max(track.Size, available - offset);
			track.Offset = offset;
			offset += track.Size;
			tracks[@track.Index] = track;
		}
		return offset;
	}

	private Size LayoutTable(Size available, bool arrange)
	{
		let children = ToScopedArray!(Controls);
		List<Cell> cells = scope .();
		for (let child in children)
		{
			if (Controls.Contains(child) && !child.IsDisposingOrDisposed && child.LocallyVisible)
			{
				let info = GetLayoutInfo(child);
				cells.Add(.(child, info.Position.Column, info.Position.Row, info.ColumnSpan, info.RowSpan));
			}
		}
		PlaceCells(cells, let columnCount, let rowCount);
		Track[] columns = new:ScopedAlloc! Track[columnCount];
		Track[] rows = new:ScopedAlloc! Track[rowCount];
		for (int i < columnCount)
		{
			let style = i < ColumnStyles.Count ? ColumnStyles[i] : ColumnStyle();
			columns[i] = MakeTrack(style.SizeType, style.Width);
		}
		for (int i < rowCount)
		{
			let style = i < RowStyles.Count ? RowStyles[i] : RowStyle();
			rows[i] = MakeTrack(style.SizeType, style.Height);
		}
		// Resolve single-cell requirements first so spans only add their remaining deficit.
		for (int pass < 2)
		{
			for (let cell in cells)
			{
				if ((cell.Columns == 1) != (pass == 0) || !Controls.Contains(cell.Child) || cell.Child.IsDisposingOrDisposed)
					continue;
				let size = GetElementSize(cell.Child, default);
				if (IsDisposingOrDisposed)
					return default;
				RequireSpace(columns, cell.Column, cell.Columns, size.width + cell.Child.Margin.Horizontal);
			}
		}
		let honorsAnchors = Parent != null && Parent.SupportsChildAnchoring;
		let constrainWidth = arrange || (honorsAnchors && available.width > 0 && Anchor.HasFlag(.Left | .Right));
		let width = SizeTracks(columns, available.width, arrange, constrainWidth);
		for (int pass < 2)
		{
			for (let cell in cells)
			{
				if ((cell.Rows == 1) != (pass == 0) || !Controls.Contains(cell.Child) || cell.Child.IsDisposingOrDisposed)
					continue;
				let size = GetElementSize(cell.Child, .(Math.Max(0, TrackExtent(columns, cell.Column, cell.Columns) - cell.Child.Margin.Horizontal), 0));
				if (IsDisposingOrDisposed)
					return default;
				RequireSpace(rows, cell.Row, cell.Rows, size.height + cell.Child.Margin.Vertical);
			}
		}
		let constrainHeight = arrange || (honorsAnchors && available.height > 0 && Anchor.HasFlag(.Top | .Bottom));
		let height = SizeTracks(rows, available.height, arrange, constrainHeight);
		if (arrange)
		{
			for (let cell in cells)
			{
				let child = cell.Child;
				if (!Controls.Contains(child) || child.IsDisposingOrDisposed)
					continue;
				let margin = child.Margin;
				let cellSize = margin.SubtractFrom(.(TrackExtent(columns, cell.Column, cell.Columns), TrackExtent(rows, cell.Row, cell.Rows)));
				var size = GetElementSize(child, cellSize);
				if (IsDisposingOrDisposed)
					return default;
				if (!Controls.Contains(child) || child.IsDisposingOrDisposed)
					continue;
				size.width = child.Anchor.HasFlag(.Left | .Right) ? cellSize.width : Math.Min(size.width, cellSize.width);
				size.height = child.Anchor.HasFlag(.Top | .Bottom) ? cellSize.height : Math.Min(size.height, cellSize.height);
				var location = Point(Padding.Left + columns[cell.Column].Offset + margin.Left, Padding.Top + rows[cell.Row].Offset + margin.Top);
				if (!child.Anchor.HasFlag(.Left))
					location.x += (cellSize.width - size.width) / (child.Anchor.HasFlag(.Right) ? 1 : 2);
				if (!child.Anchor.HasFlag(.Top))
					location.y += (cellSize.height - size.height) / (child.Anchor.HasFlag(.Bottom) ? 1 : 2);
				child.SetLayoutBounds(location, size, true);
				if (IsDisposingOrDisposed)
					return default;
			}
		}
		return .(width, height);
	}
}
