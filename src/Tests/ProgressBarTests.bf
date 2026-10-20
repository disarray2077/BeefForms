using System;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class ProgressBarTests
{
	[Test]
	public static void ProgressRangesAdjustEndpointsAndClampTheCurrentValue()
	{
		let progress = scope ProgressBar();
		progress.Minimum = 20;
		Test.Assert(progress.Value == 20 && progress.Maximum == 100);
		progress.Maximum = 200;
		progress.Value = 150;
		progress.Maximum = 50;
		Test.Assert(progress.Value == 50 && progress.Minimum == 20);
		progress.Minimum = 80;
		Test.Assert(progress.Value == 80 && progress.Maximum == 80);
		progress.Maximum = 10;
		Test.Assert(progress.Minimum == 10 && progress.Value == 10);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeProgressUsesTheConfiguredRange()
	{
		Application.UseBackend(.Win32);
		Application.EnableVisualStyles();
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let progress = new ProgressBar();
		progress.Size = .(150, 20);
		form.Controls.Add(progress);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		progress.Minimum = 20;
		progress.Maximum = 200;
		progress.Value = 150;
		Test.Assert((int)(void*)Win32.SendMessage(progress.Handle, Win32.PBM_GETRANGE, (uint*)(void*)1, null) == 20);
		Test.Assert((int)(void*)Win32.SendMessage(progress.Handle, Win32.PBM_GETRANGE, null, null) == 200);
		Test.Assert((int)(void*)Win32.SendMessage(progress.Handle, Win32.PBM_GETPOS, null, null) == 150);
	}
#endif
}
