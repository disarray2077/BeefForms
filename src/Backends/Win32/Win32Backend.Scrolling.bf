using System;
using System.Drawing;
using System.Windows.Forms;
using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	public override int32 ScrollBarSize => Win32.GetSystemMetrics(2);

	private void UpdateScrolling(ScrollableControl control)
	{
		let viewport = control.ViewportSize;
		let content = control.ScrollContentSize;
		for (let horizontal in scope bool[](true, false))
		{
			Win32.SCROLLINFO info = .(
				sizeof(Win32.SCROLLINFO), 7, 0,
				Math.Max(0, (horizontal ? content.width : content.height) - 1),
				(uint32)(horizontal ? viewport.width : viewport.height),
				horizontal ? control.ScrollPosition.x : control.ScrollPosition.y, 0);
			Win32.SetScrollInfo(control.Handle, horizontal ? 0 : 1, ref info, true);
			Win32.ShowScrollBar(control.Handle, horizontal ? 0 : 1,
				horizontal ? control.HorizontalScrollVisible : control.VerticalScrollVisible);
		}
		for (let child in control.Controls)
			UpdateControl(child, .Bounds);
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
