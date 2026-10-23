using System;
using System.Collections;
using System.Threading;
using System.Drawing;
using System.Windows.Forms;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

extension SDLWindowSession
{
	internal void HandleExposure(uint32 timestamp)
	{
		if (!CanRender) return;
		mHandledExposureTimestamp = timestamp;
		UpdateFormSize();
		RenderIfNeeded();
	}

	private bool CanRender => IsCurrentWindow(mWindowGeneration) && mForm.IsEffectivelyVisible &&
		(SDL.GetWindowFlags(mWindow) & (uint32)SDL.WindowFlags.Minimized) == 0 &&
		(mShowPending || (SDL.GetWindowFlags(mWindow) & (uint32)SDL.WindowFlags.Hidden) == 0);

	internal int32 GetRedrawTimeout()
	{
		if (!CanRender) return -1;
		if (mRedrawRequested) return 0;
		if (mNextAnimationTick == uint64.MaxValue) return -1;
		let now = SDL.GetTicks64();
		return now >= mNextAnimationTick ? 0 : (int32)Math.Min(mNextAnimationTick - now, (uint64)int32.MaxValue);
	}

	internal bool RenderIfNeeded(bool force = false, bool capture = false)
	{
		if (mRendering || !CanRender || (!force && GetRedrawTimeout() != 0)) return false;
		RenderFrame(capture);
		return true;
	}

	private void RenderFrame(bool capture = false)
	{
		let snapshot = mWindowGeneration;
		mRendering = true;
		defer { mRendering = false; }
		// Clear before drawing so invalidation from layout or Paint schedules another frame.
		mRedrawRequested = false;
		mFrameTicks = SDL.GetTicks64();
		mNextAnimationTick = uint64.MaxValue;
		mForm.NotifyResize(GetFormSize());
		if (!IsCurrentWindow(snapshot)) return;
		mRenderer.Begin(mWindow);
		let size = GetClientSize(mForm);
		RenderControl(mForm, .(0, 0, size.width, size.height), .(0, 0, size.width, size.height), snapshot);
		if (!IsCurrentWindow(snapshot)) return;
		if (capture)
		{
			mRenderer.Capture(mBackend.CapturePath);
			mBackend.CapturePath = null;
		}
		SDL.GL_SwapWindow(mWindow);
		if (mShowPending && mForm.IsEffectivelyVisible)
		{
			mShowPending = false;
			SDL.ShowWindow(mWindow);
			SetActive(SDL.GetKeyboardFocus() == mWindow);
		}
	}

	private static void InvalidateTree(Control control)
	{
		control.Invalidate();
		for (let child in control.Controls) InvalidateTree(child);
	}

	private void RenderControl(Control control, Rectangle bounds, Rectangle parentClip, Generation snapshot)
	{
		if (!IsCurrentControl(control, snapshot) || !control.IsEffectivelyVisible) return;
		var clip = bounds.Intersect(parentClip);
		if (clip.Width == 0 || clip.Height == 0)
			return;
		mRenderer.Clip(clip);
		let enabled = control.IsEffectivelyEnabled;
		let lineHeight = mRenderer.LineHeight(control);
		if (control is ScrollableControl || control is GroupBox)
			mRenderer.Fill(bounds, 240f / 255, 240f / 255, 240f / 255);
		if (let checkBox = control as CheckBox)
		{
			int32 side = Math.Min(13, Math.Max(0, bounds.Height));
			let indicator = Rectangle(bounds.X, bounds.Y + (bounds.Height - side) / 2, side, side);
			mRenderer.Fill(indicator, 1, 1, 1);
			mRenderer.Border(indicator, enabled ? 0.45f : 0.7f, enabled ? 0.45f : 0.7f, enabled ? 0.45f : 0.7f);
			if (checkBox.Checked)
				for (int32 x < Math.Max(0, side - 4))
				{
					let y = x < 3 ? x : 6 - x;
					mRenderer.Fill(.(indicator.X + x + 2, indicator.Y + side / 2 + y - 1, 2, 2), 0.15f, 0.4f, 0.65f);
				}
			mRenderer.Text(control, bounds.X + side + 4, bounds.Y + (bounds.Height - lineHeight) / 2);
			if (IsFocused(control)) mRenderer.Border(bounds, 0.35f, 0.5f, 0.7f);
		}
		else if (control is Button)
		{
			let shade = control == mPressed && control == mHovered ? 0.9f : enabled && control == mHovered ? 0.96f : 253f / 255;
			if (IsFocused(control)) mRenderer.RoundedFill(bounds, 0, 120f / 255, 215f / 255);
			else mRenderer.RoundedFill(bounds, enabled ? 0.8f : 0.9f, enabled ? 0.8f : 0.9f, enabled ? 0.8f : 0.9f);
			mRenderer.RoundedFill(.(bounds.X + 1, bounds.Y + 1, bounds.Width - 2, bounds.Height - 2), shade, shade, shade);
			let textWidth = mRenderer.Measure(control, control.Text);
			mRenderer.Text(control, bounds.X + (bounds.Width - textWidth) / 2, bounds.Y + (bounds.Height - lineHeight) / 2);
		}
		else if (let progress = control as ProgressBar)
			RenderProgressBar(progress, bounds, clip);
		else if (let editor = control as TextBoxBase)
			RenderEditor(editor, bounds, clip);
		else if (control is GroupBox)
		{
			mRenderer.Border(.(bounds.X, bounds.Y + lineHeight / 2, bounds.Width, bounds.Height - lineHeight / 2), 0.7f, 0.7f, 0.72f);
			mRenderer.Fill(.(bounds.X + 7, bounds.Y, mRenderer.Measure(control, control.Text) + 6, lineHeight), 240f / 255, 240f / 255, 240f / 255);
			mRenderer.Text(control, bounds.X + 10, bounds.Y);
		}
		else if (let label = control as Label)
			RenderLabel(label, bounds);
		else if (control.BorderStyle != .None)
			mRenderer.Border(bounds, 100f / 255, 100f / 255, 100f / 255);

		if (control.NeedsPaint) control.NotifyPaint();
		// Paint can synchronously close the form and destroy its GL context.
		if (!IsCurrentControl(control, snapshot)) return;

		let viewport = control.ViewportSize;
		int32 border = (control is Form) ? 0 : control.BorderWidth;
		let childClip = clip.Intersect(.(bounds.X + border, bounds.Y + border, viewport.width, viewport.height));
		let children = scope List<Control>();
		for (let child in control.Controls) children.Add(child);
		for (let child in children)
		{
			if (child.Parent != control) continue;
			let childSize = child.Size;
			RenderControl(child, .(bounds.X + border + child.Location.x - control.ContentOffset.x, bounds.Y + border + child.Location.y - control.ContentOffset.y, childSize.width, childSize.height), childClip, snapshot);
			if (!IsCurrentControl(control, snapshot)) return;
		}
		if (let scrollable = control as ScrollableControl)
		{
			mRenderer.Clip(clip);
			for (let horizontal in scope bool[](true, false))
			{
				var track = scrollable.ScrollTrack(horizontal);
				if (track.Width == 0 || track.Height == 0) continue;
				var thumb = scrollable.ScrollThumb(horizontal);
				track.X += bounds.X + border; track.Y += bounds.Y + border;
				thumb.X += bounds.X + border; thumb.Y += bounds.Y + border;
				mRenderer.Fill(track, 0.88f, 0.89f, 0.90f);
				mRenderer.Fill(thumb, 0.58f, 0.60f, 0.64f);
			}
		}
	}

	private void RenderEditor(TextBoxBase editor, Rectangle bounds, Rectangle parentClip)
	{
		const int32 textInset = SDLTextService.EditorTextInset;
		let background = editor.ReadOnly ? 240f / 255 : 1f;
		mRenderer.Fill(bounds, background, background, background);
		if (editor.BorderStyle != .None)
			if (IsFocused(editor)) mRenderer.Border(bounds, 0, 120f / 255, 215f / 255);
			else mRenderer.Border(bounds, 0.68f, 0.68f, 0.68f);
		let clip = parentClip.Intersect(.(bounds.X + 2, bounds.Y + 2, Math.Max(0, bounds.Width - 4), Math.Max(0, bounds.Height - 4)));
		mRenderer.Clip(clip);
		let caret = mRenderer.TextPosition(editor, editor.Caret);
		if (IsFocused(editor))
		{
			editor.ScrollX = Math.Max(0, Math.Max(caret.x - bounds.Width + 10, Math.Min(editor.ScrollX, caret.x)));
			editor.ScrollY = Math.Max(0, Math.Max(caret.y + mRenderer.LineHeight(editor) - bounds.Height + 8, Math.Min(editor.ScrollY, caret.y)));
			if (editor.SelectionByteLength > 0)
			{
				int start = editor.SelectionByteStart;
				let end = start + editor.SelectionByteLength;
				while (start < end)
				{
					var lineEnd = editor.Text.IndexOf('\n', start);
					if (lineEnd < 0 || lineEnd > end) lineEnd = end;
					let a = mRenderer.TextPosition(editor, start);
					let b = mRenderer.TextPosition(editor, lineEnd);
					mRenderer.Fill(.(bounds.X + textInset + a.x - editor.ScrollX, bounds.Y + textInset + a.y - editor.ScrollY,
						Math.Max(2, b.x - a.x), mRenderer.LineHeight(editor)), 0.65f, 0.8f, 1);
					start = lineEnd + 1;
				}
			}
			if (!editor.ReadOnly)
			{
				let phase = mFrameTicks % 1000;
				mNextAnimationTick = Math.Min(mNextAnimationTick, mFrameTicks + (phase < 550 ? 550 - phase : 1000 - phase));
				if (phase < 550)
					mRenderer.Fill(.(bounds.X + textInset + caret.x - editor.ScrollX, bounds.Y + textInset + caret.y - editor.ScrollY,
						1, mRenderer.LineHeight(editor)), 0.1f, 0.1f, 0.1f);
			}
		}
		mRenderer.Text(editor, bounds.X + textInset - editor.ScrollX, bounds.Y + textInset - editor.ScrollY);
	}

}
