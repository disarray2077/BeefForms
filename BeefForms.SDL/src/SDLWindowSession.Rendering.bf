using System;
using System.Collections;
using System.Drawing;
using System.Windows.Forms;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

extension SDLWindowSession
{
	internal void HandleExposure(uint32 timestamp)
	{
		if (!CanRender)
			return;
		mHandledExposureTimestamp = timestamp;
		UpdateFormSize();
		RenderIfNeeded();
	}

	private bool CanRender
	{
		get
		{
			if (!IsCurrentWindow(mWindowGeneration))
				return false;
			if (!mForm.IsEffectivelyVisible)
				return false;
			if ((SDL.GetWindowFlags(mWindow) & (uint32)SDL.WindowFlags.Minimized) != 0)
				return false;
			if (!mShowPending && (SDL.GetWindowFlags(mWindow) & (uint32)SDL.WindowFlags.Hidden) != 0)
				return false;
			return true;
		}
	}

	internal int32 GetRedrawTimeout()
	{
		if (!CanRender)
			return -1;
		if (mRedrawRequested)
			return 0;
		if (mNextAnimationTick == uint64.MaxValue)
			return -1;
		let now = SDL.GetTicks64();
		return now >= mNextAnimationTick ? 0 : (int32)Math.Min(mNextAnimationTick - now, (uint64)int32.MaxValue);
	}

	internal bool RenderIfNeeded(bool force = false, bool capture = false)
	{
		if (capture && mCanvas == null)
			Runtime.FatalError("Frame capture requires rendering to be enabled");
		if (mRendering || !CanRender || (!force && GetRedrawTimeout() != 0))
			return false;
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
		if (!IsCurrentWindow(snapshot))
			return;
		mCanvas?.Begin(mWindow);
		let size = GetClientSize(mForm);
		RenderControl(mForm, .(0, 0, size.width, size.height), .(0, 0, size.width, size.height), snapshot);
		if (!IsCurrentWindow(snapshot))
			return;
		if (capture)
		{
			mCanvas.Capture(mBackend.CapturePath);
			mBackend.CapturePath = null;
		}
		if (mContext != default)
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
		for (let child in control.Controls)
			InvalidateTree(child);
	}

	private void RenderControl(Control control, Rectangle bounds, Rectangle parentClip, Generation snapshot)
	{
		if (!IsCurrentControl(control, snapshot) || !control.IsEffectivelyVisible)
			return;
		var clip = bounds.Intersect(parentClip);
		if (clip.Width == 0 || clip.Height == 0)
			return;
		let focused = IsFocused(control);
		if (let editor = control as TextBoxBase)
		{
			if (editor.NeedsScrollPreparation)
			{
				let text = mBackend.TextService;
				editor.PrepareScroll(text.TextPosition(editor, editor.Caret), text.LineHeight(editor), .(bounds.Width, bounds.Height),
					text.MeasureEditorContent(editor), SDLTextService.EditorScrollMargin, focused);
			}
			if (focused && !editor.ReadOnly)
				mNextAnimationTick = Math.Min(mNextAnimationTick, editor.GetNextCaretTick(mFrameTicks));
		}
		else if (let progress = control as ProgressBar)
		{
			if (progress.IsMarqueeRunning && bounds.Width > 2 && bounds.Height > 2)
				mNextAnimationTick = Math.Min(mNextAnimationTick, progress.GetNextMarqueeTick(mFrameTicks));
		}
		mControlRenderer?.PaintControl(control, bounds, clip, .(focused, control == mHovered, control == mPressed, mFrameTicks));

		if (control.NeedsPaint)
			control.NotifyPaint();
		// Paint can synchronously close the form and destroy its GL context.
		if (!IsCurrentControl(control, snapshot))
			return;

		let viewport = control.ViewportSize;
		int32 border = (control is Form) ? 0 : control.BorderWidth;
		let childClip = clip.Intersect(.(bounds.X + border, bounds.Y + border, viewport.width, viewport.height));
		let children = scope List<Control>();
		for (let child in control.Controls)
			children.Add(child);
		for (let child in children)
		{
			if (child.Parent != control)
				continue;
			let childSize = child.Size;
			RenderControl(child, .(bounds.X + border + child.Location.x - control.ContentOffset.x, bounds.Y + border + child.Location.y - control.ContentOffset.y, childSize.width, childSize.height), childClip, snapshot);
			if (!IsCurrentControl(control, snapshot))
				return;
		}
		mControlRenderer?.PaintScrollbars(control, bounds, clip);
	}
}
