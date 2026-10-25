using System;
using System.Drawing;
using SDL2;
using BeefGL;

using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class SDLCanvas
{
	public struct FrameMetrics : this(int32 Width, int32 Height, int32 PixelWidth, int32 PixelHeight)
	{
		public float ScaleX => PixelWidth / (float)Math.Max(1, Width);
		public float ScaleY => PixelHeight / (float)Math.Max(1, Height);
		public float RasterScale => Math.Max(1f, Math.Max(ScaleX, ScaleY));

		public Rectangle ToScissor(Rectangle rect) =>
			.((.)(rect.X * ScaleX), (.)(PixelHeight - rect.Bottom * ScaleY),
			(.)(Math.Max(0, rect.Width) * ScaleX), (.)(Math.Max(0, rect.Height) * ScaleY));
	}

	public class Texture
	{
		public uint32 Handle;
		public ~this() { if (Handle != 0) GL.glDeleteTextures(1, &Handle); }
	}

	private uint32 mProgram, mBuffer, mVertexArray, mWhiteTexture;
	private int mViewportUniform, mColorUniform;
	private FrameMetrics mMetrics;
	public FrameMetrics Metrics => mMetrics;

	public this()
	{
#if BF_PLATFORM_WASM
		let shaderHeader = "#version 300 es\nprecision highp float;\nprecision highp int;\n";
#else
		let shaderHeader = "#version 330 core\n";
#endif

		let vertexSource = scope String(shaderHeader);
		vertexSource.Append("""
			layout(location = 0) in vec2 position;
			layout(location = 1) in vec2 texcoord;
			uniform vec2 viewport;
			out vec2 uv;
			void main() {
			    gl_Position = vec4(position.x / viewport.x * 2.0 - 1.0,
			        1.0 - position.y / viewport.y * 2.0, 0.0, 1.0);
			    uv = texcoord;
			}
			""");

		let fragmentSource = scope String(shaderHeader);
		fragmentSource.Append("""
			in vec2 uv;
			uniform sampler2D image;
			uniform vec4 color;
			out vec4 fragmentColor;
			void main() { fragmentColor = texture(image, uv) * color; }
			""");

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
		GL.glBindVertexArray(mVertexArray);

		GL.glGenBuffers(1, &mBuffer);
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

	public Texture Upload(SDL.Surface* surface)
	{
		let texture = new Texture();
		GL.glGenTextures(1, &texture.Handle);
		GL.glBindTexture(GL.GL_TEXTURE_2D, texture.Handle);
		GL.glPixelStorei(GL.GL_UNPACK_ALIGNMENT, 4);
		GL.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_RGBA, surface.w, surface.h, 0,
			GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, surface.pixels);
		SetTextureParameters();
		return texture;
	}

	public void Image(Rectangle rect, Texture texture, float shade) =>
		Quad(rect, texture.Handle, shade, shade, shade);

	public void Begin(SDL.Window* window)
	{
		SDL.GetWindowSize(window, out mMetrics.Width, out mMetrics.Height);
		SDL.GL_GetDrawableSize(window, out mMetrics.PixelWidth, out mMetrics.PixelHeight);
		GL.glViewport(0, 0, mMetrics.PixelWidth, mMetrics.PixelHeight);
		GL.glDisable(GL.GL_SCISSOR_TEST);
		GL.glClearColor(240f / 255, 240f / 255, 240f / 255, 1);
		GL.glClear(GL.GL_COLOR_BUFFER_BIT);
		GL.glUseProgram(mProgram);
		GL.glBindVertexArray(mVertexArray);
		GL.glBindBuffer(GL.GL_ARRAY_BUFFER, mBuffer);
		GL.glUniform2f(mViewportUniform, Math.Max(1, mMetrics.Width), Math.Max(1, mMetrics.Height));
		GL.glActiveTexture(GL.GL_TEXTURE0);
		GL.glEnable(GL.GL_BLEND);
		GL.glBlendFunc(GL.GL_SRC_ALPHA, GL.GL_ONE_MINUS_SRC_ALPHA);
		GL.glEnable(GL.GL_SCISSOR_TEST);
	}

	public void Clip(Rectangle rect)
	{
		let pixels = mMetrics.ToScissor(rect);
		GL.glScissor(pixels.X, pixels.Y, pixels.Width, pixels.Height);
	}

	public void Capture(String path)
	{
		let rowSize = mMetrics.PixelWidth * 4;
		uint8[] pixels = new:ScopedAlloc! .[rowSize * mMetrics.PixelHeight];
		GL.glReadPixels(0, 0, mMetrics.PixelWidth, mMetrics.PixelHeight, GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, pixels.Ptr);
		uint8[] row = new:ScopedAlloc! .[rowSize];
		for (int y < mMetrics.PixelHeight / 2)
		{
			let top = pixels.Ptr + y * rowSize;
			let bottom = pixels.Ptr + (mMetrics.PixelHeight - y - 1) * rowSize;
			Internal.MemCpy(row.Ptr, top, rowSize);
			Internal.MemCpy(top, bottom, rowSize);
			Internal.MemCpy(bottom, row.Ptr, rowSize);
		}
		let surface = SDL.CreateRGBSurfaceFrom(pixels.Ptr, mMetrics.PixelWidth, mMetrics.PixelHeight, 32, rowSize,
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
	public void RoundedFill(Rectangle rect, float r, float g, float b)
	{
		Fill(.(rect.X + 2, rect.Y, rect.Width - 4, 1), r, g, b);
		Fill(.(rect.X + 1, rect.Y + 1, rect.Width - 2, 1), r, g, b);
		Fill(.(rect.X, rect.Y + 2, rect.Width, rect.Height - 4), r, g, b);
		Fill(.(rect.X + 1, rect.Y + rect.Height - 2, rect.Width - 2, 1), r, g, b);
		Fill(.(rect.X + 2, rect.Y + rect.Height - 1, rect.Width - 4, 1), r, g, b);
	}
	public void Border(Rectangle rect, float r, float g, float b)
	{
		Fill(.(rect.X, rect.Y, rect.Width, 1), r,g,b);
		Fill(.(rect.X, rect.Y + rect.Height - 1, rect.Width, 1), r,g,b);
		Fill(.(rect.X, rect.Y, 1, rect.Height), r,g,b);
		Fill(.(rect.X + rect.Width - 1, rect.Y, 1, rect.Height), r,g,b);
	}

}
