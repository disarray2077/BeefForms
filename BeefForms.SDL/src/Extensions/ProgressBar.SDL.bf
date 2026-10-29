using System;

using internal System.Windows.Forms;

namespace System.Windows.Forms;

extension ProgressBar
{
	private uint64 mMarqueeStartedAt;

	internal bool IsMarqueeRunning => Style == .Marquee && MarqueeAnimationSpeed > 0;

	internal void RestartMarquee(uint64 now)
	{
		mMarqueeStartedAt = now;
	}

	internal uint64 GetMarqueeStep(uint64 now)
	{
		if (IsMarqueeRunning)
		{
			let elapsed = Math.Max(now, mMarqueeStartedAt) - mMarqueeStartedAt;
			return elapsed / (uint64)MarqueeAnimationSpeed;
		}
		return 0;
	}

	internal uint64 GetNextMarqueeTick(uint64 now)
	{
		if (IsMarqueeRunning)
		{
			let nextStep = GetMarqueeStep(now) + 1;
			return mMarqueeStartedAt + nextStep * (uint64)MarqueeAnimationSpeed;
		}
		return uint64.MaxValue;
	}
}
