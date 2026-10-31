using System;
using System.Drawing;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class TextMeasurementTests
{
	[Test]
	public static void SDLMeasuresUnrealizedControlsWithoutCreatingWindows()
	{
		Application.UseBackend(.SDL2OpenGL);
		let label = scope Label(); label.Text = "Measured before Show"; label.AutoSize = true;
		let ttfCount = SDLTTF.WasInit();
		{
			let backend = scope SDLBackend();
			let measured = backend.MeasureText(label);
			Test.Assert(measured.width > 0 && measured.height > 0);
			Test.Assert(!label.IsHandleCreated && Application.CreatedControlCount == 0 && backend.[Friend]mSessions.IsEmpty);
			Test.Assert(!backend.[Friend]mInitialized);
			label.Font = new System.Drawing.Font("Segoe UI", 24);
			let larger = backend.MeasureText(label);
			Test.Assert(larger.width > measured.width && larger.height > measured.height);
		}
		Test.Assert(SDLTTF.WasInit() == ttfCount);
	}

	private static void VerifyUnrealizedAutoSize(ApplicationBackend type)
	{
		Application.UseBackend(type);
		let form = scope Form(); form.ClientSize = .(320, 160);
		let label = new Label(); label.AutoSize = true; label.Text = "AutoSize before Show";
		form.Controls.Add(label);
		let before = label.Size;
		Test.Assert(before.width > 0 && before.height > 0);
		label.Text = "A much longer label before Show";
		Test.Assert(label.Size.width > before.width);
		let original = label.Size;
		form.Font = new System.Drawing.Font("Segoe UI", 24);
		Test.Assert(label.Size.width > original.width && label.Size.height > original.height);
		let editor = new TextBox(); editor.Size = .(200, 90); form.Controls.Add(editor);
		Test.Assert(editor.Size.width == 200 && editor.Size.height > 0 && editor.Size.height < 90);
		Test.Assert(!form.IsHandleCreated && !label.IsHandleCreated && !editor.IsHandleCreated && Application.CreatedControlCount == 0);
		let labelSize = label.Size;
		let editorSize = editor.Size;
		form.Show();
		Test.Assert(label.Size == labelSize && editor.Size == editorSize);
	}

	[Test] public static void SDLAutoSizeUsesFontMetricsBeforeShow() => VerifyUnrealizedAutoSize(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeAutoSizeUsesFontMetricsBeforeShow() => VerifyUnrealizedAutoSize(.Win32);
#endif

	[Test]
	public static void SDLMeasurementDoesNotPopulateTheTextureCacheOrTouchGLBindings()
	{
		Application.UseBackend(.SDL2OpenGL, render: true);
		let form = scope Form(); form.ClientSize = .(320, 160);
		let label = new Label(); label.Text = "CPU-only measurement"; label.Size = .(200, 100); form.Controls.Add(label);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		let session = backend.GetSession(form);
		let renderer = session.[Friend]mTextRenderer;
		session.MakeCurrent();
		defer SDL.GL_MakeCurrent(null, default);
		int32 boundTexture = 0;
		GL.glGetIntegerv(GL.GL_TEXTURE_BINDING_2D, &boundTexture);
		let count = renderer.[Friend]mText.Count;
		label.Text = "Changed without rendering";
		let measured = backend.MeasureText(label);
		int32 afterTexture = 0;
		GL.glGetIntegerv(GL.GL_TEXTURE_BINDING_2D, &afterTexture);
		Test.Assert(measured.width > 0 && renderer.[Friend]mText.Count == count && boundTexture == afterTexture);
		SDL.GL_MakeCurrent(null, default);
		Test.Assert(backend.MeasureText(label) == measured && SDL.GL_GetCurrentContext() == default);
		Test.Assert(renderer.[Friend]mText.Count == count);
	}

	[Test]
	public static void SDLMeasuredBoundsMatchRenderedTextForWrappingAlignmentAndEllipsis()
	{
		Application.UseBackend(.SDL2OpenGL, render: true);
		let form = scope Form(); form.ClientSize = .(320, 160);
		let label = new Label(); label.AutoSize = false; form.Controls.Add(label); form.Show();
		let backend = (SDLBackend)Application.Backend;
		let session = backend.GetSession(form);
		let renderer = session.[Friend]mTextRenderer;
		let samples = scope String[]("Hello", "two\nlines", "a\r\nb", "a\n", "a\n\nb", " words  with spaces ", "supercalifragilistic", "\u{E9}\u{1F600} \u{6F22}\u{5B57} text", "one\ttwo", "\u{FEFF}BOM text", "");
		for (let style in scope FontStyle[](.Regular, .Bold | .Italic))
		{
			label.Font = new System.Drawing.Font("Segoe UI", 12, style);
			for (let autoSize in scope bool[](false, true))
			{
				label.AutoSize = autoSize;
				for (let text in samples)
					for (let width in scope int32[](1, 30, 120))
						for (let align in scope ContentAlignment[](.TopLeft, .MiddleCenter, .BottomRight))
							for (let ellipsis in scope bool[](false, true))
							{
								label.Size = .(width, 100); label.TextAlign = align; label.AutoEllipsis = ellipsis; label.Text = text;
								let measured = backend.MeasureText(label);
								session.MakeCurrent();
								let texture = renderer.[Friend]GetText(label);
								let padding = text.IsEmpty ? 0 : backend.TextService.LabelPadding(label) * 2;
								Test.Assert(measured.width == texture.Width + padding && measured.height == texture.Height);
								Test.Assert(GL.glGetError() == GL.GL_NO_ERROR);
								SDL.GL_MakeCurrent(null, default);
							}
			}
		}
	}

	[Test]
	public static void SDLFontPathCanChangeAfterUnrealizedMeasurement()
	{
		Application.UseBackend(.SDL2OpenGL);
		let label = scope Label(); label.Text = "Font path before handles"; label.AutoSize = true;
		let backend = (SDLBackend)Application.Backend;
		let original = scope String(Application.SDLFontPath);
		defer { Application.SDLFontPath = original; }
		let before = backend.MeasureText(label);
		let path = scope String(backend.TextService.[Friend]mFontPath);
		Application.SDLFontPath = path;
		Test.Assert(backend.MeasureText(label) == before && backend.TextService.UsesPath(path));
		Test.Assert(Application.CreatedControlCount == 0 && backend.[Friend]mSessions.IsEmpty);
	}
}
