#if BF_PLATFORM_WINDOWS
namespace System;

static class Win32
{
	// Window Messages
	public const uint WM_DESTROY = 0x0002;
	public const uint WM_MOVE = 0x0003;
	public const uint WM_CLOSE = 0x0010;
	public const uint WM_QUIT = 0x0012;
	public const uint WM_COMMAND = 0x0111;
	public const uint WM_NCCREATE = 0x0081;
	public const uint WM_CREATE = 0x0001;
	public const uint WM_DRAWITEM = 0x002B;
	public const uint WM_PAINT = 0x000F;
	public const uint WM_SETFONT = 0x0030;
	public const uint WM_CHAR = 0x0102;
	public const uint WM_SHOWWINDOW = 0x0018;
	public const uint WM_GETFONT = 0x0031;
	public const uint WM_SIZE = 0x0005;
	public const uint WM_USER = 0x0400;

	// Window Styles
	public const uint WS_GROUP = 0x00020000;
	public const uint WS_OVERLAPPEDWINDOW = 0x00CF0000;
	public const uint WS_CHILD = 0x40000000;
	public const uint WS_VISIBLE = 0x10000000;
	public const uint WS_BORDER = 0x00800000;
	public const uint WS_VSCROLL = 0x00200000;
	public const uint WS_HSCROLL = 0x00100000;
	public const uint WS_CLIPCHILDREN = 0x02000000;
	public const uint WS_TABSTOP = 0x00010000;

	// Button Styles
	public const uint BS_PUSHBUTTON = 0x00000000;
	public const uint BS_GROUPBOX = 0x00000007;

	// Edit Control Styles
	public const uint ES_MULTILINE = 0x0004;
	public const uint ES_AUTOVSCROLL = 0x0040;
	public const uint ES_AUTOHSCROLL = 0x0080;
	public const uint ES_READONLY = 0x0800;
	public const uint EM_SETREADONLY = 0x00CF;
	public const uint EM_SETSEL = 0x00B1;
	public const uint EM_GETSEL = 0x00B0;

	// Static Control Styles
	public const uint SS_OWNERDRAW = 0x000D;
	public const uint SS_FIXEDRECT = 0x0009; // For BorderStyle.FixedSingle

	// Progress Bar Styles
	public const uint PBM_SETPOS = 0x0402;
	public const uint PBS_SMOOTH = 0x01;

	// DrawText flags
	public const uint DT_LEFT = 0x00000000;
	public const uint DT_CENTER = 0x00000001;
	public const uint DT_RIGHT = 0x00000002;
	public const uint DT_WORDBREAK = 0x00000010;
	public const uint DT_CALCRECT = 0x00000400;
	public const uint DT_NOPREFIX = 0x00000800;

	// SetWindowPos Flags
	public const uint SWP_NOSIZE = 0x0001;
	public const uint SWP_NOMOVE = 0x0002;
	public const uint SWP_NOZORDER = 0x0004;
	public const uint SWP_NOACTIVATE = 0x0010;

	public const uint SRCCOPY = 0x00CC0020;

	// Common Control Init flags
	public const uint ICC_PROGRESS_CLASS = 0x00000001;

	// ShowWindow Commands
	public const int SW_SHOW = 5;
	public const int SW_HIDE = 0;

	// GetWindowLongPtr constants
	public const int GWLP_USERDATA = -21;
	public const int GWLP_WNDPROC = -4;
	public const int GWL_STYLE = -16;
	public const int GWL_EXSTYLE = -20;

	// Stock Objects
	public const int DEFAULT_GUI_FONT = 17;

	// Background Modes
	public const int TRANSPARENT = 1;

	public typealias LRESULT = int;
	public typealias WPARAM = void*;
	public typealias LPARAM = void*;

	// Structs
	[CRepr]
	public struct POINT { public int32 x, y; }

	[CRepr]
	public struct MSG
	{
		public void* hwnd;
		public uint32 message;
		public uint32* wParam;
		public int32* lParam;
		public uint32 time;
		public POINT pt;
	}

	[CRepr]
	public struct WNDCLASSEX : this(
		uint32 cbSize,
		uint32 style,
		function LRESULT(void*, uint32, uint32*, int32*) lpfnWndProc,
		int32 cbClsExtra,
		int32 cbWndExtra,
		void* hInstance,
		void* hIcon,
		void* hCursor,
		void* hbrBackground,
		char8* lpszMenuName,
		char8* lpszClassName,
		void* hIconSm
	)
	{
	}

	[CRepr]
	public struct CREATESTRUCT
	{
		public void* lpCreateParams;
		public void* hInstance;
		public void* hMenu;
		public void* hwndParent;
		public int32 cy;
		public int32 cx;
		public int32 y;
		public int32 x;
		public int32 style;
		public char8* lpszName;
		public char8* lpszClass;
		public uint32 dwExStyle;
	}

	[CRepr]
	public struct RECT : this(int32 left, int32 top, int32 right, int32 bottom) { }

	[CRepr]
	public struct INITCOMMONCONTROLSEX : this(uint32 dwSize, uint32 dwICC) { }

	[CRepr]
	public struct DRAWITEMSTRUCT
	{
		public uint CtlType;
		public uint CtlID;
		public uint itemID;
		public uint itemAction;
		public uint itemState;
		public void* hwndItem;
		public void* hDC;
		public RECT rcItem;
		public void* itemData;
	}

	// Functions
	[Import("user32.dll"), LinkName("GetMessageA")]
	public static extern int GetMessage(out MSG lpMsg, void* hWnd, uint wMsgFilterMin, uint wMsgFilterMax);
	[Import("user32.dll"), CLink]
	public static extern bool TranslateMessage(in MSG lpMsg);
	[Import("user32.dll"), LinkName("DispatchMessageA")]
	public static extern int* DispatchMessage(in MSG lpMsg);
	[Import("user32.dll"), CLink]
	public static extern void PostQuitMessage(int nExitCode);
	[Import("user32.dll"), LinkName("RegisterClassExA")]
	public static extern uint16 RegisterClassEx(in WNDCLASSEX lpwcx);
	[Import("user32.dll"), LinkName("CreateWindowExA")]
	public static extern void* CreateWindowEx(uint dwExStyle, char8* lpClassName, char8* lpWindowName, uint dwStyle, int X, int Y, int nWidth, int nHeight, void* hWndParent, void* hMenu, void* hInstance, void* lpParam);
	[Import("user32.dll"), CLink]
	public static extern bool DestroyWindow(void* hWnd);
	[Import("user32.dll"), LinkName("DefWindowProcA")]
	public static extern LRESULT DefWindowProc(void* hWnd, uint32 uMsg, uint32* wParam, int32* lParam);
	[Import("user32.dll"), CLink]
	public static extern bool ShowWindow(void* hWnd, int nCmdShow);
	[Import("kernel32.dll"), LinkName("GetModuleHandleA")]
	public static extern void* GetModuleHandle(char8* lpModuleName);
	[Import("user32.dll"), LinkName("LoadCursorA")]
	public static extern void* LoadCursor(void* hInstance, int* lpCursorName);
	[Import("user32.dll"), LinkName("SetWindowLongPtrA")]
	public static extern void* SetWindowLongPtr(void* hWnd, int nIndex, void* dwNewLong);
	[Import("user32.dll"), LinkName("GetWindowLongPtrA")]
	public static extern void* GetWindowLongPtr(void* hWnd, int nIndex);
	[Import("user32.dll"), LinkName("SetWindowTextA")]
	public static extern bool SetWindowText(void* hWnd, char8* lpString);
	[Import("user32.dll"), LinkName("GetWindowTextLengthA")]
	public static extern int32 GetWindowTextLength(void* hWnd);
	[Import("user32.dll"), LinkName("GetWindowTextA")]
	public static extern int32 GetWindowText(void* hWnd, char8* text, int32 maxCount);
	[Import("user32.dll"), CLink]
	public static extern bool SetWindowPos(void* hWnd, void* hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
	[Import("user32.dll"), CLink]
	public static extern bool AdjustWindowRectEx(ref RECT lpRect, uint dwStyle, bool bMenu, uint dwExStyle);
	[Import("user32.dll"), CLink]
	public static extern bool GetClientRect(void* hWnd, out RECT lpRect);
	[Import("user32.dll"), CLink]
	public static extern bool GetWindowRect(void* hWnd, out RECT lpRect);
	[Import("gdi32.dll"), CLink]
	public static extern void* GetStockObject(int fnObject);
	[Import("user32.dll"), LinkName("SendMessageA")]
	public static extern int* SendMessage(void* hWnd, uint Msg, uint* wParam, int* lParam);
	[Import("comctl32.dll"), CLink]
	public static extern bool InitCommonControlsEx(in INITCOMMONCONTROLSEX picce);
	[Import("user32.dll"), CLink]
	public static extern bool InvalidateRect(void* hWnd, RECT* lpRect, bool bErase);
	[Import("user32.dll"), CLink]
	public static extern bool UpdateWindow(void* hWnd);
	[Import("user32.dll"), CLink]
	public static extern bool EnableWindow(void* hWnd, bool bEnable);
	[Import("user32.dll"), CLink]
	public static extern void* GetDC(void* hWnd);
	[Import("user32.dll"), CLink]
	public static extern int ReleaseDC(void* hWnd, void* hDC);
	[Import("gdi32.dll"), CLink]
	public static extern void* CreateCompatibleDC(void* hdc);
	[Import("gdi32.dll"), CLink]
	public static extern bool DeleteDC(void* hdc);
	[Import("gdi32.dll"), CLink]
	public static extern void* CreateCompatibleBitmap(void* hdc, int cx, int cy);
	[Import("gdi32.dll"), CLink]
	public static extern bool DeleteObject(void* ho);
	[Import("gdi32.dll"), CLink]
	public static extern void* SelectObject(void* hdc, void* h);
	[Import("user32.dll"), CLink]
	public static extern int FillRect(void* hDC, ref RECT lprc, void* hbr);
	[Import("user32.dll"), LinkName("DrawTextA")]
	public static extern int DrawText(void* hdc, char8* lpchText, int cchText, ref RECT lprc, uint format);
	[Import("gdi32.dll"), CLink]
	public static extern bool BitBlt(void* hdc, int x, int y, int cx, int cy, void* hdcSrc, int x1, int y1, uint rop);
	[Import("gdi32.dll"), CLink]
	public static extern int SetBkMode(void* hdc, int mode);

	// String constants for class names
	public static char8* PROGRESS_CLASS = "msctls_progress32";
	public static char8* BUTTON_CLASS = "BUTTON";
	public static char8* STATIC_CLASS = "STATIC";
	public static char8* EDIT_CLASS = "EDIT";
	public static char8* RICHEDIT_CLASS = "RichEdit20A";
}

#endif
