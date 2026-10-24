using System;
using System.Drawing;
using System.Windows;
using System.Windows.Forms;
using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	public override Size GetScrollBarSize(Control control)
	{
		if (control.GetHandle() == null)
			return .(Win32.GetSystemMetrics(Win32.SM_CXVSCROLL), Win32.GetSystemMetrics(Win32.SM_CYHSCROLL));
		let dpi = Win32.GetDpiForWindow(control.GetHandle());
		return .(Win32.GetSystemMetricsForDpi(Win32.SM_CXVSCROLL, dpi),
			Win32.GetSystemMetricsForDpi(Win32.SM_CYHSCROLL, dpi));
	}

	public override Size GetScrollClientSize(Control control)
	{
		if (control.GetHandle() == null) return control.ClientSize;
		Win32.GetClientRect(control.GetHandle(), var client);
		let style = (uint)(void*)Win32.GetWindowLongPtr(control.GetHandle(), Win32.GWL_STYLE);
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
			Win32.SCROLLINFO info = .(sizeof(Win32.SCROLLINFO), Win32.SIF_POS, 0, 0, 0, 0, 0);
			Win32.GetScrollInfo(control.GetHandle(), horizontal ? Win32.SB_HORZ : Win32.SB_VERT, ref info);
			if (horizontal) delta.x = info.nPos - control.ScrollPosition.x;
			else delta.y = info.nPos - control.ScrollPosition.y;
			info = .(
				sizeof(Win32.SCROLLINFO), Win32.SIF_RANGE | Win32.SIF_PAGE | Win32.SIF_POS, 0,
				Math.Max(0, (horizontal ? content.width : content.height) - 1),
				(uint32)(horizontal ? viewport.width : viewport.height),
				horizontal ? control.ScrollPosition.x : control.ScrollPosition.y, 0);
			Win32.SetScrollInfo(control.GetHandle(), horizontal ? Win32.SB_HORZ : Win32.SB_VERT, ref info, 1);
			Win32.ShowScrollBar(control.GetHandle(), horizontal ? Win32.SB_HORZ : Win32.SB_VERT,
				(horizontal ? control.HorizontalScrollVisible : control.VerticalScrollVisible) ? 1 : 0);
		}
		if (delta.x != 0 || delta.y != 0)
		{
			// Preserve visible pixels and move native children; only exposed areas need repainting.
			Win32.GetClientRect(control.GetHandle(), var clip);
			Win32.ScrollWindowEx(control.GetHandle(), delta.x, delta.y, null, &clip, null, null,
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
		case Win32.SB_LINEUP: value -= 16;
		case Win32.SB_LINEDOWN: value += 16;
		case Win32.SB_PAGEUP: value -= page;
		case Win32.SB_PAGEDOWN: value += page;
		case Win32.SB_THUMBPOSITION, Win32.SB_THUMBTRACK:
			Win32.SCROLLINFO info = .(sizeof(Win32.SCROLLINFO), Win32.SIF_TRACKPOS, 0, 0, 0, 0, 0);
			Win32.GetScrollInfo(control.GetHandle(), horizontal ? Win32.SB_HORZ : Win32.SB_VERT, ref info);
			value = info.nTrackPos;
		case Win32.SB_TOP: value = 0;
		case Win32.SB_BOTTOM: value = int32.MaxValue;
		default: return true;
		}
		if (horizontal) position.x = value;
		else position.y = value;
		scrollable.ScrollPosition = position;
		return true;
	}
}
#endif
