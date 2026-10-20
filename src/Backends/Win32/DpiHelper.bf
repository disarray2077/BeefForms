#if BF_PLATFORM_WINDOWS
namespace System;

static class DpiHelper
{
	// Win32 API functions needed for DPI awareness
	[Import("user32.dll"), CLink]
	private static extern bool SetProcessDPIAware();

	[Import("user32.dll"), CLink]
	private static extern void* GetDC(void* hWnd);
	[Import("user32.dll"), CLink]
	private static extern int ReleaseDC(void* hWnd, void* hDC);
	[Import("gdi32.dll"), CLink]
	private static extern int GetDeviceCaps(void* hdc, int nIndex);

	private const int LOGPIXELSX = 88; // Logical pixels/inch in X
	private const float DEFAULT_DPI = 96.0f;

	private static float sScaleFactor = -1.0f;

	/// <summary>
	/// Makes the application DPI-aware. This should be called once at startup.
	/// </summary>
	public static void SetDpiAware()
	{
		// This is an older but simpler way to set DPI awareness.
		// Modern apps use SetProcessDpiAwarenessContext or a manifest file.
		SetProcessDPIAware();
	}

	/// <summary>
	/// Gets the DPI scaling factor for the primary display.
	/// (e.g., 1.0 for 96 DPI, 1.25 for 120 DPI, 1.5 for 144 DPI)
	/// </summary>
	public static float GetScaleFactor()
	{
		if (sScaleFactor > 0)
		{
			return sScaleFactor;
		}

		// Get the device context for the entire screen
		void* screenDC = GetDC(null);
		if (screenDC == null)
		{
			sScaleFactor = 1.0f;
			return sScaleFactor;
		}

		// Get the logical pixels per inch
		int currentDpi = GetDeviceCaps(screenDC, LOGPIXELSX);
		ReleaseDC(null, screenDC);

		sScaleFactor = currentDpi / DEFAULT_DPI;
		return sScaleFactor;
	}

	/// <summary>
	/// Scales an integer value by the system DPI factor.
	/// </summary>
	public static int32 Scale(int32 value)
	{
		return (int32)(value * GetScaleFactor());
	}

	/// <summary>
	/// Unscales an integer value by the system DPI factor, converting it from
	/// physical pixels back to logical pixels.
	/// </summary>
	public static int32 Unscale(int32 value)
	{
	    float scaleFactor = GetScaleFactor();
	    return scaleFactor != 0 ? (int32)(value / scaleFactor) : 0;
	}
}
#endif
