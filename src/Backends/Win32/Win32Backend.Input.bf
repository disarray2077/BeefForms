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
		Win32.SetFocus(control.Handle);
		return IsFocused(control);
	}

	private static Win32.LRESULT ChildWindowProc(void* window, uint32 message, uint32* wParam, int32* lParam, uint id, uint data)
	{
		let backend = (Win32Backend)Application.Backend;
		if (backend.mControls.TryGetValue(window, let control))
		{
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
		}
		return Win32.DefSubclassProc(window, message, wParam, lParam);
	}

	private void HandleCommand(uint32* wParam, int32* lParam)
	{
		if (!mControls.TryGetValue((void*)lParam, let control))
			return;
		let notification = (uint)(void*)wParam >> 16;
		if (let button = control as Button)
			if (notification == 0)
				button.PerformClick();
		if (control is TextBoxBase && notification == 0x300)
		{
			let length = Win32.GetWindowTextLength(control.Handle);
			let text = scope String(length + 1);
			text.Append('\0', length);
			text.Length = Win32.GetWindowText(control.Handle, text.Ptr, length + 1);
			control.NotifyText(text);
		}
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
		let controls = scope List<Control>();
		CollectFocusable(root, controls);
		controls.Sort(scope (a, b) => a.TabIndex <=> b.TabIndex);
		if (controls.IsEmpty) return;
		let index = controls.IndexOf(focused);
		let next = index < 0 ? (backward ? controls.Count - 1 : 0)
			: (index + controls.Count + (backward ? -1 : 1)) % controls.Count;
		FocusControl(controls[next]);
	}

	private static void CollectFocusable(Control control, List<Control> controls)
	{
		if (!control.IsEffectivelyEnabled || !control.IsEffectivelyVisible) return;
		if (control.TabStop && control.TabIndex >= 0) controls.Add(control);
		for (let child in control.Controls) CollectFocusable(child, controls);
	}

	private bool DispatchNativeInput(Control control, uint32 message, uint32* wParam, int32* lParam)
	{
		if (HandleScroll(control, message, wParam)) return true;
		switch (message)
		{
		case Win32.WM_SETFOCUS: control.NotifyFocus(true);
		case Win32.WM_KILLFOCUS: control.NotifyFocus(false);
		case Win32.WM_KEYDOWN, Win32.WM_SYSKEYDOWN, Win32.WM_KEYUP, Win32.WM_SYSKEYUP:
			let down = message == Win32.WM_KEYDOWN || message == Win32.WM_SYSKEYDOWN;
			let args = scope KeyEventArgs((Keys)(uint)(void*)wParam | KeyboardModifiers());
			control.DispatchInput(down ? .KeyDown : .KeyUp, args);
			if (!down) mSuppressChars = false;
			else mSuppressChars = args.SuppressKeyPress;
			if (down && !args.Handled && args.KeyCode == .Tab)
			{
				AdvanceFocus(control, args.Shift);
				mSuppressChars = true;
				return true;
			}
			return args.Handled || args.SuppressKeyPress;
		case Win32.WM_CHAR:
			if (mSuppressChars) return true;
			let args = scope KeyPressEventArgs((char32)(uint)(void*)wParam);
			control.DispatchInput(.KeyPress, args);
			if (args.Handled) return true;
			if (args.KeyChar >= ' ')
			{
				let text = scope String()..Append(args.KeyChar);
				let input = scope TextInputEventArgs(text);
				control.DispatchInput(.TextInput, input);
				return input.Handled;
			}
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
			let args = scope MouseEventArgs(button, kind == .MouseDoubleClick ? 2 : 1, point.x, point.y,
				message == Win32.WM_MOUSEWHEEL ? delta : 0, message == Win32.WM_MOUSEHWHEEL ? delta : 0);
			control.DispatchInput(kind, args);
			if (args.Handled) return true;
			if (kind == .MouseDown && control.TabStop) FocusControl(control);
			if (wheel && !(control is TextBoxBase)) return true;
		default:
		}
		return false;
	}
}
#endif
