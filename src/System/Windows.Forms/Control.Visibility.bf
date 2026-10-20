using internal System.Windows.Forms;

namespace System.Windows.Forms;

extension Control
{
	private bool mVisible = true;

	public bool Visible
	{
		get => mVisible;
		set
		{
			if (mVisible == value) return;
			mVisible = value;
			UpdateSubtree(.Visibility);
			Parent?.ChildBoundsChanged();
			VisibleChanged.Invoke(this, .Empty);
		}
	}
	public bool IsEffectivelyVisible => Visible && (Parent == null || Parent.IsEffectivelyVisible);
	public ref Event<EventHandler> VisibleChanged { get; set; } ~ _.Dispose();

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
