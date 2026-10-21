using BeefForms.Backends;

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

#if BF_PLATFORM_WASM
	private static Form sMainForm;

	[CLink]
	private static extern void emscripten_set_main_loop(function void() callback, int32 fps, int32 simulateInfiniteLoop);
	[CLink]
	private static extern void emscripten_cancel_main_loop();

	private static void ReleaseMainForm()
	{
		let form = sMainForm;
		sMainForm = null;
		delete form;
		sRunning = false;
	}

	private static void BrowserFrame()
	{
		if (sMainForm == null) return;
		DoEvents();
		if (!sMainForm.IsHandleCreated)
		{
			emscripten_cancel_main_loop();
			ReleaseMainForm();
		}
	}
#endif

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
		if (sRunning)
			Runtime.FatalError("Application.Run is already active");
		sRunning = true;
#if BF_PLATFORM_WASM
		sMainForm = mainForm;
		mainForm.Show();
		// A Load handler can close the form before a browser loop is registered.
		if (!mainForm.IsHandleCreated)
		{
			ReleaseMainForm();
			return;
		}
		emscripten_set_main_loop(=> BrowserFrame, 0, 0);
#else
		defer { sRunning = false; delete mainForm; }
		mainForm.Show();
		Backend.Run(mainForm);
#endif
	}
}
