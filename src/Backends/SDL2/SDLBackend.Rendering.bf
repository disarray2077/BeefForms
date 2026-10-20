using System;
using System.Collections;
using System.Drawing;
using System.Windows.Forms;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

extension SDLBackend
{
	private static Rectangle Intersect(Rectangle a, Rectangle b)
	{
		let x = Math.Max(a.X, b.X), y = Math.Max(a.Y, b.Y);
		return .(x, y, Math.Max(0, Math.Min(a.X + a.Width, b.X + b.Width) - x),
			Math.Max(0, Math.Min(a.Y + a.Height, b.Y + b.Height) - y));
	}

	private static void InvalidateTree(Control control)
	{
		control.Invalidate();
		for (let child in control.Controls) InvalidateTree(child);
	}

	private void RenderControl(Control control, Rectangle bounds, Rectangle parentClip)
	{
		if (!control.IsEffectivelyVisible) return;
		var clip = Intersect(bounds, parentClip);
		if (clip.Width == 0 || clip.Height == 0)
			return;
		mRenderer.Clip(clip);
		let enabled = control.IsEffectivelyEnabled;
		let lineHeight = mRenderer.LineHeight(control);
		if (control is ScrollableControl || control is GroupBox)
			mRenderer.Fill(bounds, 0.94f, 0.94f, 0.95f);
		if (control is Button)
		{
			let shade = !enabled ? 0.89f : control == mPressed && control == mHovered ? 0.73f : control == mHovered ? 0.85f : 0.91f;
			mRenderer.Fill(bounds, shade, shade, shade + 0.02f);
			mRenderer.Border(bounds, IsFocused(control) ? 0.2f : 0.6f, 0.5f, 0.7f);
			let textWidth = mRenderer.Measure(control, control.Text);
			mRenderer.Text(control, bounds.X + (bounds.Width - textWidth) / 2, bounds.Y + (bounds.Height - lineHeight) / 2);
		}
		else if (let progress = control as ProgressBar)
		{
			mRenderer.Fill(bounds, 0.85f, 0.86f, 0.87f);
			let range = progress.Maximum - progress.Minimum;
			int32 width = range == 0 ? 0 : (int32)((int64)Math.Max(0, bounds.Width - 4) * (progress.Value - progress.Minimum) / range);
			mRenderer.Fill(.(bounds.X + 2, bounds.Y + 2, width,
				Math.Max(0, bounds.Height - 4)), 0.2f, 0.65f, 0.38f);
			mRenderer.Border(bounds, 0.6f, 0.62f, 0.65f);
		}
		else if (let editor = control as TextBoxBase)
			RenderEditor(editor, bounds, clip);
		else if (control is GroupBox)
		{
			mRenderer.Border(.(bounds.X, bounds.Y + lineHeight / 2, bounds.Width, bounds.Height - lineHeight / 2), 0.7f, 0.7f, 0.72f);
			mRenderer.Fill(.(bounds.X + 7, bounds.Y, mRenderer.Measure(control, control.Text) + 6, lineHeight), 0.94f, 0.94f, 0.95f);
			mRenderer.Text(control, bounds.X + 10, bounds.Y);
		}
		else if (control is Label)
			mRenderer.Text(control, bounds.X, bounds.Y);
		else if (control.BorderStyle != .None)
			mRenderer.Border(bounds, 0.7f, 0.7f, 0.72f);

		if (control.NeedsPaint) control.NotifyPaint();

		let viewport = control.ViewportSize;
		let childClip = Intersect(clip, .(bounds.X, bounds.Y, viewport.width, viewport.height));
		for (let child in control.Controls)
		{
			let childSize = child.Size;
			RenderControl(child, .(bounds.X + child.Location.x - control.ContentOffset.x, bounds.Y + child.Location.y - control.ContentOffset.y, childSize.width, childSize.height), childClip);
		}
		if (let scrollable = control as ScrollableControl)
		{
			mRenderer.Clip(clip);
			for (let horizontal in scope bool[](true, false))
			{
				var track = scrollable.ScrollTrack(horizontal);
				if (track.Width == 0 || track.Height == 0) continue;
				var thumb = scrollable.ScrollThumb(horizontal);
				track.X += bounds.X; track.Y += bounds.Y;
				thumb.X += bounds.X; thumb.Y += bounds.Y;
				mRenderer.Fill(track, 0.88f, 0.89f, 0.90f);
				mRenderer.Fill(thumb, 0.58f, 0.60f, 0.64f);
			}
		}
	}

	private void RenderEditor(TextBoxBase editor, Rectangle bounds, Rectangle parentClip)
	{
		mRenderer.Fill(bounds, editor.ReadOnly ? 0.96f : 1, editor.ReadOnly ? 0.96f : 1, 1);
		mRenderer.Border(bounds, IsFocused(editor) ? 0.2f : 0.65f, 0.5f, 0.7f);
		let clip = Intersect(parentClip, .(bounds.X + 2, bounds.Y + 2, Math.Max(0, bounds.Width - 4), Math.Max(0, bounds.Height - 4)));
		mRenderer.Clip(clip);
		let caret = mRenderer.TextPosition(editor, editor.Caret);
		if (IsFocused(editor))
		{
			editor.ScrollX = Math.Max(0, Math.Max(caret.x - bounds.Width + 10, Math.Min(editor.ScrollX, caret.x)));
			editor.ScrollY = Math.Max(0, Math.Max(caret.y + mRenderer.LineHeight(editor) - bounds.Height + 8, Math.Min(editor.ScrollY, caret.y)));
			if (editor.SelectionLength > 0)
			{
				int start = editor.SelectionStart;
				let end = start + editor.SelectionLength;
				while (start < end)
				{
					var lineEnd = editor.Text.IndexOf('\n', start);
					if (lineEnd < 0 || lineEnd > end) lineEnd = end;
					let a = mRenderer.TextPosition(editor, start);
					let b = mRenderer.TextPosition(editor, lineEnd);
					mRenderer.Fill(.(bounds.X + 4 + a.x - editor.ScrollX, bounds.Y + 4 + a.y - editor.ScrollY,
						Math.Max(2, b.x - a.x), mRenderer.LineHeight(editor)), 0.65f, 0.8f, 1);
					start = lineEnd + 1;
				}
			}
			if (!editor.ReadOnly && SDL.GetTicks() % 1000 < 550)
				mRenderer.Fill(.(bounds.X + 4 + caret.x - editor.ScrollX, bounds.Y + 4 + caret.y - editor.ScrollY,
					1, mRenderer.LineHeight(editor)), 0.1f, 0.1f, 0.1f);
		}
		mRenderer.Text(editor, bounds.X + 4 - editor.ScrollX, bounds.Y + 4 - editor.ScrollY);
	}

}
