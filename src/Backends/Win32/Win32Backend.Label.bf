using System;
using System.Windows.Forms;
using internal System.Windows.Forms;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	private void PaintLabel(Label label)
	{
		let context = Win32.BeginPaint(label.Handle, var paint);
		defer Win32.EndPaint(label.Handle, ref paint);
		Win32.GetClientRect(label.Handle, var bounds);
		Win32.FillRect(context, ref bounds, (void*)16);
		let font = (void*)Win32.SendMessage(label.Handle, Win32.WM_GETFONT, null, null);
		let previous = Win32.SelectObject(context, font);
		defer Win32.SelectObject(context, previous);
		Win32.SetBkMode(context, Win32.TRANSPARENT);
		Win32.SetTextColor(context, Win32.GetSysColor(label.Enabled ? 18 : 17));
		uint flags = Win32.DT_NOPREFIX;
		flags |= (label.AutoEllipsis && !label.AutoSize) ? Win32.DT_SINGLELINE | Win32.DT_END_ELLIPSIS : Win32.DT_WORDBREAK;
		if (label.HorizontalTextAlignment == 1) flags |= Win32.DT_CENTER;
		if (label.HorizontalTextAlignment == 2) flags |= Win32.DT_RIGHT;
		let text = label.Text.ToScopedNativeWChar!();
		var measured = bounds;
		Win32.DrawText(context, text, -1, ref measured, flags | Win32.DT_CALCRECT);
		let remaining = Math.Max(0, bounds.bottom - (measured.bottom - measured.top));
		if (label.VerticalTextAlignment == 1) bounds.top += remaining / 2;
		if (label.VerticalTextAlignment == 2) bounds.top += remaining;
		Win32.DrawText(context, text, -1, ref bounds, flags);
		label.NotifyPaint();
	}
}
#endif
