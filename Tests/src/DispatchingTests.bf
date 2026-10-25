using System;
using System.Collections;
using System.Threading;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class DispatchingTests
{
	private class RepostingWork
	{
		public Control Target;
		public int Calls, Limit = 1000;
		public bool Slow;
		public void Run()
		{
			Calls++;
			if (Slow) Thread.Sleep(1);
			if (Calls < Limit) Target.BeginInvoke(new => Run);
		}
	}

	private class ConcurrentInvocations
	{
		public Control Target;
		public append WaitEvent Done = .();
		public int Remaining = 4;
		public int Calls;

		public void Run()
		{
			for (int i < 100)
			{
				let expected = i + 1;
				int value = 0;
				let invoked = Target.Invoke<int>(scope [&] () =>
				{
					Calls++;
					value = expected;
					return value;
				});
				Test.Assert(invoked case .Ok(expected) && value == expected);
				let result = Target.BeginInvoke(new [&] () => { Calls++; value = -expected; }); defer delete result;
				if (i % 3 == 0)
				{
					let deadline = TimerScheduler.Now + 3000;
					while (!result.IsCompleted && TimerScheduler.Now < deadline) Thread.Sleep(0);
					Test.Assert(result.IsCompleted);
				}
				else if (i % 3 == 1)
				{
					let wait = result.AsyncWaitHandle;
					let deadline = TimerScheduler.Now + 3000;
					while (!result.IsCompleted && TimerScheduler.Now < deadline) Thread.Sleep(0);
					Test.Assert(result.IsCompleted && wait.WaitFor(0));
				}
				else Test.Assert(result.AsyncWaitHandle.WaitFor(3000) && result.IsCompleted);
				Test.Assert(Target.EndInvoke(result) case .Ok && value == -expected);
			}
			if (Interlocked.Decrement(ref Remaining) == 0) Done.Set(true);
		}
	}

	private static bool PumpUntil(WaitEvent done)
	{
		let deadline = TimerScheduler.Now + 3000;
		while (!done.WaitFor(0) && TimerScheduler.Now < deadline)
		{
			Application.DoEvents();
			Thread.Sleep(1);
		}
		return done.WaitFor(0);
	}

	private static bool RunWithTimeout(Form form)
	{
		let deadline = TimerScheduler.Now + 3000;
		bool timedOut = false;
		let watchdog = scope Timer(); watchdog.Interval = 20;
		watchdog.Tick.Add(new [&] (sender, args) =>
		{
			if (TimerScheduler.Now < deadline) return;
			timedOut = true;
			watchdog.Stop();
			form.Close();
		});
		watchdog.Start();
		defer watchdog.Stop();
		Application.Run(form);
		return !timedOut;
	}

	private static void VerifyQueue(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let dispatcher = Application.Dispatcher;
		let uiThread = Thread.CurrentThreadId;
		let order = scope String();
		let worker = scope Thread(new [&] () =>
		{
			Test.Assert(!dispatcher.CheckAccess);
			Test.Assert(dispatcher.Post(new [&] () =>
			{
				Test.Assert(Thread.CurrentThreadId == uiThread);
				order.Append('A');
				dispatcher.Post(new [&] () => order.Append('C'));
			}) case .Ok);
			dispatcher.Post(new [&] () => order.Append('B'));
		});
		worker.Start(false); worker.Join();
		Test.Assert(order.IsEmpty && dispatcher.CheckAccess);
		Application.DoEvents();
		Test.Assert(order == "ABC" && Application.CreatedControlCount == 0);
		Test.Assert(dispatcher.Invoke<int>(scope () => 42) case .Ok(42));
	}
	[Test] public static void SDLDispatcherPostsInOrderWithoutAForm() => VerifyQueue(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeDispatcherPostsInOrderWithoutAForm() => VerifyQueue(.Win32);
#endif

	private static void VerifyRepostsDrain(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140); form.Show();
		let work = scope RepostingWork() { Target = form };
		form.BeginInvoke(new => work.Run);
		Application.DoEvents();
		Test.Assert(work.Calls == 1000);
		form.Close();
	}
	[Test] public static void SDLRepostedCallbacksDrainInOnePumpLikeDotNet() => VerifyRepostsDrain(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeRepostedCallbacksDrainInOnePumpLikeDotNet() => VerifyRepostsDrain(.Win32);

	[Test]
	public static void NativeRepostedCallbacksDrainBeforeTimersLikeDotNet()
	{
		Application.UseBackend(.Win32);
		let form = new Form(); form.ClientSize = .(240, 140);
		let work = scope RepostingWork() { Target = form, Limit = 20, Slow = true };
		int callsAtTick = 0;
		let timer = scope Timer(); timer.Interval = 1;
		timer.Tick.Add(new [&] (sender, args) =>
		{
			callsAtTick = work.Calls;
			timer.Stop();
			form.Close();
		});
		form.Load.Add(new [&] (sender, args) =>
		{
			form.BeginInvoke(new => work.Run);
			timer.Start();
		});
		let completed = RunWithTimeout(form);
		timer.Stop();
		Test.Assert(completed && callsAtTick == 20);
	}

	[Test]
	public static void NativeRepostedCallbacksDrainBeforePaintingLikeDotNet()
	{
		Application.UseBackend(.Win32);
		let form = new Form(); form.ClientSize = .(240, 140);
		let work = scope RepostingWork() { Target = form };
		let panel = new Panel(); panel.Size = .(200, 100); form.Controls.Add(panel);
		int callsAtPaint = 0;
		panel.Paint.Add(new [&] (sender, args) =>
		{
			if (work.Calls == 0) return;
			callsAtPaint = work.Calls;
			form.Close();
		});
		form.Load.Add(new [&] (sender, args) =>
		{
			form.BeginInvoke(new [&] () =>
			{
				panel.Invalidate();
				work.Run();
			});
		});
		let completed = RunWithTimeout(form);
		Test.Assert(completed && callsAtPaint == 1000);
	}
#endif

	private static void VerifyWorker(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140);
		let child = new TextBox(); child.Size = .(180, 30); form.Controls.Add(child); form.Show();
		let uiThread = Thread.CurrentThreadId;
		let ready = scope WaitEvent(); let done = scope WaitEvent();
		int result = 0;
		let worker = scope Thread(new [&] () =>
		{
			Test.Assert(child.InvokeRequired && form.InvokeRequired);
			ready.Set(true);
			let value = child.Invoke<int>(scope [&] () =>
			{
				Test.Assert(Thread.CurrentThreadId == uiThread && !child.InvokeRequired);
				child.Text = "from worker";
				return 73;
			});
			if (value case .Ok(let answer)) result = answer;
			done.Set(true);
		});
		worker.Start(false);
		let started = ready.WaitFor(3000);
		let waited = !done.WaitFor(20);
		let completed = PumpUntil(done);
		if (!completed) Application.DispatcherCore.Shutdown();
		Test.Assert(worker.Join(3000));
		Test.Assert(started && waited && completed && result == 73 && child.Text == "from worker");
		form.Close();
	}
	[Test] public static void SDLInvokeWaitsAndReturnsAValueFromTheUIThread() => VerifyWorker(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeInvokeWaitsAndReturnsAValueFromTheUIThread() => VerifyWorker(.Win32);
#endif

	private static void VerifySubtreeCancellation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140);
		let panel = new Panel(); panel.Size = .(200, 100); form.Controls.Add(panel);
		let results = scope InvokeAsyncResult[128]();
		defer { for (let result in results) delete result; }
		for (int i < results.Count)
			panel.Controls.Add(new Control() { Size = .(10, 10) });
		form.Show();
		let order = scope List<int>();
		for (int i < results.Count)
		{
			results[i] = panel.Controls[i].BeginInvoke(new () => Test.FatalError("A canceled invocation ran"));
			let index = i;
			form.BeginInvoke(new [=] () => order.Add(index));
		}
		panel.Dispose();
		delete panel;
		for (let result in results)
			Test.Assert(result.IsCompleted && form.EndInvoke(result) case .Err);
		Application.DoEvents();
		Test.Assert(order.Count == results.Count);
		for (int i < order.Count) Test.Assert(order[i] == i);
		form.Close();
	}
	[Test] public static void SDLSubtreeDisposalCancelsImmediatelyAndPreservesOtherTargetsOrder() => VerifySubtreeCancellation(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeSubtreeDisposalCancelsImmediatelyAndPreservesOtherTargetsOrder() => VerifySubtreeCancellation(.Win32);
#endif

	private static void VerifyAsync(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140); form.Show();
		let order = scope String();
		let first = form.BeginInvoke(new [&] () => order.Append('A')); defer delete first;
		let second = form.BeginInvoke(new [&] () => order.Append('B')); defer delete second;
		Test.Assert(!first.IsCompleted && !first.CompletedSynchronously && first.AsyncState == null && order.IsEmpty);
		Test.Assert(form.EndInvoke(second) case .Ok);
		Test.Assert(order == "AB" && first.IsCompleted && second.IsCompleted && second.AsyncWaitHandle.WaitFor(0));
		form.BeginInvoke(new [&] () => order.Append('C'));
		let discarded = form.BeginInvoke(new [&] () => order.Append('D')); delete discarded;
		Test.Assert(form.Invoke(scope [&] () => order.Append('E')) case .Ok);
		Test.Assert(order == "ABCDE");
		form.Close();
	}
	[Test] public static void SDLAsyncResultsSupportWaitingDiscardingAndEarlyDeletion() => VerifyAsync(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeAsyncResultsSupportWaitingDiscardingAndEarlyDeletion() => VerifyAsync(.Win32);
#endif

	private static void VerifyUIDrain(ApplicationBackend backend, bool endInvoke)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140); form.Show();
		let order = scope String();
		form.BeginInvoke(new [&] () =>
		{
			order.Append('A');
			form.BeginInvoke(new [&] () => order.Append('C'));
		});
		if (endInvoke)
		{
			let result = form.BeginInvoke(new [&] () => order.Append('B')); defer delete result;
			Test.Assert(form.EndInvoke(result) case .Ok);
		}
		else Test.Assert(form.Invoke(scope [&] () => order.Append('B')) case .Ok);
		Test.Assert(order == "ABC");
		form.Close();
	}
	[Test] public static void SDLUIInvokeDrainsCallbacksQueuedAfterItsOwnCallLikeDotNet() => VerifyUIDrain(.SDL2OpenGL, false);
	[Test] public static void SDLUIEndInvokeDrainsCallbacksQueuedAfterItsResultLikeDotNet() => VerifyUIDrain(.SDL2OpenGL, true);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeUIInvokeDrainsCallbacksQueuedAfterItsOwnCallLikeDotNet() => VerifyUIDrain(.Win32, false);
	[Test] public static void NativeUIEndInvokeDrainsCallbacksQueuedAfterItsResultLikeDotNet() => VerifyUIDrain(.Win32, true);
#endif

	private static void VerifyOnlyDispatchControlDrains(ApplicationBackend backend, bool endInvoke)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140);
		let first = new Control(); first.Size = .(20, 20); form.Controls.Add(first);
		let second = new Control(); second.Size = .(20, 20); form.Controls.Add(second); form.Show();
		let order = scope String();
		let other = second.BeginInvoke(new [&] () => order.Append('B')); defer delete other;
		first.BeginInvoke(new [&] () => order.Append('A'));
		if (endInvoke)
		{
			let result = first.BeginInvoke(new [&] () => order.Append('C')); defer delete result;
			Test.Assert(first.EndInvoke(result) case .Ok);
		}
		else Test.Assert(first.Invoke(scope [&] () => order.Append('C')) case .Ok);
		Test.Assert(order == "AC" && !other.IsCompleted);
		Application.DoEvents();
		Test.Assert(order == "ACB" && other.IsCompleted);
		form.Close();
	}
	[Test] public static void SDLUIInvokeOnlyDrainsItsDispatchControlLikeDotNet() => VerifyOnlyDispatchControlDrains(.SDL2OpenGL, false);
	[Test] public static void SDLUIEndInvokeOnlyDrainsItsDispatchControlLikeDotNet() => VerifyOnlyDispatchControlDrains(.SDL2OpenGL, true);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeUIInvokeOnlyDrainsItsDispatchControlLikeDotNet() => VerifyOnlyDispatchControlDrains(.Win32, false);
	[Test] public static void NativeUIEndInvokeOnlyDrainsItsDispatchControlLikeDotNet() => VerifyOnlyDispatchControlDrains(.Win32, true);
#endif

	private static void VerifyPerControlOrder(ApplicationBackend backend, bool shareAncestor)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140);
		let first = new Control(); first.Size = .(20, 20); first.Visible = !shareAncestor; form.Controls.Add(first);
		let second = new Control(); second.Size = .(20, 20); second.Visible = !shareAncestor; form.Controls.Add(second); form.Show();
		let order = scope String();
		first.BeginInvoke(new [&] () => order.Append('A'));
		second.BeginInvoke(new [&] () => order.Append('B'));
		first.BeginInvoke(new [&] () => order.Append('C'));
		Application.DoEvents();
		Test.Assert(order == (shareAncestor ? "ABC" : "ACB"));
		form.Close();
	}
	[Test] public static void SDLControlsWithHandlesDrainSeparateQueuesLikeDotNet() => VerifyPerControlOrder(.SDL2OpenGL, false);
	[Test] public static void SDLUncreatedControlsShareTheirAncestorsQueueLikeDotNet() => VerifyPerControlOrder(.SDL2OpenGL, true);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeControlsWithHandlesDrainSeparateQueuesLikeDotNet() => VerifyPerControlOrder(.Win32, false);
	[Test] public static void NativeUncreatedControlsShareTheirAncestorsQueueLikeDotNet() => VerifyPerControlOrder(.Win32, true);
#endif

	private static void VerifyCompletedEndInvoke(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140); form.Show();
		let order = scope String();
		let first = form.BeginInvoke(new [&] () => order.Append('A')); defer delete first;
		Test.Assert(form.EndInvoke(first) case .Ok);
		let second = form.BeginInvoke(new [&] () => order.Append('B')); defer delete second;
		Test.Assert(form.EndInvoke(first) case .Ok);
		Test.Assert(order == "A" && !second.IsCompleted);
		Application.DoEvents();
		Test.Assert(order == "AB");
		form.Close();
	}
	[Test] public static void SDLCompletedEndInvokeDoesNotDrainNewWorkLikeDotNet() => VerifyCompletedEndInvoke(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeCompletedEndInvokeDoesNotDrainNewWorkLikeDotNet() => VerifyCompletedEndInvoke(.Win32);
#endif

	[Test]
	public static void MissingHandlesDoNotInitializeTheDispatcherOnTheWorker()
	{
		let control = scope Control();
		bool ran = false;
		let worker = scope Thread(new [&] () =>
		{
			Test.Assert(!control.InvokeRequired);
			Test.Assert(control.Invoke(scope [&] () => ran = true) case .Err);
			let pending = control.BeginInvoke(new [&] () => ran = true); defer delete pending;
			Test.Assert(pending.IsCompleted && control.EndInvoke(pending) case .Err);
		});
		worker.Start(false); worker.Join();
		Test.Assert(!ran && !control.IsHandleCreated);
	}

	private static void VerifyAncestor(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140);
		let child = new Control(); child.Visible = false; form.Controls.Add(child); form.Show();
		bool ran = false;
		let pending = child.BeginInvoke(new [&] () => ran = true); defer delete pending;
		Test.Assert(!child.IsHandleCreated && !pending.IsCompleted);
		child.Dispose(); delete child;
		Application.DoEvents();
		Test.Assert(ran && form.EndInvoke(pending) case .Ok);
		form.Close();
	}
	[Test] public static void SDLUncreatedChildrenUseTheirExistingAncestorsHandle() => VerifyAncestor(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeUncreatedChildrenUseTheirExistingAncestorsHandle() => VerifyAncestor(.Win32);
#endif

	private static void VerifyDestruction(ApplicationBackend backend, bool dispose)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140);
		let child = new Control(); child.Size = .(100, 40); form.Controls.Add(child); form.Show();
		bool ran = false, survived = false;
		let pending = child.BeginInvoke(new [&] () => ran = true); defer delete pending;
		child.BeginInvoke(new [&] () => ran = true);
		let other = form.BeginInvoke(new [&] () => survived = true); defer delete other;
		if (dispose) { child.Dispose(); delete child; }
		else child.[Friend]DestroyHandle();
		Test.Assert(pending.IsCompleted && form.EndInvoke(pending) case .Err);
		Application.DoEvents(); Test.Assert(!ran && survived && other.IsCompleted);
		form.Close();
	}
	[Test] public static void SDLDestroyingOrDisposingATargetCancelsItsPendingCalls()
	{
		VerifyDestruction(.SDL2OpenGL, false); VerifyDestruction(.SDL2OpenGL, true);
	}
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeDestroyingOrDisposingATargetCancelsItsPendingCalls()
	{
		VerifyDestruction(.Win32, false); VerifyDestruction(.Win32, true);
	}
#endif

	private static void VerifyRecreation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140);
		let editor = new TextBox(); editor.Size = .(180, 60); form.Controls.Add(editor); form.Show();
		int calls = 0;
		let pending = editor.BeginInvoke(new [&] () => calls++); defer delete pending;
		editor.Multiline = true;
		Application.DoEvents();
		Test.Assert(calls == 1 && editor.EndInvoke(pending) case .Ok);
		form.Close();
	}
	[Test] public static void SDLModeChangesKeepPendingCalls() => VerifyRecreation(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeModeChangesKeepPendingCallsAcrossHandleRecreation() => VerifyRecreation(.Win32);
#endif

	private static void VerifyRun(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = new Form(); form.ClientSize = .(240, 140);
		bool invoked = false;
		let worker = scope Thread(new [&] () =>
		{
			Thread.Sleep(50);
			invoked = form.Invoke(scope [&] () => form.Close()) case .Ok;
		});
		form.Load.Add(new [&] (sender, args) => worker.Start(false));
		let completed = RunWithTimeout(form);
		Test.Assert(worker.Join(3000));
		Test.Assert(completed && invoked && Application.CreatedControlCount == 0);
	}
	[Test] public static void SDLBlockedRunWakesForAnInvocation() => VerifyRun(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeBlockedRunWakesForAnInvocation() => VerifyRun(.Win32);
#endif

	private static void VerifyShutdown(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let dispatcher = Application.Dispatcher;
		let form = new Form(); form.ClientSize = .(240, 140);
		bool ran = false, canceled = false;
		let worker = scope Thread(new [&] () =>
		{
			let result = dispatcher.Invoke(scope [&] () => ran = true);
			canceled = result case .Err;
		});
		form.Load.Add(new [&] (sender, args) =>
		{
			worker.Start(false);
			let deadline = TimerScheduler.Now + 3000;
			while (!dispatcher.HasPending && TimerScheduler.Now < deadline) Thread.Sleep(1);
			form.Close();
		});
		Application.Run(form); Test.Assert(worker.Join(3000));
		Test.Assert(canceled && !ran && !dispatcher.HasPending);
		Test.Assert(dispatcher.Post(new [&] () => ran = true) case .Err);
		let restarted = Application.Dispatcher;
		restarted.Post(new [&] () => ran = true); Application.DoEvents(); Test.Assert(ran);
	}
	[Test] public static void SDLShutdownReleasesWaitingWorkersAndTheQueueCanRestart() => VerifyShutdown(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeShutdownReleasesWaitingWorkersAndTheQueueCanRestart() => VerifyShutdown(.Win32);
#endif

	private static void VerifyWaitingCancellation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140); form.Show();
		bool canceled = false;
		let worker = scope Thread(new [&] () =>
		{
			let result = form.Invoke(scope () => Test.FatalError("A canceled invocation ran"));
			canceled = result case .Err;
		});
		worker.Start(false);
		let deadline = TimerScheduler.Now + 3000;
		while (!Application.DispatcherCore.HasPending && TimerScheduler.Now < deadline) Thread.Sleep(1);
		let queued = Application.DispatcherCore.HasPending;
		if (queued) form.Close();
		else Application.DispatcherCore.Shutdown();
		Test.Assert(worker.Join(3000));
		Test.Assert(queued && canceled);
	}
	[Test] public static void SDLClosingTheTargetReleasesASynchronousCaller() => VerifyWaitingCancellation(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeClosingTheTargetReleasesASynchronousCaller() => VerifyWaitingCancellation(.Win32);
#endif

	private static void VerifyTeardownPosts(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = new Form(); form.ClientSize = .(240, 140);
		bool ran = false, posted = false;
		form.Disposed.Add(new [&] (sender, args) =>
		{
			posted = Application.Dispatcher.Post(new [&] () => ran = true) case .Ok;
		});
		form.Load.Add(new (sender, args) => ((Form)sender).Close());
		Application.Run(form);
		Application.DoEvents();
		Test.Assert(posted && !ran);
	}
	[Test] public static void SDLShutdownCancelsWorkPostedByDisposalHandlers() => VerifyTeardownPosts(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeShutdownCancelsWorkPostedByDisposalHandlers() => VerifyTeardownPosts(.Win32);
#endif

	private static void VerifyConcurrentPosts(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let dispatcher = Application.Dispatcher;
		let uiThread = Thread.CurrentThreadId;
		int calls = 0;
		let workers = scope Thread[3]();
		for (int i < workers.Count)
		{
			workers[i] = new Thread(new [&] () =>
			{
				for (int j < 50)
					dispatcher.Post(new [&] () =>
					{
						Test.Assert(Thread.CurrentThreadId == uiThread);
						calls++;
					});
			});
			workers[i].Start(false);
		}
		for (let worker in workers) { worker.Join(); delete worker; }
		Application.DoEvents();
		Test.Assert(calls == 150);
	}
	[Test] public static void SDLMultipleWorkersShareTheDispatchQueue() => VerifyConcurrentPosts(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeMultipleWorkersShareTheDispatchQueue() => VerifyConcurrentPosts(.Win32);
#endif

	private static void VerifyConcurrentInvocations(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140);
		let child = new Control(); child.Size = .(20, 20); form.Controls.Add(child); form.Show();
		let work = scope ConcurrentInvocations() { Target = child };
		let workers = scope Thread[4]();
		for (int i < workers.Count)
		{
			workers[i] = new Thread(new => work.Run);
			workers[i].Start(false);
		}
		let completed = PumpUntil(work.Done);
		if (!completed) Application.DispatcherCore.Shutdown();
		for (let worker in workers) { Test.Assert(worker.Join(3000)); delete worker; }
		Test.Assert(completed && work.Calls == 800);
		form.Close();
	}
	[Test] public static void SDLConcurrentInvocationsPublishResultsAndSignalWaitHandles() => VerifyConcurrentInvocations(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeConcurrentInvocationsPublishResultsAndSignalWaitHandles() => VerifyConcurrentInvocations(.Win32);
#endif

#if BF_PLATFORM_WINDOWS
	private static void VerifyNestedDispatchControlOrder(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 140);
		let first = new Control(); first.Size = .(20, 20); form.Controls.Add(first);
		let second = new Control(); second.Size = .(20, 20); form.Controls.Add(second); form.Show();
		let order = scope String();
		let deadline = TimerScheduler.Now + 3000;
		bool timedOut = false;
		let watchdog = scope Timer(); watchdog.Interval = 20;
		watchdog.Tick.Add(new [&] (sender, args) =>
		{
			if (TimerScheduler.Now < deadline) return;
			timedOut = true; watchdog.Stop();
			Win32.PostMessage(Win32.GetActiveWindow(), Win32.WM_CLOSE, null, null);
		});
		first.BeginInvoke(new [&] () =>
		{
			order.Append('A');
			MessageBox.Show("The second control closes this dialog", "Nested dispatch control order");
			order.Append('D');
		});
		first.BeginInvoke(new [&] () => order.Append('C'));
		second.BeginInvoke(new [&] () =>
		{
			order.Append('B');
			let dialog = Win32.GetActiveWindow();
			char16[64] title = ?; let length = Win32.GetWindowText(dialog, &title, title.Count);
			if (scope String(Span<char16>(&title, length)) == "Nested dispatch control order")
				Win32.PostMessage(dialog, Win32.WM_CLOSE, null, null);
		});
		watchdog.Start();
		Application.DoEvents();
		watchdog.Stop();
		Test.Assert(!timedOut && order == "ACBD");
		form.Close();
	}
	[Test] public static void NativeNestedModalLoopsPreserveDispatchControlOrderingLikeDotNet() => VerifyNestedDispatchControlOrder(.Win32);
	[Test] public static void SDLNestedModalLoopsPreserveDispatchControlOrderingLikeDotNetOnWindows() => VerifyNestedDispatchControlOrder(.SDL2OpenGL);

	private static void VerifyModal(ApplicationBackend backend, bool fromDispatch = false)
	{
		Application.UseBackend(backend);
		let dispatcher = Application.Dispatcher;
		let deadline = TimerScheduler.Now + 3000;
		bool dispatched = false, timedOut = false;
		let watchdog = scope Timer(); watchdog.Interval = 20;
		watchdog.Tick.Add(new [&] (sender, args) =>
		{
			if (TimerScheduler.Now < deadline) return;
			timedOut = true; watchdog.Stop(); dispatcher.Shutdown();
			Win32.PostMessage(Win32.GetActiveWindow(), Win32.WM_CLOSE, null, null);
		});
		let worker = scope Thread(new [&] () =>
		{
			while (TimerScheduler.Now < deadline)
			{
				let result = dispatcher.Invoke<bool>(scope () =>
				{
					let dialog = Win32.GetActiveWindow();
					char16[64] title = ?; let length = Win32.GetWindowText(dialog, &title, title.Count);
					if (scope String(Span<char16>(&title, length)) != "Dispatch modal test") return false;
					Win32.PostMessage(dialog, Win32.WM_CLOSE, null, null);
					return true;
				});
				if (result case .Err) break;
				if (result case .Ok(true)) { dispatched = true; break; }
				Thread.Sleep(10);
			}
		});
		DialogResult result = default;
		if (fromDispatch)
			dispatcher.Post(new [&] () => result = MessageBox.Show("The worker closes this dialog", "Dispatch modal test"));
		watchdog.Start(); worker.Start(false);
		if (fromDispatch) Application.DoEvents();
		else result = MessageBox.Show("The worker closes this dialog", "Dispatch modal test");
		watchdog.Stop(); Test.Assert(worker.Join(3000));
		Test.Assert(result == .OK && dispatched && !timedOut);
	}
	[Test] public static void NativeMessageBoxesContinueDispatching() => VerifyModal(.Win32);
	[Test] public static void SDLMessageBoxesContinueDispatchingOnWindows() => VerifyModal(.SDL2OpenGL);
	[Test] public static void NativeCallbacksCanDispatchWhileInsideAMessageBox() => VerifyModal(.Win32, true);
	[Test] public static void SDLCallbacksCanDispatchWhileInsideAMessageBoxOnWindows() => VerifyModal(.SDL2OpenGL, true);
#endif
}
