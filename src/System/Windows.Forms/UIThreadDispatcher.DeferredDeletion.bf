using internal System.Windows.Forms;

namespace System.Windows.Forms;

extension UIThreadDispatcher
{
	internal void BeginEventLoop()
	{
		using (SyncRoot.Enter())
		{
			mEventLoopState = .Running;
		}
	}

	internal void EndEventLoop()
	{
		using (SyncRoot.Enter())
			mEventLoopState = .Stopping;
		ProcessDeferredDeletes();
		using (SyncRoot.Enter())
			mEventLoopState = .Stopped;
	}

	internal bool QueueDeleteLocked(Control control)
	{
		if (mEventLoopState == .Stopping || mEventLoopState == .Stopped)
			return false;
		control.mDeferredDeleteNode = mDeferredDeletes.AddLast(control);
		if (mState == .Accepting)
			Wake(0);
		return true;
	}

	internal void ForgetDeleteLocked(Control control)
	{
		if (control.mDeferredDeleteNode == null)
			return;
		mDeferredDeletes.Remove(control.mDeferredDeleteNode);
		control.mDeferredDeleteNode = null;
	}

	// Only host-loop boundaries call this. Nested DoEvents/modal pumps leave the queue alone.
	internal void ProcessDeferredDeletes()
	{
		using (SyncRoot.Enter())
		{
			if (mEventLoopState == .NotStarted || mEventLoopState == .Stopped || mDeletingControls)
				return;
			mDeletingControls = true;
		}
		defer
		{
			using (SyncRoot.Enter())
				mDeletingControls = false;
		}
		while (true)
		{
			Control control;
			using (SyncRoot.Enter())
			{
				if (mDeferredDeletes.Count == 0)
					break;
				control = mDeferredDeletes.First.Value;
				ForgetDeleteLocked(control);
			}
			// The host retains this pointer until Run returns; Application owns its final deletion.
			if (Application.OwnsMainForm(control))
			{
				if (!control.IsDisposed)
					control.Dispose();
			}
			else
				delete control;
		}
	}
}
