using System;
using System.Collections;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
internal class Win32Backend : FormsBackend
{
	public override ApplicationBackend Type => .Win32;

	private append Dictionary<void*, Control> mControls = .();
	private bool mRegistered;
	private void* mParkingWindow;
	private Control mHovered;
	private bool mSuppressChars;

	private append PaintBitmapCache mPaintBitmapCache = .();

	public ~this()
	{
		if (mParkingWindow != null)
			Win32.DestroyWindow(mParkingWindow);
		if (mWindowIcon != null)
			Win32.DestroyIcon(mWindowIcon);
		if (mSmallWindowIcon != null)
			Win32.DestroyIcon(mSmallWindowIcon);
		if (mGdiPlusToken != 0)
			Win32.GdiplusShutdown(mGdiPlusToken);
	}

	public override void EnableVisualStyles()
	{
		Win32.INITCOMMONCONTROLSEX controls = .(sizeof(Win32.INITCOMMONCONTROLSEX), Win32.ICC_PROGRESS_CLASS);
		Win32.InitCommonControlsEx(controls);
	}

	private static char16* GetWindowClass(Control control)
	{
		if (control is Form)
			return (char16*)&Win32.FORM_CLASS;
		if (control is UserControl)
			return (char16*)&Win32.USERCONTROL_CLASS;
		if (control is ButtonBase || control is GroupBox)
			return (char16*)&Win32.BUTTON_CLASS;
		if (control is TextBoxBase)
			return (char16*)&Win32.EDIT_CLASS;
		if (control is ProgressBar)
			return (char16*)&Win32.PROGRESS_CLASS;
		return (char16*)&Win32.STATIC_CLASS;
	}

	private static uint GetWindowStyle(Control control)
	{
		if (control is Form)
			return Win32.WS_OVERLAPPEDWINDOW | Win32.WS_CLIPCHILDREN;
		uint style = Win32.WS_CHILD | Win32.WS_CLIPCHILDREN | Win32.WS_CLIPSIBLINGS;
		if (control.IsEffectivelyVisible)
			style |= Win32.WS_VISIBLE;
		if (control.TabIndex >= 0 && control.TabStop)
			style |= Win32.WS_TABSTOP;
		if (control is GroupBox)
			style |= Win32.BS_GROUPBOX | Win32.WS_GROUP;
		if (control is CheckBox)
			style |= Win32.BS_CHECKBOX;
		if (control is RadioButton)
			style |= Win32.BS_RADIOBUTTON;
		if (let progress = control as ProgressBar)
		{
			if (progress.Style == .Continuous)
				style |= Win32.PBS_SMOOTH;
			if (progress.Style == .Marquee)
				style |= Win32.PBS_MARQUEE;
		}
		if (let textBox = control as TextBoxBase)
		{
			style |= Win32.ES_AUTOHSCROLL;
			if (textBox.Multiline)
				style |= Win32.ES_MULTILINE | Win32.ES_AUTOVSCROLL | Win32.WS_VSCROLL;
			if (textBox.ReadOnly)
				style |= Win32.ES_READONLY;
		}
		if (control.BorderStyle == .FixedSingle)
			style |= Win32.WS_BORDER;
		if (let scrollable = control as ScrollableControl)
		{
			if (scrollable.AutoScroll)
				style |= Win32.WS_HSCROLL | Win32.WS_VSCROLL;
		}
		return style;
	}

	private static uint GetWindowExtendedStyle(Control control)
	{
		uint style = (control is GroupBox || control is UserControl) ? Win32.WS_EX_CONTROLPARENT : 0;
		if (!(control is Form) && control.BorderStyle == .Fixed3D)
			style |= Win32.WS_EX_CLIENTEDGE;
		return style;
	}

	private void UpdateBorderStyle(Control control)
	{
		let style = (uint)(void*)Win32.GetWindowLongPtr(control.GetHandle(), Win32.GWL_STYLE);
		let extendedStyle = (uint)(void*)Win32.GetWindowLongPtr(control.GetHandle(), Win32.GWL_EXSTYLE);
		Win32.SetWindowLongPtr(control.GetHandle(), Win32.GWL_STYLE,
			(void*)((style & ~Win32.WS_BORDER) | (GetWindowStyle(control) & Win32.WS_BORDER)));
		Win32.SetWindowLongPtr(control.GetHandle(), Win32.GWL_EXSTYLE,
			(void*)((extendedStyle & ~Win32.WS_EX_CLIENTEDGE) | (GetWindowExtendedStyle(control) & Win32.WS_EX_CLIENTEDGE)));
		Win32.SetWindowPos(control.GetHandle(), null, 0, 0, 0, 0,
			Win32.SWP_NOMOVE | Win32.SWP_NOSIZE | Win32.SWP_NOZORDER | Win32.SWP_NOACTIVATE | Win32.SWP_FRAMECHANGED);
	}

	private void* GetParentHandle(Control control)
	{
		let parent = control.Parent?.GetHandle();
		if (parent != null)
			return parent;
		if (let form = control as Form)
			return form.Owner?.Handle;
		if (mParkingWindow == null)
			mParkingWindow = Win32.CreateWindowEx(0, (char16*)&Win32.STATIC_CLASS, null, 0,
				0, 0, 0, 0, null, null, Win32.GetModuleHandle(null), null);
		return mParkingWindow;
	}

	public override void CreateControl(Control control)
	{
		if (!mRegistered)
		{
			Win32.WNDCLASSEX definition = .(
				sizeof(Win32.WNDCLASSEX), Win32.CS_DBLCLKS, => WindowProc, 0, 0, Win32.GetModuleHandle(null),
				null, Win32.LoadCursor(null, (int*)(void*)Win32.IDC_ARROW), (void*)(Win32.COLOR_BTNFACE + 1), null, (char16*)&Win32.FORM_CLASS, null);
			Win32.RegisterClassEx(definition);

			definition.lpszClassName = (char16*)&Win32.USERCONTROL_CLASS;
			definition.lpfnWndProc = => UserControlWindowProc;
			Win32.RegisterClassEx(definition);

			mRegistered = true;
		}

		let parent = GetParentHandle(control);
		let style = GetWindowStyle(control);
		let size = control.Size;
		var bounds = Win32.RECT(0, 0, size.width, size.height);
		if (let form = control as Form)
		{
			if (form.HasInitialClientSize)
			{
				let client = form.InitialClientSize;
				bounds = .(0, 0, client.width, client.height);
				Win32.AdjustWindowRectEx(ref bounds, style, 0, 0);
			}
		}
		let extendedStyle = GetWindowExtendedStyle(control);
		let handle = Win32.CreateWindowEx(extendedStyle, GetWindowClass(control), control.Text.ToScopedNativeWChar!(), style,
			control.Location.x, control.Location.y, bounds.right - bounds.left, bounds.bottom - bounds.top,
			parent, null, Win32.GetModuleHandle(null), Internal.UnsafeCastToPtr(control));
		if (handle == null)
			Runtime.FatalError("Could not create the Windows control");
		control.SetNativeHandle(handle);
		mControls[handle] = control;
		if (let form = control as Form)
		{
			SetDefaultIcon(form);
			Win32.GetWindowRect(handle, var outer);
			control.NotifyResize(.(outer.right - outer.left, outer.bottom - outer.top));
		}
		if (!(control is Form))
			Win32.SetWindowSubclass(handle, => ChildWindowProc, 1, 0);
		UpdateControl(control, .All);
		for (let child in control.Controls)
		{
			if (child.GetHandle() != null)
				UpdateControl(child, .Parent);
		}
	}

	private void ClearInputState(Control control)
	{
		if (mSurrogateControl == control)
		{
			mHighSurrogate = 0;
			mSurrogateControl = null;
		}
		if (Control.IsAncestorOf(control, mHovered))
		{
			let hovered = mHovered;
			mHovered = null;
			Control.UpdateMouseOver(hovered, null);
		}
	}

	private void NotifyControlDestroyed(Control control, void* window)
	{
		if (control.GetHandle() != window)
			return;
		mControls.Remove(window);
		control.NotifyHandleDestroyed(window);
		ClearInputState(control);
	}

	public override void DestroyControl(Control control)
	{
		ClearInputState(control);
		if (control.GetHandle() == null)
			return;
		let handle = control.GetHandle();
		let generation = control.HandleGeneration;
		Win32.DestroyWindow(handle);
		if (control.HandleGeneration.IsCurrent(generation))
			NotifyControlDestroyed(control, handle);
	}

	public override void UpdateControl(Control control, ControlChange change)
	{
		if (change == .Multiline)
		{
			RecreateEditor((TextBoxBase)control);
			return;
		}
		if (control.GetHandle() == null)
			return;
		if (change == .Parent)
			Win32.SetParent(control.GetHandle(), GetParentHandle(control));
		if (!control.IsEffectivelyVisible || !control.IsEffectivelyEnabled)
		{
			if (mControls.TryGetValue(Win32.GetFocus(), let focused) && Control.IsAncestorOf(control, focused))
				Win32.SetFocus(null);
			if (mControls.TryGetValue(Win32.GetCapture(), let captured) && Control.IsAncestorOf(control, captured))
				Win32.ReleaseCapture();
			if (Control.IsAncestorOf(control, mHovered))
			{
				Control.UpdateMouseOver(mHovered, null);
				mHovered = null;
			}
		}
		if (change == .Visibility || change == .Parent || (change == .All && !(control is Form)))
			Win32.ShowWindow(control.GetHandle(), control.IsEffectivelyVisible ? Win32.SW_SHOW : Win32.SW_HIDE);
		if (change == .ZOrder && control.Parent != null)
		{
			for (let child in control.Parent.Controls)
			{
				if (child.GetHandle() != null)
					Win32.SetWindowPos(child.GetHandle(), null, 0, 0, 0, 0,
						Win32.SWP_NOMOVE | Win32.SWP_NOSIZE | Win32.SWP_NOACTIVATE);
			}
		}
		if (change == .Text)
			Win32.SetWindowText(control.GetHandle(), control.Text.ToScopedNativeWChar!());
		if (change == .Font || change == .All)
			Win32.SendMessage(control.GetHandle(), Win32.WM_SETFONT, (uint*)GetNativeFont(control).Handle, (int*)(void*)1);
		if (change == .Enabled || change == .All)
			Win32.EnableWindow(control.GetHandle(), control.IsEffectivelyEnabled ? 1 : 0);
		if (change == .Border && !(control is Form))
			UpdateBorderStyle(control);
		if (change == .Bounds || change == .Constraints || change == .Parent || change == .All)
		{
			let size = control.Size;
			let location = control.Location;
			let offset = control.Parent?.ContentOffset ?? .(0, 0);
			if (let form = control as Form)
				Win32.SetWindowPos(form.GetHandle(), null, location.x, location.y,
					Math.Max(size.width, form.MinimumSize.width), Math.Max(size.height, form.MinimumSize.height), Win32.SWP_NOZORDER);
			else
				Win32.SetWindowPos(control.GetHandle(), null, location.x - offset.x, location.y - offset.y, size.width, size.height, Win32.SWP_NOZORDER);
		}
		if (change == .Scroll || change == .All)
		{
			if (let scrollable = control as ScrollableControl)
				UpdateScrolling(scrollable);
		}
		if (change == .Value || change == .Appearance || change == .All)
		{
			if (let progress = control as ProgressBar)
				UpdateProgressBar(progress, change);
		}
		if (change == .Value || change == .All)
		{
			if (let checkBox = control as CheckBox)
				Win32.SendMessage(control.GetHandle(), Win32.BM_SETCHECK, (uint*)(void*)(checkBox.Checked ? 1 : 0), null);
			if (let radio = control as RadioButton)
				Win32.SendMessage(control.GetHandle(), Win32.BM_SETCHECK, (uint*)(void*)(radio.Checked ? 1 : 0), null);
		}
		if (let editor = control as TextBoxBase)
		{
			if (change == .ReadOnly || change == .All)
				Win32.SendMessage(control.GetHandle(), Win32.EM_SETREADONLY, (uint*)(void*)(editor.ReadOnly ? 1 : 0), null);
			if (change == .Selection || change == .All)
				Win32.SendMessage(control.GetHandle(), Win32.EM_SETSEL,
					(uint*)(void*)TextEncodingHelper.ToUtf16Offset(editor.Text, editor.SelectionAnchor),
					(int*)(void*)TextEncodingHelper.ToUtf16Offset(editor.Text, editor.Caret));
		}
		Win32.InvalidateRect(control.GetHandle(), null, true);
	}

	public override System.Drawing.Rectangle GetScreenWorkingArea()
	{
		Win32.GetCursorPos(var point);
		Win32.MONITORINFO info = .();
		info.cbSize = sizeof(Win32.MONITORINFO);
		Win32.GetMonitorInfo(Win32.MonitorFromPoint(point, Win32.MONITOR_DEFAULTTONEAREST), ref info);
		return .(info.rcWork.left, info.rcWork.top, info.rcWork.right - info.rcWork.left, info.rcWork.bottom - info.rcWork.top);
	}

	public override Size GetClientSize(Form form)
	{
		if (form.GetHandle() == null)
		{
			var frame = Win32.RECT(0, 0, 0, 0);
			Win32.AdjustWindowRectEx(ref frame, GetWindowStyle(form), 0, 0);
			return .(Math.Max(0, form.Size.width - frame.right + frame.left), Math.Max(0, form.Size.height - frame.bottom + frame.top));
		}
		Win32.GetClientRect(form.GetHandle(), var bounds);
		return .(bounds.right, bounds.bottom);
	}

	public override void SetClientSize(Form form, Size size)
	{
		var bounds = Win32.RECT(0, 0, size.width, size.height);
		Win32.AdjustWindowRectEx(ref bounds, GetWindowStyle(form), 0, 0);
		Win32.SetWindowPos(form.GetHandle(), null, form.Location.x, form.Location.y,
			Math.Max(bounds.right - bounds.left, form.MinimumSize.width), Math.Max(bounds.bottom - bounds.top, form.MinimumSize.height), Win32.SWP_NOZORDER);
	}

	public override void Show(Form form)
	{
		Win32.ShowWindow(form.GetHandle(), Win32.SW_SHOW);
	}

	public override void Activate(Form form)
	{
		Win32.SetForegroundWindow(form.GetHandle());
	}

	public override void SetOwner(Form form, Form owner)
	{
		if (form.Parent == null)
			Win32.SetWindowLongPtr(form.GetHandle(), Win32.GWLP_HWNDPARENT, owner?.Handle);
	}

	public override void DoEvents()
	{
		Application.DispatcherCore.VerifyAccess();
		Win32.MSG message = ?;
		while (Win32.PeekMessage(out message, null, 0, 0, Win32.PM_REMOVE) != 0)
		{
			if (message.message == Win32.WM_QUIT)
			{
				// Leave shutdown visible to an enclosing native Run loop.
				Win32.PostQuitMessage((int)(void*)message.wParam);
				break;
			}
			Win32.TranslateMessage(message);
			Win32.DispatchMessage(message);
		}
	}

	public override void Run(Form form)
	{
		Application.DispatcherCore.VerifyAccess();
		Application.DispatcherCore.ProcessDeferredDeletes();
		Win32.MSG message = ?;
		while (form.IsHandleCreated && Win32.GetMessage(out message, null, 0, 0) > 0)
		{
			Win32.TranslateMessage(message);
			Win32.DispatchMessage(message);
			Application.DispatcherCore.ProcessDeferredDeletes();
		}
	}

	private static Win32.LRESULT UserControlWindowProc(void* window, uint32 message, uint32* wParam, int32* lParam)
	{
		return Win32.DefWindowProc(window, message, wParam, lParam);
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
		if (backend.DispatchNativeInput(form, message, wParam, lParam))
			return 0;
		if (form.GetHandle() != window)
			return 0;

		switch (message)
		{
		case Win32.WM_DISPLAYCHANGE:
			backend.mPaintBitmapCache.Invalidate();
		case Win32.WM_COMMAND:
			backend.HandleCommand(wParam, lParam);
		case Win32.WM_SHOWWINDOW:
			let snapshot = form.HandleGeneration;
			let result = Win32.DefWindowProc(window, message, wParam, lParam);
			if (form.GetHandle() == window && form.IsCurrentHandle(snapshot))
				form.NotifyVisibility(wParam != null);
			return result;
		case Win32.WM_GETMINMAXINFO:
			let limits = (Win32.MINMAXINFO*)lParam;
			limits.minTrackSize.x = Math.Max(limits.minTrackSize.x, form.MinimumSize.width);
			limits.minTrackSize.y = Math.Max(limits.minTrackSize.y, form.MinimumSize.height);
			return 0;
		case Win32.WM_SIZE:
			Win32.GetWindowRect(window, var windowBounds);
			form.NotifyResize(.(windowBounds.right - windowBounds.left, windowBounds.bottom - windowBounds.top));
		case Win32.WM_MOVE:
			Win32.GetWindowRect(window, var bounds);
			form.NotifyMove(.(bounds.left, bounds.top));
		case Win32.WM_CLOSE:
			form.Close();
			return 0;
		case Win32.WM_NCDESTROY:
			backend.NotifyControlDestroyed(form, window);
			return Win32.DefWindowProc(window, message, wParam, lParam);
		default:
		}
		return form.GetHandle() == window ? Win32.DefWindowProc(window, message, wParam, lParam) : 0;
	}
}
#endif
