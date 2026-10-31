using System.Drawing;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public enum AutoSizeMode
{
	GrowAndShrink,
	GrowOnly
}

extension Control
{
	// User preferred-size overrides and layout callbacks need not converge.
	internal const int MaxLayoutPasses = 16;
	// Automatic layout must preserve the caller's requested size as the GrowOnly floor.
	private Size mSpecifiedSize;
	private AutoSizeMode mAutoSizeMode = .GrowOnly;
	internal Object mLayoutData ~ delete _;
	internal Size SpecifiedSize => mSpecifiedSize;
	protected internal virtual bool SupportsChildAnchoring => true;
	public Size PreferredSize => GetPreferredSize(default);

	public virtual Size GetPreferredSize(Size proposedSize) => mSpecifiedSize;

	public ref Event<EventHandler> AutoSizeChanged { get; set; } ~ _.Dispose();

	protected virtual void OnAutoSizeChanged(EventArgs args)
	{
		AutoSizeChanged.Invoke(this, args);
	}

	protected AutoSizeMode GetAutoSizeMode() => mAutoSizeMode;

	protected void SetAutoSizeMode(AutoSizeMode value)
	{
		if (mAutoSizeMode == value)
			return;
		mAutoSizeMode = value;
		UpdateAutoSize();
	}

	protected internal virtual bool SelfAutoSize => false;

	protected virtual void RestoreSpecifiedSize()
	{
		SetLayoutBounds(Location, mSpecifiedSize, true);
	}

	internal Size GetAutoSize(Size proposedSize, Size minimum)
	{
		var preferred = GetPreferredSize(proposedSize);
		if (mAutoSizeMode == .GrowOnly)
			preferred = .(Math.Max(preferred.width, minimum.width), Math.Max(preferred.height, minimum.height));
		return preferred;
	}

	internal Size MeasureForLayout(Size proposedSize)
	{
		var size = Size;
		if (AutoSize && !SelfAutoSize)
			size = GetAutoSize(proposedSize, mSpecifiedSize);
		return size;
	}

	internal void ApplyAutoSize()
	{
		let preferred = GetAutoSize(default, mSpecifiedSize);
		if (!IsDisposingOrDisposed)
			SetLayoutBounds(Location, preferred);
	}

	protected internal void SetLayoutBounds(Point location, Size size, bool updateAnchors = false)
	{
		let moved = location != mLocation;
		let resized = size != mSize;
		if (!moved && !resized)
			return;
		mLocation = location;
		mSize = size;
		UpdateClientSize();
		if (updateAnchors)
			UpdateAnchorDistances();
		UpdateBackend(.Bounds);
		if (moved)
			OnLocationChanged(.Empty);
		if (resized)
			OnSizeChanged(.Empty);
	}

	protected Size GetPreferredContainerSize()
	{
		Size preferred = default;
		if (IsDisposingOrDisposed)
			return Size;
		let children = ToScopedArray!(Controls);
		for (let child in children)
		{
			if (!Controls.Contains(child) || child.IsDisposingOrDisposed || !child.LocallyVisible)
				continue;
			let size = child.MeasureForLayout(default);
			if (!Controls.Contains(child))
				continue;
			let right = child.Location.x + size.width;
			let bottom = child.Location.y + size.height;
			if (child.Anchor.HasFlag(.Right))
				preferred.width = Math.Max(preferred.width, right + child.mAnchorInfo.Right);
			else if (child.Anchor.HasFlag(.Left))
				preferred.width = Math.Max(preferred.width, right);
			if (child.Anchor.HasFlag(.Bottom))
				preferred.height = Math.Max(preferred.height, bottom + child.mAnchorInfo.Bottom);
			else
				preferred.height = Math.Max(preferred.height, bottom);
		}
		return .(preferred.width + BorderWidth * 2, preferred.height + BorderWidth * 2);
	}
}
