using System;
using System.Drawing;
using System.Windows.Forms;
using internal System.Windows.Forms;

namespace BeefForms.Backends;

extension SDLBackend
{
	private void RenderLabel(Label label, Rectangle bounds)
	{
		let size = mRenderer.MeasureText(label);
		int32 x = bounds.X + mRenderer.LabelPadding(label), y = bounds.Y;
		if (label.HorizontalTextAlignment == 1) x += (bounds.Width - size.width) / 2;
		if (label.HorizontalTextAlignment == 2) x += bounds.Width - size.width;
		if (label.VerticalTextAlignment == 1) y += (bounds.Height - size.height) / 2;
		if (label.VerticalTextAlignment == 2) y += bounds.Height - size.height;
		mRenderer.Text(label, x, y);
	}
}
