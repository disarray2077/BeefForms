using System;
using System.Collections;
using System.Drawing;
using System.Windows.Forms;

using internal System.Drawing;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	private class NativeFont
	{
		public void* Handle ~ Win32.DeleteObject(_);
		public int32 Height;
		public this(void* handle, int32 height) { Handle = handle; Height = height; }
	}
	private append Dictionary<String, NativeFont> mFonts = .() ~ DeleteDictionaryKeysAndValues!(_);
	private uint mGdiPlusToken;

	private NativeFont GetNativeFont(Control control)
	{
		let font = control.Font;
		let family = font == null ? "Segoe UI" : font.FamilyName;
		uint32 dpi = control.Handle == null ? 96 : Win32.GetDpiForWindow(control.Handle);
		let pixels = font == null ? 9f * dpi / 72 : font.GetPixelSize(dpi);
		let style = font == null ? FontStyle.Regular : font.Style;
		let key = scope $"{family}:{pixels}:{style}:{dpi}";
		if (mFonts.TryGetValue(key, let cached)) return cached;

		let handle = Win32.CreateFont(-(int32)Math.Round(pixels), 0, 0, 0, style.HasFlag(.Bold) ? 700 : 400,
			style.HasFlag(.Italic) ? 1 : 0, style.HasFlag(.Underline) ? 1 : 0, style.HasFlag(.Strikeout) ? 1 : 0,
			1, 0, 0, 5, 0, family.ToScopedNativeWChar!());
		if (mGdiPlusToken == 0)
		{
			Win32.GdiplusStartupInput startup = .();
			startup.Version = 1;
			Win32.GdiplusStartup(out mGdiPlusToken, ref startup, null);
		}
		let context = Win32.GetDC(control.Handle);
		defer Win32.ReleaseDC(control.Handle, context);
		let previous = Win32.SelectObject(context, handle);
		defer Win32.SelectObject(context, previous);
		void* measuredFont = null;
		Win32.GdipCreateFontFromDC(context, out measuredFont);
		defer Win32.GdipDeleteFont(measuredFont);
		float height = 0;
		Win32.GdipGetFontHeightGivenDPI(measuredFont, dpi, out height);
		let result = new NativeFont(handle, (int32)Math.Ceiling(height));
		mFonts.Add(new String(key), result);
		return result;
	}

	public override int32 GetTextBoxHeight(TextBoxBase editor)
	{
		uint32 dpi = editor.Handle == null ? 96 : Win32.GetDpiForWindow(editor.Handle);
		return GetNativeFont(editor).Height + (editor.BorderStyle == .None ? 0 : Win32.GetSystemMetricsForDpi(Win32.SM_CYBORDER, dpi) * 4 + 3);
	}
}
#endif
