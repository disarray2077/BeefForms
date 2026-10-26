using System;
using System.Collections;
using System.Diagnostics;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal static class TimerScheduler
{
	private static Dictionary<uint, Timer> sTimers = new .() ~ delete _;
	private static uint sNextRegistration;
	internal static int64 Now => Stopwatch.GetTimestamp() / 1000;
	internal static bool IsEmpty => sTimers.Count == 0;

	internal static uint Start(Timer timer)
	{
		let registration = ++sNextRegistration;
		sTimers.Add(registration, timer);
#if BF_PLATFORM_WINDOWS
		Win32Timer.Start(registration, timer.Interval);
#endif
		return registration;
	}

	internal static void Stop(uint registration)
	{
		if (!sTimers.Remove(registration))
			return;
#if BF_PLATFORM_WINDOWS
		Win32Timer.Stop(registration);
#endif
	}

	internal static void Dispatch(uint registration)
	{
		if (sTimers.TryGetValue(registration, let timer))
			timer.NotifyTick();
	}

	internal static int32 GetNextTimeout()
	{
		int32 timeout = -1;
#if !BF_PLATFORM_WINDOWS
		let now = Now;
		for (let entry in sTimers)
		{
			let remaining = (int32)Math.Clamp(entry.value.NextTick - now, 0, int32.MaxValue);
			if (timeout < 0 || remaining < timeout)
				timeout = remaining;
		}
#endif
		return timeout;
	}

	internal static void Process()
	{
#if BF_PLATFORM_WINDOWS
		Win32Timer.Process();
#else
		ProcessDue();
#endif
	}

	private static void ProcessDue()
	{
		let pending = ToScopedArray!(sTimers);
		let now = Now;
		for (let entry in pending)
		{
			if (sTimers.TryGetValue(entry.key, let timer) && timer.NextTick <= now)
				timer.NotifyTick();
		}
	}
}
