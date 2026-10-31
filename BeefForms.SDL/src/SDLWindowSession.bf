using System;
using System.Collections;
using System.Drawing;
using System.Windows;
using System.Windows.Forms;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class SDLWindowSession : RefCounted
{
	private struct WindowInsets : this(int32 Top, int32 Left, int32 Bottom, int32 Right);

	private SDLBackend mBackend;
	internal SDLBackend Backend => mBackend;

	internal struct LifetimeScope : IDisposable
	{
		private SDLWindowSession mSession;

		public this(SDLWindowSession session)
		{
			mSession = session;
			session.AddRef();
		}

		public void Dispose()
		{
			mSession.ReleaseRef();
		}
	}

	internal LifetimeScope Retain()
		=> .(this);

	public this(SDLBackend backend, Form form, bool wheelHasPosition)
	{
		mBackend = backend;
		mForm = form;
		mWheelHasPosition = wheelHasPosition;
	}

	// Invalidates work from a previous native handle of this session.
	private Generation mWindowGeneration;

	// Changes on each focus transition so a nested transition from a callback
	// prevents the outer transition from overwriting its result.
	private Generation mFocusGeneration;

	internal SDL.Window* mWindow;
	internal SDL.SDL_GLContext mContext;
	private SDLCanvas mCanvas;
	private SDLTextRenderer mTextRenderer;
	private SDLControlRenderer mControlRenderer;
	internal Form mForm;
	private Control mFocused, mPressed, mHovered;
	private Point mPointerPosition;
	private bool mPointerInside;
	private Control mCaptured;
	private bool mAutomaticCapture;
	private bool mActive;
	private bool mWheelHasPosition;
	private bool mSuppressTextInput;
	private bool mRunning;
	private bool mRendering;
	internal bool Rendering => mRendering;
	private uint32? mHandledExposureTimestamp;
	private bool mRedrawRequested, mShowPending;
	private uint64 mFrameTicks, mNextAnimationTick = uint64.MaxValue;
#if BF_PLATFORM_WASM
	private TextBoxBase mExtractedEditor;
	private append String mExtractedOriginal = .();
	private Generation mExtractedHandle;
#endif

	public ~this()
	{
		if (mForm?.SDLSession == this)
			mForm.SDLSession = null;
		DestroyWindow();
	}

	public void CreateControl(Control control)
	{
		RequestRedraw();
		if (!(control is Form))
		{
			if (let progress = control as ProgressBar)
				progress.RestartMarquee(SDL.GetTicks64());
			if (let editor = control as TextBoxBase)
				editor.InvalidateScroll();
			return;
		}
		mForm = (Form)control;
		mWindowGeneration.Advance();
		let size = mForm.HasInitialClientSize ? mForm.InitialClientSize : control.Size;
		SDL.WindowFlags flags = .Resizable | .AllowHighDPI | .Hidden;
		if (mBackend.RenderingEnabled)
		{
			flags |= .OpenGL;
			SDL.GL_SetAttribute(.GL_CONTEXT_MAJOR_VERSION, 3);
#if BF_PLATFORM_WASM
			SDL.GL_SetAttribute(.GL_CONTEXT_MINOR_VERSION, 0);
			SDL.GL_SetAttribute(.GL_CONTEXT_PROFILE_MASK, .GL_CONTEXT_PROFILE_ES);
#else
			SDL.GL_SetAttribute(.GL_CONTEXT_MINOR_VERSION, 3);
			SDL.GL_SetAttribute(.GL_CONTEXT_PROFILE_MASK, .GL_CONTEXT_PROFILE_CORE);
#endif
			SDL.GL_SetAttribute(.GL_DOUBLEBUFFER, 1);
		}
		mWindow = SDL.CreateWindow(control.Text.ToScopeCStr!(), (.)control.Location.x, (.)control.Location.y,
			Math.Max(1, size.width), Math.Max(1, size.height), flags);
		if (mWindow == null)
			Runtime.FatalError(scope $"Could not create SDL window: {StringView(SDL.GetError())}");
#if !BF_PLATFORM_WASM
		let iconData = (Span<uint8>)DefaultIcon.Data;
		let icon = SDLImage.Load_RW(SDL.RWFromConstMem(iconData.Ptr, (int32)iconData.Length), 1);
		SDL.SetWindowIcon(mWindow, icon);
		SDL.FreeSurface(icon);
#endif
		if (mBackend.RenderingEnabled)
		{
			mContext = SDL.GL_CreateContext(mWindow);
			if (mContext == default)
				Runtime.FatalError(scope $"Could not create OpenGL context: {StringView(SDL.GetError())}");
			GL.Init(scope (name) => SDL.GL_GetProcAddress(name));
#if !BF_PLATFORM_WASM
			SDL.GL_SetSwapInterval(1);
#endif
			mCanvas = new .();
			mTextRenderer = new .(mCanvas, mBackend.TextService);
			mControlRenderer = new .(mCanvas, mTextRenderer, mBackend.TextService);
		}
		control.SetNativeHandle(mWindow);
		if (!mForm.HasInitialClientSize)
			SetFormSize(mForm, size);
		control.NotifyResize(GetFormSize());
		SetFormLocation(control.Location);
		control.NotifyMove(GetFormLocation());
		ApplyMinimumSize(mForm);
#if BF_PLATFORM_WASM
		InstallExtractedEditor();
#endif
	}

	private void DestroyWindow()
	{
		if (mWindow == null)
			return;
#if BF_PLATFORM_WASM
		UninstallExtractedEditor();
#endif
		mWindowGeneration.Advance();
		if (mActive)
			SDL.StopTextInput();
		MakeCurrent();
		delete mControlRenderer;
		mControlRenderer = null;
		delete mTextRenderer;
		mTextRenderer = null;
		delete mCanvas;
		mCanvas = null;
		if (mContext != default)
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

	public void DestroyControl(Control control)
	{
#if BF_PLATFORM_WASM
		if (Control.IsAncestorOf(control, mExtractedEditor))
			CancelExtractedEditor();
#endif
		let generation = control.HandleGeneration;
		RequestRedraw();
		if (Control.IsAncestorOf(control, mFocused))
			Focus(null);
		if (Control.IsAncestorOf(control, mCaptured))
			SetCapture(mCaptured, false);
		if (mPressed == control)
			mPressed = null;
		if (Control.IsAncestorOf(control, mHovered))
			Hover(null);
		mTextRenderer?.Forget(control);
		if (control == mForm)
		{
			DestroyWindow();
			mForm = null;
		}
		if (control.HandleGeneration.IsCurrent(generation))
			control.SetNativeHandle(null);
	}

	public void UpdateControl(Control control, ControlChange change)
	{
#if BF_PLATFORM_WASM
		if (mExtractedEditor != null && Control.IsAncestorOf(control, mExtractedEditor) &&
			(!mExtractedEditor.IsEffectivelyVisible || !mExtractedEditor.IsEffectivelyEnabled ||
			(control == mExtractedEditor && (change == .Text || change == .ReadOnly || change == .Multiline || change == .Parent))))
			CancelExtractedEditor();
#endif
		RequestRedraw();
		if (change == .Appearance || change == .All)
		{
			if (let progress = control as ProgressBar)
				progress.RestartMarquee(SDL.GetTicks64());
		}
		if (let editor = control as TextBoxBase)
		{
			if (change == .Text || change == .Font || change == .Bounds || change == .Border || change == .Multiline || change == .All)
				editor.InvalidateScroll();
			if (IsFocused(editor) && (change == .Text || change == .Selection || change == .ReadOnly || change == .Multiline))
			{
				editor.RestartCaretBlink(SDL.GetTicks64());
				if (change != .ReadOnly)
					editor.RequestCaretReveal();
			}
		}
		if (!control.IsEffectivelyVisible || !control.IsEffectivelyEnabled)
		{
			if (Control.IsAncestorOf(control, mFocused))
				Focus(null);
			if (Control.IsAncestorOf(control, mCaptured))
				SetCapture(mCaptured, false);
			if (Control.IsAncestorOf(control, mPressed))
				mPressed = null;
			if (Control.IsAncestorOf(control, mHovered))
				Hover(null);
		}
		if (control == mForm && mWindow != null)
		{
			if (change == .Visibility)
			{
				if (control.Visible)
					Show(mForm);
				else
				{
					mShowPending = false;
					SDL.HideWindow(mWindow);
				}
			}
			if (change == .Text)
				SDL.SetWindowTitle(mWindow, control.Text.ToScopeCStr!());
			if (change == .Constraints)
				ApplyMinimumSize(mForm);
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

	public Size GetClientSize(Form form)
	{
		if (mWindow == null)
			return form.Size;
		SDL.GetWindowSize(mWindow, var width, var height);
		return .(width, height);
	}

	private WindowInsets GetWindowInsets()
	{
		SDL.GetWindowBordersSize(mWindow, var top, var left, var bottom, var right);
		return .(top, left, bottom, right);
	}

	private Point GetFormLocation()
	{
		SDL.GetWindowPosition(mWindow, var x, var y);
		let insets = GetWindowInsets();
		return .(x - insets.Left, y - insets.Top);
	}

	private void SetFormLocation(Point location)
	{
		let insets = GetWindowInsets();
		SDL.SetWindowPosition(mWindow, location.x + insets.Left, location.y + insets.Top);
	}

	private Size GetFormSize()
	{
		let client = GetClientSize(mForm);
		let insets = GetWindowInsets();
		return .(client.width + insets.Left + insets.Right, client.height + insets.Top + insets.Bottom);
	}

	private void UpdateFormSize()
	{
		let size = GetFormSize();
		if (size.width == mForm.Size.width && size.height == mForm.Size.height)
			return;
		mForm.NotifyResize(size);
		RequestRedraw();
	}

	private void SetFormSize(Form form, Size size)
	{
		let insets = GetWindowInsets();
		SetClientSize(form, .(Math.Max(1, size.width - insets.Left - insets.Right), Math.Max(1, size.height - insets.Top - insets.Bottom)));
	}

	private Size GetMinimumClientSize(Form form)
	{
		let insets = GetWindowInsets();
		return .(Math.Max(0, form.MinimumSize.width - insets.Left - insets.Right), Math.Max(0, form.MinimumSize.height - insets.Top - insets.Bottom));
	}

	private void ApplyMinimumSize(Form form)
	{
		let minimum = GetMinimumClientSize(form);
		SDL.SetWindowMinimumSize(mWindow, minimum.width, minimum.height);
		let size = GetClientSize(form);
		SetClientSize(form, size);
	}

	public void SetClientSize(Form form, Size size)
	{
		let minimum = GetMinimumClientSize(form);
		SDL.SetWindowSize(mWindow, Math.Max(1, Math.Max(size.width, minimum.width)), Math.Max(1, Math.Max(size.height, minimum.height)));
		form.NotifyResize(GetFormSize());
	}

	public void Show(Form form)
	{
		ApplyMinimumSize(form);
		mRunning = true;
		mShowPending = (SDL.GetWindowFlags(mWindow) & (uint32)SDL.WindowFlags.Hidden) != 0;
		RequestRedraw();
	}

	public void Activate()
	{
		SDL.RaiseWindow(mWindow);
	}

	private void RequestRedraw()
	{
		if (mRedrawRequested)
			return;
		mRedrawRequested = true;
		if (mRunning)
			mBackend.WakeEventLoop();
	}

	internal void MakeCurrent()
	{
		if (mContext != default && mWindow != null && (SDL.GL_GetCurrentContext() != mContext || SDL.GL_GetCurrentWindow() != mWindow))
		{
			if (SDL.GL_MakeCurrent(mWindow, mContext) != 0)
				Runtime.FatalError("Could not activate the window's OpenGL context");
		}
	}

	// Close is synchronous. A callback may even replace the window before returning.
	private bool IsCurrentWindow(Generation snapshot)
		=> mWindowGeneration.IsCurrent(snapshot) && mRunning &&
		mWindow != null && mForm != null && mForm.IsHandleCreated && !mForm.IsDisposingOrDisposed;

	private bool IsCurrentControl(Control control, Generation snapshot)
		=> IsCurrentWindow(snapshot) &&
		control != null && control.IsHandleCreated && !control.IsDisposingOrDisposed;

	private bool IsCurrentControl(Control control, Generation snapshot, Generation handleSnapshot)
		=> IsCurrentWindow(snapshot) && control != null && control.IsCurrentHandle(handleSnapshot);
}
