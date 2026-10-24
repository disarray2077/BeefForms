using internal System.Windows.Forms;

namespace System.Windows.Forms;

extension Control
{
	private bool mVisible = true;

	public bool Visible
	{
		get => mVisible && (Parent == null || Parent.Visible);
		set => SetVisibleCore(value);
	}

	protected virtual void SetVisibleCore(bool value)
	{
		if (mVisible == value && Visible == value) return;
		let wasVisible = Visible;
		mVisible = value;
		if (value && (Parent == null || Parent.IsHandleCreated)) CreateControl();
		if (IsDisposingOrDisposed) return;
		UpdateSubtree(.Visibility);
		Parent?.ChildBoundsChanged();
		if (wasVisible != Visible || value) OnVisibleChanged(.Empty);
	}

	internal void NotifyVisibility(bool visible)
	{
		let wasVisible = Visible;
		if (visible)
		{
			mVisible = true;
			CreateControl();
			if (IsDisposingOrDisposed) return;
		}
		else if (Parent?.Visible == true || this is Form)
			mVisible = false;
		if (wasVisible != visible) OnVisibleChanged(.Empty);
	}

	public bool IsEffectivelyVisible => Visible;
	internal bool LocallyVisible => mVisible;
	public ref Event<EventHandler> VisibleChanged { get; set; } ~ _.Dispose();

	protected virtual void OnVisibleChanged(EventArgs args)
	{
		if (Visible && Parent?.IsHandleCreated == true) CreateControl();
		VisibleChanged.Invoke(this, args);
		for (let child in Controls)
			if (child.Visible) child.OnVisibleChanged(args);
	}

	public virtual void Show() => Visible = true;
	public void Hide() => Visible = false;

	public void BringToFront() => Parent?.Controls.SetZOrder(this, true);
	public void SendToBack() => Parent?.Controls.SetZOrder(this, false);

	private void UpdateSubtree(ControlChange change)
	{
		UpdateBackend(change);
		for (let child in Controls)
			child.UpdateSubtree(change);
	}
}
