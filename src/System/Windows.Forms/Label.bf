using System.Drawing;
using internal BeefForms.Backends;
using internal System.Windows.Forms;

namespace System.Windows.Forms;

public class Label : Control
{
	public this()
	{
		base.DoubleBuffered = true;
	}

	protected internal override bool SelfAutoSize => true;

	public override Size GetPreferredSize(Size proposedSize)
	{
		let border = BorderWidth * 2;
		Size constraints = .(proposedSize.width > 0 ? Math.Max(1, proposedSize.width - border - Padding.Horizontal) : 0,
			proposedSize.height > 0 ? Math.Max(1, proposedSize.height - border - Padding.Vertical) : 0);
		let text = Application.Backend.MeasureText(this, constraints);
		return .(text.width + border + Padding.Horizontal, text.height + border + Padding.Vertical);
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
		set
		{
			mTextAlign = value;
			UpdateBackend(.Appearance);
		}
	}
	public bool AutoEllipsis
	{
		get => mAutoEllipsis;
		set
		{
			mAutoEllipsis = value;
			UpdateBackend(.Appearance);
		}
	}
}
