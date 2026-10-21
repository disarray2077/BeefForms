using System;
using System.Collections;
using System.Drawing;
using System.Windows.Forms;
using SDL2;

namespace BeefForms.Backends;

extension SDLBackend
{
	private Dictionary<ProgressBar, uint64> mMarqueeStarts = new .() ~ delete _;

	private void UpdateMarquee(ProgressBar progress)
	{
		if (progress.Style == .Marquee && progress.MarqueeAnimationSpeed > 0)
			mMarqueeStarts[progress] = SDL.GetTicks64();
		else
			mMarqueeStarts.Remove(progress);
	}

	private void RenderProgressBar(ProgressBar progress, Rectangle bounds, Rectangle clip)
	{
		mRenderer.Fill(bounds, 230f / 255, 230f / 255, 230f / 255);
		let track = Rectangle(bounds.X + 1, bounds.Y + 1, Math.Max(0, bounds.Width - 2), Math.Max(0, bounds.Height - 2));
		mRenderer.Clip(Intersect(clip, track));
		if (progress.Style == .Marquee)
		{
			if (progress.MarqueeAnimationSpeed > 0 && track.Width > 0 && track.Height > 0)
			{
				let segment = Math.Max(8, track.Width / 4);
				let interval = (uint64)progress.MarqueeAnimationSpeed;
				let started = mMarqueeStarts[progress];
				let elapsed = Math.Max(mFrameTicks, started) - started;
				let step = elapsed / interval;
				mNextAnimationTick = Math.Min(mNextAnimationTick, started + (step + 1) * interval);
				// Match the native marquee's six-pixel movement per timer tick.
				let position = (step + 1) * 6;
				let offset = (int)(position % (uint64)(track.Width + segment)) - segment;
				mRenderer.Fill(.((int32)(track.X + offset), track.Y, (int32)segment, track.Height), 0, 128f / 255, 0);
			}
		}
		else
		{
			let range = progress.Maximum - progress.Minimum;
			int32 width = range == 0 ? 0 : (int32)((int64)track.Width * (progress.Value - progress.Minimum) / range);
			// Themed Win32 progress bars use a solid fill for both determinate styles.
			mRenderer.Fill(.(track.X, track.Y, width, track.Height), 0, 128f / 255, 0);
		}
		mRenderer.Clip(clip);
		mRenderer.Border(bounds, 188f / 255, 188f / 255, 188f / 255);
	}
}
