#if BF_PLATFORM_WINDOWS
namespace System;

static class Win32
{
	[Import("user32.dll"), CLink]
	public static extern uint SetTimer(void* window, uint id, uint32 interval, function void(void*, uint32, uint, uint32) callback);
	[Import("user32.dll"), CLink]
	public static extern BOOL KillTimer(void* window, uint id);
	[Import("user32.dll"), LinkName("MessageBoxW")]
	public static extern int32 MessageBox(void* owner, char16* text, char16* caption, uint32 type);
	[Import("user32.dll"), CLink]
	public static extern void* GetActiveWindow();
	[Import("user32.dll"), CLink]
	public static extern bool SetForegroundWindow(void* window);
	[Import("user32.dll"), CLink]
	public static extern void* GetAncestor(void* window, uint32 flags);

	public const uint32 GA_ROOT = 2;

	[CRepr]
	public struct SCROLLINFO
	{
		public uint32 cbSize, fMask;
		public int32 nMin, nMax;
		public uint32 nPage;
		public int32 nPos, nTrackPos;

		public this(uint32 size, uint32 mask, int32 minimum, int32 maximum, uint32 page, int32 position, int32 track)
		{
			cbSize = size;
			fMask = mask;
			nMin = minimum;
			nMax = maximum;
			nPage = page;
			nPos = position;
			nTrackPos = track;
		}
	}

	public const int32 SB_HORZ = 0;
	public const int32 SB_VERT = 1;
	public const uint32 SIF_RANGE = 0x1;
	public const uint32 SIF_PAGE = 0x2;
	public const uint32 SIF_POS = 0x4;
	public const uint32 SIF_TRACKPOS = 0x10;
	public const uint32 SB_LINEUP = 0;
	public const uint32 SB_LINEDOWN = 1;
	public const uint32 SB_PAGEUP = 2;
	public const uint32 SB_PAGEDOWN = 3;
	public const uint32 SB_THUMBPOSITION = 4;
	public const uint32 SB_THUMBTRACK = 5;
	public const uint32 SB_TOP = 6;
	public const uint32 SB_BOTTOM = 7;

	[Import("user32.dll"), CLink]
	public static extern int32 SetScrollInfo(void* window, int32 bar, ref SCROLLINFO info, BOOL redraw);
	[Import("user32.dll"), CLink]
	public static extern BOOL GetScrollInfo(void* window, int32 bar, ref SCROLLINFO info);
	[Import("user32.dll"), CLink]
	public static extern BOOL ShowScrollBar(void* window, int32 bar, BOOL show);
	[Import("user32.dll"), CLink]
	public static extern int32 ScrollWindowEx(void* window, int32 dx, int32 dy, RECT* scroll, RECT* clip, void* updateRegion, RECT* update, uint flags);

	public const uint SW_SCROLLCHILDREN = 0x0001;
	public const uint SW_INVALIDATE = 0x0002;
	public const uint SW_ERASE = 0x0004;

	[Import("user32.dll"), CLink]
	public static extern int32 GetSystemMetrics(int32 index);
	[Import("user32.dll"), CLink]
	public static extern uint32 GetDpiForWindow(void* window);
	[Import("user32.dll"), CLink]
	public static extern int32 GetSystemMetricsForDpi(int32 index, uint32 dpi);

	public const int32 SM_CXVSCROLL = 2;
	public const int32 SM_CYHSCROLL = 3;
	public const int32 SM_CYBORDER = 6;
	public const uint32 BN_CLICKED = 0;
	public const uint32 EN_CHANGE = 0x0300;
	public const int32 VK_SHIFT = 0x10;
	public const int32 VK_CONTROL = 0x11;
	public const int32 VK_MENU = 0x12;
	public const int IDC_ARROW = 32512;
	public const int COLOR_BTNFACE = 15;
	public const int32 COLOR_GRAYTEXT = 17;
	public const int32 COLOR_BTNTEXT = 18;
	public const uint32 TME_LEAVE = 0x00000002;

	[CRepr]
	public struct GdiplusStartupInput
	{
		public uint32 Version;
		public void* DebugCallback;
		public BOOL SuppressBackgroundThread, SuppressExternalCodecs;
	}

	[Import("gdiplus.dll"), CLink]
	public static extern int32 GdiplusStartup(out uint token, ref GdiplusStartupInput input, void* output);
	[Import("gdiplus.dll"), CLink]
	public static extern void GdiplusShutdown(uint token);
	[Import("gdiplus.dll"), CLink]
	public static extern int32 GdipCreateFontFromDC(void* context, out void* font);
	[Import("gdiplus.dll"), CLink]
	public static extern int32 GdipGetFontHeightGivenDPI(void* font, float dpi, out float height);
	[Import("gdiplus.dll"), CLink]
	public static extern int32 GdipDeleteFont(void* font);
	[Import("gdi32.dll"), LinkName("CreateFontW")]
	public static extern void* CreateFont(int32 height, int32 width, int32 escapement, int32 orientation, int32 weight,
		uint32 italic, uint32 underline, uint32 strikeout, uint32 charset, uint32 outputPrecision, uint32 clipPrecision, uint32 quality, uint32 pitch, char16* family);

	public const int32 SM_CXICON = 11, SM_CYICON = 12, SM_CXSMICON = 49, SM_CYSMICON = 50;
	public const uint WM_SETICON = 0x0080;

	[Import("user32.dll"), CLink]
	public static extern void* CreateIconFromResourceEx(uint8* bits, uint32 size, BOOL icon, uint32 version, int32 width, int32 height, uint32 flags);
	[Import("user32.dll"), CLink]
	public static extern BOOL DestroyIcon(void* icon);

	[CRepr]
	public struct MONITORINFO
	{
		public uint32 cbSize;
		public RECT rcMonitor, rcWork;
		public uint32 dwFlags;
	}

	public const uint32 MONITOR_DEFAULTTONEAREST = 2;

	[Import("user32.dll"), CLink]
	public static extern BOOL GetCursorPos(out POINT point);
	[Import("user32.dll"), CLink]
	public static extern void* MonitorFromPoint(POINT point, uint32 flags);
	[Import("user32.dll"), LinkName("GetMonitorInfoW")]
	public static extern BOOL GetMonitorInfo(void* monitor, ref MONITORINFO info);

	// Window Messages
	public const uint WM_HSCROLL = 0x0114;
	public const uint WM_VSCROLL = 0x0115;
	public const uint WM_DESTROY = 0x0002;
	public const uint WM_MOVE = 0x0003;
	public const uint WM_CLOSE = 0x0010;
	public const uint WM_GETMINMAXINFO = 0x0024;
	public const uint WM_QUIT = 0x0012;
	public const uint PM_REMOVE = 0x0001;

	[Import("user32.dll"), LinkName("PeekMessageW")]
	public static extern BOOL PeekMessage(out MSG message, void* window, uint minimum, uint maximum, uint flags);

	public const uint WM_COMMAND = 0x0111;
	public const uint WM_NCCREATE = 0x0081;
	public const uint WM_CREATE = 0x0001;
	public const uint WM_DRAWITEM = 0x002B;
	public const uint WM_PAINT = 0x000F;
	public const uint WM_DISPLAYCHANGE = 0x007E;
	public const uint WM_ERASEBKGND = 0x0014;
	public const uint WM_NCHITTEST = 0x0084;
	public const uint WM_NCLBUTTONDOWN = 0x00A1;
	public const uint WM_NCLBUTTONDBLCLK = 0x00A3;
	public const int HTTRANSPARENT = -1;
	public const int HTCLIENT = 1;
	public const int HTHSCROLL = 6;
	public const int HTVSCROLL = 7;
	public const uint WM_SETFONT = 0x0030;
	public const uint WM_CHAR = 0x0102;
	public const uint WM_KEYDOWN = 0x0100;
	public const uint WM_KEYUP = 0x0101;
	public const uint WM_SYSKEYDOWN = 0x0104;
	public const uint WM_SYSKEYUP = 0x0105;
	public const uint WM_SETFOCUS = 0x0007;
	public const uint WM_KILLFOCUS = 0x0008;
	public const uint WM_MOUSEMOVE = 0x0200;
	public const uint WM_LBUTTONDOWN = 0x0201;
	public const uint WM_LBUTTONUP = 0x0202;
	public const uint WM_LBUTTONDBLCLK = 0x0203;
	public const uint WM_RBUTTONDOWN = 0x0204;
	public const uint WM_RBUTTONUP = 0x0205;
	public const uint WM_RBUTTONDBLCLK = 0x0206;
	public const uint WM_MBUTTONDOWN = 0x0207;
	public const uint WM_MBUTTONUP = 0x0208;
	public const uint WM_MBUTTONDBLCLK = 0x0209;
	public const uint WM_MOUSEWHEEL = 0x020A;
	public const uint WM_MOUSEHWHEEL = 0x020E;
	public const uint WM_MOUSELEAVE = 0x02A3;
	public const uint WM_NCDESTROY = 0x0082;
	public const uint WM_SHOWWINDOW = 0x0018;
	public const uint WM_GETFONT = 0x0031;
	public const uint WM_SIZE = 0x0005;
	public const uint WM_USER = 0x0400;

	// Window Styles
	public const uint CS_DBLCLKS = 0x0008;
	public const uint WS_GROUP = 0x00020000;
	public const uint WS_EX_CONTROLPARENT = 0x00010000;
	public const uint WS_EX_CLIENTEDGE = 0x00000200;
	public const uint WS_OVERLAPPEDWINDOW = 0x00CF0000;
	public const uint WS_CHILD = 0x40000000;
	public const uint WS_VISIBLE = 0x10000000;
	public const uint WS_BORDER = 0x00800000;
	public const uint WS_VSCROLL = 0x00200000;
	public const uint WS_HSCROLL = 0x00100000;
	public const uint WS_CLIPSIBLINGS = 0x04000000;
	public const uint WS_CLIPCHILDREN = 0x02000000;
	public const uint WS_TABSTOP = 0x00010000;

	// Button Styles
	public const uint BS_PUSHBUTTON = 0x00000000;
	public const uint BS_DEFPUSHBUTTON = 0x00000001;
	public const uint BM_SETSTYLE = 0x00F4;
	public const uint BS_CHECKBOX = 0x00000002;
	public const uint BM_GETCHECK = 0x00F0;
	public const uint BM_SETCHECK = 0x00F1;
	public const uint BS_GROUPBOX = 0x00000007;

	// Edit Control Styles
	public const uint ES_MULTILINE = 0x0004;
	public const uint ES_AUTOVSCROLL = 0x0040;
	public const uint ES_AUTOHSCROLL = 0x0080;
	public const uint ES_READONLY = 0x0800;
	public const uint EM_SETREADONLY = 0x00CF;
	public const uint EM_SETSEL = 0x00B1;
	public const uint EM_GETSEL = 0x00B0;
	public const uint EM_REPLACESEL = 0x00C2;
	public const uint EM_UNDO = 0x00C7;
	public const uint EM_POSFROMCHAR = 0x00D6;
	public const uint EM_CHARFROMPOS = 0x00D7;
	public const uint WM_SETTEXT = 0x000C;
	public const uint WM_TIMER = 0x0113;
	public const uint WM_CUT = 0x0300;
	public const uint WM_PASTE = 0x0302;
	public const uint WM_CLEAR = 0x0303;
	public const uint WM_UNDO = 0x0304;
	public const uint WM_IME_COMPOSITION = 0x010F;
	public const uint WM_IME_ENDCOMPOSITION = 0x010E;

	// Static Control Styles
	public const uint SS_OWNERDRAW = 0x000D;
	public const uint SS_FIXEDRECT = 0x0009; // For BorderStyle.FixedSingle

	// Progress Bar Styles
	public const uint PBM_SETPOS = 0x0402;
	public const uint PBM_SETRANGE32 = 0x0406;
	public const uint PBM_GETRANGE = 0x0407;
	public const uint PBM_GETPOS = 0x0408;
	public const uint PBS_SMOOTH = 0x01;
	public const uint PBS_MARQUEE = 0x08;
	public const uint PBM_SETMARQUEE = 0x040A;

	// DrawText flags
	public const uint DT_LEFT = 0x00000000;
	public const uint DT_CENTER = 0x00000001;
	public const uint DT_RIGHT = 0x00000002;
	public const uint DT_WORDBREAK = 0x00000010;
	public const uint DT_CALCRECT = 0x00000400;
	public const uint DT_NOPREFIX = 0x00000800;
	public const uint DT_SINGLELINE = 0x00000020;
	public const uint DT_END_ELLIPSIS = 0x00008000;

	// SetWindowPos Flags
	public const uint SWP_NOSIZE = 0x0001;
	public const uint SWP_NOMOVE = 0x0002;
	public const uint SWP_NOZORDER = 0x0004;
	public const uint SWP_NOACTIVATE = 0x0010;
	public const uint SWP_FRAMECHANGED = 0x0020;

	public const uint RDW_INVALIDATE = 0x0001;
	public const uint RDW_ERASE = 0x0004;
	public const uint RDW_ALLCHILDREN = 0x0080;
	public const uint RDW_UPDATENOW = 0x0100;

	public const uint SRCCOPY = 0x00CC0020;
	public const int32 BITSPIXEL = 12;
	public const int32 PLANES = 14;

	// Common Control Init flags
	public const uint ICC_PROGRESS_CLASS = 0x00000001;

	// ShowWindow Commands
	public const int SW_SHOW = 5;
	public const int SW_HIDE = 0;

	// GetWindowLongPtr constants
	public const int GWLP_USERDATA = -21;
	public const int GWLP_WNDPROC = -4;
	public const int GWLP_HWNDPARENT = -8;
	public const int GWL_STYLE = -16;
	public const int GWL_EXSTYLE = -20;
	public const int GCL_STYLE = -26;

	// Stock Objects
	public const int DEFAULT_GUI_FONT = 17;

	// Background Modes
	public const int TRANSPARENT = 1;

	// Win32 BOOL is 32-bit, unlike Beef bool.
	public typealias BOOL = int32;
	public typealias LRESULT = int;
	public typealias WPARAM = void*;
	public typealias LPARAM = void*;

	// Structs
	[CRepr]
	public struct PAINTSTRUCT
	{
		public void* hdc;
		public BOOL erase;
		public RECT paint;
		public BOOL restore, update;
		public uint8[32] reserved;
	}

	[CRepr]
	public struct POINT
	{
		public int32 x, y;
	}

	[CRepr]
	public struct MINMAXINFO
	{
		public POINT reserved, maxSize, maxPosition, minTrackSize, maxTrackSize;
	}

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
		char16* lpszMenuName,
		char16* lpszClassName,
		void* hIconSm
	);

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
		public char16* lpszName;
		public char16* lpszClass;
		public uint32 dwExStyle;
	}

	[CRepr]
	public struct RECT : this(int32 left, int32 top, int32 right, int32 bottom);

	[CRepr]
	public struct INITCOMMONCONTROLSEX : this(uint32 dwSize, uint32 dwICC);

	[CRepr]
	public struct TRACKMOUSEEVENT : this(uint32 cbSize, uint32 dwFlags, void* hwndTrack, uint32 dwHoverTime);

	public function LRESULT SubclassProc(void* window, uint32 message, uint32* wParam, int32* lParam, uint id, uint data);

	[Import("comctl32.dll"), CLink]
	public static extern bool SetWindowSubclass(void* window, SubclassProc callback, uint id, uint data);
	[Import("comctl32.dll"), CLink]
	public static extern bool RemoveWindowSubclass(void* window, SubclassProc callback, uint id);
	[Import("comctl32.dll"), CLink]
	public static extern LRESULT DefSubclassProc(void* window, uint32 message, uint32* wParam, int32* lParam);
	[Import("user32.dll"), CLink]
	public static extern void* SetFocus(void* window);
	[Import("user32.dll"), CLink]
	public static extern void* GetFocus();
	[Import("user32.dll"), CLink]
	public static extern bool GetCaretPos(out POINT point);
	[Import("user32.dll"), CLink]
	public static extern void* SetCapture(void* window);
	[Import("user32.dll"), CLink]
	public static extern void* GetCapture();
	[Import("user32.dll"), CLink]
	public static extern bool ReleaseCapture();
	[Import("user32.dll"), CLink]
	public static extern int16 GetKeyState(int32 key);
	[Import("user32.dll"), CLink]
	public static extern bool ScreenToClient(void* window, ref POINT point);
	[Import("user32.dll"), CLink]
	public static extern bool TrackMouseEvent(ref TRACKMOUSEEVENT tracking);

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
	[Import("user32.dll"), CLink]
	public static extern void* BeginPaint(void* window, out PAINTSTRUCT paint);
	[Import("user32.dll"), CLink]
	public static extern BOOL EndPaint(void* window, ref PAINTSTRUCT paint);
	[Import("user32.dll"), CLink]
	public static extern uint32 GetSysColor(int32 index);
	[Import("gdi32.dll"), CLink]
	public static extern uint32 SetTextColor(void* context, uint32 color);
	[Import("user32.dll"), CLink]
	public static extern bool IsWindowVisible(void* window);
	[Import("user32.dll"), CLink]
	public static extern void* GetWindow(void* window, uint32 command);
	[Import("user32.dll"), CLink]
	public static extern void* GetParent(void* window);
	[Import("user32.dll"), CLink]
	public static extern void* SetParent(void* window, void* parent);
	[Import("user32.dll"), LinkName("GetClassLongW")]
	public static extern uint32 GetClassLong(void* window, int32 index);
	[Import("user32.dll"), LinkName("GetMessageW")]
	public static extern int GetMessage(out MSG lpMsg, void* hWnd, uint wMsgFilterMin, uint wMsgFilterMax);
	[Import("user32.dll"), CLink]
	public static extern bool TranslateMessage(in MSG lpMsg);
	[Import("user32.dll"), LinkName("DispatchMessageW")]
	public static extern int* DispatchMessage(in MSG lpMsg);
	[Import("user32.dll"), CLink]
	public static extern void PostQuitMessage(int nExitCode);
	[Import("user32.dll"), LinkName("RegisterClassExW")]
	public static extern uint16 RegisterClassEx(in WNDCLASSEX lpwcx);
	[Import("user32.dll"), LinkName("CreateWindowExW")]
	public static extern void* CreateWindowEx(uint dwExStyle, char16* lpClassName, char16* lpWindowName, uint dwStyle, int X, int Y, int nWidth, int nHeight, void* hWndParent, void* hMenu, void* hInstance, void* lpParam);
	[Import("user32.dll"), CLink]
	public static extern bool DestroyWindow(void* hWnd);
	[Import("user32.dll"), LinkName("DefWindowProcW")]
	public static extern LRESULT DefWindowProc(void* hWnd, uint32 uMsg, uint32* wParam, int32* lParam);
	[Import("user32.dll"), CLink]
	public static extern bool ShowWindow(void* hWnd, int nCmdShow);
	[Import("kernel32.dll"), LinkName("GetModuleHandleW")]
	public static extern void* GetModuleHandle(char16* lpModuleName);
	[Import("user32.dll"), LinkName("LoadCursorW")]
	public static extern void* LoadCursor(void* hInstance, int* lpCursorName);
	[Import("user32.dll"), LinkName("SetWindowLongPtrW")]
	public static extern void* SetWindowLongPtr(void* hWnd, int nIndex, void* dwNewLong);
	[Import("user32.dll"), LinkName("GetWindowLongPtrW")]
	public static extern void* GetWindowLongPtr(void* hWnd, int nIndex);
	[Import("user32.dll"), LinkName("SetWindowTextW")]
	public static extern bool SetWindowText(void* hWnd, char16* lpString);
	[Import("user32.dll"), LinkName("GetWindowTextLengthW")]
	public static extern int32 GetWindowTextLength(void* hWnd);
	[Import("user32.dll"), LinkName("GetWindowTextW")]
	public static extern int32 GetWindowText(void* hWnd, char16* text, int32 maxCount);
	[Import("user32.dll"), CLink]
	public static extern bool SetWindowPos(void* hWnd, void* hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
	[Import("user32.dll"), CLink]
	public static extern bool AdjustWindowRectEx(ref RECT lpRect, uint dwStyle, BOOL bMenu, uint dwExStyle);
	[Import("user32.dll"), CLink]
	public static extern bool GetClientRect(void* hWnd, out RECT lpRect);
	[Import("user32.dll"), CLink]
	public static extern bool GetWindowRect(void* hWnd, out RECT lpRect);
	[Import("gdi32.dll"), CLink]
	public static extern void* GetStockObject(int fnObject);
	[Import("user32.dll"), LinkName("SendMessageW")]
	public static extern int* SendMessage(void* hWnd, uint Msg, uint* wParam, int* lParam);
	[Import("user32.dll"), LinkName("PostMessageW")]
	public static extern BOOL PostMessage(void* hWnd, uint Msg, uint* wParam, int* lParam);
	[Import("comctl32.dll"), CLink]
	public static extern bool InitCommonControlsEx(in INITCOMMONCONTROLSEX picce);
	[Import("user32.dll"), CLink]
	public static extern bool InvalidateRect(void* hWnd, RECT* lpRect, bool bErase);
	[Import("user32.dll"), CLink]
	public static extern bool UpdateWindow(void* hWnd);
	[Import("user32.dll"), CLink]
	public static extern BOOL RedrawWindow(void* window, RECT* bounds, void* region, uint flags);
	[Import("user32.dll"), CLink]
	public static extern BOOL EnableWindow(void* hWnd, BOOL bEnable);
	[Import("user32.dll"), CLink]
	public static extern BOOL IsWindowEnabled(void* hWnd);
	[Import("user32.dll"), CLink]
	public static extern void* GetDC(void* hWnd);
	[Import("user32.dll"), CLink]
	public static extern int ReleaseDC(void* hWnd, void* hDC);
	[Import("gdi32.dll"), CLink]
	public static extern void* CreateCompatibleDC(void* hdc);
	[Import("gdi32.dll"), CLink]
	public static extern int32 GetDeviceCaps(void* hdc, int32 index);
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
	[Import("user32.dll"), LinkName("DrawTextW")]
	public static extern int DrawText(void* hdc, char16* lpchText, int cchText, ref RECT lprc, uint format);
	[Import("gdi32.dll"), CLink]
	public static extern bool BitBlt(void* hdc, int x, int y, int cx, int cy, void* hdcSrc, int x1, int y1, uint rop);
	[Import("gdi32.dll"), CLink]
	public static extern int SetBkMode(void* hdc, int mode);

	// UTF-16 class names
	public static char16[?] FORM_CLASS = "BeefWinForm".ToConstNativeW();
	public static char16[?] PROGRESS_CLASS = "msctls_progress32".ToConstNativeW();
	public static char16[?] USERCONTROL_CLASS = "BeefFormsUserControl".ToConstNativeW();
	public static char16[?] BUTTON_CLASS = "BUTTON".ToConstNativeW();
	public static char16[?] STATIC_CLASS = "STATIC".ToConstNativeW();
	public static char16[?] EDIT_CLASS = "EDIT".ToConstNativeW();
	public static char16[?] RICHEDIT_CLASS = "RichEdit20W".ToConstNativeW();
}

#endif
