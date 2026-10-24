using System.ComponentModel;
using BeefForms.Backends;

using internal BeefForms.Backends;

namespace System.Windows.Forms;

/// Raises Tick on the UI thread while its event loop processes messages.
public class Timer : Component
{
	private int32 mInterval = 100;
	private uint mRegistration;
	private int64 mNextTick;
	private bool mDeleting;

	public this() {}
	public this(IContainer container)
	{
		container?.Add(this);
	}

	public Object Tag { get; set; }
	public ref Event<EventHandler> Tick { get; set; } ~ _.Dispose();
	protected virtual void OnTick(EventArgs args) => Tick.Invoke(this, args);

	public virtual bool Enabled
	{
		get => mRegistration != 0;
		set
		{
			if (value == Enabled || (value && mDeleting)) return;
			if (value)
			{
				ResetDeadline();
				mRegistration = TimerScheduler.Start(this);
			}
			else StopTimer();
		}
	}

	public int32 Interval
	{
		get => mInterval;
		set
		{
			if (value < 1) Runtime.FatalError("Timer.Interval must be greater than zero");
			if (mInterval == value) return;
			mInterval = value;
			if (Enabled)
			{
				let previous = mRegistration;
				ResetDeadline();
				mRegistration = TimerScheduler.Start(this);
				TimerScheduler.Stop(previous);
			}
		}
	}

	public void Start() => Enabled = true;
	public void Stop() => Enabled = false;

	internal int64 NextTick => mNextTick;
	private void ResetDeadline() => mNextTick = TimerScheduler.Now + mInterval;
	internal void NotifyTick()
	{
		ResetDeadline();
		OnTick(.Empty);
	}

	private void StopTimer()
	{
		let registration = mRegistration;
		mRegistration = 0;
		if (registration != 0) TimerScheduler.Stop(registration);
	}

	protected override void Dispose(bool disposing)
	{
		if (disposing)
		{
			StopTimer();
			Enabled = false;
		}
		base.Dispose(disposing);
	}

	public ~this()
	{
		// Disposed handlers cannot extend the lifetime of a deleted Beef allocation.
		mDeleting = true;
		StopTimer();
	}
}
