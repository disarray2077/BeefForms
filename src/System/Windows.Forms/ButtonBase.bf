namespace System.Windows.Forms;

public class ButtonBase : Control
{
	public this() { TabStop = true; }
    public bool UseVisualStyleBackColor { get; set; }
}
