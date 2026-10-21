using System;
using System.Collections;
using System.Drawing;
using System.Windows.Forms;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class SDLBackend : FormsBackend
{
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
		if (!(control is Form))
			return;
		if (mWindow != null)
			Runtime.FatalError("The SDL backend currently supports one top-level form");
		if (!mInitialized)
		{
			if (SDL.InitSubSystem(.Video) != 0 || SDLTTF.Init() != 0)
				Runtime.FatalError(scope $"Could not initialize SDL: {StringView(SDL.GetError())}");
			mInitialized = true;
			SDL.GetVersion(var version);
			mWheelHasPosition = version.major > 2 || version.minor >= 26;
		}
		mForm = (Form)control;
		let size = mForm.HasInitialClientSize ? mForm.InitialClientSize : control.Size;
		SDL.GL_SetAttribute(.GL_CONTEXT_MAJOR_VERSION, 3);
		SDL.GL_SetAttribute(.GL_CONTEXT_MINOR_VERSION, 3);
		SDL.GL_SetAttribute(.GL_CONTEXT_PROFILE_MASK, .GL_CONTEXT_PROFILE_CORE);
		SDL.GL_SetAttribute(.GL_DOUBLEBUFFER, 1);
		mWindow = SDL.CreateWindow(control.Text, (.)SDL.WindowPos.Centered, (.)SDL.WindowPos.Centered,
			Math.Max(1, size.width), Math.Max(1, size.height), .OpenGL | .Resizable | .AllowHighDPI | .Hidden);
		if (mWindow == null)
			Runtime.FatalError(scope $"Could not create SDL window: {StringView(SDL.GetError())}");
		let iconData = (Span<uint8>)DefaultIcon.Data;
		let icon = SDLImage.Load_RW(SDL.RWFromConstMem(iconData.Ptr, (int32)iconData.Length), 1);
		SDL.SetWindowIcon(mWindow, icon);
		SDL.FreeSurface(icon);
		mContext = SDL.GL_CreateContext(mWindow);
		if (mContext == default)
			Runtime.FatalError(scope $"Could not create OpenGL context: {StringView(SDL.GetError())}");
		GL.Init(scope (name) => SDL.GL_GetProcAddress(name));
		SDL.GL_SetSwapInterval(1);
		mRenderer = new .("");
		control.SetNativeHandle(mWindow);
		if (!mForm.HasInitialClientSize) SetFormSize(mForm, size);
		control.NotifyResize(GetFormSize());
		SDL.GetWindowPosition(mWindow, var x, var y);
		control.NotifyMove(.(x, y));
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
		mPointerInside = false;
		mActive = false;
		mSuppressTextInput = false;
	}

	public override void DestroyControl(Control control)
	{
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
				if (control.Visible) SDL.ShowWindow(mWindow);
				else SDL.HideWindow(mWindow);
			}
			if (change == .Text)
				SDL.SetWindowTitle(mWindow, control.Text);
			if (change == .Constraints) ApplyMinimumSize(mForm);
			if (change == .Bounds)
			{
				SetFormSize(mForm, control.Size);
				SDL.GetWindowPosition(mWindow, var x, var y);
				if (x != control.Location.x || y != control.Location.y)
					SDL.SetWindowPosition(mWindow, control.Location.x, control.Location.y);
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
	private Size GetFormSize()
	{
		let client = GetClientSize(mForm);
		SDL.GetWindowBordersSize(mWindow, var top, var left, var bottom, var right);
		return .(client.width + left + right, client.height + top + bottom);
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
		SDL.ShowWindow(mWindow);
		ApplyMinimumSize(form);
		SetActive(SDL.GetKeyboardFocus() == mWindow);
		mRunning = true;
	}
	public override void Close(Form form) => mRunning = false;

	public override void Run(Form form)
	{
		int frames = 0;
		while (mRunning)
		{
			ProcessEvents();
			if (!mRunning)
				break;
			mRenderer.Begin(mWindow);
			let size = GetClientSize(form);
			RenderControl(form, .(0, 0, size.width, size.height), .(0, 0, size.width, size.height));
			if (CapturePath != null && (FrameLimit == 0 || frames + 1 == FrameLimit))
			{
				mRenderer.Capture(CapturePath);
				CapturePath = null;
			}
			SDL.GL_SwapWindow(mWindow);
			if (FrameLimit > 0 && ++frames >= FrameLimit)
				mRunning = false;
			SDL.Delay(1);
		}
	}

	internal void ProcessEvents()
	{
		SDL.Event input = ?;
		while (mWindow != null && SDL.PollEvent(out input) != 0)
			ProcessEvent(ref input);
	}

}
