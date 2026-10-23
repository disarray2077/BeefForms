using System.Drawing;
using internal System.Windows.Forms;

namespace System.Windows.Forms;

public class Label : Control
{
	private ContentAlignment mTextAlign = .TopLeft;
	private bool mAutoEllipsis;
	protected override bool CanSelectCore() => false;
	public ContentAlignment TextAlign
	{
		get => mTextAlign;
		set { mTextAlign = value; UpdateBackend(.Appearance); }
	}
	public bool AutoEllipsis
	{
		get => mAutoEllipsis;
		set { mAutoEllipsis = value; UpdateBackend(.Appearance); }
	}
}
