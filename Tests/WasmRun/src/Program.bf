using System;
using System.Windows.Forms;

namespace BeefForms.WasmRunTests;

// Browser integration tests: actual Emscripten callbacks run after Main returns.
class Program
{
	private static int sDisposed, sPaints, sRuns;
	private static TestForm sLiveForm;

	[CLink]
	private static extern void emscripten_async_call(function void(void*) callback, void* argument, int32 milliseconds);

	private class TestForm : Form
	{
		public bool CancelClose;
		public this(bool closeOnLoad = false)
		{
			ClientSize = .(240, 100);
			let panel = new Panel();
			panel.Size = .(200, 80);
			panel.Paint.Add(new (sender, args) => { sPaints++; });
			Controls.Add(panel);
			FormClosing.Add(new [&] (sender, args) => { args.Cancel = CancelClose; });
			if (closeOnLoad) Load.Add(new (sender, args) => { ((Form)sender).Close(); });
		}
		public ~this() { sDisposed++; sLiveForm = null; }
	}

	private static void Check(bool condition)
	{
		if (!condition) Runtime.FatalError("Wasm Run lifecycle test failed");
	}

	public static void Main()
	{
		Application.Run(new TestForm(true));
		Check(sDisposed == 1 && !Application.[Friend]sRunning);
		Check(Application.[Friend]CreatedControlCount == 0);

		// Manual pumping continues to work without Application owning the form.
		let manual = new TestForm();
		manual.Show();
		Application.DoEvents();
		Check(sPaints > 0 && !Application.[Friend]sRunning);
		manual.Close();
		Application.DoEvents();
		Check(sDisposed == 1);
		delete manual;
		StartRun();
	}

	private static void StartRun()
	{
		sPaints = 0;
		sLiveForm = new TestForm();
		Application.Run(sLiveForm);
		Check(sLiveForm != null && Application.[Friend]sRunning);
		Check(sPaints == 0); // Run returns before the browser drives its first frame.
		emscripten_async_call(=> CloseAfterFrames, null, 100);
	}

	private static void CloseAfterFrames(void* argument)
	{
		Check(sPaints > 0 && sLiveForm.IsHandleCreated);
		sLiveForm.CancelClose = true;
		sLiveForm.Close();
		Check(sLiveForm.IsHandleCreated && Application.[Friend]sRunning);
		sPaints = 0;
		sLiveForm.Controls[0].Invalidate();
		emscripten_async_call(=> AcceptClose, null, 100);
	}

	private static void AcceptClose(void* argument)
	{
		Check(sPaints > 0 && sLiveForm.IsHandleCreated); // Cancelled close kept frames running.
		Application.DoEvents(); // Also allowed while Run owns the form.
		sLiveForm.CancelClose = false;
		sLiveForm.Close();
		Check(!sLiveForm.IsHandleCreated && Application.[Friend]sRunning);
		emscripten_async_call(=> VerifyCleanup, null, 100);
	}

	private static void VerifyCleanup(void* argument)
	{
		Check(sLiveForm == null && !Application.[Friend]sRunning);
		Check(Application.[Friend]CreatedControlCount == 0);
		Check(sDisposed == 3 + sRuns);
		Application.DoEvents();
		if (++sRuns == 1)
			StartRun(); // Also verifies the old Emscripten loop was cancelled.
		else
			Console.WriteLine("PASS: Wasm Run lifecycle and manual DoEvents");
	}
}
