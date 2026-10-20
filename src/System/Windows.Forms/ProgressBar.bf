using internal System.Windows.Forms;

namespace System.Windows.Forms;

public class ProgressBar : Control
{
	protected override bool CanSelectCore() => false;
	private int mValue, mMinimum;
	private int mMaximum = 100;

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
