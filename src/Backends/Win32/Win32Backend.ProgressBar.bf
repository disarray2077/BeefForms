using System;
using System.Windows.Forms;
using internal System.Windows.Forms;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	private void UpdateProgressBar(ProgressBar progress, ControlChange change)
	{
		if (change != .Value)
		{
			Win32.SendMessage(progress.Handle, Win32.PBM_SETMARQUEE, null, null);
			var style = (uint)(void*)Win32.GetWindowLongPtr(progress.Handle, Win32.GWL_STYLE);
			style &= ~(Win32.PBS_SMOOTH | Win32.PBS_MARQUEE);
			if (progress.Style == .Continuous) style |= Win32.PBS_SMOOTH;
			if (progress.Style == .Marquee) style |= Win32.PBS_MARQUEE;
			Win32.SetWindowLongPtr(progress.Handle, Win32.GWL_STYLE, (void*)style);
			if (progress.Style == .Marquee && progress.MarqueeAnimationSpeed > 0)
				Win32.SendMessage(progress.Handle, Win32.PBM_SETMARQUEE, (uint*)(void*)1, (int*)(void*)(int)progress.MarqueeAnimationSpeed);
		}
		if (progress.Style != .Marquee)
		{
			Win32.SendMessage(progress.Handle, Win32.PBM_SETRANGE32, (uint*)(void*)progress.Minimum, (int*)(void*)progress.Maximum);
			Win32.SendMessage(progress.Handle, Win32.PBM_SETPOS, (uint*)(void*)progress.Value, null);
		}
	}
}
#endif
