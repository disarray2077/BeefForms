using System;
using System.Collections;
using System.Threading;
using System.Drawing;
using System.Windows.Forms;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class SDLBackend : FormsBackend
{
	public override ApplicationBackend Type => .SDL2OpenGL;

	private append List<SDLWindowSession> mSessions = .();
	private append Dictionary<uint32, SDLWindowSession> mWindows = .();

	private bool mInitialized, mWheelHasPosition, mPumpingEvents;
	private int mRenderThreadId, mFrames;
	private SDL.EventType mRedrawEvent;

	private SDLTextService mTextService;
	internal SDLTextService TextService
	{
		get
		{
			if (mTextService == null || !mTextService.UsesPath(Application.SDLFontPath))
			{
				delete mTextService;
				mTextService = new .(Application.SDLFontPath);
			}
			return mTextService;
		}
	}

	public int FrameLimit;
	public String CapturePath;

	public ~this()
	{
		for (let session in mSessions) session.ReleaseRef();
		delete mTextService;
		if (mInitialized)
		{
			SDL.QuitSubSystem(.Video);
		}
	}

	internal SDLWindowSession GetSession(Control control)
	{
		// Creation and teardown also need this lookup before/after IsHandleCreated is true.
		let session = control?.FindForm()?.SDLSession;
		return session?.Backend == this ? session : null;
	}

	private struct ContextSnapshot
	{
		public SDL.Window* Window;
		public SDL.SDL_GLContext Context;
		public SDLWindowSession Owner;

		public static ContextSnapshot CaptureContext(SDLBackend backend)
		{
			ContextSnapshot snapshot = .();
			snapshot.Window = SDL.GL_GetCurrentWindow();
			snapshot.Context = SDL.GL_GetCurrentContext();
			if (snapshot.Context != default)
				for (let session in backend.mSessions)
					if (session.mContext == snapshot.Context)
					{
						session.AddRef();
						snapshot.Owner = session;
						break;
					}
			return snapshot;
		}

		public void RestoreContext()
		{
			var window = this.Window;
			var context = this.Context;
			// A callback may destroy an owned context. Its retained session identifies
			// that lifetime even if a new native context reuses the same address.
			if (this.Owner != null && this.Owner.mContext != context)
			{
				window = null;
				context = default;
			}
			if (SDL.GL_GetCurrentContext() == context && SDL.GL_GetCurrentWindow() == window) return;
			if (SDL.GL_MakeCurrent(window, context) != 0)
				Runtime.FatalError("Could not restore the previous OpenGL context");
		}
	}

	// Owns both session references until synchronous callbacks have unwound.
	private struct ContextScope : IDisposable
	{
		private ContextSnapshot mPrevious;
		public SDLWindowSession Session;

		public this(SDLBackend backend, SDLWindowSession session = null)
		{
			mPrevious = ContextSnapshot.CaptureContext(backend);
			Session = session;
			Session?.AddRef();
			Session?.MakeCurrent();
		}

		public void Dispose()
		{
			mPrevious.RestoreContext();
			mPrevious.Owner?.ReleaseRef();
			Session?.ReleaseRef();
		}
	}

	private ContextScope UseSession(Control control) => .(this, GetSession(control));

	public override void CreateControl(Control control)
	{
		if (let form = control as Form)
		{
#if BF_PLATFORM_WASM
			// SDL2's Emscripten driver binds every window to the same browser canvas.
			if (!mSessions.IsEmpty)
				Runtime.FatalError("The Emscripten SDL2 driver supports a single browser canvas");
#endif
			if (!mInitialized)
			{
				if (SDL.InitSubSystem(.Video) != 0)
					Runtime.FatalError(scope $"Could not initialize SDL: {StringView(SDL.GetError())}");
				mInitialized = true;
				mRedrawEvent = (.)SDL.RegisterEvents(1);
				SDL.GetVersion(var version);
				mWheelHasPosition = version.major > 2 || version.minor >= 26;
			}
			let session = new SDLWindowSession(this, form, mWheelHasPosition);
			mSessions.Add(session);
			form.SDLSession = session;
		}
		using (let current = UseSession(control))
		{
			let session = current.Session;
			session?.CreateControl(control);
			if (control is Form) mWindows[SDL.GetWindowID(session.mWindow)] = session;
		}
	}

	public override void DestroyControl(Control control)
	{
		using (let current = UseSession(control))
		{
			let session = current.Session;
			if (session == null) return;
			let generation = control.HandleGeneration;
			let windowID = (control is Form) ? SDL.GetWindowID(session.mWindow) : 0;
			session.DestroyControl(control);
			if (let form = control as Form)
			{
				if (form.SDLSession == session && form.HandleGeneration.IsCurrent(generation))
					form.SDLSession = null;
				mWindows.Remove(windowID);
				mSessions.Remove(session);
				session.ReleaseRef();
			}
		}
	}

	public override void UpdateControl(Control control, ControlChange change)
	{
		using (let current = UseSession(control))
		{
			let session = current.Session;
			session?.UpdateControl(control, change);
		}
	}

	public override Size GetClientSize(Form form)
	{
		let session = GetSession(form);
		return session == null ? form.Size : session.GetClientSize(form);
	}
	public override Rectangle GetScreenWorkingArea()
	{
		SDL.GetGlobalMouseState(var x, var y);
		SDL.Point point = .(x, y);
		let display = Math.Max(0, SDL.GetPointDisplayIndex(&point));
		SDL.GetDisplayUsableBounds(display, var area);
		return .(area.x, area.y, area.w, area.h);
	}
	public override void SetClientSize(Form form, Size size)
	{
		using (let current = UseSession(form))
		{
			let session = current.Session;
			session?.SetClientSize(form, size);
		}
	}
	public override void Show(Form form)
	{
		using (let current = UseSession(form))
		{
			let session = current.Session;
			session?.Show(form);
		}
	}
	public override bool FocusControl(Control control)
	{
		using (let current = UseSession(control))
		{
			let session = current.Session;
			if (session == null) return false;
			return session.FocusControl(control);
		}
	}
	public override bool IsFocused(Control control) => GetSession(control)?.IsFocused(control) ?? false;
	public override bool HasCapture(Control control) => GetSession(control)?.HasCapture(control) ?? false;
	public override void SetCapture(Control control, bool capture)
	{
		using (let current = UseSession(control))
		{
			let session = current.Session;
			if (session == null) return;
			if (capture && (!control.IsHandleCreated || control.IsDisposingOrDisposed ||
				!control.IsEffectivelyVisible || !control.IsEffectivelyEnabled)) return;
			if (capture)
			{
				let sessions = ToScopedArray!(mSessions);
				for (let other in sessions)
					if (other != session) other.ReleaseCapture();
			}
			session.SetCapture(control, capture);
		}
	}
	public override Size MeasureText(Control control) => TextService.MeasureText(control);
	public override int32 GetTextBoxHeight(TextBoxBase editor) => TextService.LineHeight(editor) + (editor.BorderStyle == .None ? 0 : 7);

	internal void WakeEventLoop()
	{
		SDL.Event input = .();
		input.type = mRedrawEvent;
		SDL.PushEvent(ref input);
	}

#if !BF_PLATFORM_WASM
	public override void Run(Form form)
	{
		mFrames = 0;
		mRenderThreadId = Thread.CurrentThreadId;
		SDL.AddEventWatch(=> WatchWindowEvents, Internal.UnsafeCastToPtr(this));
		defer SDL.DelEventWatch(=> WatchWindowEvents, Internal.UnsafeCastToPtr(this));
		while (form.IsHandleCreated)
		{
			let frames = mFrames;
			DoEvents();
			if (!form.IsHandleCreated || (FrameLimit > 0 && mFrames >= FrameLimit)) break;
			if (FrameLimit > 0 && mFrames != frames) continue;
			let timeout = GetRedrawTimeout();
			if (timeout == 0) continue;
			SDL.Event input = ?;
			if (SDL.WaitEventTimeout(out input, timeout) != 0) ProcessEvents(input);
		}
	}
#endif

	private int32 GetRedrawTimeout()
	{
		int32 timeout = -1;
		for (let session in mSessions)
		{
			let next = session.GetRedrawTimeout();
			if (next >= 0 && (timeout < 0 || next < timeout)) timeout = next;
		}
		return timeout;
	}

	public override void DoEvents()
	{
		if (mPumpingEvents || IsRendering) return;
		mPumpingEvents = true;
		defer { mPumpingEvents = false; }
		ProcessEvents();
		let capture = CapturePath != null && (FrameLimit == 0 || mFrames + 1 == FrameLimit);
		if (RenderIfNeeded(FrameLimit > 0 || capture, capture) && FrameLimit > 0) mFrames++;
	}

	private bool IsRendering
	{
		get { for (let session in mSessions) if (session.Rendering) return true; return false; }
	}

	private bool RenderIfNeeded(bool force = false, bool capture = false)
	{
		using (ContextScope(this))
		{
			bool rendered = false;
			let sessions = ToScopedArray!(mSessions);
			for (let session in sessions)
			{
				session.MakeCurrent();
				rendered |= session.RenderIfNeeded(force, capture && CapturePath != null);
			}
			return rendered;
		}
	}

	internal void ProcessEvents(SDL.Event? first = null)
	{
		// StopTextInput flushes SDL's global text queue. Capture pending events before
		// callbacks can close a different window or change the active text editor.
		let pending = scope List<SDL.Event>();
		if (first.HasValue) pending.Add(first.Value);
		SDL.Event input = ?;
		while (true)
		{
			while (SDL.PollEvent(out input) != 0) pending.Add(input);
			if (pending.IsEmpty) break;
			for (var queued in pending) ProcessEvent(ref queued);
			pending.Clear();
		}
	}

	private static uint32 EventWindowID(SDL.Event input)
	{
		switch (input.type)
		{
		case .WindowEvent: return input.window.windowID;
		case .KeyDown, .KeyUp: return input.key.windowID;
		case .TextInput: return input.text.windowID;
		case .MouseMotion: return input.motion.windowID;
		case .MouseButtonDown, .MouseButtonUp: return input.button.windowID;
		case .MouseWheel: return input.wheel.windowID;
		default: return 0;
		}
	}

	private void ProcessEvent(ref SDL.Event input)
	{
		if (input.type == .Quit)
		{
			Application.Exit();
			return;
		}
		if (!mWindows.TryGetValue(EventWindowID(input), let session)) return;
		using (ContextScope(this, session))
		{
			if (input.type == .WindowEvent && input.window.windowEvent == .FocusGained)
			{
				let sessions = ToScopedArray!(mSessions);
				for (let other in sessions)
					if (other != session) other.Deactivate();
			}
			session.ProcessEvent(ref input);
		}
	}

	private static int32 WatchWindowEvents(void* userData, SDL.Event* input)
	{
		if (input.type != .WindowEvent || input.window.windowEvent != .Exposed) return 0;
		let backend = (SDLBackend)Internal.UnsafeCastToObject(userData);
		// SDL may invoke watches from another thread or inside a modal resize loop.
		if (Thread.CurrentThreadId != backend.mRenderThreadId || backend.IsRendering) return 0;
		if (!backend.mWindows.TryGetValue(input.window.windowID, let session)) return 0;
		using (ContextScope(backend, session))
		{
			session.HandleExposure(input.window.timestamp);
			return 0;
		}
	}
}
