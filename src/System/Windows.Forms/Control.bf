using System.Collections;
using System.Drawing;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal System.Drawing;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

internal enum ControlChange
{
	Paint, Text, Font, Bounds, Enabled, Value, Appearance, Border, Constraints, ReadOnly, Multiline, Selection, Scroll, Visibility, Parent, ZOrder, All
}

public class Control : System.ComponentModel.Component
{
	public class ControlCollection : IEnumerable<Control>
	{
		private Control mOwner;
		private append List<Control> mItems = .();

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
			// Validate before detaching from the old parent.
			if (Control.IsAncestorOf(value, mOwner))
				Runtime.FatalError("A control cannot be parented to itself or its descendant");
			if (value.Parent == mOwner) return;
			value.Parent?.Controls.Remove(value);
			value.ReleaseDisposalOwner();
			mItems.Insert(index, value);
			value.mParent = mOwner;
			value.UpdateBackend(.Parent);
			value.UpdateAnchorDistances();
			value.UpdateFont();
			if (mOwner.IsHandleCreated) value.CreateControl();
			mOwner.PerformLayout();
			value.UpdateBackend(.ZOrder);
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
		internal Control TakeLastForDeletion()
		{
			let child = mItems.PopBack();
			child.mParent = null;
			return child;
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
	// Cascaded disposal detaches the public tree but keeps allocations alive until delete.
	private List<Control> mDisposedChildren ~ delete _;
	private Control mDisposalOwner;
	private append String mText = .();
	private append String mName = .();
	private Font mFont ~ _?.Release();
	private Point mLocation;
	private Size mSize, mClientSize;
	private AnchorInfo mAnchorInfo;
	private uint32 mLayoutSuspendCount;
	private bool mLayoutDeferred;
	private bool mEnabled = true;
	private bool mAutoSize;
	private BorderStyle mBorderStyle;
	private bool mHandleCreated;
	private bool mCreated;
	private Generation mHandleGeneration;
	private bool mDisposing, mDisposed;
	internal bool NeedsPaint = true;

	public ref Event<EventHandler> LocationChanged { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> SizeChanged { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> Layout { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> Load { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> TextChanged { get; set; } ~ _.Dispose();

	public void* Handle
	{
		get
		{
			if (!IsHandleCreated) CreateHandle();
			return mHandle;
		}
	}
	/// Returns the current handle without creating one.
	internal void* GetHandle() => mHandle;
	public bool IsHandleCreated => mHandleCreated;
	public bool Created => mCreated;
	internal Generation HandleGeneration => mHandleGeneration;
	internal bool IsCurrentHandle(Generation snapshot) => mHandleCreated && !IsDisposingOrDisposed && mHandleGeneration.IsCurrent(snapshot);
	public bool Disposing => mDisposing;
	public bool IsDisposed => mDisposed;
	internal bool IsDisposingOrDisposed => mDisposing || mDisposed;
	public Control Parent => mParent;

	/// Returns the nearest containing form, including this control, or null if there is none.
	public Form FindForm()
	{
		for (var control = this; control != null; control = control.Parent)
			if (let form = control as Form) return form;
		return null;
	}

	protected internal virtual Point ContentOffset => .(0, 0);
	protected internal virtual Size ViewportSize => ClientSize;
	protected internal virtual Size LayoutSize => ClientSize;
	internal bool LayoutSuspended => mLayoutSuspendCount > 0;
	protected internal virtual void ChildBoundsChanged()
	{
		if (LayoutSuspended) mLayoutDeferred = true;
		else if (AutoSize) PerformLayout();
	}

	internal int32 BorderWidth => BorderStyle == .None ? 0 : BorderStyle == .FixedSingle ? 1 : 2;

	internal Point RootToLocalPoint(Point point)
	{
		var result = point;
		for (var current = this; current.Parent != null; current = current.Parent)
		{
			int32 border = (current.Parent is Form) ? 0 : current.Parent.BorderWidth;
			result.x -= current.Location.x + border - current.Parent.ContentOffset.x;
			result.y -= current.Location.y + border - current.Parent.ContentOffset.y;
		}
		if (!(this is Form))
		{
			result.x -= BorderWidth;
			result.y -= BorderWidth;
		}
		return result;
	}
	internal Point LocalToRootPoint(Point point)
	{
		let origin = RootToLocalPoint(.(0, 0));
		return .(point.x - origin.x, point.y - origin.y);
	}

	public virtual Size ClientSize
	{
		get => mClientSize;
		set => Size = .(value.width + BorderWidth * 2, value.height + BorderWidth * 2);
	}
	public bool IsEffectivelyEnabled => Enabled;

	public virtual StringView Text
	{
		get => mText;
		set
		{
			if (!SetTextValue(value)) return;
			UpdateBackend(.Text);
			NotifyTextChanged();
		}
	}

	protected bool SetTextValue(StringView text)
	{
		if (mText == text) return false;
		mText.Set(text);
		return true;
	}

	protected void NotifyTextChanged()
	{
		UpdateAutoSize();
		TextChanged.Invoke(this, .Empty);
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

	public Point Location
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
			mSpecifiedSize = value;
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

	public StringView Name
	{
		get => mName;
		set => mName.Set(value);
	}
	public int TabIndex { get; set; }
	private AnchorStyles mAnchor = .Top | .Left;
	public AnchorStyles Anchor
	{
		get => mAnchor;
		set
		{
			if (mAnchor == value) return;
			mAnchor = value;
			UpdateAnchorDistances();
			Parent?.PerformLayout();
		}
	}
	public virtual bool AutoSize
	{
		get => mAutoSize;
		set
		{
			if (mAutoSize == value) return;
			mAutoSize = value;
			if (!value) RestoreSpecifiedSize();
			UpdateAutoSize();
			OnAutoSizeChanged(.Empty);
		}
	}

	// Keep separate: an appended ControlCollection causes a compiler type-layout cycle :(
	public readonly ControlCollection Controls ~ delete _;

	public virtual BorderStyle BorderStyle
	{
		get => mBorderStyle;
		set
		{
			if (mBorderStyle == value) return;
			mBorderStyle = value;
			if (mHandleCreated) UpdateClientSize();
			UpdateBackend(.Border);
			UpdateAutoSize();
			PerformLayout();
		}
	}

	public this() { Controls = new .(this); }
	public ~this()
	{
		if (!mDisposed) Dispose();
		// Disposal callbacks can reparent this control and even recreate its handle.
		DestroyHandle();
		Parent?.Controls.Remove(this);
		ReleaseDisposalOwner();
		// The owner's Disposed event can add children after the logical cascade ends.
		while (!Controls.IsEmpty)
			delete Controls.TakeLastForDeletion();
		if (mDisposedChildren != null)
			while (!mDisposedChildren.IsEmpty)
			{
				let child = mDisposedChildren.PopBack();
				child.mDisposalOwner = null;
				delete child;
			}
#if TEST
		GC.Collect(false);
#endif
	}

	private void ReleaseDisposalOwner()
	{
		mDisposalOwner?.mDisposedChildren.Remove(this);
		mDisposalOwner = null;
	}

	protected override void Dispose(bool disposing)
	{
		if (!disposing || mDisposing) return;
		mDisposing = true;
		defer { mDisposing = false; mDisposed = true; }
		DestroyHandle();
		Parent?.Controls.Remove(this);
		DisposeChildren();
		base.Dispose(disposing);
	}

	private void DisposeChildren()
	{
		let children = scope List<Control>();
		while (true)
		{
			children.Clear();
			for (let child in Controls)
				if (child.Parent == this) children.Add(child);
			if (children.IsEmpty) break;
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
			// Callbacks may have added children or moved pending ones to another parent.
		}
		Controls.ClearAfterDisposal();
	}

	private void UpdateClientSize() => mClientSize = .(Math.Max(0, mSize.width - BorderWidth * 2), Math.Max(0, mSize.height - BorderWidth * 2));

	private bool ResetHandleState()
	{
		if (!mHandleCreated) return false;
		mHandleCreated = false;
		mCreated = false;
		if (let form = this as Form) Application.UnregisterForm(form);
		mHandleGeneration.Advance();
		return true;
	}

	protected internal virtual void DestroyHandle()
	{
		if (!ResetHandleState()) return;
		for (let child in Controls) child.DestroyHandle();
		Application.Backend.DestroyControl(this);
		Application.CreatedControlCount--;
	}

	public void Invalidate() => UpdateBackend(.Paint);

	protected internal virtual void NotifyPaint() => NeedsPaint = false;

	internal void UpdateBackend(ControlChange change)
	{
		NeedsPaint = true;
		if (mHandleCreated && !(this is Form && change == .Visibility && Visible && !Created))
			Application.Backend.UpdateControl(this, change);
	}

	protected virtual void UpdateAutoSize() => Parent?.PerformLayout();

	private void UpdateFont()
	{
		UpdateBackend(.Font);
		UpdateAutoSize();
		for (let child in Controls)
			if (child.mFont == null) child.UpdateFont();
	}

	public virtual void SuspendLayout() => mLayoutSuspendCount++;
	public virtual void ResumeLayout(bool performLayout)
	{
		if (mLayoutSuspendCount > 0)
		{
			mLayoutSuspendCount--;
			if (!LayoutSuspended && mLayoutDeferred && performLayout) PerformLayout();
		}
		// WinForms refreshes anchor baselines on every ResumeLayout(false), even an inner one.
		if (!performLayout)
			for (let child in Controls) child.UpdateAnchorDistances();
	}

	public virtual void PerformLayout()
	{
		if (LayoutSuspended)
		{
			mLayoutDeferred = true;
			return;
		}
		{
			// Layout requests made by callbacks must not recurse into the active pass.
			mLayoutSuspendCount = 1;
			defer { mLayoutSuspendCount = 0; }
			Layout.Invoke(this, .Empty);
			if (IsDisposingOrDisposed) return;
			for (int pass < MaxLayoutPasses)
			{
				mLayoutDeferred = false;
				let children = ToScopedArray!(Controls);
				for (let child in children)
				{
					if (!Controls.Contains(child) || child.IsDisposingOrDisposed) continue;
					child.ApplyAnchoring(LayoutSize);
					if (IsDisposingOrDisposed) return;
				}
				if (!mLayoutDeferred) break;
			}
		}
		if (AutoSize) Parent?.PerformLayout();
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
		let parent = Parent;
		var location = mLocation;
		var size = mSize;
		if (Anchor.HasFlag(.Right))
		{
			if (Anchor.HasFlag(.Left))
				size.width = Math.Max(0, parentSize.width - mAnchorInfo.Left - mAnchorInfo.Right);
			else location.x = parentSize.width - size.width - mAnchorInfo.Right;
		}
		if (Anchor.HasFlag(.Bottom))
		{
			if (Anchor.HasFlag(.Top))
				size.height = Math.Max(0, parentSize.height - mAnchorInfo.Top - mAnchorInfo.Bottom);
			else location.y = parentSize.height - size.height - mAnchorInfo.Bottom;
		}
		if (AutoSize && !SelfAutoSize && LocallyVisible)
		{
			var minimum = mSpecifiedSize;
			Size proposed = default;
			if (Anchor.HasFlag(.Left | .Right)) minimum.width = proposed.width = size.width;
			if (Anchor.HasFlag(.Top | .Bottom)) minimum.height = proposed.height = size.height;
			let preferred = GetAutoSize(proposed, minimum);
			if (IsDisposingOrDisposed || Parent != parent) return;
			if (Anchor.HasFlag(.Right) && !Anchor.HasFlag(.Left)) location.x -= preferred.width - size.width;
			if (Anchor.HasFlag(.Bottom) && !Anchor.HasFlag(.Top)) location.y -= preferred.height - size.height;
			size = preferred;
		}
		SetLayoutBounds(location, size);
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
	internal void NotifyHandleDestroyed(void* handle)
	{
		if (mHandle != handle) return;
		mHandle = null;
		// DestroyHandle already invalidates state and accounts for its own destruction.
		if (ResetHandleState()) Application.CreatedControlCount--;
	}

	internal void NotifyMove(Point location)
	{
		mLocation = location;
		OnLocationChanged(.Empty);
	}
	internal void NotifyText(String text, bool forceNotification = false)
	{
		if (SetTextValue(text) || forceNotification) NotifyTextChanged();
	}
	internal void NotifyResize(Size size)
	{
		if (mSize.width == size.width && mSize.height == size.height) return;
		mSpecifiedSize = size;
		mSize = size;
		UpdateClientSize();
		if (mHandleCreated) OnSizeChanged(.Empty);
	}

	public void CreateControl()
	{
		if (mCreated || !Visible || IsDisposed) return;
		mCreated = true;
		if (!IsHandleCreated) CreateHandle();
		if (!IsHandleCreated || IsDisposingOrDisposed) return;
		let children = ToScopedArray!(Controls);
		for (let child in children)
		{
			// Check membership before dereferencing: a previous callback may have deleted this child.
			if (!Controls.Contains(child) || child.IsDisposingOrDisposed) continue;
			child.UpdateAnchorDistances();
			child.CreateControl();
			if (!mCreated || IsDisposingOrDisposed) return;
		}
		PerformLayout();
		if (!mCreated || IsDisposingOrDisposed) return;
		OnCreateControl();
	}

	protected virtual void OnCreateControl() {}

	protected internal virtual void CreateHandle()
	{
		if (IsDisposed)
			Runtime.FatalError("Cannot create a handle for a disposed control");
		if (mHandleCreated)
			return;
		mHandleGeneration.Advance();
		Application.CreatedControlCount++;
		Application.Backend.CreateControl(this);
		UpdateClientSize();
		mHandleCreated = true;
		UpdateAutoSize();
		if (!(this is Form) && Visible) CreateControl();
	}
}
