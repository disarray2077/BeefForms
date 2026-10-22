using System.Collections;
using System.Drawing;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal System.Drawing;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

internal enum ControlChange
{
	Paint, Text, Font, Bounds, Enabled, Value, Appearance, Border, Constraints, ReadOnly, Selection, Scroll, Visibility, ZOrder, All
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

		/// Takes ownership until the child is removed or independently disposed.
		public void Add(Control value) => Insert(Count, value);
		public void Insert(int index, Control value)
		{
			if (TryInsert(index, value) case .Err)
				Runtime.FatalError("A control cannot be parented to itself or its descendant");
		}
		private Result<void> TryInsert(int index, Control value)
		{
			// Validate before detaching from the old parent.
			if (Control.IsAncestorOf(value, mOwner)) return .Err;
			if (value.Parent == mOwner) return .Ok;
			value.Parent?.Controls.Remove(value);
			mItems.Insert(index, value);
			value.mParent = mOwner;
			value.UpdateAnchorDistances();
			if (mOwner.IsHandleCreated) value.CreateHandle();
			mOwner.PerformLayout();
			value.UpdateBackend(.ZOrder);
			return .Ok;
		}
		/// Detaches without disposal or deletion; ownership returns to the caller.
		public bool Remove(Control value)
		{
			if (value.Parent != mOwner) return false;
			let index = IndexOf(value);
			if (index < 0) return false;
			RemoveAt(index);
			return true;
		}
		public void RemoveAt(int index)
		{
			let value = mItems[index];
			if (value.Parent != mOwner) return;
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
		internal void ClearAfterDisposal() => mItems.Clear();

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
	// Cascaded disposal detaches the public tree but keeps allocations alive until delete.
	private List<Control> mDisposedChildren ~ delete _;
	private Control mDisposalOwner;
	private String mText = new .() ~ delete _;
	private Font mFont ~ _?.Release();
	private System.Drawing.Point mLocation;
	private Size mSize, mClientSize;
	private AnchorInfo mAnchorInfo;
	private bool mLayoutSuspended;
	private bool mEnabled = true;
	private bool mAutoSize;
	private BorderStyle mBorderStyle;
	private bool mCreated;
	private Generation mHandleGeneration;
	private bool mDisposing, mDisposed;
	internal bool NeedsPaint = true;

	public ref Event<EventHandler> LocationChanged { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> SizeChanged { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> Layout { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> Load { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> TextChanged { get; set; } ~ _.Dispose();

	public void* Handle => mHandle;
	public bool IsHandleCreated => mCreated;
	internal Generation HandleGeneration => mHandleGeneration;
	internal bool IsCurrentHandle(Generation snapshot) => mCreated && !IsDisposingOrDisposed && mHandleGeneration.IsCurrent(snapshot);
	public bool Disposing => mDisposing;
	public bool IsDisposed => mDisposed;
	internal bool IsDisposingOrDisposed => mDisposing || mDisposed;
	public Control Parent => mParent;
	protected internal virtual System.Drawing.Point ContentOffset => .(0, 0);
	protected internal virtual Size ViewportSize => ClientSize;
	protected internal virtual Size LayoutSize => ClientSize;
	internal bool LayoutSuspended => mLayoutSuspended;
	protected internal virtual void ChildBoundsChanged() {}

	internal int32 BorderWidth => BorderStyle == .None ? 0 : BorderStyle == .FixedSingle ? 1 : 2;
	public virtual Size ClientSize
	{
		get => mClientSize;
		set => Size = .(value.width + BorderWidth * 2, value.height + BorderWidth * 2);
	}
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

	public virtual Size Size
	{
		get => mSize;
		set
		{
			if (mSize.width == value.width && mSize.height == value.height)
				return;
			mSize = value;
			UpdateClientSize();
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
	public readonly ControlCollection Controls ~ delete _;
	public virtual BorderStyle BorderStyle
	{
		get => mBorderStyle;
		set
		{
			if (mBorderStyle == value) return;
			mBorderStyle = value;
			if (mCreated) UpdateClientSize();
			UpdateBackend(.Border);
			UpdateAutoSize();
			PerformLayout();
		}
	}

	public this() { Controls = new .(this); }
	public ~this()
	{
		if (!mDisposed) Dispose();
		mDisposalOwner?.mDisposedChildren.Remove(this);
		if (mDisposedChildren != null)
			while (!mDisposedChildren.IsEmpty)
			{
				let child = mDisposedChildren.PopBack();
				child.mDisposalOwner = null;
				delete child;
			}
	}

	protected override void Dispose(bool disposing)
	{
		if (!disposing || mDisposing) return;
		mDisposing = true;
		defer { mDisposing = false; mDisposed = true; }
		let children = scope List<Control>();
		for (let child in Controls) children.Add(child);
		DestroyHandle();
		Parent?.Controls.Remove(this);
		for (let child in children)
		{
			if (child.Parent != this) continue;
			// Match WinForms: clear Parent before notifying, clear Controls after the cascade.
			child.mParent = null;
			if (mDisposedChildren == null) mDisposedChildren = new .();
			mDisposedChildren.Add(child);
			child.mDisposalOwner = this;
			child.Dispose();
		}
		Controls.ClearAfterDisposal();
		base.Dispose(disposing);
	}
	private void UpdateClientSize() => mClientSize = .(Math.Max(0, mSize.width - BorderWidth * 2), Math.Max(0, mSize.height - BorderWidth * 2));

	internal void DestroyHandle()
	{
		if (!mCreated) return;
		mCreated = false;
		mHandleGeneration.Advance();
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
		else if (mCreated && AutoSize && this is TextBoxBase && !(this is RichTextBox))
			Size = .(Size.width, Application.Backend.GetTextBoxHeight((TextBoxBase)this));
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
		UpdateClientSize();
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
		if (mSize.width == size.width && mSize.height == size.height) return;
		mSize = size;
		UpdateClientSize();
		if (mCreated) OnSizeChanged(.Empty);
	}

	protected internal virtual void CreateHandle()
	{
		if (IsDisposingOrDisposed)
			Runtime.FatalError("Cannot create a handle for a disposed control");
		if (mCreated)
			return;
		mHandleGeneration.Advance();
		Application.CreatedControlCount++;
		Application.Backend.CreateControl(this);
		UpdateClientSize();
		mCreated = true;
		UpdateAutoSize();
		for (let child in Controls)
		{
			if (child.IsDisposingOrDisposed) continue;
			child.UpdateAnchorDistances();
			child.CreateHandle();
		}
		PerformLayout();
	}
}
