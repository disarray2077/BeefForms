using System;
using System.Drawing;
using System.Windows;

using internal System.Windows.Forms;

namespace System.Windows.Forms;

extension TextBoxBase
{
	internal int32 ScrollX { get; private set; }
	internal int32 ScrollY { get; private set; }
	private bool mScrollValidationPending = true;
	private bool mCaretRevealPending;
	private uint64 mCaretBlinkStartedAt;
	private const uint64 CaretVisibleDuration = 550;
	private const uint64 CaretBlinkPeriod = 1000;

	internal bool NeedsScrollPreparation => mScrollValidationPending || mCaretRevealPending;
	internal void InvalidateScroll() => mScrollValidationPending = true;
	internal void RequestCaretReveal() => mCaretRevealPending = true;
	internal void RestartCaretBlink(uint64 now) => mCaretBlinkStartedAt = now;
	private uint64 CaretPhase(uint64 now) => (Math.Max(now, mCaretBlinkStartedAt) - mCaretBlinkStartedAt) % CaretBlinkPeriod;
	internal bool IsCaretVisible(uint64 now) => CaretPhase(now) < CaretVisibleDuration;
	internal uint64 GetNextCaretTick(uint64 now)
	{
		let phase = CaretPhase(now);
		return now + (phase < CaretVisibleDuration ? CaretVisibleDuration - phase : CaretBlinkPeriod - phase);
	}

	// Explicit scrolling takes precedence over an outstanding caret reveal.
	internal void SetScrollOffset(Point offset)
	{
		ScrollX = Math.Max(0, offset.x);
		ScrollY = Math.Max(0, offset.y);
		mCaretRevealPending = false;
		InvalidateScroll();
		UpdateBackend(.Scroll);
	}

	internal void PrepareScroll(Point caret, int32 lineHeight, Size viewport, Size content, Size trailingMargin, bool focused)
	{
		if (focused && mCaretRevealPending)
		{
			ScrollX = Math.Max(caret.x - viewport.width + trailingMargin.width, Math.Min(ScrollX, caret.x));
			ScrollY = Math.Max(caret.y + lineHeight - viewport.height + trailingMargin.height, Math.Min(ScrollY, caret.y));
		}
		ScrollX = Math.Clamp(ScrollX, 0, Math.Max(0, content.width + trailingMargin.width - viewport.width));
		ScrollY = Math.Clamp(ScrollY, 0, Math.Max(0, content.height + trailingMargin.height - viewport.height));
		mScrollValidationPending = false;
		mCaretRevealPending = false;
	}
}
