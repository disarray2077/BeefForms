using System;
using System.Collections;
using System.Drawing;
using System.Windows.Forms;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class SDLTextRenderer
{
	private class TextTexture
	{
		public SDLCanvas.Texture Image ~ delete _;
		public int32 Width, Height, FontKey, LayoutWidth;
		public HorizontalAlignment Alignment;
		public float RasterScale;
		public bool Ellipsis, Multiline;
		public append String Text = .();
	}

	private SDLCanvas mCanvas;
	private SDLTextService mTextService;
	private append Dictionary<Control, TextTexture> mText = .() ~ DeleteDictionaryValues!(_);

	public this(SDLCanvas canvas, SDLTextService textService)
	{
		mCanvas = canvas;
		mTextService = textService;
	}

	public void Forget(Control control)
	{
		if (mText.GetAndRemove(control) case .Ok(let texture))
			delete texture.value;
	}
	
	private TextTexture GetText(Control control)
	{
		TextTexture texture;
		if (!mText.TryGetValue(control, out texture))
		{
			texture = new .();
			mText.Add(control, texture);
		}
		let key = SDLTextService.FontKey(control);
		let layoutWidth = mTextService.LayoutWidth(control);
		let alignment = SDLTextService.Alignment(control);
		let ellipsis = SDLTextService.HasEllipsis(control);
		let multiline = (control as TextBoxBase)?.Multiline == true;
		let rasterScale = mCanvas.Metrics.RasterScale;
		if (texture.Text == control.Text && texture.FontKey == key && texture.LayoutWidth == layoutWidth && texture.Alignment == alignment && texture.Ellipsis == ellipsis && texture.Multiline == multiline && texture.RasterScale == rasterScale)
			return texture;
		delete texture.Image;
		texture.Image = null;
		texture.Text.Set(control.Text);
		texture.FontKey = key;
		texture.LayoutWidth = layoutWidth;
		texture.Alignment = alignment;
		texture.Ellipsis = ellipsis;
		texture.Multiline = multiline;
		texture.RasterScale = rasterScale;
		texture.Width = 0;
		texture.Height = 0;
		if (control.Text.IsEmpty)
			return texture;
		let displayText = scope String();
		mTextService.GetDisplayText(control, displayText);
		let lines = scope List<SDLTextService.TextLine>();
		let size = mTextService.LayoutText(control, displayText, rasterScale == 1 ? null : lines);
		let surface = RasterizeText(control, displayText, rasterScale, size, lines);
		if (surface == null)
			Runtime.FatalError(scope $"Could not render UI text: {StringView(SDL.GetError())}");
		defer SDL.FreeSurface(surface);
		let rgba = SDL.ConvertSurfaceFormat(surface, SDL.PIXELFORMAT_ABGR8888, 0);
		if (rgba == null)
			Runtime.FatalError("Could not convert UI text pixels");
		defer SDL.FreeSurface(rgba);
		texture.Width = size.width;
		texture.Height = size.height;
		texture.Image = mCanvas.Upload(rgba);
		return texture;
	}

	private SDL.Surface* RasterizeText(Control control, String text, float scale, Size size, List<SDLTextService.TextLine> lines)
	{
		let font = mTextService.GetFont(control, scale);
		let alignment = SDLTextService.Alignment(control);
		if (scale == 1)
		{
			SDLTTF.SetFontWrappedAlign(font, (int32)alignment);
			defer SDLTTF.SetFontWrappedAlign(font, (int32)HorizontalAlignment.Left);
			return SDLTTF.RenderUTF8_Blended_Wrapped(font, text, .(255, 255, 255, 255),
				SDLTextService.HasEllipsis(control) ? 0 : (uint32)mTextService.LayoutWidth(control));
		}
		// Keep logical line breaks, alignment and bounds even when font hinting at
		// the drawable resolution produces slightly different glyph advances.
		let surface = SDL.CreateRGBSurfaceWithFormat(0, (.)Math.Ceiling(size.width * scale),
			(.)Math.Ceiling(size.height * scale), 32, SDL.PIXELFORMAT_ABGR8888);
		if (surface == null) return null;
		if (SDL.FillRect(surface, null, 0) != 0)
			Runtime.FatalError("Could not clear UI text pixels");
		let lineSkip = mTextService.LineHeight(control);
		int row = 0;
		for (let line in lines)
		{
			defer { row++; }
			if (line.Width == 0 || line.Length == 0) continue;
			let content = scope String(text, line.Start, line.Length);
			let rendered = SDLTTF.RenderUTF8_Blended(font, content, .(255, 255, 255, 255));
			if (rendered == null) Runtime.FatalError(scope $"Could not render UI text: {StringView(SDL.GetError())}");
			defer SDL.FreeSurface(rendered);
			let x = alignment == .Center ? (size.width - line.Width) / 2 : alignment == .Right ? size.width - line.Width : 0;
			SDL.Rect destination = .((.)Math.Round(x * scale), (.)Math.Round(row * lineSkip * scale),
				(.)Math.Ceiling(line.Width * scale), (.)Math.Ceiling(line.Height * scale));
			if (SDL.SetSurfaceBlendMode(rendered, .None) != 0 || SDL.BlitScaled(rendered, null, surface, &destination) != 0)
				Runtime.FatalError(scope $"Could not compose UI text: {StringView(SDL.GetError())}");
		}
		return surface;
	}

	public void Draw(Control control, int x, int y, float shade)
	{
		let texture = GetText(control);
		if (texture.Image == null)
			return;
		mCanvas.Image(.((.)x, (.)y, texture.Width, texture.Height), texture.Image, shade);
	}
}
