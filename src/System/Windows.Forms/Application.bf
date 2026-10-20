using System.Collections;
using internal System.Windows.Forms;

namespace System.Windows.Forms;

static class Application
{
	// Maps HWND to Control instances for message dispatching
	static Dictionary<void*, Control> sControlMap = new .() ~ delete _;

	public static void RegisterControl(Control c)
	{
		if (c.Handle != null)
		{
			sControlMap[c.Handle] = c;
		}
	}

	public static void UnregisterControl(Control c)
	{
		if (c.Handle != null)
		{
			sControlMap.Remove(c.Handle);
		}
	}

	public static Control GetControlFromHandle(void* hWnd)
	{
		if (sControlMap.TryGetValue(hWnd, var control))
		{
			return control;
		}
		return null;
	}

	public static void EnableVisualStyles()
	{
		// This is a simplified version. A full implementation requires manifests.
		var icex = Win32.INITCOMMONCONTROLSEX(dwSize: sizeof(Win32.INITCOMMONCONTROLSEX), dwICC: Win32.ICC_PROGRESS_CLASS);
		Win32.InitCommonControlsEx(icex);
	}

	public static void SetCompatibleTextRenderingDefault(bool defaultValue)
	{
		// Stub - not implemented
	}

	public static void Run(Form mainForm)
	{
		mainForm.CreateHandle();
		mainForm.Show();

		Win32.MSG msg = ?;
		while (Win32.GetMessage(out msg, null, 0, 0) > 0)
		{
			Win32.TranslateMessage(msg);
			Win32.DispatchMessage(msg);
		}

		delete mainForm;
	}
}