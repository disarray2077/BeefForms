using internal System.Windows.Forms;

namespace System.Windows.Forms;

public class ProgressBar : Control
{
	private int mValue;
	public int Value
	{
		get => mValue;
		set { mValue = value; UpdateBackend(.Value); }
	}
}
