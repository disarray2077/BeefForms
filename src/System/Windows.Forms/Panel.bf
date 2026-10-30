namespace System.Windows.Forms;

public class Panel : ScrollableControl
{
	public virtual AutoSizeMode AutoSizeMode
	{
		get => GetAutoSizeMode();
		set => SetAutoSizeMode(value);
	}

	public override System.Drawing.Size GetPreferredSize(System.Drawing.Size proposedSize)
		=> GetPreferredContainerSize();
	protected override bool CanSelectCore() => false;
}
