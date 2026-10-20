using System;
using System.Collections;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class SDLRenderer
{
	private class TextTexture
	{
		public uint32 Texture;
		public int32 Width, Height, FontKey;
		public String Text = new .() ~ delete _;
		public ~this() { if (Texture != 0) GL.glDeleteTextures(1, &Texture); }
	}

	private uint32 mProgram, mBuffer, mVertexArray, mWhiteTexture;
	private int mViewportUniform, mColorUniform;
	private Dictionary<int32, SDLTTF.Font*> mFonts = new .() ~ delete _;
	private Dictionary<Control, TextTexture> mText = new .() ~ DeleteDictionaryAndValues!(_);
	private String mFontPath = new .() ~ delete _;
	private int32 mWidth, mHeight, mPixelWidth, mPixelHeight;

	public this(StringView fontPath)
	{
		mFontPath.Set(fontPath);
		if (mFontPath.IsEmpty)
		{
#if BF_PLATFORM_WINDOWS
			Environment.GetEnvironmentVariable("WINDIR", mFontPath);
			mFontPath.Append("/Fonts/segoeui.ttf");
#else
			mFontPath.Set("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");
#endif
		}
		if (!File.Exists(mFontPath))
			Runtime.FatalError(scope $"Cannot find the UI font: {mFontPath}");

		let vertexSource = """
			#version 330 core
			layout(location = 0) in vec2 position;
			layout(location = 1) in vec2 texcoord;
			uniform vec2 viewport;
			out vec2 uv;
			void main() {
			    gl_Position = vec4(position.x / viewport.x * 2.0 - 1.0,
			        1.0 - position.y / viewport.y * 2.0, 0.0, 1.0);
			    uv = texcoord;
			}
			""";
		let fragmentSource = """
			#version 330 core
			in vec2 uv;
			uniform sampler2D image;
			uniform vec4 color;
			out vec4 fragmentColor;
			void main() { fragmentColor = texture(image, uv) * color; }
			""";
		let vertex = CompileShader(GL.GL_VERTEX_SHADER, vertexSource);
		defer GL.glDeleteShader(vertex);
		let fragment = CompileShader(GL.GL_FRAGMENT_SHADER, fragmentSource);
		defer GL.glDeleteShader(fragment);
		mProgram = (.)GL.glCreateProgram();
		GL.glAttachShader(mProgram, vertex);
		GL.glAttachShader(mProgram, fragment);
		GL.glLinkProgram(mProgram);
		int32 linked = 0;
		GL.glGetProgramiv(mProgram, GL.GL_LINK_STATUS, &linked);
		if (linked == 0)
		{
			char8[2048] log = .();
			GL.glGetProgramInfoLog(mProgram, log.Count, null, &log);
			Runtime.FatalError(scope String(&log));
		}
		mViewportUniform = GL.glGetUniformLocation(mProgram, "viewport");
		mColorUniform = GL.glGetUniformLocation(mProgram, "color");
		GL.glUseProgram(mProgram);
		GL.glUniform1i(GL.glGetUniformLocation(mProgram, "image"), 0);
		GL.glGenVertexArrays(1, &mVertexArray);
		GL.glGenBuffers(1, &mBuffer);
		GL.glBindVertexArray(mVertexArray);
		GL.glBindBuffer(GL.GL_ARRAY_BUFFER, mBuffer);
		GL.glEnableVertexAttribArray(0);
		GL.glEnableVertexAttribArray(1);
		GL.glVertexAttribPointer(0, 2, GL.GL_FLOAT, 0, 4 * sizeof(float), null);
		GL.glVertexAttribPointer(1, 2, GL.GL_FLOAT, 0, 4 * sizeof(float), (void*)(int)(2 * sizeof(float)));
		GL.glGenTextures(1, &mWhiteTexture);
		GL.glBindTexture(GL.GL_TEXTURE_2D, mWhiteTexture);
		uint32 white = 0xFFFFFFFF;
		GL.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_RGBA, 1, 1, 0, GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, &white);
		SetTextureParameters();
	}

	public ~this()
	{
		// GL resources must be released before the backend destroys its context.
		for (let entry in mFonts)
			SDLTTF.CloseFont(entry.value);
		GL.glDeleteBuffers(1, &mBuffer);
		GL.glDeleteVertexArrays(1, &mVertexArray);
		GL.glDeleteTextures(1, &mWhiteTexture);
		GL.glDeleteProgram(mProgram);
	}

	private static uint32 CompileShader(uint32 type, String source)
	{
		let shader = (uint32)GL.glCreateShader(type);
		var pointer = source.CStr();
		GL.glShaderSource(shader, 1, &pointer, null);
		GL.glCompileShader(shader);
		int32 compiled = 0;
		GL.glGetShaderiv(shader, GL.GL_COMPILE_STATUS, &compiled);
		if (compiled == 0)
		{
			char8[2048] log = .();
			GL.glGetShaderInfoLog(shader, log.Count, null, &log);
			Runtime.FatalError(scope String(&log));
		}
		return shader;
	}

	private static void SetTextureParameters()
	{
		GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR);
		GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR);
		GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_CLAMP_TO_EDGE);
		GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_CLAMP_TO_EDGE);
	}

	private int32 GetFontKey(Control control)
	{
		let font = control.Font;
		let pixels = font == null ? 13 : Math.Max(1, (int32)(font.Size * (font.Unit == .Point ? 96.0f / 72 : 1)));
		return (int32)(pixels * 32 + (font == null ? 0 : (int32)font.Style));
	}

	private SDLTTF.Font* GetFont(Control control)
	{
		let key = GetFontKey(control);
		if (mFonts.TryGetValue(key, let font))
			return font;
		let result = SDLTTF.OpenFont(mFontPath, key / 32);
		if (result == null)
			Runtime.FatalError(scope $"Could not open UI font: {StringView(SDL.GetError())}");
		SDLTTF.SetFontStyle(result, key % 32);
		mFonts.Add(key, result);
		return result;
	}

	public int32 LineHeight(Control control) => SDLTTF.FontLineSkip(GetFont(control));

	public Size MeasureText(Control control)
	{
		let texture = GetText(control);
		return .(texture.Width, texture.Height);
	}

	public int32 Measure(Control control, StringView text)
	{
		int32 width = 0, height = 0;
		SDLTTF.SizeUTF8(GetFont(control), scope String(text), out width, out height);
		return width;
	}

	public Point TextPosition(TextBoxBase control, int position)
	{
		int lineStart = 0, line = 0;
		for (int i < position)
			if (control.Text[i] == '\n')
			{
				lineStart = i + 1;
				line++;
			}
		return .(Measure(control, .(control.Text, lineStart, position - lineStart)), (int32)(line * LineHeight(control)));
	}

	public int HitText(TextBoxBase control, int x, int y)
	{
		let line = Math.Max(0, (y + control.ScrollY - 4) / LineHeight(control));
		int start = 0;
		for (int i < line)
		{
			let end = control.Text.IndexOf('\n', start);
			if (end < 0)
				return control.Text.Length;
			start = end + 1;
		}
		int position = start;
		while (position < control.Text.Length && control.Text[position] != '\n')
		{
			let next = control.AdjacentPosition(position, true);
			let left = Measure(control, .(control.Text, start, position - start));
			let right = Measure(control, .(control.Text, start, next - start));
			if (x + control.ScrollX - 4 < (left + right) / 2)
				break;
			position = next;
		}
		return position;
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
		let key = GetFontKey(control);
		if (texture.Text == control.Text && texture.FontKey == key)
			return texture;
		if (texture.Texture != 0)
		{
			GL.glDeleteTextures(1, &texture.Texture);
			texture.Texture = 0;
		}
		texture.Text.Set(control.Text);
		texture.FontKey = key;
		texture.Width = 0;
		texture.Height = 0;
		if (control.Text.IsEmpty)
			return texture;
		let surface = SDLTTF.RenderUTF8_Blended_Wrapped(GetFont(control), control.Text, .(255, 255, 255, 255), 0);
		if (surface == null)
			Runtime.FatalError(scope $"Could not render UI text: {StringView(SDL.GetError())}");
		defer SDL.FreeSurface(surface);
		let rgba = SDL.ConvertSurfaceFormat(surface, SDL.PIXELFORMAT_ABGR8888, 0);
		if (rgba == null)
			Runtime.FatalError("Could not convert UI text pixels");
		defer SDL.FreeSurface(rgba);
		texture.Width = rgba.w;
		texture.Height = rgba.h;
		GL.glGenTextures(1, &texture.Texture);
		GL.glBindTexture(GL.GL_TEXTURE_2D, texture.Texture);
		GL.glPixelStorei(GL.GL_UNPACK_ALIGNMENT, 4);
		GL.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_RGBA, rgba.w, rgba.h, 0, GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, rgba.pixels);
		SetTextureParameters();
		return texture;
	}

	public void Begin(SDL.Window* window)
	{
		SDL.GetWindowSize(window, out mWidth, out mHeight);
		SDL.GL_GetDrawableSize(window, out mPixelWidth, out mPixelHeight);
		GL.glViewport(0, 0, mPixelWidth, mPixelHeight);
		GL.glDisable(GL.GL_SCISSOR_TEST);
		GL.glClearColor(0.94f, 0.94f, 0.95f, 1);
		GL.glClear(GL.GL_COLOR_BUFFER_BIT);
		GL.glUseProgram(mProgram);
		GL.glBindVertexArray(mVertexArray);
		GL.glBindBuffer(GL.GL_ARRAY_BUFFER, mBuffer);
		GL.glUniform2f(mViewportUniform, Math.Max(1, mWidth), Math.Max(1, mHeight));
		GL.glActiveTexture(GL.GL_TEXTURE0);
		GL.glEnable(GL.GL_BLEND);
		GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);
		GL.glEnable(GL.GL_SCISSOR_TEST);
	}

	public void Clip(Rectangle rect)
	{
		let sx = mPixelWidth / (float)Math.Max(1, mWidth);
		let sy = mPixelHeight / (float)Math.Max(1, mHeight);
		GL.glScissor((.)(rect.X * sx), (.)(mPixelHeight - (rect.Y + rect.Height) * sy),
			(.)(Math.Max(0, rect.Width) * sx), (.)(Math.Max(0, rect.Height) * sy));
	}

	public void Capture(String path)
	{
		let rowSize = mPixelWidth * 4;
		uint8[] pixels = new .[rowSize * mPixelHeight];
		defer delete pixels;
		GL.glReadPixels(0, 0, mPixelWidth, mPixelHeight, GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, pixels.Ptr);
		uint8[] row = scope .[rowSize];
		for (int y < mPixelHeight / 2)
		{
			let top = pixels.Ptr + y * rowSize;
			let bottom = pixels.Ptr + (mPixelHeight - y - 1) * rowSize;
			Internal.MemCpy(row.Ptr, top, rowSize);
			Internal.MemCpy(top, bottom, rowSize);
			Internal.MemCpy(bottom, row.Ptr, rowSize);
		}
		let surface = SDL.CreateRGBSurfaceFrom(pixels.Ptr, mPixelWidth, mPixelHeight, 32, rowSize,
			0xFF, 0xFF00, 0xFF0000, 0xFF000000);
		defer SDL.FreeSurface(surface);
		if (surface == null || SDL.SDL_SaveBMP(surface, path) != 0)
			Runtime.FatalError("Could not save the rendered frame");
	}

	private void Quad(Rectangle rect, uint32 texture, float r, float g, float b, float a = 1)
	{
		if (rect.Width <= 0 || rect.Height <= 0)
			return;
		let x = (float)rect.X, y = (float)rect.Y;
		let right = x + rect.Width, bottom = y + rect.Height;
		float[24] vertices = .(x,y,0,0, right,y,1,0, right,bottom,1,1,
			x,y,0,0, right,bottom,1,1, x,bottom,0,1);
		GL.glBindTexture(GL.GL_TEXTURE_2D, texture);
		GL.glUniform4f(mColorUniform, r, g, b, a);
		GL.glBufferData(GL.GL_ARRAY_BUFFER, sizeof(decltype(vertices)), &vertices, GL.GL_STREAM_DRAW);
		GL.glDrawArrays(GL.GL_TRIANGLES, 0, 6);
	}

	public void Fill(Rectangle rect, float r, float g, float b) => Quad(rect, mWhiteTexture, r, g, b);
	public void Border(Rectangle rect, float r, float g, float b)
	{
		Fill(.(rect.X, rect.Y, rect.Width, 1), r,g,b);
		Fill(.(rect.X, rect.Y + rect.Height - 1, rect.Width, 1), r,g,b);
		Fill(.(rect.X, rect.Y, 1, rect.Height), r,g,b);
		Fill(.(rect.X + rect.Width - 1, rect.Y, 1, rect.Height), r,g,b);
	}

	public void Text(Control control, int x, int y)
	{
		let texture = GetText(control);
		if (texture.Texture == 0)
			return;
		let shade = control.IsEffectivelyEnabled ? 0.12f : 0.55f;
		Quad(.((.)x, (.)y, texture.Width, texture.Height), texture.Texture, shade, shade, shade);
	}
}
