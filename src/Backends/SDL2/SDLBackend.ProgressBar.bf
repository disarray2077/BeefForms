using System;
using System.Drawing;
using System.Windows.Forms;
using SDL2;

namespace BeefForms.Backends;

extension SDLBackend
{
	private void RenderProgressBar(ProgressBar progress, Rectangle bounds, Rectangle clip)
	{
		mRenderer.Fill(bounds, 0.85f, 0.86f, 0.87f);
		let track = Rectangle(bounds.X + 2, bounds.Y + 2, Math.Max(0, bounds.Width - 4), Math.Max(0, bounds.Height - 4));
		mRenderer.Clip(Intersect(clip, track));
		if (progress.Style == .Marquee)
		{
			if (progress.MarqueeAnimationSpeed > 0 && track.Width > 0)
			{
				let segment = Math.Max(8, track.Width / 4);
				let offset = (int)(SDL.GetTicks() / (uint32)progress.MarqueeAnimationSpeed) % (track.Width + segment) - segment;
				mRenderer.Fill(.((int32)(track.X + offset), track.Y, (int32)segment, track.Height), 0.2f, 0.65f, 0.38f);
			}
		}
		else
		{
			let range = progress.Maximum - progress.Minimum;
			int32 width = range == 0 ? 0 : (int32)((int64)track.Width * (progress.Value - progress.Minimum) / range);
			if (progress.Style == .Continuous)
				mRenderer.Fill(.(track.X, track.Y, width, track.Height), 0.2f, 0.65f, 0.38f);
			else
				for (int32 x = 0; x < width; x += 10)
					mRenderer.Fill(.(track.X + x, track.Y, Math.Min(8, width - x), track.Height), 0.2f, 0.65f, 0.38f);
		}
		mRenderer.Clip(clip);
		mRenderer.Border(bounds, 0.6f, 0.62f, 0.65f);
	}
}
