using System;
using System.Windows.Forms;

using internal System.Windows.Forms;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	private void* mWindowIcon, mSmallWindowIcon;

	private void SetDefaultIcon(Form form)
	{
		let data = (Span<uint8>)DefaultIcon.Data;
		if (mWindowIcon == null)
		{
			mWindowIcon = Win32.CreateIconFromResourceEx(data.Ptr, (uint32)data.Length,
				1, 0x00030000, Win32.GetSystemMetrics(Win32.SM_CXICON), Win32.GetSystemMetrics(Win32.SM_CYICON), 0);
			mSmallWindowIcon = Win32.CreateIconFromResourceEx(data.Ptr, (uint32)data.Length,
				1, 0x00030000, Win32.GetSystemMetrics(Win32.SM_CXSMICON), Win32.GetSystemMetrics(Win32.SM_CYSMICON), 0);
		}
		Win32.SendMessage(form.GetHandle(), Win32.WM_SETICON, (uint*)(void*)1, (int*)mWindowIcon);
		Win32.SendMessage(form.GetHandle(), Win32.WM_SETICON, null, (int*)mSmallWindowIcon);
	}
}
#endif
