using System.Drawing;
using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public class ScrollableControl : Control
{
	private bool mAutoScroll;
	private Size mMinimumSize, mContentSize;
	private System.Drawing.Point mScrollPosition;
	private bool mHorizontalScroll, mVerticalScroll;
	private bool mDragging, mDragHorizontal;
	private int32 mDragOffset;

	public ref Event<EventHandler> Scroll { get; set; } ~ _.Dispose();

	public bool AutoScroll
	{
		get => mAutoScroll;
		set { mAutoScroll = value; UpdateScrollBounds(); }
	}
	public Size AutoScrollMinSize
	{
		get => mMinimumSize;
		set { mMinimumSize = value; UpdateScrollBounds(); }
	}
	public System.Drawing.Point ScrollPosition
	{
		get => mScrollPosition;
		set
		{
			let viewport = ViewportSize;
			let position = System.Drawing.Point(
				Math.Clamp(value.x, 0, Math.Max(0, mContentSize.width - viewport.width)),
				Math.Clamp(value.y, 0, Math.Max(0, mContentSize.height - viewport.height)));
			if (position.x == mScrollPosition.x && position.y == mScrollPosition.y) return;
			mScrollPosition = position;
			UpdateBackend(.Scroll);
			Scroll.Invoke(this, .Empty);
		}
	}
	public bool HorizontalScrollVisible => mHorizontalScroll;
	public bool VerticalScrollVisible => mVerticalScroll;
	internal Size ScrollContentSize => mContentSize;
	protected internal override System.Drawing.Point ContentOffset => mScrollPosition;
	protected internal override Size LayoutSize => Application.Backend.GetScrollClientSize(this);
	protected internal override Size ViewportSize
	{
		get
		{
			let size = LayoutSize;
			let bars = Application.Backend.GetScrollBarSize(this);
			return .(Math.Max(0, size.width - (mVerticalScroll ? bars.width : 0)),
				Math.Max(0, size.height - (mHorizontalScroll ? bars.height : 0)));
		}
	}

	public override void PerformLayout()
	{
		base.PerformLayout();
		if (!LayoutSuspended) UpdateScrollBounds();
	}
	protected internal override void ChildBoundsChanged()
	{
		if (!LayoutSuspended) UpdateScrollBounds();
	}

	private void UpdateScrollBounds()
	{
		mContentSize = mAutoScroll ? mMinimumSize : .(0, 0);
		if (mAutoScroll)
			for (let child in Controls)
			{
				if (!child.LocallyVisible) continue;
				mContentSize.width = Math.Max(mContentSize.width, child.Location.x + child.Size.width);
				mContentSize.height = Math.Max(mContentSize.height, child.Location.y + child.Size.height);
			}
		mHorizontalScroll = false;
		mVerticalScroll = false;
		// Each scrollbar reduces the other axis's viewport.
		for (int pass < 2)
		{
			let viewport = ViewportSize;
			mHorizontalScroll |= mContentSize.width > viewport.width;
			mVerticalScroll |= mContentSize.height > viewport.height;
		}
		ScrollPosition = mScrollPosition;
		UpdateBackend(.Scroll);
	}

	internal Rectangle ScrollTrack(bool horizontal)
	{
		let viewport = ViewportSize;
		let bars = Application.Backend.GetScrollBarSize(this);
		if (horizontal)
			return mHorizontalScroll ? .(0, viewport.height, viewport.width, bars.height) : default;
		return mVerticalScroll ? .(viewport.width, 0, bars.width, viewport.height) : default;
	}
	internal Rectangle ScrollThumb(bool horizontal)
	{
		var result = ScrollTrack(horizontal);
		let length = horizontal ? result.Width : result.Height;
		let extent = horizontal ? mContentSize.width : mContentSize.height;
		if (length == 0 || extent == 0) return result;
		let thumb = Math.Min(length, Math.Max(16, length * length / extent));
		let position = horizontal ? mScrollPosition.x : mScrollPosition.y;
		let offset = extent > length ? position * (length - thumb) / (extent - length) : 0;
		if (horizontal) { result.X += offset; result.Width = thumb; }
		else { result.Y += offset; result.Height = thumb; }
		return result;
	}

	private static bool Contains(Rectangle rect, int32 x, int32 y) =>
		x >= rect.X && y >= rect.Y && x < rect.X + rect.Width && y < rect.Y + rect.Height;

	protected override void OnMouseWheel(MouseEventArgs args)
	{
		base.OnMouseWheel(args);
		if (args.Handled || IsDisposingOrDisposed || !AutoScroll) return;
		let previous = mScrollPosition;
		var next = previous;
		if (mVerticalScroll) next.y -= args.Delta * 48 / 120;
		else next.x -= args.Delta * 48 / 120;
		next.x += args.DeltaX * 48 / 120;
		ScrollPosition = next;
		args.Handled = previous.x != mScrollPosition.x || previous.y != mScrollPosition.y;
	}

	protected override void OnMouseDown(MouseEventArgs args)
	{
		base.OnMouseDown(args);
		if (args.Handled || IsDisposingOrDisposed || args.Button != .Left) return;
		for (let horizontal in scope bool[](true, false))
		{
			if (!Contains(ScrollTrack(horizontal), args.X, args.Y)) continue;
			let thumb = ScrollThumb(horizontal);
			let coordinate = horizontal ? args.X : args.Y;
			let start = horizontal ? thumb.X : thumb.Y;
			if (Contains(thumb, args.X, args.Y))
			{
				mDragging = true;
				mDragHorizontal = horizontal;
				mDragOffset = coordinate - start;
				Capture = true;
			}
			else
			{
				var position = mScrollPosition;
				let page = horizontal ? ViewportSize.width : ViewportSize.height;
				if (horizontal) position.x += coordinate < start ? -page : page;
				else position.y += coordinate < start ? -page : page;
				ScrollPosition = position;
			}
			args.Handled = true;
			break;
		}
	}

	protected override void OnMouseMove(MouseEventArgs args)
	{
		base.OnMouseMove(args);
		if (IsDisposingOrDisposed || !mDragging || !Capture) return;
		let track = ScrollTrack(mDragHorizontal);
		let thumb = ScrollThumb(mDragHorizontal);
		let length = mDragHorizontal ? track.Width : track.Height;
		let thumbLength = mDragHorizontal ? thumb.Width : thumb.Height;
		let extent = mDragHorizontal ? mContentSize.width : mContentSize.height;
		if (length > thumbLength)
		{
			let coordinate = mDragHorizontal ? args.X : args.Y;
			let value = (coordinate - mDragOffset) * (extent - length) / (length - thumbLength);
			var position = mScrollPosition;
			if (mDragHorizontal) position.x = value;
			else position.y = value;
			ScrollPosition = position;
		}
		args.Handled = true;
	}

	protected override void OnMouseUp(MouseEventArgs args)
	{
		base.OnMouseUp(args);
		if (IsDisposingOrDisposed || args.Button != .Left || !mDragging) return;
		mDragging = false;
		Capture = false;
		args.Handled = true;
	}
}
