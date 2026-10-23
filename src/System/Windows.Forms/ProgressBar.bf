using internal System.Windows.Forms;

namespace System.Windows.Forms;

public enum ProgressBarStyle { Blocks, Continuous, Marquee }

public class ProgressBar : Control
{
	protected override bool CanSelectCore() => false;
	private int mValue, mMinimum;
	private int mMaximum = 100;
	private ProgressBarStyle mStyle;
	private int32 mMarqueeAnimationSpeed = 100;
	private uint64 mMarqueeStartedAt;

	internal bool IsMarqueeRunning => Style == .Marquee && MarqueeAnimationSpeed > 0;
	internal void RestartMarquee(uint64 now) => mMarqueeStartedAt = now;
	internal uint64 GetMarqueeStep(uint64 now) => IsMarqueeRunning
		? (Math.Max(now, mMarqueeStartedAt) - mMarqueeStartedAt) / (uint64)MarqueeAnimationSpeed : 0;
	internal uint64 GetNextMarqueeTick(uint64 now) => IsMarqueeRunning
		? mMarqueeStartedAt + (GetMarqueeStep(now) + 1) * (uint64)MarqueeAnimationSpeed : uint64.MaxValue;

	public ProgressBarStyle Style
	{
		get => mStyle;
		set { mStyle = value; UpdateBackend(.Appearance); }
	}
	public int32 MarqueeAnimationSpeed
	{
		get => mMarqueeAnimationSpeed;
		set
		{
			if (value < 0) Runtime.FatalError("MarqueeAnimationSpeed must not be negative");
			mMarqueeAnimationSpeed = value;
			UpdateBackend(.Appearance);
		}
	}

	public int Minimum
	{
		get => mMinimum;
		set
		{
			if (value < 0) Runtime.FatalError("Minimum must not be negative");
			mMinimum = value;
			mMaximum = Math.Max(mMaximum, value);
			mValue = Math.Clamp(mValue, mMinimum, mMaximum);
			UpdateBackend(.Value);
		}
	}
	public int Maximum
	{
		get => mMaximum;
		set
		{
			if (value < 0) Runtime.FatalError("Maximum must not be negative");
			mMaximum = value;
			mMinimum = Math.Min(mMinimum, value);
			mValue = Math.Clamp(mValue, mMinimum, mMaximum);
			UpdateBackend(.Value);
		}
	}
	public int Value
	{
		get => mValue;
		set
		{
			if (value < mMinimum || value > mMaximum)
				Runtime.FatalError("Value must be between Minimum and Maximum");
			mValue = value;
			UpdateBackend(.Value);
		}
	}
}
