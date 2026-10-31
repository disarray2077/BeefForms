using System.Drawing;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public enum FlowDirection
{
	LeftToRight,
	TopDown,
	RightToLeft,
	BottomUp
}

public class FlowLayoutPanel : Panel
{
	protected internal override bool SupportsChildAnchoring => false;
	private FlowDirection mFlowDirection;
	private bool mWrapContents = true;
	private bool mArranging, mLayoutRequested;

	public FlowDirection FlowDirection
	{
		get => mFlowDirection;
		set
		{
			if ((uint)value > (uint)System.Windows.Forms.FlowDirection.BottomUp)
				Runtime.FatalError("FlowDirection must be a valid flow direction");
			if (mFlowDirection == value)
				return;
			mFlowDirection = value;
			PerformLayout();
		}
	}

	public bool WrapContents
	{
		get => mWrapContents;
		set
		{
			if (mWrapContents == value)
				return;
			mWrapContents = value;
			PerformLayout();
		}
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
		LayoutFlow(ViewportSize, true);
	}

	public override Size GetPreferredSize(Size proposedSize)
	{
		if (IsDisposingOrDisposed)
			return Size;
		let border = BorderWidth * 2;
		let content = LayoutFlow(.(Math.Max(0, proposedSize.width - border), Math.Max(0, proposedSize.height - border)), false);
		return .(content.width + border, content.height + border);
	}

	private Size LayoutFlow(Size available, bool arrange)
	{
		let vertical = mFlowDirection == .TopDown || mFlowDirection == .BottomUp;
		let reverse = mFlowDirection == .RightToLeft || mFlowDirection == .BottomUp;
		let limit = vertical ? available.height : available.width;
		let wrap = mWrapContents && (arrange || limit > 0);
		int32 position = 0, lineOffset = 0, lineSize = 0, extent = 0;
		bool hasItems = false;
		let children = ToScopedArray!(Controls);
		for (let child in children)
		{
			if (!Controls.Contains(child) || child.IsDisposingOrDisposed || !child.LocallyVisible)
				continue;
			let size = child.MeasureForLayout(default);
			if (IsDisposingOrDisposed)
				return default;
			if (!Controls.Contains(child) || child.IsDisposingOrDisposed || !child.LocallyVisible)
				continue;
			let length = Math.Max(0, vertical ? size.height : size.width);
			let thickness = Math.Max(0, vertical ? size.width : size.height);
			if (wrap && hasItems && position + length > limit)
			{
				lineOffset += lineSize;
				position = 0;
				lineSize = 0;
				hasItems = false;
			}
			if (arrange)
			{
				let coordinate = reverse ? limit - position - length : position;
				let location = vertical ? Point(lineOffset, coordinate) : Point(coordinate, lineOffset);
				child.SetLayoutBounds(location, size, true);
				if (IsDisposingOrDisposed)
					return default;
			}
			position += length;
			lineSize = Math.Max(lineSize, thickness);
			extent = Math.Max(extent, position);
			hasItems = true;
		}
		return vertical ? .(lineOffset + lineSize, extent) : .(extent, lineOffset + lineSize);
	}
}
