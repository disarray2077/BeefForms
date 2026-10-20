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
#if BF_PLATFORM_WINDOWS
	internal static FormsBackend Backend = new Win32Backend() ~ delete _;
#else
	internal static FormsBackend Backend = new SDLBackend() ~ delete _;
#endif
	private static bool sRunning;
	internal static int CreatedControlCount;

	public static void UseBackend(ApplicationBackend backend)
	{
		if (sRunning || CreatedControlCount != 0)
			Runtime.FatalError("Dispose existing controls before changing the forms backend");
		delete Backend;
		switch (backend)
		{
		case .SDL2OpenGL: Backend = new SDLBackend();
#if BF_PLATFORM_WINDOWS
		case .Win32: Backend = new Win32Backend();
#else
		case .Win32: Runtime.FatalError("The Win32 backend requires Windows");
#endif
		}
	}

	public static void EnableVisualStyles() => Backend.EnableVisualStyles();
	public static void SetCompatibleTextRenderingDefault(bool defaultValue) {}

	public static void Run(Form mainForm)
	{
		sRunning = true;
		defer { sRunning = false; delete mainForm; }
		mainForm.Show();
		Backend.Run(mainForm);
	}
}
