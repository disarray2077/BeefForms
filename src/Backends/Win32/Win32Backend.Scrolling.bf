using System;
using System.Drawing;
using System.Windows.Forms;
using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	public override Size GetScrollBarSize(Control control)
	{
		if (control.Handle == null)
			return .(Win32.GetSystemMetrics(Win32.SM_CXVSCROLL), Win32.GetSystemMetrics(Win32.SM_CYHSCROLL));
		let dpi = Win32.GetDpiForWindow(control.Handle);
		return .(Win32.GetSystemMetricsForDpi(Win32.SM_CXVSCROLL, dpi),
			Win32.GetSystemMetricsForDpi(Win32.SM_CYHSCROLL, dpi));
	}

	public override Size GetScrollClientSize(Control control)
	{
		if (control.Handle == null) return control.ClientSize;
		Win32.GetClientRect(control.Handle, var client);
		let style = (uint)(void*)Win32.GetWindowLongPtr(control.Handle, Win32.GWL_STYLE);
		let bars = GetScrollBarSize(control);
		// Layout uses the client area before scrollbars; ViewportSize subtracts them once.
		return .(client.right + ((style & Win32.WS_VSCROLL) != 0 ? bars.width : 0),
			client.bottom + ((style & Win32.WS_HSCROLL) != 0 ? bars.height : 0));
	}

	private void UpdateScrolling(ScrollableControl control)
	{
		let viewport = control.ViewportSize;
		let content = control.ScrollContentSize;
		Point delta = .(0, 0);
		for (let horizontal in scope bool[](true, false))
		{
			Win32.SCROLLINFO info = .(sizeof(Win32.SCROLLINFO), 4, 0, 0, 0, 0, 0);
			Win32.GetScrollInfo(control.Handle, horizontal ? 0 : 1, ref info);
			if (horizontal) delta.x = info.nPos - control.ScrollPosition.x;
			else delta.y = info.nPos - control.ScrollPosition.y;
			info = .(
				sizeof(Win32.SCROLLINFO), 7, 0,
				Math.Max(0, (horizontal ? content.width : content.height) - 1),
				(uint32)(horizontal ? viewport.width : viewport.height),
				horizontal ? control.ScrollPosition.x : control.ScrollPosition.y, 0);
			Win32.SetScrollInfo(control.Handle, horizontal ? 0 : 1, ref info, 1);
			Win32.ShowScrollBar(control.Handle, horizontal ? 0 : 1,
				(horizontal ? control.HorizontalScrollVisible : control.VerticalScrollVisible) ? 1 : 0);
		}
		if (delta.x != 0 || delta.y != 0)
		{
			// Preserve visible pixels and move native children; only exposed areas need repainting.
			Win32.GetClientRect(control.Handle, var clip);
			Win32.ScrollWindowEx(control.Handle, delta.x, delta.y, null, &clip, null, null,
				Win32.SW_INVALIDATE | Win32.SW_ERASE | Win32.SW_SCROLLCHILDREN);
		}
	}

	private bool HandleScroll(Control control, uint32 message, uint32* wParam)
	{
		if (message != Win32.WM_HSCROLL && message != Win32.WM_VSCROLL) return false;
		let scrollable = control as ScrollableControl;
		if (scrollable == null || !scrollable.AutoScroll) return false;
		let horizontal = message == Win32.WM_HSCROLL;
		let command = (uint)(void*)wParam & 0xFFFF;
		var position = scrollable.ScrollPosition;
		var value = horizontal ? position.x : position.y;
		let page = horizontal ? scrollable.ViewportSize.width : scrollable.ViewportSize.height;
		switch (command)
		{
		case 0: value -= 16;
		case 1: value += 16;
		case 2: value -= page;
		case 3: value += page;
		case 4, 5:
			Win32.SCROLLINFO info = .(sizeof(Win32.SCROLLINFO), 0x10, 0, 0, 0, 0, 0);
			Win32.GetScrollInfo(control.Handle, horizontal ? 0 : 1, ref info);
			value = info.nTrackPos;
		case 6: value = 0;
		case 7: value = int32.MaxValue;
		default: return true;
		}
		if (horizontal) position.x = value;
		else position.y = value;
		scrollable.ScrollPosition = position;
		return true;
	}
}
#endif
