using System;
using System.Drawing;
using System.Text;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class SDLTextReviewTests
{
	private static int ReferenceHit(SDLTextService service, TextBoxBase editor, int x)
	{
		int position = 0;
		while (position < editor.Text.Length)
		{
			let next = TextEncodingHelper.AdjacentPosition(editor.Text, position, true, editor.Multiline);
			let left = service.Measure(editor, .(editor.Text, 0, position));
			let right = service.Measure(editor, .(editor.Text, 0, next));
			if (x < (left + right) / 2) break;
			position = next;
		}
		return position;
	}

	[Test]
	public static void HitTestingAndEllipsisPreserveKerningAndUtf8Boundaries()
	{
		Application.UseBackend(.SDL2OpenGL);
		let service = ((SDLBackend)Application.Backend).TextService;
		let editor = scope TextBox();
		let label = scope Label(); label.AutoEllipsis = true;
		let samples = scope String[]("AVATAR To fi", "\u{E9}\u{1F600} \u{6F22}\u{5B57}", "a\u{301}bc", "\u{FEFF}BOM", "");
		for (let style in scope FontStyle[](.Regular, .Bold | .Italic))
		{
			editor.Font = new System.Drawing.Font("Segoe UI", 12, style);
			label.Font = new System.Drawing.Font("Segoe UI", 12, style);
			for (let sample in samples)
			{
				editor.Text = sample; label.Text = sample;
				let fullWidth = service.Measure(editor, sample);
				for (int32 x = -2; x <= fullWidth + 2; x++)
				{
					Test.Assert(service.HitText(editor, x + 4 - editor.BorderWidth, 4 - editor.BorderWidth) == ReferenceHit(service, editor, x));
					label.Size = .(x + service.LabelPadding(label) * 2, 100);
					let expected = scope String(sample);
					if (fullWidth > x)
					{
						let available = x - service.Measure(label, "...");
						int length = 0;
						for (let character in sample.DecodedChars)
						{
							let next = length + UTF8.GetEncodedLength(character);
							if (service.Measure(label, .(sample, 0, next)) > available) break;
							length = next;
						}
						expected.Remove(length, expected.Length - length); expected.Append("...");
					}
					let actual = scope String(); service.GetDisplayText(label, actual);
					Test.Assert(actual == expected);
				}
			}
		}
		editor.Multiline = true;
		editor.Text = "first\n\u{E9}\u{1F600} last\n";
		editor.SetScrollOffset(.(7, service.LineHeight(editor)));
		let lineEnd = editor.Text.IndexOf('\n', 6);
		Test.Assert(service.HitText(editor, -100, 4 - editor.BorderWidth) == 6);
		Test.Assert(service.HitText(editor, 1000, 4 - editor.BorderWidth) == lineEnd);
		Test.Assert(service.HitText(editor, 0, 1000) == editor.Text.Length);
	}

	[Test]
	public static void LongLineHitTestingAndEllipsis()
	{
		Application.UseBackend(.SDL2OpenGL);
		let service = ((SDLBackend)Application.Backend).TextService;
		let editor = scope TextBox();
		let label = scope Label(); label.AutoEllipsis = true;
		let text = scope String(); for (int i < 16000) text.Append('W');
		editor.Text = text; label.Text = text;
		let width = service.Measure(editor, text);
		label.Size = .(width - 100, 100);
		Test.Assert(service.HitText(editor, width + 4 - editor.BorderWidth, 4 - editor.BorderWidth) == text.Length);
		let display = scope String(); service.GetDisplayText(label, display);
		Test.Assert(display.EndsWith("...") && display.Length < text.Length && display.Length > text.Length / 2);
	}

	private static void VerifyRasterScale(float scale)
	{
		Application.UseBackend(.SDL2OpenGL, render: true);
		let form = scope Form(); form.ClientSize = .(240, 160);
		let label = new Label(); label.Size = .(70, 100); label.Text = "AVATAR words wrap\n\nlast line";
		form.Controls.Add(label); form.Show();
		let backend = (SDLBackend)Application.Backend;
		let session = backend.GetSession(form);
		session.MakeCurrent(); defer SDL.GL_MakeCurrent(null, default);
		let renderer = session.[Friend]mTextRenderer;
		let canvas = session.[Friend]mCanvas;
		canvas.Begin(session.mWindow);
		// Exercise drawable/logical ratios independently of the test monitor's DPI.
		canvas.[Friend]mMetrics.Width = 240; canvas.[Friend]mMetrics.Height = 160;
		canvas.[Friend]mMetrics.PixelWidth = 240; canvas.[Friend]mMetrics.PixelHeight = 160;
		let measured = backend.MeasureText(label);
		let texture = renderer.[Friend]GetText(label);
		let width = texture.Width, height = texture.Height;
		for (let align in scope ContentAlignment[](.TopLeft, .MiddleCenter, .BottomRight))
		{
			label.TextAlign = align;
			let logicalSize = backend.MeasureText(label);
			canvas.[Friend]mMetrics.PixelWidth = (.)(240 * scale); canvas.[Friend]mMetrics.PixelHeight = (.)(160 * scale);
			let scaled = renderer.[Friend]GetText(label);
			GL.glBindTexture(GL.GL_TEXTURE_2D, scaled.Image.Handle);
			int32 pixelWidth = 0, pixelHeight = 0;
			GL.glGetTexLevelParameteriv(GL.GL_TEXTURE_2D, 0, GL.GL_TEXTURE_WIDTH, &pixelWidth);
			GL.glGetTexLevelParameteriv(GL.GL_TEXTURE_2D, 0, GL.GL_TEXTURE_HEIGHT, &pixelHeight);
			Test.Assert(pixelWidth == (int32)Math.Ceiling(scaled.Width * scale) && pixelHeight == (int32)Math.Ceiling(scaled.Height * scale));
			Test.Assert(scaled.Height == height && backend.MeasureText(label) == logicalSize);
			// Blank explicit lines and wrapped line count must survive rasterization.
			let pixels = scope uint8[pixelWidth * pixelHeight * 4];
			GL.glGetTexImage(GL.GL_TEXTURE_2D, 0, GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, pixels.Ptr);
			let lineHeight = backend.TextService.LineHeight(label);
			let lastStart = (int32)Math.Ceiling((height - lineHeight) * scale);
			bool lastLine = false;
			for (int y = lastStart; y < pixelHeight; y++)
				for (int x < pixelWidth) lastLine |= pixels[(y * pixelWidth + x) * 4 + 3] != 0;
			Test.Assert(lastLine && GL.glGetError() == GL.GL_NO_ERROR);
		}
		canvas.[Friend]mMetrics.PixelWidth = 240; canvas.[Friend]mMetrics.PixelHeight = 160;
		label.TextAlign = .TopLeft;
		let restored = renderer.[Friend]GetText(label);
		GL.glBindTexture(GL.GL_TEXTURE_2D, restored.Image.Handle);
		int32 restoredWidth = 0;
		GL.glGetTexLevelParameteriv(GL.GL_TEXTURE_2D, 0, GL.GL_TEXTURE_WIDTH, &restoredWidth);
		Test.Assert(restoredWidth == width && backend.MeasureText(label) == measured);
	}

	[Test] public static void TextTexturesFollowDoubleDrawableResolution() => VerifyRasterScale(2);
	[Test] public static void TextTexturesFollowFractionalDrawableResolution() => VerifyRasterScale(1.5f);

	[Test]
	public static void DisplayChangesRedrawAnIdleWindow()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(240, 160);
		let label = new Label(); label.Text = "Display change"; form.Controls.Add(label); form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		backend.[Friend]RenderIfNeeded();
		Test.Assert(!backend.[Friend]RenderIfNeeded());
		SDL.Event input = .(); input.type = .WindowEvent; input.window.windowEvent = .DISPLAY_CHANGED;
		SDLTestInput.SetWindow(ref input, form);
		backend.[Friend]ProcessEvent(ref input);
		Test.Assert(backend.[Friend]RenderIfNeeded());
		Test.Assert(!backend.[Friend]RenderIfNeeded());
	}
}
