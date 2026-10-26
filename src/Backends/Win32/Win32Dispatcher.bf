using System;
using System.Windows.Forms;

using internal System.Windows.Forms;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
internal static class Win32Dispatcher
{
	private static void* sWindow;
	private static bool sRegistered;
	private static char16[?] sWindowClass = "BeefFormsDispatcher".ToConstNativeW();
	private const uint32 DispatchMessage = Win32.WM_USER + 1;

	public static void Initialize()
	{
		if (sWindow != null)
			return;
		let instance = Win32.GetModuleHandle(null);
		if (!sRegistered)
		{
			Win32.WNDCLASSEX definition = .(sizeof(Win32.WNDCLASSEX), 0, => WindowProc, 0, 0,
				instance, null, null, null, null, &sWindowClass, null);
			if (Win32.RegisterClassEx(definition) == 0)
				Runtime.FatalError("Could not register the dispatch window class");
			sRegistered = true;
		}
		sWindow = Win32.CreateWindowEx(0, &sWindowClass, null, 0, 0, 0, 0, 0,
			(void*)(int)(-3) /* HWND_MESSAGE */, null, instance, null);
		if (sWindow == null)
			Runtime.FatalError("Could not create the dispatch window");
	}

	public static void Wake(uint64 target)
	{
		// Each invocation needs a message: a callback can enter a nested native loop.
		// Split the identity so both 32-bit and 64-bit Windows preserve it.
		Win32.PostMessage(sWindow, DispatchMessage, (uint*)(void*)(uint)(uint32)target, (int*)(void*)(uint)(uint32)(target >> 32));
	}

	public static void Shutdown()
	{
		let window = sWindow;
		sWindow = null;
		if (window != null)
			Win32.DestroyWindow(window);
	}

	private static Win32.LRESULT WindowProc(void* window, uint32 message, uint32* wParam, int32* lParam)
	{
		if (message == DispatchMessage)
		{
			let target = (uint64)(uint)(void*)wParam | ((uint64)(uint)(void*)lParam << 32);
			Application.DispatcherCore.ProcessTarget(target);
			return 0;
		}
		return Win32.DefWindowProc(window, message, wParam, lParam);
	}
}
#endif
