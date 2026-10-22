using System;
using System.Windows.Forms;

namespace BeefForms.WasmRunTests;

// Smoke test for Emscripten scheduling and cancellation. Lifecycle cases live in Tests/src.
class Program
{
	private static int sPaints, sRuns;
	private static TestForm sLiveForm;

	[CLink]
	private static extern void emscripten_async_call(function void(void*) callback, void* argument, int32 milliseconds);

	private class TestForm : Form
	{
		public this()
		{
			ClientSize = .(240, 100);
			let panel = new Panel();
			panel.Size = .(200, 80);
			panel.Paint.Add(new (sender, args) => { sPaints++; });
			Controls.Add(panel);
		}
		public ~this() { sLiveForm = null; }
	}

	private static void Check(bool condition)
	{
		if (!condition) Runtime.FatalError("Emscripten main-loop smoke test failed");
	}

	public static void Main() => StartRun();

	private static void StartRun()
	{
		sPaints = 0;
		sLiveForm = new TestForm();
		Application.Run(sLiveForm);
		Check(sLiveForm != null && Application.[Friend]sRunning && sPaints == 0);
		emscripten_async_call(=> CloseAfterFrames, null, 100);
	}

	private static void CloseAfterFrames(void* argument)
	{
		Check(sPaints > 0 && sLiveForm.IsHandleCreated);
		sLiveForm.Close();
		emscripten_async_call(=> VerifyStopped, null, 100);
	}

	private static void VerifyStopped(void* argument)
	{
		Check(sLiveForm == null && !Application.[Friend]sRunning);
		if (++sRuns == 1)
			StartRun(); // A second registration verifies cancellation of the previous loop.
		else
			Console.WriteLine("PASS: Emscripten main-loop scheduling, cancellation, and restart");
	}
}
