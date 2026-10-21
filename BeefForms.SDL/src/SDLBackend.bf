using System;
using System.Collections;
using System.Threading;
using System.Drawing;
using System.Windows.Forms;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class SDLBackend : FormsBackend
{
	public override ApplicationBackend Type => .SDL2OpenGL;

	private SDL.Window* mWindow;
	private SDL.SDL_GLContext mContext;
	private SDLRenderer mRenderer;
	private Form mForm;
	private Control mFocused, mPressed, mHovered;
	private Point mPointerPosition;
	private bool mPointerInside;
	private Control mCaptured;
	private bool mAutomaticCapture;
	private bool mActive;
	private bool mWheelHasPosition;
	private bool mSuppressTextInput;
	private bool mInitialized, mRunning;
	private bool mRendering;
	private uint32? mHandledExposureTimestamp;
	private int mRenderThreadId;
	private bool mRedrawRequested, mShowPending;
	private SDL.EventType mRedrawEvent;
	private uint64 mFrameTicks, mNextAnimationTick = uint64.MaxValue;
	private int mFrames;
	private bool mPumpingEvents;
	public int FrameLimit;
	public String CapturePath;

	public ~this()
	{
		DestroyWindow();
		if (mInitialized)
		{
			SDLTTF.Quit();
			SDL.QuitSubSystem(.Video);
		}
	}

	public override void CreateControl(Control control)
	{
		RequestRedraw();
		if (!(control is Form))
		{
			if (let progress = control as ProgressBar) UpdateMarquee(progress);
			return;
		}
		if (mWindow != null)
			Runtime.FatalError("The SDL backend currently supports one top-level form");
		if (!mInitialized)
		{
			if (SDL.InitSubSystem(.Video) != 0 || SDLTTF.Init() != 0)
				Runtime.FatalError(scope $"Could not initialize SDL: {StringView(SDL.GetError())}");
			mInitialized = true;
			mRedrawEvent = (.)SDL.RegisterEvents(1);
			SDL.GetVersion(var version);
			mWheelHasPosition = version.major > 2 || version.minor >= 26;
		}
		mForm = (Form)control;
		let size = mForm.HasInitialClientSize ? mForm.InitialClientSize : control.Size;
		SDL.GL_SetAttribute(.GL_CONTEXT_MAJOR_VERSION, 3);
#if BF_PLATFORM_WASM
		SDL.GL_SetAttribute(.GL_CONTEXT_MINOR_VERSION, 0);
		SDL.GL_SetAttribute(.GL_CONTEXT_PROFILE_MASK, .GL_CONTEXT_PROFILE_ES);
#else
		SDL.GL_SetAttribute(.GL_CONTEXT_MINOR_VERSION, 3);
		SDL.GL_SetAttribute(.GL_CONTEXT_PROFILE_MASK, .GL_CONTEXT_PROFILE_CORE);
#endif
		SDL.GL_SetAttribute(.GL_DOUBLEBUFFER, 1);
		mWindow = SDL.CreateWindow(control.Text, (.)control.Location.x, (.)control.Location.y,
			Math.Max(1, size.width), Math.Max(1, size.height), .OpenGL | .Resizable | .AllowHighDPI | .Hidden);
		if (mWindow == null)
			Runtime.FatalError(scope $"Could not create SDL window: {StringView(SDL.GetError())}");
#if !BF_PLATFORM_WASM
		let iconData = (Span<uint8>)DefaultIcon.Data;
		let icon = SDLImage.Load_RW(SDL.RWFromConstMem(iconData.Ptr, (int32)iconData.Length), 1);
		SDL.SetWindowIcon(mWindow, icon);
		SDL.FreeSurface(icon);
#endif
		mContext = SDL.GL_CreateContext(mWindow);
		if (mContext == default)
			Runtime.FatalError(scope $"Could not create OpenGL context: {StringView(SDL.GetError())}");
		GL.Init(scope (name) => SDL.GL_GetProcAddress(name));
#if !BF_PLATFORM_WASM
		SDL.GL_SetSwapInterval(1);
#endif
		mRenderer = new .(Application.SDLFontPath);
		mFrames = 0;
		control.SetNativeHandle(mWindow);
		if (!mForm.HasInitialClientSize) SetFormSize(mForm, size);
		control.NotifyResize(GetFormSize());
		SetFormLocation(control.Location);
		control.NotifyMove(GetFormLocation());
		ApplyMinimumSize(mForm);
	}

	private void DestroyWindow()
	{
		if (mWindow == null)
			return;
		SDL.StopTextInput();
		delete mRenderer;
		mRenderer = null;
		SDL.GL_DeleteContext(mContext);
		mContext = default;
		SDL.DestroyWindow(mWindow);
		mWindow = null;
		mRunning = false;
		mShowPending = false;
		mPointerInside = false;
		mHandledExposureTimestamp = null;
		mActive = false;
		mSuppressTextInput = false;
	}

	public override void DestroyControl(Control control)
	{
		RequestRedraw();
		if (let progress = control as ProgressBar) mMarqueeStarts.Remove(progress);
		if (Control.IsAncestorOf(control, mFocused)) Focus(null);
		if (Control.IsAncestorOf(control, mCaptured)) SetCapture(mCaptured, false);
		if (mPressed == control) mPressed = null;
		if (Control.IsAncestorOf(control, mHovered)) Hover(null);
		mRenderer?.Forget(control);
		if (control == mForm)
		{
			DestroyWindow();
			mForm = null;
		}
		control.SetNativeHandle(null);
	}

	public override void UpdateControl(Control control, ControlChange change)
	{
		RequestRedraw();
		if (change == .Appearance || change == .All)
			if (let progress = control as ProgressBar) UpdateMarquee(progress);
		if (!control.IsEffectivelyVisible || !control.IsEffectivelyEnabled)
		{
			if (Control.IsAncestorOf(control, mFocused)) Focus(null);
			if (Control.IsAncestorOf(control, mCaptured)) SetCapture(mCaptured, false);
			if (Control.IsAncestorOf(control, mPressed)) mPressed = null;
			if (Control.IsAncestorOf(control, mHovered)) Hover(null);
		}
		if (control == mForm && mWindow != null)
		{
			if (change == .Visibility)
			{
				if (control.Visible) Show(mForm);
				else
				{
					mShowPending = false;
					SDL.HideWindow(mWindow);
				}
			}
			if (change == .Text)
				SDL.SetWindowTitle(mWindow, control.Text);
			if (change == .Constraints) ApplyMinimumSize(mForm);
			if (change == .Bounds)
			{
				SetFormSize(mForm, control.Size);
				let location = GetFormLocation();
				if (location.x != control.Location.x || location.y != control.Location.y)
					SetFormLocation(control.Location);
			}
		}
		if (change == .Scroll || change == .Bounds || change == .Visibility || change == .Enabled || change == .ZOrder)
			UpdateHover();
	}

	public override Size GetClientSize(Form form)
	{
		if (mWindow == null) return form.Size;
		SDL.GetWindowSize(mWindow, var width, var height);
		return .(width, height);
	}
	public override Rectangle GetScreenWorkingArea()
	{
		SDL.GetGlobalMouseState(var x, var y);
		SDL.Point point = .(x, y);
		let display = Math.Max(0, SDL.GetPointDisplayIndex(&point));
		SDL.GetDisplayUsableBounds(display, var area);
		return .(area.x, area.y, area.w, area.h);
	}
	private Point GetFormLocation()
	{
		SDL.GetWindowPosition(mWindow, var x, var y);
		SDL.GetWindowBordersSize(mWindow, var top, var left, var bottom, var right);
		return .(x - left, y - top);
	}
	private void SetFormLocation(Point location)
	{
		SDL.GetWindowBordersSize(mWindow, var top, var left, var bottom, var right);
		SDL.SetWindowPosition(mWindow, location.x + left, location.y + top);
	}
	private Size GetFormSize()
	{
		let client = GetClientSize(mForm);
		SDL.GetWindowBordersSize(mWindow, var top, var left, var bottom, var right);
		return .(client.width + left + right, client.height + top + bottom);
	}
	private void UpdateFormSize()
	{
		let size = GetFormSize();
		if (size.width == mForm.Size.width && size.height == mForm.Size.height) return;
		mForm.NotifyResize(size);
		RequestRedraw();
	}
	private void SetFormSize(Form form, Size size)
	{
		SDL.GetWindowBordersSize(mWindow, var top, var left, var bottom, var right);
		SetClientSize(form, .(Math.Max(1, size.width - left - right), Math.Max(1, size.height - top - bottom)));
	}
	public override Size MeasureText(Control control) => mRenderer.MeasureText(control);
	public override int32 GetTextBoxHeight(TextBoxBase editor) => mRenderer.LineHeight(editor) + (editor.BorderStyle == .None ? 0 : 7);
	private Size GetMinimumClientSize(Form form)
	{
		SDL.GetWindowBordersSize(mWindow, var top, var left, var bottom, var right);
		return .(Math.Max(0, form.MinimumSize.width - left - right), Math.Max(0, form.MinimumSize.height - top - bottom));
	}
	private void ApplyMinimumSize(Form form)
	{
		let minimum = GetMinimumClientSize(form);
		SDL.SetWindowMinimumSize(mWindow, minimum.width, minimum.height);
		let size = GetClientSize(form);
		SetClientSize(form, size);
	}
	public override void SetClientSize(Form form, Size size)
	{
		let minimum = GetMinimumClientSize(form);
		SDL.SetWindowSize(mWindow, Math.Max(1, Math.Max(size.width, minimum.width)), Math.Max(1, Math.Max(size.height, minimum.height)));
		form.NotifyResize(GetFormSize());
	}
	public override void Show(Form form)
	{
		ApplyMinimumSize(form);
		mRunning = true;
		mShowPending = (SDL.GetWindowFlags(mWindow) & (uint32)SDL.WindowFlags.Hidden) != 0;
		RequestRedraw();
	}
	public override void Close(Form form)
	{
		mRunning = false;
		WakeEventLoop();
	}

	private void WakeEventLoop()
	{
		SDL.Event input = .();
		input.type = mRedrawEvent;
		SDL.PushEvent(ref input);
	}

	private void RequestRedraw()
	{
		if (mRedrawRequested) return;
		mRedrawRequested = true;
		if (mRunning) WakeEventLoop();
	}

#if !BF_PLATFORM_WASM
	public override void Run(Form form)
	{
		mRenderThreadId = Thread.CurrentThreadId;
		SDL.AddEventWatch(=> WatchWindowEvents, Internal.UnsafeCastToPtr(this));
		defer SDL.DelEventWatch(=> WatchWindowEvents, Internal.UnsafeCastToPtr(this));
		while (mRunning)
		{
			let frames = mFrames;
			DoEvents();
			if (!mRunning) break;
			if (FrameLimit > 0 && mFrames != frames) continue;
			let timeout = GetRedrawTimeout();
			if (timeout == 0) continue;
			SDL.Event input = ?;
			if (SDL.WaitEventTimeout(out input, timeout) != 0 && mWindow != null)
				ProcessEvent(ref input);
		}
		mRunning = false;
	}
#endif

	public override void DoEvents()
	{
		if (mWindow == null || !mRunning || mPumpingEvents || mRendering) return;
		mPumpingEvents = true;
		defer { mPumpingEvents = false; }
		ProcessEvents();
		if (!mRunning || mWindow == null) return;
		let capture = CapturePath != null && (FrameLimit == 0 || mFrames + 1 == FrameLimit);
		// Explicit frame limits also advance static forms for capture and smoke tests.
		if (RenderIfNeeded(FrameLimit > 0 || capture, capture) && FrameLimit > 0 && ++mFrames >= FrameLimit)
			mRunning = false;
	}

	internal void ProcessEvents()
	{
		SDL.Event input = ?;
		while (mWindow != null && SDL.PollEvent(out input) != 0)
			ProcessEvent(ref input);
	}

}
