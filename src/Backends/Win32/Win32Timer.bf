using System;

using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
internal static class Win32Timer
{
	private static void* sWindow;
	private static bool sRegistered;
	private static char16[?] sWindowClass = "BeefFormsTimer".ToConstNativeW();

	internal static void Start(uint registration, int32 interval)
	{
		if (sWindow == null)
		{
			let instance = Win32.GetModuleHandle(null);
			if (!sRegistered)
			{
				Win32.WNDCLASSEX definition = .(sizeof(Win32.WNDCLASSEX), 0, => WindowProc, 0, 0,
					instance, null, null, null, null, &sWindowClass, null);
				if (Win32.RegisterClassEx(definition) == 0)
					Runtime.FatalError("Could not register the timer window class");
				sRegistered = true;
			}
			sWindow = Win32.CreateWindowEx(0, &sWindowClass, null, 0, 0, 0, 0, 0,
				(void*)(int)(-3) /* HWND_MESSAGE */, null, instance, null);
			if (sWindow == null)
				Runtime.FatalError("Could not create the timer window");
		}
		if (Win32.SetTimer(sWindow, registration, (uint32)interval, null) == 0)
			Runtime.FatalError("Could not start the timer");
	}

	internal static void Stop(uint registration)
	{
		Win32.KillTimer(sWindow, registration);
		if (TimerScheduler.IsEmpty)
		{
			let window = sWindow;
			sWindow = null;
			Win32.DestroyWindow(window);
		}
	}

	internal static void Process()
	{
		Win32.MSG message = ?;
		while (sWindow != null && Win32.PeekMessage(out message, sWindow, Win32.WM_TIMER, Win32.WM_TIMER, Win32.PM_REMOVE) != 0)
			Win32.DispatchMessage(message);
	}

	private static Win32.LRESULT WindowProc(void* window, uint32 message, uint32* wParam, int32* lParam)
	{
		if (message == Win32.WM_TIMER)
		{
			TimerScheduler.Dispatch((uint)(void*)wParam);
			return 0;
		}
		return Win32.DefWindowProc(window, message, wParam, lParam);
	}
}
#endif
