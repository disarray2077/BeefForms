using System;
using System.Text;
using System.Drawing;
using System.Windows.Forms;
using internal System.Windows.Forms;

namespace BeefForms.Backends;

extension SDLRenderer
{
	private void Ellipsize(Label label, String text)
	{
		if (Measure(label, text) <= label.Size.width) return;
		let available = label.Size.width - Measure(label, "...");
		int length = 0;
		for (let character in text.DecodedChars)
		{
			let next = length + UTF8.GetEncodedLength(character);
			if (Measure(label, .(text, 0, next)) > available) break;
			length = next;
		}
		text.Remove(length, text.Length - length);
		text.Append("...");
	}
}

extension SDLBackend
{
	private void RenderLabel(Label label, Rectangle bounds)
	{
		let size = mRenderer.MeasureText(label);
		int32 x = bounds.X, y = bounds.Y;
		if (label.HorizontalTextAlignment == 1) x += (bounds.Width - size.width) / 2;
		if (label.HorizontalTextAlignment == 2) x += bounds.Width - size.width;
		if (label.VerticalTextAlignment == 1) y += (bounds.Height - size.height) / 2;
		if (label.VerticalTextAlignment == 2) y += bounds.Height - size.height;
		mRenderer.Text(label, x, y);
	}
}
