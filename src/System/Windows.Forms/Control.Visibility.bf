using internal System.Windows.Forms;

namespace System.Windows.Forms;

extension Control
{
	private bool mVisible = true;

	public bool Visible
	{
		get => mVisible && (Parent == null || Parent.Visible);
		set
		{
			if (mVisible == value) return;
			let wasVisible = Visible;
			mVisible = value;
			UpdateSubtree(.Visibility);
			Parent?.ChildBoundsChanged();
			if (wasVisible != Visible) OnVisibleChanged(.Empty);
		}
	}
	public bool IsEffectivelyVisible => Visible;
	internal bool LocallyVisible => mVisible;
	public ref Event<EventHandler> VisibleChanged { get; set; } ~ _.Dispose();

	protected virtual void OnVisibleChanged(EventArgs args)
	{
		VisibleChanged.Invoke(this, args);
		for (let child in Controls)
			if (child.mVisible) child.OnVisibleChanged(args);
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
