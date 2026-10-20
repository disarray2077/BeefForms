namespace System.Windows.Forms;

public class ProgressBar : Control
{
	private int mValue = 0;

	public int Value
	{
		get => mValue;
		set
		{
			mValue = value;
			if (Handle != null)
			{
				Win32.SendMessage(Handle, Win32.PBM_SETPOS, (uint*)(void*)value, null);
			}
		}
	}

	protected override char8* WindowClassName => Win32.PROGRESS_CLASS;
	protected override uint WindowStyle => base.WindowStyle | Win32.PBS_SMOOTH;

	protected internal override void CreateHandle()
	{
		base.CreateHandle();

		// Set initial value when handle is created
		if (Handle != null)
		{
			Win32.SendMessage(Handle, Win32.PBM_SETPOS, (uint*)(void*)mValue, null);
		}
	}
}