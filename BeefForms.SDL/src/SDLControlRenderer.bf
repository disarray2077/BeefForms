using System;
using System.Drawing;
using System.Windows;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal System.Drawing;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class SDLControlRenderer
{
	public struct PaintState : this(bool Focused, bool Hovered, bool Pressed, uint64 Ticks);

	private SDLCanvas mCanvas;
	private SDLTextRenderer mText;
	private SDLTextService mTextService;

	public this(SDLCanvas canvas, SDLTextRenderer text, SDLTextService textService)
	{
		mCanvas = canvas;
		mText = text;
		mTextService = textService;
	}

	private void Text(Control control, int x, int y) =>
		mText.Draw(control, x, y, control.IsEffectivelyEnabled ? 0f : 109f / 255);

	public void PaintControl(Control control, Rectangle bounds, Rectangle clip, PaintState state)
	{
		mCanvas.Clip(clip);
		let enabled = control.IsEffectivelyEnabled;
		let lineHeight = mTextService.LineHeight(control);
		if (control is ScrollableControl || control is GroupBox)
			mCanvas.Fill(bounds, 240f / 255, 240f / 255, 240f / 255);
		if (let checkBox = control as CheckBox)
		{
			int32 side = Math.Min(13, Math.Max(0, bounds.Height));
			let indicator = Rectangle(bounds.X, bounds.Y + (bounds.Height - side) / 2, side, side);
			mCanvas.Fill(indicator, 1, 1, 1);
			mCanvas.Border(indicator, enabled ? 0.45f : 0.7f, enabled ? 0.45f : 0.7f, enabled ? 0.45f : 0.7f);
			if (checkBox.Checked)
				for (int32 x < Math.Max(0, side - 4))
				{
					let y = x < 3 ? x : 6 - x;
					mCanvas.Fill(.(indicator.X + x + 2, indicator.Y + side / 2 + y - 1, 2, 2), 0.15f, 0.4f, 0.65f);
				}
			Text(control, bounds.X + side + 4, bounds.Y + (bounds.Height - lineHeight) / 2);
			if (state.Focused) mCanvas.Border(bounds, 0.35f, 0.5f, 0.7f);
		}
		else if (control is Button)
		{
			let shade = state.Pressed && state.Hovered ? 0.9f : enabled && state.Hovered ? 0.96f : 253f / 255;
			if (state.Focused) mCanvas.RoundedFill(bounds, 0, 120f / 255, 215f / 255);
			else mCanvas.RoundedFill(bounds, enabled ? 0.8f : 0.9f, enabled ? 0.8f : 0.9f, enabled ? 0.8f : 0.9f);
			mCanvas.RoundedFill(.(bounds.X + 1, bounds.Y + 1, bounds.Width - 2, bounds.Height - 2), shade, shade, shade);
			let textWidth = mTextService.Measure(control, control.Text);
			Text(control, bounds.X + (bounds.Width - textWidth) / 2, bounds.Y + (bounds.Height - lineHeight) / 2);
		}
		else if (let progress = control as ProgressBar)
			PaintProgressBar(progress, bounds, clip, state.Ticks);
		else if (let editor = control as TextBoxBase)
			PaintEditor(editor, bounds, clip, state);
		else if (control is GroupBox)
		{
			mCanvas.Border(.(bounds.X, bounds.Y + lineHeight / 2, bounds.Width, bounds.Height - lineHeight / 2), 0.7f, 0.7f, 0.72f);
			mCanvas.Fill(.(bounds.X + 7, bounds.Y, mTextService.Measure(control, control.Text) + 6, lineHeight), 240f / 255, 240f / 255, 240f / 255);
			Text(control, bounds.X + 10, bounds.Y);
		}
		else if (let label = control as Label)
			PaintLabel(label, bounds);
		else if (control.BorderStyle != .None)
			mCanvas.Border(bounds, 100f / 255, 100f / 255, 100f / 255);
	}

	public void PaintScrollbars(Control control, Rectangle bounds, Rectangle clip)
	{
		int32 border = (control is Form) ? 0 : control.BorderWidth;
		if (let scrollable = control as ScrollableControl)
		{
			mCanvas.Clip(clip);
			for (let horizontal in scope bool[](true, false))
			{
				var track = scrollable.ScrollTrack(horizontal);
				if (track.Width == 0 || track.Height == 0) continue;
				var thumb = scrollable.ScrollThumb(horizontal);
				track.X += bounds.X + border; track.Y += bounds.Y + border;
				thumb.X += bounds.X + border; thumb.Y += bounds.Y + border;
				mCanvas.Fill(track, 0.88f, 0.89f, 0.90f);
				mCanvas.Fill(thumb, 0.58f, 0.60f, 0.64f);
			}
		}
	}

	private void PaintEditor(TextBoxBase editor, Rectangle bounds, Rectangle parentClip, PaintState state)
	{
		const int32 textInset = SDLTextService.EditorTextInset;
		let background = editor.ReadOnly ? 240f / 255 : 1f;
		mCanvas.Fill(bounds, background, background, background);
		if (editor.BorderStyle != .None)
			if (state.Focused) mCanvas.Border(bounds, 0, 120f / 255, 215f / 255);
			else mCanvas.Border(bounds, 0.68f, 0.68f, 0.68f);
		let clip = parentClip.Intersect(.(bounds.X + 2, bounds.Y + 2, Math.Max(0, bounds.Width - 4), Math.Max(0, bounds.Height - 4)));
		mCanvas.Clip(clip);
		let caret = mTextService.TextPosition(editor, editor.Caret);
		if (state.Focused)
		{
			if (editor.SelectionByteLength > 0)
			{
				int start = editor.SelectionByteStart;
				let end = start + editor.SelectionByteLength;
				while (start < end)
				{
					var lineEnd = editor.Multiline ? editor.Text.IndexOf('\n', start) : -1;
					if (lineEnd < 0 || lineEnd > end) lineEnd = end;
					let a = mTextService.TextPosition(editor, start);
					let b = mTextService.TextPosition(editor, lineEnd);
					mCanvas.Fill(.(bounds.X + textInset + a.x - editor.ScrollX, bounds.Y + textInset + a.y - editor.ScrollY,
						Math.Max(2, b.x - a.x), mTextService.LineHeight(editor)), 0.65f, 0.8f, 1);
					start = lineEnd + 1;
				}
			}
			if (!editor.ReadOnly && editor.IsCaretVisible(state.Ticks))
				mCanvas.Fill(.(bounds.X + textInset + caret.x - editor.ScrollX, bounds.Y + textInset + caret.y - editor.ScrollY,
					1, mTextService.LineHeight(editor)), 0.1f, 0.1f, 0.1f);
		}
		Text(editor, bounds.X + textInset - editor.ScrollX, bounds.Y + textInset - editor.ScrollY);
	}

	private void PaintLabel(Label label, Rectangle bounds)
	{
		let size = mTextService.MeasureText(label);
		int32 x = bounds.X + mTextService.LabelPadding(label), y = bounds.Y;
		if (label.TextAlign.Horizontal == .Center) x += (bounds.Width - size.width) / 2;
		if (label.TextAlign.Horizontal == .Right) x += bounds.Width - size.width;
		if (label.TextAlign.Vertical == .Middle) y += (bounds.Height - size.height) / 2;
		if (label.TextAlign.Vertical == .Bottom) y += bounds.Height - size.height;
		Text(label, x, y);
	}

	private void PaintProgressBar(ProgressBar progress, Rectangle bounds, Rectangle clip, uint64 now)
	{
		mCanvas.Fill(bounds, 230f / 255, 230f / 255, 230f / 255);
		let track = Rectangle(bounds.X + 1, bounds.Y + 1, Math.Max(0, bounds.Width - 2), Math.Max(0, bounds.Height - 2));
		mCanvas.Clip(clip.Intersect(track));
		if (progress.Style == .Marquee)
		{
			if (progress.MarqueeAnimationSpeed > 0 && track.Width > 0 && track.Height > 0)
			{
				let segment = Math.Max(8, track.Width / 4);
				let step = progress.GetMarqueeStep(now);
				// Match the native marquee's six-pixel movement per timer tick.
				let position = (step + 1) * 6;
				let offset = (int)(position % (uint64)(track.Width + segment)) - segment;
				mCanvas.Fill(.((int32)(track.X + offset), track.Y, (int32)segment, track.Height), 0, 128f / 255, 0);
			}
		}
		else
		{
			let range = progress.Maximum - progress.Minimum;
			int32 width = range == 0 ? 0 : (int32)((int64)track.Width * (progress.Value - progress.Minimum) / range);
			// Themed Win32 progress bars use a solid fill for both determinate styles.
			mCanvas.Fill(.(track.X, track.Y, width, track.Height), 0, 128f / 255, 0);
		}
		mCanvas.Clip(clip);
		mCanvas.Border(bounds, 188f / 255, 188f / 255, 188f / 255);
	}
}
