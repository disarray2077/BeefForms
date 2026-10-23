using System;
using System.Drawing;
using System.Windows.Forms;
using internal System.Windows.Forms;
using internal System.Drawing;

namespace BeefForms.Backends;

extension SDLWindowSession
{
	private void RenderLabel(Label label, Rectangle bounds)
	{
		let size = mRenderer.MeasureText(label);
		int32 x = bounds.X + mRenderer.LabelPadding(label), y = bounds.Y;
		if (label.TextAlign.Horizontal == .Center) x += (bounds.Width - size.width) / 2;
		if (label.TextAlign.Horizontal == .Right) x += bounds.Width - size.width;
		if (label.TextAlign.Vertical == .Middle) y += (bounds.Height - size.height) / 2;
		if (label.TextAlign.Vertical == .Bottom) y += bounds.Height - size.height;
		mRenderer.Text(label, x, y);
	}
}
