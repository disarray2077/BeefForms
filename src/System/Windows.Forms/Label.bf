using System.Drawing;
using internal BeefForms.Backends;
using internal System.Windows.Forms;

namespace System.Windows.Forms;

public class Label : Control
{
	protected internal override bool SelfAutoSize => true;
	public override Size GetPreferredSize(Size proposedSize)
	{
		let border = BorderWidth * 2;
		Size constraints = .(proposedSize.width > border ? proposedSize.width - border : 0,
			proposedSize.height > border ? proposedSize.height - border : 0);
		let text = Application.Backend.MeasureText(this, constraints);
		return .(text.width + border, text.height + border);
	}
	protected override void UpdateAutoSize()
	{
		if (AutoSize && (IsHandleCreated || Parent != null))
			SetLayoutBounds(Location, PreferredSize, true);
		base.UpdateAutoSize();
	}
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
