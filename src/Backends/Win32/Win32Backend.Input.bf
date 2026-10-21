using System;
using System.Collections;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	public override bool IsFocused(Control control) => Win32.GetFocus() == control.Handle;
	public override bool HasCapture(Control control) => Win32.GetCapture() == control.Handle;
	public override void SetCapture(Control control, bool capture)
	{
		if (capture) Win32.SetCapture(control.Handle);
		else if (HasCapture(control)) Win32.ReleaseCapture();
	}
	public override bool FocusControl(Control control)
	{
		if (!control.CanSelect) return false;
		Win32.SetFocus(control.Handle);
		return IsFocused(control);
	}

	private static Win32.LRESULT ChildWindowProc(void* window, uint32 message, uint32* wParam, int32* lParam, uint id, uint data)
	{
		let backend = (Win32Backend)Application.Backend;
		if (backend.mControls.TryGetValue(window, let control))
		{
			if (message == Win32.WM_PAINT && control is Label)
			{
				backend.PaintLabel((Label)control);
				return 0;
			}
			if (control is GroupBox && message == Win32.WM_ERASEBKGND)
			{
				// Native group boxes leave background erasure to their host.
				Win32.GetClientRect(window, var bounds);
				Win32.FillRect(wParam, ref bounds, (void*)16);
				return 1;
			}
			if (backend.DispatchNativeInput(control, message, wParam, lParam))
				return 0;
			if (message == Win32.WM_COMMAND)
				backend.HandleCommand(wParam, lParam);
			if (message == Win32.WM_NCDESTROY)
			{
				Win32.RemoveWindowSubclass(window, => ChildWindowProc, id);
				control.SetNativeHandle(null);
				backend.mControls.Remove(window);
			}
			// BUTTON's press handling would give the frame keyboard focus.
			if (control is GroupBox && (message == Win32.WM_LBUTTONDOWN || message == Win32.WM_LBUTTONDBLCLK))
				return Win32.DefWindowProc(window, message, wParam, lParam);
			// Let Windows track non-client scrollbars instead of the STATIC/BUTTON class's click handling.
			if (control is ScrollableControl && (message == Win32.WM_NCLBUTTONDOWN || message == Win32.WM_NCLBUTTONDBLCLK))
				return Win32.DefWindowProc(window, message, wParam, lParam);
			let result = Win32.DefSubclassProc(window, message, wParam, lParam);
			// STATIC and group boxes are mouse-transparent; preserve client and scrollbar hit testing.
			if (message == Win32.WM_NCHITTEST && result == Win32.HTTRANSPARENT)
				return Win32.DefWindowProc(window, message, wParam, lParam);
			if (message == Win32.WM_PAINT) control.NotifyPaint();
			if (let editor = control as TextBoxBase)
				backend.SynchronizeSelectionAfterMessage(editor, message);
			return result;
		}
		return Win32.DefSubclassProc(window, message, wParam, lParam);
	}

	private void HandleCommand(uint32* wParam, int32* lParam)
	{
		if (!mControls.TryGetValue((void*)lParam, let control))
			return;
		let notification = (uint)(void*)wParam >> 16;
		if (let button = control as ButtonBase)
			if (notification == 0)
				button.PerformClick();
		if (control is TextBoxBase && notification == 0x300)
			NotifyNativeText(control);
	}

	private static Keys KeyboardModifiers()
	{
		Keys result = .None;
		if (Win32.GetKeyState(16) < 0) result |= .Shift;
		if (Win32.GetKeyState(17) < 0) result |= .Control;
		if (Win32.GetKeyState(18) < 0) result |= .Alt;
		return result;
	}

	private void AdvanceFocus(Control focused, bool backward)
	{
		var root = focused;
		while (root.Parent != null) root = root.Parent;
		if (let next = Control.NextTabControl(root, focused, backward)) FocusControl(next);
	}

	private bool DispatchNativeInput(Control control, uint32 message, uint32* wParam, int32* lParam)
	{
		if (HandleScroll(control, message, wParam)) return true;
		switch (message)
		{
		case Win32.WM_SETFOCUS, Win32.WM_KILLFOCUS:
			let focused = message == Win32.WM_SETFOCUS;
			if (control is Button)
				Win32.SendMessage(control.Handle, Win32.BM_SETSTYLE,
					(uint*)(void*)(focused ? Win32.BS_DEFPUSHBUTTON : Win32.BS_PUSHBUTTON), (int*)(void*)1);
			if (!focused)
			{
				mHighSurrogate = 0;
				mSurrogateControl = null;
			}
			control.NotifyFocus(focused);
		case Win32.WM_KEYDOWN, Win32.WM_SYSKEYDOWN, Win32.WM_KEYUP, Win32.WM_SYSKEYUP:
			let down = message == Win32.WM_KEYDOWN || message == Win32.WM_SYSKEYDOWN;
			let args = scope KeyEventArgs((Keys)(uint)(void*)wParam | KeyboardModifiers());
			if (down && args.KeyCode == .Tab)
			{
				AdvanceFocus(control, args.Shift);
				mSuppressChars = true;
				return true;
			}
			control.DispatchInput(down ? .KeyDown : .KeyUp, args);
			mSuppressChars = down && args.SuppressKeyPress;
			return args.Handled || args.SuppressKeyPress;
		case Win32.WM_CHAR:
			return HandleCharacter(control, (char16)(uint)(void*)wParam, lParam);
		case Win32.WM_MOUSELEAVE:
			if (mHovered == control)
			{
				Control.UpdateMouseOver(mHovered, null);
				mHovered = null;
			}
		case Win32.WM_MOUSEMOVE, Win32.WM_LBUTTONDOWN, Win32.WM_LBUTTONUP, Win32.WM_LBUTTONDBLCLK,
			Win32.WM_RBUTTONDOWN, Win32.WM_RBUTTONUP, Win32.WM_RBUTTONDBLCLK,
			Win32.WM_MBUTTONDOWN, Win32.WM_MBUTTONUP, Win32.WM_MBUTTONDBLCLK,
			Win32.WM_MOUSEWHEEL, Win32.WM_MOUSEHWHEEL:
			let packed = (uint)(void*)lParam;
			Win32.POINT point = .() { x = (int16)(packed & 0xFFFF), y = (int16)((packed >> 16) & 0xFFFF) };
			let wheel = message == Win32.WM_MOUSEWHEEL || message == Win32.WM_MOUSEHWHEEL;
			if (wheel) Win32.ScreenToClient(control.Handle, ref point);
			MouseButtons button = .None;
			InputEventKind kind = .MouseMove;
			switch (message)
			{
			case Win32.WM_LBUTTONDOWN: button = .Left; kind = .MouseDown;
			case Win32.WM_LBUTTONUP: button = .Left; kind = .MouseUp;
			case Win32.WM_LBUTTONDBLCLK: button = .Left; kind = .MouseDoubleClick;
			case Win32.WM_RBUTTONDOWN: button = .Right; kind = .MouseDown;
			case Win32.WM_RBUTTONUP: button = .Right; kind = .MouseUp;
			case Win32.WM_RBUTTONDBLCLK: button = .Right; kind = .MouseDoubleClick;
			case Win32.WM_MBUTTONDOWN: button = .Middle; kind = .MouseDown;
			case Win32.WM_MBUTTONUP: button = .Middle; kind = .MouseUp;
			case Win32.WM_MBUTTONDBLCLK: button = .Middle; kind = .MouseDoubleClick;
			case Win32.WM_MOUSEWHEEL, Win32.WM_MOUSEHWHEEL: kind = .MouseWheel;
			default:
			}
			if (kind == .MouseMove)
			{
				Control.UpdateMouseOver(mHovered, control);
				mHovered = control;
				Win32.TRACKMOUSEEVENT tracking = .(sizeof(Win32.TRACKMOUSEEVENT), 2, control.Handle, 0);
				Win32.TrackMouseEvent(ref tracking);
			}
			let delta = wheel ? (int16)(((uint)(void*)wParam >> 16) & 0xFFFF) : 0;
			let doubleClick = kind == .MouseDoubleClick;
			int32 clicks = doubleClick ? 2 : ((kind == .MouseMove || wheel) ? 0 : 1);
			let args = scope MouseEventArgs(button, clicks, point.x, point.y,
				message == Win32.WM_MOUSEWHEEL ? delta : 0, message == Win32.WM_MOUSEHWHEEL ? delta : 0);
			control.DispatchInput(doubleClick ? .MouseDown : kind, args);
			if (doubleClick && !args.Handled) control.DispatchInput(.MouseDoubleClick, args);
			if (args.Handled) return true;
			if ((kind == .MouseDown || doubleClick) && !(control is Form) && control.CanSelect) FocusControl(control);
		default:
		}
		return false;
	}
}
#endif
