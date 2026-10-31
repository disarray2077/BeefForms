using System;
using System.Threading;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class SDLRenderingTests
{
	[Test]
	public static void NonRenderingModeKeepsInputAndPaintWithoutCreatingGLResources()
	{
		Application.UseBackend(.SDL2OpenGL);
		let backend = (SDLBackend)Application.Backend;
		Test.Assert(!backend.RenderingEnabled);
		let form = scope Form();
		form.ClientSize = .(240, 120);
		let editor = new TextBox();
		editor.Size = .(180, 25);
		form.Controls.Add(editor);
		int paints = 0;
		editor.Paint.Add(new [&] (sender, args) => paints++);
		form.Show();
		let session = backend.GetSession(form);
		Test.Assert(session.mWindow != null && session.mContext == default);
		Test.Assert((SDL.GetWindowFlags(session.mWindow) & (uint32)SDL.WindowFlags.OpenGL) == 0);
		Test.Assert(session.[Friend]mCanvas == null && session.[Friend]mTextRenderer == null && session.[Friend]mControlRenderer == null);
		SDLTestInput.Activate(backend);
		Test.Assert((SDL.GetWindowFlags(session.mWindow) & (uint32)SDL.WindowFlags.Hidden) == 0);
		Test.Assert(!session.[Friend]mShowPending && session.mContext == default);
		Test.Assert(editor.Focus());
		SDLTestInput.TypeText(backend, "abc");
		Test.Assert(editor.Text == "abc" && paints > 0);
		form.Close();
		backend.Run(form);
	}

	[Test]
	public static void SelectingTheSameBackendRestoresTheDefaultTestMode()
	{
		Application.UseBackend(.SDL2OpenGL, render: true);
		let backend = (SDLBackend)Application.Backend;
		Test.Assert(backend.RenderingEnabled);
		Application.UseBackend(.SDL2OpenGL);
		Test.Assert(Application.Backend == backend && !backend.RenderingEnabled);
	}

	[Test]
	public static void ExposureWatchSkipsIdleFramesAndPreservesPaintInvalidation()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 120);
		let panel = new Panel();
		panel.Size = .(200, 100);
		form.Controls.Add(panel);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		backend.[Friend]RenderIfNeeded();
		SDLTestInput.Activate(backend);
		backend.[Friend]RenderIfNeeded();
		backend.[Friend]mRenderThreadId = Thread.CurrentThreadId;
		SDL.AddEventWatch(=> SDLBackend.[Friend]WatchWindowEvents, Internal.UnsafeCastToPtr(backend));
		defer SDL.DelEventWatch(=> SDLBackend.[Friend]WatchWindowEvents, Internal.UnsafeCastToPtr(backend));
		SDL.Event exposure = .();
		exposure.type = .WindowEvent;
		exposure.window.windowEvent = .Exposed;
		exposure.window.windowID = SDL.GetWindowID((SDL.Window*)form.Handle);
		let frame = backend.GetSession(form).[Friend]mFrameTicks;
		SDL.Delay(2);
		SDLTestInput.PushEvent(ref exposure);
		backend.ProcessEvents();
		Test.Assert(backend.GetSession(form).[Friend]mFrameTicks == frame);
		Test.Assert(!backend.[Friend]RenderIfNeeded());

		int paints = 0;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			paints++;
			if (paints == 1) panel.Invalidate();
		});
		panel.Invalidate();
		SDLTestInput.PushEvent(ref exposure);
		Test.Assert(paints == 1);
		backend.ProcessEvents();
		Test.Assert(backend.[Friend]RenderIfNeeded());
		Test.Assert(paints == 2);
		Test.Assert(!backend.[Friend]RenderIfNeeded());
	}

	[Test]
	public static void ExposureWatchRendersDueAnimationsWithoutInvalidatingControls()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 120);
		let progress = new ProgressBar();
		progress.Size = .(200, 20);
		progress.Style = .Marquee;
		progress.MarqueeAnimationSpeed = 500;
		form.Controls.Add(progress);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		backend.[Friend]RenderIfNeeded();
		SDLTestInput.Activate(backend);
		backend.[Friend]RenderIfNeeded();
		backend.[Friend]mRenderThreadId = Thread.CurrentThreadId;
		SDL.AddEventWatch(=> SDLBackend.[Friend]WatchWindowEvents, Internal.UnsafeCastToPtr(backend));
		defer SDL.DelEventWatch(=> SDLBackend.[Friend]WatchWindowEvents, Internal.UnsafeCastToPtr(backend));
		let frame = backend.GetSession(form).[Friend]mFrameTicks;
		SDL.Delay(550);
		SDL.Event exposure = .();
		exposure.type = .WindowEvent;
		exposure.window.windowEvent = .Exposed;
		exposure.window.windowID = SDL.GetWindowID((SDL.Window*)form.Handle);
		SDLTestInput.PushEvent(ref exposure);
		Test.Assert(backend.GetSession(form).[Friend]mFrameTicks > frame);
		backend.ProcessEvents();
		Test.Assert(!backend.[Friend]RenderIfNeeded());
		Test.Assert(!progress.NeedsPaint);
	}

	[Test]
	public static void StaticFormsRedrawOnlyAfterChanges()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 120);
		let label = new Label();
		label.Size = .(200, 20);
		form.Controls.Add(label);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		Test.Assert(backend.[Friend]RenderIfNeeded());
		Test.Assert(!backend.[Friend]RenderIfNeeded());
		label.Text = "Changed";
		Test.Assert(backend.[Friend]RenderIfNeeded());
		Test.Assert(!backend.[Friend]RenderIfNeeded());
		label.Invalidate();
		Test.Assert(backend.[Friend]RenderIfNeeded());
	}

	[Test]
	public static void MarqueeRedrawsStopWhenHiddenClippedOrPaused()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 120);
		let progress = new ProgressBar();
		progress.Size = .(200, 20);
		progress.Style = .Marquee;
		progress.MarqueeAnimationSpeed = 20;
		form.Controls.Add(progress);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		backend.[Friend]RenderIfNeeded();
		SDL.Delay(25);
		Test.Assert(backend.[Friend]RenderIfNeeded());
		progress.Hide();
		backend.[Friend]RenderIfNeeded();
		SDL.Delay(25);
		Test.Assert(!backend.[Friend]RenderIfNeeded());
		progress.Show();
		progress.Location = .(0, 150);
		backend.[Friend]RenderIfNeeded();
		SDL.Delay(25);
		Test.Assert(!backend.[Friend]RenderIfNeeded());
		progress.Location = .(0, 0);
		progress.MarqueeAnimationSpeed = 0;
		backend.[Friend]RenderIfNeeded();
		SDL.Delay(25);
		Test.Assert(!backend.[Friend]RenderIfNeeded());
	}

	[Test]
	public static void MarqueesStartedAtDifferentTimesHaveIndependentPhases()
	{
		Application.UseBackend(.SDL2OpenGL, render: true);
		let form = scope Form();
		form.ClientSize = .(240, 120);
		let older = new ProgressBar();
		older.Size = .(200, 20);
		older.MarqueeAnimationSpeed = 500;
		let newer = new ProgressBar();
		newer.Location = .(0, 30);
		newer.Size = .(200, 20);
		newer.MarqueeAnimationSpeed = 500;
		form.Controls.Add(older);
		form.Controls.Add(newer);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		older.Style = .Marquee;
		backend.[Friend]RenderIfNeeded();
		SDL.Delay(550);
		newer.Style = .Marquee;
		backend.[Friend]RenderIfNeeded();
		uint8[4] olderPixel = .(), newerPixel = .();
		let window = SDL.GL_GetCurrentWindow();
		let context = SDL.GL_GetCurrentContext();
		backend.GetSession(form).MakeCurrent();
		defer { Test.Assert(SDL.GL_MakeCurrent(window, context) == 0); }
		GL.glReadBuffer(GL.GL_FRONT);
		defer GL.glReadBuffer(GL.GL_BACK);
		GL.glReadPixels(9, 109, 1, 1, GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, &olderPixel);
		GL.glReadPixels(9, 79, 1, 1, GL.GL_RGBA, GL.GL_UNSIGNED_BYTE, &newerPixel);
		Test.Assert(olderPixel[1] > olderPixel[0]);
		Test.Assert(newerPixel[1] == newerPixel[0]);
	}

	[Test]
	public static void CaretBlinkingRedrawsOnlyWhileEditableAndFocused()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 120);
		let editor = new TextBox();
		editor.Size = .(200, 25);
		form.Controls.Add(editor);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		editor.Focus();
		backend.[Friend]RenderIfNeeded();
		SDL.Delay(560);
		Test.Assert(backend.[Friend]RenderIfNeeded());
		editor.ReadOnly = true;
		backend.[Friend]RenderIfNeeded();
		SDL.Delay(560);
		Test.Assert(!backend.[Friend]RenderIfNeeded());
		editor.ReadOnly = false;
		SDLTestInput.SetActive(backend, false);
		backend.[Friend]RenderIfNeeded();
		SDL.Delay(560);
		Test.Assert(!backend.[Friend]RenderIfNeeded());
	}
}
