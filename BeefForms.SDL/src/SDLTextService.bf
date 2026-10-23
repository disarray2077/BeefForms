using System;
using System.Collections;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Forms;
using SDL2;

using internal System.Windows.Forms;
using internal System.Drawing;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

// Font metrics and text layout have no window or OpenGL resources.
internal class SDLTextService
{
	// Shared by painting, hit testing, and keyboard navigation in logical pixels.
	public const int32 EditorTextInset = 4;
	private const int32 FontStyleStride = 32;

	private append Dictionary<int32, SDLTTF.Font*> mFonts = .();
	private append String mConfiguredPath = .();
	private append String mFontPath = .();

	public this(StringView fontPath)
	{
		mConfiguredPath.Set(fontPath);
		mFontPath.Set(fontPath);
		if (mFontPath.IsEmpty)
		{
#if BF_PLATFORM_WASM
			mFontPath.Set("/BeefForms/fonts/NotoSans-Regular.ttf");
#elif BF_PLATFORM_WINDOWS
			Environment.GetEnvironmentVariable("WINDIR", mFontPath);
			mFontPath.Append("/Fonts/segoeui.ttf");
#else
			mFontPath.Set("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");
#endif
		}
		if (!File.Exists(mFontPath)) Runtime.FatalError(scope $"Cannot find the UI font: {mFontPath}");
		if (SDLTTF.Init() != 0) Runtime.FatalError(scope $"Could not initialize SDL_ttf: {StringView(SDL.GetError())}");
	}

	public ~this()
	{
		for (let entry in mFonts) SDLTTF.CloseFont(entry.value);
		SDLTTF.Quit();
	}

	public bool UsesPath(StringView path) => mConfiguredPath == path;

	public static int32 FontKey(Control control, float rasterScale = 1)
	{
		let font = control.Font;
		let pixels = font == null ? 12 : Math.Max(1, (int32)font.GetPixelSize(96));
		return (int32)Math.Ceiling(pixels * rasterScale) * FontStyleStride + (font == null ? 0 : (int32)font.Style);
	}

	public SDLTTF.Font* GetFont(Control control, float rasterScale = 1)
	{
		let key = FontKey(control, rasterScale);
		if (mFonts.TryGetValue(key, let font)) return font;
		let result = SDLTTF.OpenFont(mFontPath, key / FontStyleStride);
		if (result == null) Runtime.FatalError(scope $"Could not open UI font: {StringView(SDL.GetError())}");
		SDLTTF.SetFontStyle(result, key % FontStyleStride);
		mFonts.Add(key, result);
		return result;
	}

	public int32 LineHeight(Control control) => SDLTTF.FontLineSkip(GetFont(control));
	public int32 LabelPadding(Control control) => (LineHeight(control) + 5) / 6;
	public int32 LayoutWidth(Control control) => control is Label && !control.AutoSize ? Math.Max(1, control.ClientSize.width - LabelPadding(control) * 2) : 0;
	public static HorizontalAlignment Alignment(Control control) => (control as Label)?.TextAlign.Horizontal ?? .Left;
	public static bool HasEllipsis(Control control) => (control as Label)?.AutoEllipsis == true && !control.AutoSize;

	public void GetDisplayText(Control control, String display)
	{
		display.Set(control.Text);
		if (!HasEllipsis(control)) return;
		let width = control.ClientSize.width - LabelPadding(control) * 2;
		if (Measure(control, display) <= width) return;
		let available = width - Measure(control, "...");
		let boundaries = scope List<int>();
		// Search complete prefixes so SDL_ttf retains kerning and glyph bounds.
		TextEncodingHelper.GetCharacterBoundaries(display, boundaries);
		int low = 0, high = boundaries.Count - 1;
		while (low < high)
		{
			let middle = (low + high + 1) / 2;
			if (Measure(control, .(display, 0, boundaries[middle])) <= available) low = middle;
			else high = middle - 1;
		}
		let length = boundaries[low];
		display.Remove(length, display.Length - length);
		display.Append("...");
	}

	public int32 Measure(Control control, StringView text)
	{
		int32 width = 0, height = 0;
		if (SDLTTF.SizeUTF8(GetFont(control), scope String(text), out width, out height) != 0)
			Runtime.FatalError(scope $"Could not measure UI text: {StringView(SDL.GetError())}");
		return width;
	}

	public Size MeasureText(Control control)
	{
		if (control.Text.IsEmpty) return .(0, 0);
		let display = scope String();
		GetDisplayText(control, display);
		let size = LayoutText(control, display);
		return .(size.width + ((control is Label) ? LabelPadding(control) * 2 : 0), size.height);
	}

	public struct TextLine
	{
		public int Start, Length;
		public int32 Width, Height;
		public this(int start, int length, int32 width, int32 height)
		{
			Start = start; Length = length; Width = width; Height = height;
		}
	}

	public Size LayoutText(Control control, String display, List<TextLine> lines = null) =>
		MeasureWrapped(GetFont(control), display, HasEllipsis(control) ? 0 : LayoutWidth(control), Alignment(control), lines);

	// Match SDL_ttf's wrapped surface bounds using metrics, without rasterizing pixels.
	private Size MeasureWrapped(SDLTTF.Font* font, String text, int32 wrapWidth, HorizontalAlignment alignment, List<TextLine> lines)
	{
		if (SDLTTF.SizeUTF8(font, text, var fullWidth, var fullHeight) != 0)
			Runtime.FatalError(scope $"Could not measure UI text: {StringView(SDL.GetError())}");
		int rows = 0, widest = 0, start = 0;
		while (start < text.Length)
		{
			int32 limit = int32.MaxValue;
			if (wrapWidth > 0)
			{
				if (SDLTTF.MeasureUTF8(font, text.Ptr + start, wrapWidth, var extent, var count) != 0)
					Runtime.FatalError(scope $"Could not measure wrapped UI text: {StringView(SDL.GetError())}");
				limit = Math.Max(1, count);
			}
			int position = start, characters = 0, lastBreak = -1, breakEnd = -1, end = start;
			while (position < text.Length)
			{
				let previous = position;
				let (character, bytes) = UTF8.Decode(text.Ptr + position, text.Length - position);
				position += Math.Max(1, (int)bytes);
				end = position;
				if (character == '\u{FEFF}' || character == '\u{FFFE}') continue;
				characters++;
				let newline = character == '\n' || (wrapWidth > 0 && character == '\r');
				if (newline || (wrapWidth > 0 && (character == ' ' || character == '\t')))
				{
					lastBreak = position;
					breakEnd = newline ? previous : position;
				}
				if (newline) { end = previous; break; }
				if (characters == limit) break;
			}
			if (lastBreak >= 0 && position < text.Length) { position = lastBreak; end = breakEnd; }
			let line = scope String(text, start, end - start);
			if (SDLTTF.SizeUTF8(font, line, var width, var height) != 0)
				Runtime.FatalError(scope $"Could not measure UI text: {StringView(SDL.GetError())}");
			lines?.Add(.(start, end - start, width, height));
			widest = Math.Max(widest, width);
			rows++;
			start = position;
		}
		let lineSkip = SDLTTF.FontLineSkip(font);
		let width = wrapWidth == 0 ? (rows > 1 ? Math.Max(1, widest) : fullWidth)
			: (rows <= 1 && alignment == .Left ? Math.Min(wrapWidth, fullWidth) : wrapWidth);
		return .((int32)width, (int32)(Math.Max(fullHeight, lineSkip) + lineSkip * Math.Max(0, rows - 1)));
	}

	public Point TextPosition(TextBoxBase control, int position)
	{
		int lineStart = 0, line = 0;
		for (int i < position)
			if (control.Text[i] == '\n') { lineStart = i + 1; line++; }
		return .(Measure(control, .(control.Text, lineStart, position - lineStart)), (int32)(line * LineHeight(control)));
	}

	public int HitText(TextBoxBase control, int x, int y)
	{
		let line = Math.Max(0, (y + control.BorderWidth + control.ScrollY - EditorTextInset) / LineHeight(control));
		int start = 0;
		for (int i < line)
		{
			let end = control.Text.IndexOf('\n', start);
			if (end < 0) return control.Text.Length;
			start = end + 1;
		}
		var end = control.Text.IndexOf('\n', start);
		if (end < 0) end = control.Text.Length;
		let text = StringView(control.Text, start, end - start);
		let boundaries = scope List<int>();
		TextEncodingHelper.GetCharacterBoundaries(text, boundaries);
		let target = x + control.BorderWidth + control.ScrollX - EditorTextInset;
		int low = 0, high = boundaries.Count - 1;
		while (low < high)
		{
			let middle = (low + high) / 2;
			let left = Measure(control, text.Substring(0, boundaries[middle]));
			let right = Measure(control, text.Substring(0, boundaries[middle + 1]));
			if (target < (left + right) / 2) high = middle;
			else low = middle + 1;
		}
		return start + boundaries[low];
	}

}
