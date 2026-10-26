using internal System.Windows.Forms;

namespace System.Windows.Forms;

extension Control
{
	private uint64 mInvocationTarget;
	private bool mRecreatingHandle;
	private bool IsRecreatingHandle => mRecreatingHandle || Parent?.IsRecreatingHandle == true;

	private void SetParent(Control parent)
	{
		using (Application.DispatcherCore.SyncRoot.Enter())
			mParent = parent;
	}

	private Control FindDispatchControl()
	{
		for (var control = this; control != null; control = control.Parent)
		{
			if (control.IsHandleCreated)
				return control;
		}
		return null;
	}

	/// False also means that neither this control nor an ancestor has a handle yet.
	public bool InvokeRequired
	{
		get
		{
			let dispatcher = Application.DispatcherCore;
			using (dispatcher.SyncRoot.Enter())
				return FindDispatchControl() != null && !dispatcher.CheckAccess;
		}
	}

	private InvocationState EnqueueInvocation(delegate void() callback, bool ownsCallback)
	{
		let dispatcher = Application.DispatcherCore;
		let state = new InvocationState(callback, ownsCallback);
		using (dispatcher.SyncRoot.Enter())
		{
			let dispatchControl = FindDispatchControl();
			if (dispatchControl == null || dispatchControl.IsDisposingOrDisposed)
				dispatcher.EnqueueLocked(state, error: true);
			else
			{
				if (dispatchControl.mInvocationTarget == 0)
					dispatchControl.mInvocationTarget = dispatcher.RegisterTargetLocked();
				dispatcher.EnqueueLocked(state, dispatchControl.mInvocationTarget);
			}
		}
		return state;
	}

	/// Borrows the delegate until completion. Returns Err if the target or dispatcher disappears.
	public Result<void> Invoke(delegate void() callback)
	{
		let state = EnqueueInvocation(callback, false);
		defer state.ReleaseRef();
		return Application.DispatcherCore.Wait(state);
	}

	public Result<T> Invoke<T>(delegate T() callback)
	{
		T value = default;
		delegate void() invoke = scope [&] () => value = callback();
		let result = Invoke(invoke);
		if (result case .Err(let error))
			return .Err(error);
		return .Ok(value);
	}

	/// Takes ownership of the heap delegate. The caller owns the result if retained.
	public InvokeAsyncResult BeginInvoke(delegate void() callback)
		=> new .(EnqueueInvocation(callback, true));
	public Result<void> EndInvoke(IAsyncResult result)
		=> Application.DispatcherCore.Wait(((InvokeAsyncResult)result).State);

	private void CancelInvocationsLocked()
	{
		if (mInvocationTarget == 0)
			return;
		Application.DispatcherCore.CancelPendingLocked(mInvocationTarget);
		mInvocationTarget = 0;
	}
}
