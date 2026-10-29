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
		let window = label.GetHandle();
		let context = Win32.BeginPaint(window, var paint);
		defer Win32.EndPaint(window, ref paint);

		Win32.GetClientRect(window, var bounds);
		if (!label.[Friend]DoubleBuffered || !PaintBufferedLabel(label, context, bounds))
			DrawLabel(label, context, bounds);

		label.NotifyPaint();
	}

	private bool PaintBufferedLabel(Label label, void* context, Win32.RECT bounds)
	{
		let width = bounds.right - bounds.left;
		let height = bounds.bottom - bounds.top;
		if (width <= 0 || height <= 0)
			return false;

		using (var lease = mPaintBitmapCache.Acquire(context, width, height))
		{
			if (lease.Bitmap == null)
				return false;

			let buffer = Win32.CreateCompatibleDC(context);
			if (buffer == null)
				return false;
			defer Win32.DeleteDC(buffer);

			let previous = Win32.SelectObject(buffer, lease.Bitmap);
			if (previous == null)
				return false;
			defer Win32.SelectObject(buffer, previous);

			DrawLabel(label, buffer, bounds);
			return Win32.BitBlt(context, 0, 0, width, height, buffer, 0, 0, Win32.SRCCOPY);
		}
	}

	private void DrawLabel(Label label, void* context, Win32.RECT clientBounds)
	{
		var bounds = clientBounds;
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
	}
}
#endif
