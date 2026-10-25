namespace System.Windows.Forms;

public class ContainerControl : ScrollableControl
{
	public override System.Drawing.Size GetPreferredSize(System.Drawing.Size proposedSize) => GetPreferredContainerSize();
    public System.Drawing.SizeF AutoScaleDimensions { get; set; }
    public AutoScaleMode AutoScaleMode { get; set; }
}
