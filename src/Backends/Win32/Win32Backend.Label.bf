using System;
using System.Windows.Forms;
using internal System.Windows.Forms;
using internal System.Drawing;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	private void PaintLabel(Label label)
	{
		let context = Win32.BeginPaint(label.GetHandle(), var paint);
		defer Win32.EndPaint(label.GetHandle(), ref paint);

		Win32.GetClientRect(label.GetHandle(), var bounds);
		Win32.FillRect(context, ref bounds, (void*)(Win32.COLOR_BTNFACE + 1));

		let font = (void*)Win32.SendMessage(label.GetHandle(), Win32.WM_GETFONT, null, null);
		let previous = Win32.SelectObject(context, font);
		defer Win32.SelectObject(context, previous);

		Win32.SetBkMode(context, Win32.TRANSPARENT);
		Win32.SetTextColor(context, Win32.GetSysColor(label.Enabled ? Win32.COLOR_BTNTEXT : Win32.COLOR_GRAYTEXT));

		let padding = (GetNativeFont(label).Height + 5) / 6;
		bounds.left += padding;
		bounds.right = Math.Max(bounds.left, bounds.right - padding);

		uint flags = Win32.DT_NOPREFIX;
		flags |= (label.AutoEllipsis && !label.AutoSize) ? Win32.DT_SINGLELINE | Win32.DT_END_ELLIPSIS : Win32.DT_WORDBREAK;
		if (label.TextAlign.Horizontal == .Center)
			flags |= Win32.DT_CENTER;
		if (label.TextAlign.Horizontal == .Right)
			flags |= Win32.DT_RIGHT;

		let text = label.Text.ToScopedNativeWChar!();
		var measured = bounds;
		Win32.DrawText(context, text, -1, ref measured, flags | Win32.DT_CALCRECT);

		let remaining = Math.Max(0, bounds.bottom - (measured.bottom - measured.top));
		if (label.TextAlign.Vertical == .Middle)
			bounds.top += remaining / 2;
		if (label.TextAlign.Vertical == .Bottom)
			bounds.top += remaining;
		Win32.DrawText(context, text, -1, ref bounds, flags);

		label.NotifyPaint();
	}
}
#endif
