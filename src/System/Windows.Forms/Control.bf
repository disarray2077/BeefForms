using System.Collections;
using System.Drawing;

using internal System.Windows.Forms;
using internal System.Drawing;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

internal enum ControlChange
{
	Paint, Text, Font, Bounds, Enabled, Value, Appearance, Constraints, ReadOnly, Selection, Scroll, Visibility, ZOrder, All
}

public class Control : System.ComponentModel.Component
{
	public class ControlCollection : IEnumerable<Control>
	{
		private Control mOwner;
		private List<Control> mItems = new .() ~ delete _;

		public this(Control owner) { mOwner = owner; }
		public int Count => mItems.Count;
		public bool IsEmpty => mItems.IsEmpty;
		public Control this[int index] => mItems[index];
		public int IndexOf(Control value) => mItems.IndexOf(value);
		public bool Contains(Control value) => mItems.Contains(value);

		public void Add(Control value) => Insert(Count, value);
		public void Insert(int index, Control value)
		{
			if (value.Parent == mOwner) return;
			value.Parent?.Controls.Remove(value);
			mItems.Insert(index, value);
			value.mParent = mOwner;
			value.UpdateAnchorDistances();
			if (mOwner.IsHandleCreated) value.CreateHandle();
			mOwner.PerformLayout();
			value.UpdateBackend(.ZOrder);
		}
		public bool Remove(Control value)
		{
			let index = IndexOf(value);
			if (index < 0) return false;
			RemoveAt(index);
			return true;
		}
		public void RemoveAt(int index)
		{
			let value = mItems[index];
			mItems.RemoveAt(index);
			value.DestroyHandle();
			value.mParent = null;
			mOwner.PerformLayout();
		}
		public void Clear()
		{
			while (Count > 0)
			{
				let value = mItems.Back;
				mItems.RemoveAt(Count - 1);
				value.DestroyHandle();
				value.mParent = null;
			}
			mOwner.PerformLayout();
		}
		internal void SetZOrder(Control value, bool front)
		{
			let index = IndexOf(value);
			if (index < 0 || index == (front ? Count - 1 : 0)) return;
			mItems.RemoveAt(index);
			mItems.Insert(front ? Count : 0, value);
			value.UpdateBackend(.ZOrder);
		}

		public Enumerator GetEnumerator() => .(this);
		public struct Enumerator : IEnumerator<Control>
		{
			private ControlCollection mCollection;
			private int mIndex;
			public this(ControlCollection collection) { mCollection = collection; mIndex = 0; }
			public Result<Control> GetNext() mut => mIndex < mCollection.Count ? .Ok(mCollection[mIndex++]) : .Err;
			public void Remove() mut { mCollection.RemoveAt(--mIndex); }
		}
	}

	private struct AnchorInfo : this(int32 Left, int32 Top, int32 Right, int32 Bottom) {}
	private void* mHandle;
	private Control mParent;
	private String mText = new .() ~ delete _;
	private Font mFont ~ _?.Release();
	private System.Drawing.Point mLocation;
	private Size mSize;
	private AnchorInfo mAnchorInfo;
	private bool mLayoutSuspended;
	private bool mEnabled = true;
	private bool mAutoSize;
	private bool mCreated;
	internal bool NeedsPaint = true;

	public ref Event<EventHandler> LocationChanged { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> SizeChanged { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> Layout { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> Load { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> TextChanged { get; set; } ~ _.Dispose();

	public void* Handle => mHandle;
	public bool IsHandleCreated => mCreated;
	public Control Parent => mParent;
	protected internal virtual System.Drawing.Point ContentOffset => .(0, 0);
	protected internal virtual Size ViewportSize => ClientSize;
	protected internal virtual Size LayoutSize => ClientSize;
	internal bool LayoutSuspended => mLayoutSuspended;
	protected internal virtual void ChildBoundsChanged() {}

	public virtual Size ClientSize { get => Size; set => Size = value; }
	public bool IsEffectivelyEnabled => Enabled;

	public virtual String Text
	{
		get => mText;
		set
		{
			if (mText == value)
				return;
			mText.Set(value ?? String.Empty);
			UpdateBackend(.Text);
			UpdateAutoSize();
			TextChanged.Invoke(this, .Empty);
		}
	}

	public virtual Font Font
	{
		get => mFont ?? Parent?.Font;
		set
		{
			if (mFont == value)
				return;
			value?.Retain();
			mFont?.Release();
			mFont = value;
			UpdateFont();
		}
	}

	public System.Drawing.Point Location
	{
		get => mLocation;
		set
		{
			if (mLocation.x == value.x && mLocation.y == value.y)
				return;
			mLocation = value;
			UpdateAnchorDistances();
			UpdateBackend(.Bounds);
			OnLocationChanged(.Empty);
		}
	}

	public Size Size
	{
		get => mSize;
		set
		{
			if (mSize.width == value.width && mSize.height == value.height)
				return;
			mSize = value;
			UpdateAnchorDistances();
			UpdateBackend(.Bounds);
			OnSizeChanged(.Empty);
		}
	}

	public bool Enabled
	{
		get => mEnabled && (Parent == null || Parent.Enabled);
		set { mEnabled = value; UpdateSubtree(.Enabled); }
	}

	public String Name { get; set; }
	public int TabIndex { get; set; }
	public AnchorStyles Anchor { get; set; } = .Top | .Left;
	public bool AutoSize
	{
		get => mAutoSize;
		set { mAutoSize = value; UpdateAutoSize(); }
	}
	public readonly ControlCollection Controls ~ DeleteContainerAndItems!(_);
	public virtual BorderStyle BorderStyle { get; set; }

	public this() { Controls = new .(this); }
	public ~this() { DestroyHandle(); }

	internal void DestroyHandle()
	{
		if (!mCreated) return;
		mCreated = false;
		for (let child in Controls) child.DestroyHandle();
		Application.Backend.DestroyControl(this);
		Application.CreatedControlCount--;
	}

	public void Invalidate() => UpdateBackend(.Paint);

	protected internal virtual void NotifyPaint() => NeedsPaint = false;

	internal void UpdateBackend(ControlChange change)
	{
		NeedsPaint = true;
		if (mCreated)
			Application.Backend.UpdateControl(this, change);
	}

	private void UpdateAutoSize()
	{
		if (mCreated && AutoSize && this is Label)
			Size = Application.Backend.MeasureText(this);
	}

	private void UpdateFont()
	{
		UpdateBackend(.Font);
		UpdateAutoSize();
		for (let child in Controls)
			if (child.mFont == null) child.UpdateFont();
	}

	public virtual void SuspendLayout() => mLayoutSuspended = true;
	public virtual void ResumeLayout(bool performLayout)
	{
		mLayoutSuspended = false;
		if (performLayout)
			PerformLayout();
	}

	public virtual void PerformLayout()
	{
		if (mLayoutSuspended)
			return;
		for (let child in Controls)
			child.ApplyAnchoring(LayoutSize);
		Layout.Invoke(this, .Empty);
	}

	internal void UpdateAnchorDistances()
	{
		if (mParent == null)
			return;
		let size = mParent.LayoutSize;
		mAnchorInfo = .(mLocation.x, mLocation.y,
			size.width - mLocation.x - mSize.width, size.height - mLocation.y - mSize.height);
	}

	internal void ApplyAnchoring(Size parentSize)
	{
		if (mLayoutSuspended)
			return;
		var location = mLocation;
		var size = mSize;
		if (Anchor.HasFlag(.Right))
		{
			if (Anchor.HasFlag(.Left))
				size.width = Math.Max(0, parentSize.width - mAnchorInfo.Left - mAnchorInfo.Right);
			else
				location.x = parentSize.width - size.width - mAnchorInfo.Right;
		}
		if (Anchor.HasFlag(.Bottom))
		{
			if (Anchor.HasFlag(.Top))
				size.height = Math.Max(0, parentSize.height - mAnchorInfo.Top - mAnchorInfo.Bottom);
			else
				location.y = parentSize.height - size.height - mAnchorInfo.Bottom;
		}
		let moved = location.x != mLocation.x || location.y != mLocation.y;
		let resized = size.width != mSize.width || size.height != mSize.height;
		mLocation = location;
		mSize = size;
		if (moved || resized)
			UpdateBackend(.Bounds);
		if (moved)
			OnLocationChanged(.Empty);
		if (resized)
			OnSizeChanged(.Empty);
	}

	protected virtual void OnLocationChanged(EventArgs e)
	{
		Parent?.ChildBoundsChanged();
		LocationChanged.Invoke(this, e);
	}
	protected virtual void OnSizeChanged(EventArgs e)
	{
		PerformLayout();
		Parent?.ChildBoundsChanged();
		SizeChanged.Invoke(this, e);
	}

	internal void SetNativeHandle(void* handle) => mHandle = handle;
	internal void NotifyMove(System.Drawing.Point location)
	{
		mLocation = location;
		OnLocationChanged(.Empty);
	}
	internal void NotifyText(String text)
	{
		if (mText == text)
			return;
		mText.Set(text);
		UpdateAutoSize();
		TextChanged.Invoke(this, .Empty);
	}
	internal void NotifyResize(Size size)
	{
		mSize = size;
		OnSizeChanged(.Empty);
	}

	protected internal virtual void CreateHandle()
	{
		if (mCreated)
			return;
		Application.CreatedControlCount++;
		Application.Backend.CreateControl(this);
		mCreated = true;
		UpdateAutoSize();
		for (let child in Controls)
			child.CreateHandle();
		PerformLayout();
	}
}
