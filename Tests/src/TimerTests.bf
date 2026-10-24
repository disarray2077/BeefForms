using System;
using System.ComponentModel;
using System.Threading;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class TimerTests
{
	private class TestContainer : IContainer
	{
		public IComponent Added;
		public ComponentCollection Components => null;
		public void Add(IComponent component) => Added = component;
		public void Add(IComponent component, StringView name) => Add(component);
		public void Remove(IComponent component) { if (Added == component) Added = null; }
		public void Dispose() { Added?.Dispose(); Added = null; }
	}

	private static void PumpUntil<F>(F done) where F : delegate bool()
	{
		let deadline = TimerScheduler.Now + 2000;
		while (!done() && TimerScheduler.Now < deadline)
		{
			Application.DoEvents();
			Thread.Sleep(1);
		}
		Test.Assert(done());
	}

	[Test]
	public static void DefaultsAndContainerConstructorMatchWinForms()
	{
		let timer = scope Timer();
		Test.Assert(!timer.Enabled && timer.Interval == 100 && timer.Tag == null);
		let tag = scope String("Timer tag"); timer.Tag = tag;
		Test.Assert(timer.Tag == tag);
		let container = scope TestContainer();
		let contained = scope Timer(container);
		Test.Assert(container.Added == contained && !contained.Enabled);
	}

	private static void VerifyDelivery(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let timer = scope Timer(); timer.Interval = 10;
		let thread = Thread.CurrentThreadId;
		int ticks = 0;
		timer.Tick.Add(new [&] (sender, args) =>
		{
			Test.Assert(sender == timer && args != null && Thread.CurrentThreadId == thread);
			if (++ticks == 1) timer.Interval = 20;
			if (ticks == 3) timer.Stop();
		});
		timer.Start();
		Thread.Sleep(40);
		Test.Assert(ticks == 0);
		PumpUntil(scope [&] () => ticks == 3);
		Test.Assert(!timer.Enabled && TimerScheduler.IsEmpty && Application.CreatedControlCount == 0);
		Thread.Sleep(30); Application.DoEvents(); Test.Assert(ticks == 3);
	}

	[Test] public static void SDLTimersTickOnThePumpingThreadWithoutAForm() => VerifyDelivery(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void Win32TimersTickOnThePumpingThreadWithoutAForm() => VerifyDelivery(.Win32);
#endif

	[Test]
	public static void StartingAgainAndAssigningTheSameIntervalDoNotRestart()
	{
		let timer = scope Timer(); timer.Interval = 1000; timer.Start();
		let registration = timer.[Friend]mRegistration;
		let due = timer.NextTick;
		timer.Start(); timer.Enabled = true; timer.Interval = 1000;
		Test.Assert(timer.[Friend]mRegistration == registration && timer.NextTick == due);
		timer.Stop(); timer.Start();
		Test.Assert(timer.[Friend]mRegistration != registration);
	}

	[Test]
	public static void DisposeStopsTicksAndAllowsAnExplicitRestart()
	{
		let timer = scope Timer(); timer.Interval = 10;
		int ticks = 0, disposed = 0;
		timer.Tick.Add(new [&] (sender, args) => { ticks++; timer.Stop(); });
		timer.Disposed.Add(new [&] (sender, args) => { disposed++; Test.Assert(!timer.Enabled); });
		timer.Start(); timer.Dispose();
		Test.Assert(disposed == 1 && TimerScheduler.IsEmpty);
		Thread.Sleep(30); Application.DoEvents(); Test.Assert(ticks == 0);
		timer.Start(); PumpUntil(scope [&] () => ticks == 1);
		timer.Dispose(); Test.Assert(disposed == 2 && TimerScheduler.IsEmpty);
	}

	[Test]
	public static void DeletingAnEnabledTimerRemovesItsRegistration()
	{
		int ticks = 0;
		let timer = new Timer(); timer.Interval = 1000;
		timer.Tick.Add(new [&] (sender, args) => ticks++);
		timer.Start(); let registration = timer.[Friend]mRegistration;
		delete timer;
		TimerScheduler.Dispatch(registration);
		Test.Assert(ticks == 0 && TimerScheduler.IsEmpty);
	}

	[Test]
	public static void ATickCanDisposeItsOwnTimer()
	{
		let timer = scope Timer(); timer.Interval = 10;
		int ticks = 0;
		timer.Tick.Add(new [&] (sender, args) =>
		{
			ticks++;
			timer.Dispose();
		});
		timer.Start(); PumpUntil(scope [&] () => ticks == 1);
		Test.Assert(!timer.Enabled && TimerScheduler.IsEmpty);
	}

	[Test]
	public static void ATickCanDeleteItsOwnTimer()
	{
		Timer timer = new .(); timer.Interval = 10;
		defer { delete timer; }
		int ticks = 0;
		timer.Tick.Add(new [&] (sender, args) =>
		{
			ticks++;
			let deleting = timer;
			timer = null;
			delete deleting;
		});
		timer.Start(); PumpUntil(scope [&] () => ticks == 1);
		Test.Assert(timer == null && TimerScheduler.IsEmpty);
	}

	[Test]
	public static void DeletionCannotResurrectATimerThroughDisposed()
	{
		let timer = new Timer();
		timer.Disposed.Add(new (sender, args) => timer.Start());
		timer.Start(); delete timer;
		Test.Assert(TimerScheduler.IsEmpty);
	}

	[Test]
	public static void DeadlineDispatchToleratesDeletingAnotherPendingTimer()
	{
		Timer first = new .(); Timer second = new .();
		defer { delete first; delete second; }
		first.Interval = second.Interval = 10;
		int ticks = 0;
		first.Tick.Add(new [&] (sender, args) => { ticks++; delete second; second = null; first.Stop(); });
		second.Tick.Add(new [&] (sender, args) => { ticks++; delete first; first = null; second.Stop(); });
		first.Start(); second.Start(); Thread.Sleep(30);
		TimerScheduler.[Friend]ProcessDue();
		Test.Assert(ticks == 1 && TimerScheduler.IsEmpty);
	}

	[Test]
	public static void MissedDeadlinesProduceOneTickRatherThanABurst()
	{
		let timer = scope Timer(); timer.Interval = 20;
		int ticks = 0; timer.Tick.Add(new [&] (sender, args) => ticks++);
		timer.Start(); Thread.Sleep(90);
		TimerScheduler.[Friend]ProcessDue();
		Test.Assert(ticks == 1 && timer.NextTick > TimerScheduler.Now);
	}

	private static void VerifyRun(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = new Form(); form.ClientSize = .(200, 100);
		let timer = scope Timer(); timer.Interval = 30;
		int ticks = 0;
		timer.Tick.Add(new [&] (sender, args) => { ticks++; timer.Stop(); form.Close(); });
		form.Load.Add(new (sender, args) => timer.Start());
		Application.Run(form);
		Test.Assert(ticks == 1 && !timer.Enabled && TimerScheduler.IsEmpty && Application.CreatedControlCount == 0);
	}

	[Test] public static void SDLRunWakesForATimerAndExitsWhenItsHandlerClosesTheForm() => VerifyRun(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void Win32RunWakesForATimerAndExitsWhenItsHandlerClosesTheForm() => VerifyRun(.Win32);

	[Test]
	public static void OldQueuedMessagesDoNotReachARestartedTimer()
	{
		let timer = scope Timer(); timer.Interval = 5000;
		int ticks = 0; timer.Tick.Add(new [&] (sender, args) => ticks++);
		timer.Start(); let previous = timer.[Friend]mRegistration;
		timer.Interval = 4000;
		Test.Assert(timer.[Friend]mRegistration != previous);
		Win32.PostMessage(Win32Timer.[Friend]sWindow, Win32.WM_TIMER, (uint*)(void*)previous, null);
		Application.DoEvents(); Test.Assert(ticks == 0);
	}

	private static void VerifyModalDelivery(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let timer = scope Timer(); timer.Interval = 10;
		int ticks = 0;
		timer.Tick.Add(new [&] (sender, args) =>
		{
			if (++ticks > 100) Runtime.FatalError("The timer did not find its modal message box");
			let dialog = Win32.GetActiveWindow();
			char16[64] title = ?; let length = Win32.GetWindowText(dialog, &title, title.Count);
			if (scope String(Span<char16>(&title, length)) != "Timer modal test") return;
			timer.Stop(); Win32.PostMessage(dialog, Win32.WM_CLOSE, null, null);
		});
		timer.Start();
		Test.Assert(MessageBox.Show("The UI timer closes this dialog", "Timer modal test") == .OK);
		Test.Assert(ticks > 0 && !timer.Enabled && TimerScheduler.IsEmpty);
	}

	[Test] public static void Win32TimersContinueDuringNativeMessageBoxes() => VerifyModalDelivery(.Win32);
	[Test] public static void SDLTimersContinueDuringNativeMessageBoxesOnWindows() => VerifyModalDelivery(.SDL2OpenGL);
#endif

	[Test(ShouldFail = true)]
	public static void ZeroIntervalsAreRejected() { let timer = scope Timer(); timer.Interval = 0; }
	[Test(ShouldFail = true)]
	public static void NegativeIntervalsAreRejected() { let timer = scope Timer(); timer.Interval = -1; }
}
