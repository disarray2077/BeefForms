using System;

using internal System.Windows.Forms;

namespace System.Windows.Forms;

extension ProgressBar
{
	private uint64 mMarqueeStartedAt;

	internal bool IsMarqueeRunning => Style == .Marquee && MarqueeAnimationSpeed > 0;
	internal void RestartMarquee(uint64 now) => mMarqueeStartedAt = now;
	internal uint64 GetMarqueeStep(uint64 now) => IsMarqueeRunning
		? (Math.Max(now, mMarqueeStartedAt) - mMarqueeStartedAt) / (uint64)MarqueeAnimationSpeed : 0;
	internal uint64 GetNextMarqueeTick(uint64 now) => IsMarqueeRunning
		? mMarqueeStartedAt + (GetMarqueeStep(now) + 1) * (uint64)MarqueeAnimationSpeed : uint64.MaxValue;
}
