using internal System.Windows.Forms;

namespace System.Windows.Forms;

public class Form : ContainerControl
{
    private static bool sWindowClassRegistered = false;
	private static char8* sWindowClassName = "BeefWinForm";

	public System.Drawing.Size ClientSize
	{
		get
		{
			if (Handle != null)
			{
				Win32.GetClientRect(Handle, var rect);
				return System.Drawing.Size(rect.right, rect.bottom);
			}
			return base.Size;
		}
		set
		{
			if (Handle != null)
			{
				var style = Win32.GetWindowLongPtr(Handle, -16); // GWL_STYLE
				var exStyle = Win32.GetWindowLongPtr(Handle, -20); // GWL_EXSTYLE

				var rect = Win32.RECT(0, 0, value.width, value.height);
				Win32.AdjustWindowRectEx(ref rect, (uint)style, false, (uint)exStyle);

	            var totalWidth = rect.right - rect.left;
	            var totalHeight = rect.bottom - rect.top;
				base.Size = .(totalWidth, totalHeight);
			}
			else
			{
				base.Size = value;
			}
		}
	}

	protected override char8* WindowClassName => sWindowClassName;
	protected override uint WindowStyle => Win32.WS_OVERLAPPEDWINDOW | Win32.WS_CLIPCHILDREN;

	public this()
	{
		RegisterWindowClass();
	}

	public void Show()
	{
		if (Handle != null)
		{
			Win32.ShowWindow(Handle, Win32.SW_SHOW);
		}
	}

	private static void RegisterWindowClass()
	{
		if (sWindowClassRegistered) return;

		var wc = Win32.WNDCLASSEX(
			cbSize: sizeof(Win32.WNDCLASSEX),
			style: 0,
			lpfnWndProc: => StaticWndProc,
			cbClsExtra: 0,
			cbWndExtra: 0,
			hInstance: Win32.GetModuleHandle(null),
			hIcon: null,
			hCursor: Win32.LoadCursor(null, (int*)(void*)32512), // IDC_ARROW
			hbrBackground: (void*)16, // COLOR_BTNFACE + 1
			lpszMenuName: null,
			lpszClassName: sWindowClassName,
			hIconSm: null
		);

		if (Win32.RegisterClassEx(wc) != 0)
		{
			sWindowClassRegistered = true;
		}
	}

	private static Win32.LRESULT StaticWndProc(void* hWnd, uint32 uMsg, uint32* wParam, int32* lParam)
	{
		Form form = null;
		if (uMsg == Win32.WM_NCCREATE)
		{
			var cs = (Win32.CREATESTRUCT*)lParam;
			form = (Form)Internal.UnsafeCastToObject(cs.lpCreateParams);
			form.mHwnd = hWnd;
			Win32.SetWindowLongPtr(hWnd, Win32.GWLP_USERDATA, Internal.UnsafeCastToPtr(form));
		}
		else
		{
			form = (Form)Internal.UnsafeCastToObject(Win32.GetWindowLongPtr(hWnd, Win32.GWLP_USERDATA));
		}

		if (form != null)
		{
			return form.WndProc(hWnd, uMsg, wParam, lParam);
		}

		return Win32.DefWindowProc(hWnd, uMsg, wParam, lParam);
	}

	protected virtual Win32.LRESULT WndProc(void* hWnd, uint32 uMsg, uint32* wParam, int32* lParam)
	{
		switch (uMsg)
		{
			case Win32.WM_COMMAND:
				// HIWORD(wParam) is the notification code (e.g., BN_CLICKED)
				// LOWORD(wParam) is the control ID (we don't use it)
				// lParam is the HWND of the control
				void* controlHwnd = (void*)lParam;
				if (controlHwnd != null)
				{
					var control = Application.GetControlFromHandle(controlHwnd);
					if (let button = control as Button)
					{
						button.Click.Invoke(button, .Empty);
						return 0;
					}
				}
			case Win32.WM_PAINT:
				// Find the control that needs painting
				var control = Application.GetControlFromHandle(hWnd);
				if (let panel = control as Panel)
				{
					// For simplicity, we create a dummy PaintEventArgs
					panel.Paint.Invoke(panel, scope PaintEventArgs());
				}
			case Win32.WM_SHOWWINDOW:
				if (wParam != null) // If being shown
				{
					Load.Invoke(this, .Empty);
				}
			case Win32.WM_SIZE:
				// lParam contains the new client width and height
				int32 newClientWidth = (((int32)(int)(void*)lParam) & 0xFFFF);
				int32 newClientHeight = (((int32)(int)(void*)lParam) >> 16);

				this.[Friend]mSize = System.Drawing.Size(newClientWidth, newClientHeight);
				OnSizeChanged(null);
				return 0;
			case Win32.WM_CLOSE:
				Win32.DestroyWindow(hWnd);
				return 0;
			case Win32.WM_DESTROY:
				// If this is the main form, quit the application
				if (mParent == null)
				{
					Win32.PostQuitMessage(0);
				}
				mHwnd = null; // Prevent double-destroy
				return 0;
			default:
				break;
		}
		return Win32.DefWindowProc(hWnd, uMsg, wParam, lParam);
	}
}