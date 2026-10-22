using BeefForms.Backends;
using System.Collections;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public enum ApplicationBackend
{
	Win32,
	SDL2OpenGL
}

public static class Application
{
	internal static FormsBackend Backend = FormsBackendFactory.Instance.CreateDefaultBackend() ~ delete _;
	private static bool sRunning;
	private static bool sProcessingEvents;
	private static bool sExiting;
	private static Form sMainForm;
	private static List<Form> sOpenForms = new .() ~ delete _;

	internal static void RegisterForm(Form form) => sOpenForms.Add(form);
	internal static void UnregisterForm(Form form) => sOpenForms.Remove(form);

#if BF_PLATFORM_WASM
	[CLink]
	private static extern void emscripten_set_main_loop(function void() callback, int32 fps, int32 simulateInfiniteLoop);
	[CLink]
	private static extern void emscripten_cancel_main_loop();

	private static void BrowserFrame() => RunFrame(=> emscripten_cancel_main_loop);
#endif

	private static void BeginRun(Form mainForm)
	{
		if (sRunning)
			Runtime.FatalError("Application.Run is already active");
		sRunning = true;
		sMainForm = mainForm;
		mainForm.Show();
	}

	private static void ReleaseMainForm()
	{
		let form = sMainForm;
		sMainForm = null;
		// Like WinForms thread teardown, dispose remaining windows after dispatch unwinds.
		// Show() does not transfer ownership of their Beef allocations to Application.
		while (!sOpenForms.IsEmpty)
			sOpenForms.Back.Dispose();
		delete form;
		sRunning = false;
	}

	// Scheduled hosts call this once per frame; only stopping their loop is platform-specific.
	private static void RunFrame<F>(F stopMainLoop) where F : delegate void()
	{
		if (sMainForm == null || sProcessingEvents) return;
		DoEvents();
		if (!sMainForm.IsHandleCreated)
		{
			stopMainLoop();
			ReleaseMainForm();
		}
	}

	internal static int CreatedControlCount;

	public static void UseBackend(ApplicationBackend backend)
	{
		if (sRunning || sProcessingEvents || CreatedControlCount != 0)
			Runtime.FatalError("Dispose existing controls before changing the forms backend");
		
		if (Backend.Type == backend)
			return;

		delete Backend;
		switch (backend)
		{
		case .SDL2OpenGL: Backend = FormsBackendFactory.Instance.CreateSDLBackend();
#if BF_PLATFORM_WINDOWS
		case .Win32: Backend = new Win32Backend();
#else
		case .Win32: Runtime.FatalError("The Win32 backend requires Windows");
#endif
		}
	}

	public static void EnableVisualStyles() => Backend.EnableVisualStyles();
	public static void SetCompatibleTextRenderingDefault(bool defaultValue) {}

	/// Closes the open forms only after all FormClosing handlers accept application exit.
	public static void Exit()
	{
		if (sExiting) return;
		sExiting = true;
		defer { sExiting = false; }
		let queried = scope HashSet<Form>();
		while (true)
		{
			Form next = null;
			for (int i = sOpenForms.Count - 1; i >= 0; i--)
				if (!queried.Contains(sOpenForms[i])) { next = sOpenForms[i]; break; }
			if (next == null) break;
			queried.Add(next);
			if (next.QueryApplicationExit()) return;
		}

		// Closed notifications precede disposal. Callbacks can change the open-form list.
		let closed = scope List<Form>();
		while (!sOpenForms.IsEmpty)
		{
			let form = sOpenForms.Back;
			closed.Add(form);
			form.CloseForApplicationExit();
			UnregisterForm(form);
		}
		for (let form in closed)
			if (!form.IsDisposingOrDisposed) form.Dispose();
	}

	/// Processes pending input and draws any due frame without waiting for more events.
	/// Must be called from the UI thread.
	public static void DoEvents()
	{
		if (sProcessingEvents) return;
		sProcessingEvents = true;
		defer { sProcessingEvents = false; }
		Backend.DoEvents();
	}

	/// Owns and deletes the form when its event loop exits.
	/// On Wasm, schedules browser frames and returns immediately.
	public static void Run(Form mainForm)
	{
		BeginRun(mainForm);
#if BF_PLATFORM_WASM
		// A Load handler can close the form before a browser loop is registered.
		if (!mainForm.IsHandleCreated)
		{
			ReleaseMainForm();
			return;
		}
		emscripten_set_main_loop(=> BrowserFrame, 0, 0);
#else
		defer { ReleaseMainForm(); }
		Backend.Run(mainForm);
#endif
	}
}
