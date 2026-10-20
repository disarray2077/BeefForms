using System;
using System.Collections;
using System.Drawing;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
internal class Win32Backend : FormsBackend
{
	private Dictionary<void*, Control> mControls = new .() ~ delete _;
	private bool mRegistered;

	public override void EnableVisualStyles()
	{
		Win32.INITCOMMONCONTROLSEX controls = .(sizeof(Win32.INITCOMMONCONTROLSEX), Win32.ICC_PROGRESS_CLASS);
		Win32.InitCommonControlsEx(controls);
	}

	private static char8* GetWindowClass(Control control)
	{
		if (control is Form) return "BeefWinForm";
		if (control is Button || control is GroupBox) return Win32.BUTTON_CLASS;
		if (control is TextBoxBase) return Win32.EDIT_CLASS;
		if (control is ProgressBar) return Win32.PROGRESS_CLASS;
		return Win32.STATIC_CLASS;
	}

	private static uint GetWindowStyle(Control control)
	{
		if (control is Form)
			return Win32.WS_OVERLAPPEDWINDOW | Win32.WS_CLIPCHILDREN;
		uint style = Win32.WS_CHILD | Win32.WS_VISIBLE;
		if (control.TabIndex >= 0)
			style |= Win32.WS_TABSTOP;
		if (control is GroupBox)
			style |= Win32.BS_GROUPBOX | Win32.WS_GROUP;
		if (control is ProgressBar)
			style |= Win32.PBS_SMOOTH;
		if (let textBox = control as TextBoxBase)
		{
			style |= Win32.ES_AUTOHSCROLL;
			if (control is RichTextBox)
				style |= Win32.ES_MULTILINE | Win32.ES_AUTOVSCROLL | Win32.WS_VSCROLL;
			if (textBox.ReadOnly)
				style |= Win32.ES_READONLY;
		}
		if (control.BorderStyle != .None)
			style |= Win32.WS_BORDER;
		if (let scrollable = control as ScrollableControl)
			if (scrollable.AutoScroll)
				style |= Win32.WS_HSCROLL | Win32.WS_VSCROLL;
		return style;
	}

	public override void CreateControl(Control control)
	{
		if (!mRegistered)
		{
			Win32.WNDCLASSEX definition = .(
				sizeof(Win32.WNDCLASSEX), 0, => WindowProc, 0, 0, Win32.GetModuleHandle(null),
				null, Win32.LoadCursor(null, (int*)(void*)32512), (void*)16, null, "BeefWinForm", null);
			Win32.RegisterClassEx(definition);
			mRegistered = true;
		}

		let style = GetWindowStyle(control);
		let size = control.Size;
		var bounds = Win32.RECT(0, 0, size.width, size.height);
		if (control is Form)
			Win32.AdjustWindowRectEx(ref bounds, style, false, 0);
		let handle = Win32.CreateWindowEx(0, GetWindowClass(control), control.Text.CStr(), style,
			control.Location.x, control.Location.y, bounds.right - bounds.left, bounds.bottom - bounds.top,
			control.Parent?.Handle, null, Win32.GetModuleHandle(null), Internal.UnsafeCastToPtr(control));
		if (handle == null)
			Runtime.FatalError("Could not create the Windows control");
		control.SetNativeHandle(handle);
		mControls[handle] = control;
		UpdateControl(control, .All);
	}

	public override void DestroyControl(Control control)
	{
		if (control.Handle == null)
			return;
		let handle = control.Handle;
		Win32.DestroyWindow(handle);
		mControls.Remove(handle);
		control.SetNativeHandle(null);
	}

	public override void UpdateControl(Control control, ControlChange change)
	{
		if (control.Handle == null)
			return;
		if (change == .Text || change == .All)
			Win32.SetWindowText(control.Handle, control.Text.CStr());
		if (change == .Font || change == .All)
			Win32.SendMessage(control.Handle, Win32.WM_SETFONT, (uint*)Win32.GetStockObject(Win32.DEFAULT_GUI_FONT), (int*)(void*)1);
		if (change == .Enabled || change == .All)
			Win32.EnableWindow(control.Handle, control.IsEffectivelyEnabled);
		if (change == .Bounds || change == .All)
		{
			let size = control.Size;
			let location = control.Location;
			if (let form = control as Form)
				SetClientSize(form, size);
			else
				Win32.SetWindowPos(control.Handle, null, location.x, location.y, size.width, size.height, Win32.SWP_NOZORDER);
		}
		if (change == .Value || change == .All)
			if (let progress = control as ProgressBar)
				Win32.SendMessage(control.Handle, Win32.PBM_SETPOS, (uint*)(void*)progress.Value, null);
		if (let editor = control as TextBoxBase)
		{
			if (change == .ReadOnly || change == .All)
				Win32.SendMessage(control.Handle, Win32.EM_SETREADONLY, (uint*)(void*)(int)(editor.ReadOnly ? 1 : 0), null);
			if (change == .Selection)
				Win32.SendMessage(control.Handle, Win32.EM_SETSEL, (uint*)(void*)editor.SelectionStart,
					(int*)(void*)(editor.SelectionStart + editor.SelectionLength));
		}
		Win32.InvalidateRect(control.Handle, null, true);
	}

	public override Size GetClientSize(Form form)
	{
		Win32.GetClientRect(form.Handle, var bounds);
		return .(bounds.right, bounds.bottom);
	}

	public override void SetClientSize(Form form, Size size)
	{
		var bounds = Win32.RECT(0, 0, size.width, size.height);
		Win32.AdjustWindowRectEx(ref bounds, GetWindowStyle(form), false, 0);
		Win32.SetWindowPos(form.Handle, null, form.Location.x, form.Location.y,
			bounds.right - bounds.left, bounds.bottom - bounds.top, Win32.SWP_NOZORDER);
	}

	public override void Show(Form form) => Win32.ShowWindow(form.Handle, Win32.SW_SHOW);
	public override void Close(Form form) => DestroyControl(form);
	public override void Run(Form form)
	{
		Win32.MSG message = ?;
		while (Win32.GetMessage(out message, null, 0, 0) > 0)
		{
			Win32.TranslateMessage(message);
			Win32.DispatchMessage(message);
		}
	}

	private static Win32.LRESULT WindowProc(void* window, uint32 message, uint32* wParam, int32* lParam)
	{
		let backend = (Win32Backend)Application.Backend;
		Form form = null;
		if (message == Win32.WM_NCCREATE)
		{
			form = (Form)Internal.UnsafeCastToObject(((Win32.CREATESTRUCT*)lParam).lpCreateParams);
			form.SetNativeHandle(window);
			backend.mControls[window] = form;
		}
		else if (backend.mControls.TryGetValue(window, let control))
			form = control as Form;
		if (form == null)
			return Win32.DefWindowProc(window, message, wParam, lParam);

		switch (message)
		{
		case Win32.WM_COMMAND:
			if (backend.mControls.TryGetValue((void*)lParam, let control))
			{
				if (let button = control as Button)
					if (((uint)(void*)wParam >> 16) == 0)
						button.PerformClick();
				if (control is TextBoxBase && (((uint)(void*)wParam >> 16) == 0x300))
				{
					let length = Win32.GetWindowTextLength(control.Handle);
					let text = scope String(length + 1);
					text.Append('\0', length);
					text.Length = Win32.GetWindowText(control.Handle, text.Ptr, length + 1);
					control.NotifyText(text);
				}
			}
		case Win32.WM_SHOWWINDOW:
			if (wParam != null)
				form.NotifyLoad();
		case Win32.WM_SIZE:
			let packed = (uint)(void*)lParam;
			form.NotifyResize(.((int32)(packed & 0xFFFF), (int32)((packed >> 16) & 0xFFFF)));
		case Win32.WM_MOVE:
			Win32.GetWindowRect(window, var bounds);
			form.NotifyMove(.(bounds.left, bounds.top));
		case Win32.WM_CLOSE:
			backend.Close(form);
			return 0;
		case Win32.WM_DESTROY:
			form.SetNativeHandle(null);
			Win32.PostQuitMessage(0);
			return 0;
		default:
		}
		return Win32.DefWindowProc(window, message, wParam, lParam);
	}
}
#endif
