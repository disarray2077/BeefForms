using System.Collections;
using System.Threading;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

/// Obtain Application.Dispatcher on the UI thread before sharing it with workers.
public sealed class UIThreadDispatcher
{
	// Control validation, queue publication, and native wake ordering share this lock.
	internal append Monitor SyncRoot = .();
	private append InvocationQueue mPending = .();
	private int mThreadId;
	private bool mAccepting;
	private uint64 mNextTarget;
	private int mExecuting;

	internal this() {}
	public ~this() { Shutdown(); }

	public bool CheckAccess => Interlocked.Load(ref mThreadId, .Acquire) == Thread.CurrentThreadId;
	internal bool HasPending { get { using (SyncRoot.Enter()) return mPending.Count != 0; } }
	internal bool IsDispatching => Interlocked.Load(ref mExecuting, .Acquire) != 0;

	internal void Initialize()
	{
		if (Interlocked.Load(ref mAccepting, .Acquire))
			return;
		using (SyncRoot.Enter())
		{
			let threadId = Interlocked.Load(ref mThreadId, .Relaxed);
			if (threadId != 0 && threadId != Thread.CurrentThreadId)
				return;
			if (Interlocked.Load(ref mAccepting, .Relaxed))
				return;
			Interlocked.Store(ref mThreadId, Thread.CurrentThreadId, .Release);
			Application.Backend.InitializeDispatcher();
#if BF_PLATFORM_WINDOWS
			Win32Dispatcher.Initialize();
#endif
			Interlocked.Store(ref mAccepting, true, .Release);
		}
	}

	internal uint64 RegisterTargetLocked() => ++mNextTarget;
	internal void VerifyAccess()
	{
		Initialize();
		if (!CheckAccess) Runtime.FatalError("This operation must run on the UI thread");
	}

	private InvocationState Enqueue(delegate void() callback, bool ownsCallback)
	{
		let state = new InvocationState(callback, ownsCallback);
		using (SyncRoot.Enter())
			EnqueueLocked(state);
		return state;
	}

	internal void EnqueueLocked(InvocationState state, uint64 target = 0, bool error = false)
	{
		state.Target = target;
		if (error || !Interlocked.Load(ref mAccepting, .Relaxed))
			state.Complete(.Err);
		else
		{
			mPending.Add(state);
			if (state.OwnsCallback || !CheckAccess)
				Wake(target);
		}
	}

	/// Takes ownership of the heap delegate, including when dispatch is rejected.
	public Result<void> Post(delegate void() callback)
	{
		let state = Enqueue(callback, true);
		defer state.ReleaseRef();
		return state.Completion ?? .Ok;
	}

	/// The delegate is borrowed until this call returns; scope delegates are supported.
	public Result<void> Invoke(delegate void() callback)
	{
		let state = Enqueue(callback, false);
		defer state.ReleaseRef();
		return Wait(state);
	}

	public Result<T> Invoke<T>(delegate T() callback)
	{
		T value = default;
		delegate void() invoke = scope [&] () => value = callback();
		let result = Invoke(invoke);
		if (result case .Err(let error)) return .Err(error);
		return .Ok(value);
	}

	internal Result<void> Wait(InvocationState state)
	{
		if (CheckAccess && !state.Completion.HasValue) ProcessTarget(state.Target);
		return state.Wait();
	}

	private void Wake(uint64 target)
	{
#if BF_PLATFORM_WINDOWS
		Win32Dispatcher.Wake(target);
#endif
		Application.Backend.WakeEventLoop();
	}

	internal void ProcessPending()
	{
		if (!CheckAccess) return;
		while (true)
		{
			uint64 target;
			using (SyncRoot.Enter())
			{
				if (mPending.Count == 0) break;
				target = mPending.FirstTarget;
			}
			ProcessTarget(target);
		}
	}

	internal void ProcessTarget(uint64 target)
	{
		if (!CheckAccess) return;
		// WinForms drains the dispatch control's whole queue even after a waiting invocation completes.
		while (true)
		{
			InvocationState state;
			using (SyncRoot.Enter())
			{
				state = mPending.PopTarget(target);
				if (state == null) break;
				Interlocked.Increment(ref mExecuting);
			}
			defer
			{
				Interlocked.Decrement(ref mExecuting);
				state.ReleaseRef();
			}
			state.Execute();
		}
	}

	internal void CancelPendingLocked(uint64 target)
	{
		while (true)
		{
			let state = target == 0 ? mPending.PopFront() : mPending.PopTarget(target);
			if (state == null) break;
			state.Complete(.Err);
			state.ReleaseRef();
		}
	}

	internal void Shutdown()
	{
		using (SyncRoot.Enter())
		{
			Interlocked.Store(ref mAccepting, false, .Release);
			CancelPendingLocked(0);
#if BF_PLATFORM_WINDOWS
			Win32Dispatcher.Shutdown();
#endif
		}
	}
}

// Removing an entry transfers the queue's reference to the caller.
internal class InvocationQueue
{
	private struct TargetQueue
	{
		public InvocationState First, Last;
	}
	private append Dictionary<uint64, TargetQueue> mTargets = .();
	private InvocationState mFirst, mLast;

	public int Count { get; private set; }
	public uint64 FirstTarget => mFirst.Target;

	public void Add(InvocationState state)
	{
		state.AddRef();
		state.Previous = mLast;
		if (mLast != null) mLast.Next = state;
		else mFirst = state;
		mLast = state;
		Count++;
		if (mTargets.TryGetValue(state.Target, var target))
			target.Last.NextForTarget = state;
		else target.First = state;
		target.Last = state;
		mTargets[state.Target] = target;
	}

	public InvocationState PopFront() => Remove(mFirst);
	public InvocationState PopTarget(uint64 target)
	{
		if (!mTargets.TryGetValue(target, let queue)) return null;
		return Remove(queue.First);
	}

	private InvocationState Remove(InvocationState state)
	{
		if (state == null) return null;
		if (state.Previous != null) state.Previous.Next = state.Next;
		else mFirst = state.Next;
		if (state.Next != null) state.Next.Previous = state.Previous;
		else mLast = state.Previous;
		Count--;
		// Both dequeue paths remove the oldest pending entry for its target.
		if (state.NextForTarget == null) mTargets.Remove(state.Target);
		else
		{
			var target = mTargets[state.Target];
			target.First = state.NextForTarget;
			mTargets[state.Target] = target;
		}
		state.Previous = null;
		state.Next = null;
		state.NextForTarget = null;
		return state;
	}
}

internal class InvocationState : RefCounted
{
	private enum CompletionState { Pending, Publishing, Completed }

	internal InvocationState Previous, Next, NextForTarget;
	private append Monitor mLock = .();
	private delegate void() mCallback;
	private bool mOwnsCallback;
	private WaitEvent mWait ~ delete _;
	private Result<void>? mCompletion;
	private CompletionState mCompletionState;

	public uint64 Target { get; internal set; }
	public bool OwnsCallback => mOwnsCallback;

	public this(delegate void() callback, bool ownsCallback)
	{
		mCallback = callback;
		mOwnsCallback = ownsCallback;
	}
	public ~this() { if (mOwnsCallback) delete mCallback; }

	public Result<void>? Completion
	{
		get
		{
			let state = Interlocked.Load(ref mCompletionState, .Acquire);
			if (state == .Pending) return null;
			if (state == .Completed) return mCompletion;
			// Completion and an existing wait handle become observable together.
			using (mLock.Enter()) return mCompletion;
		}
	}

	public WaitEvent WaitHandle
	{
		get
		{
			using (mLock.Enter())
			{
				if (mWait == null) mWait = new .(mCompletion.HasValue);
				return mWait;
			}
		}
	}

	public void Execute()
	{
		mCallback();
		Complete(.Ok);
	}

	public void Complete(Result<void> result)
	{
		using (mLock.Enter())
		{
			Interlocked.Store(ref mCompletionState, .Publishing, .Release);
			mCompletion = result;
			mWait?.Set(true);
			Interlocked.Store(ref mCompletionState, .Completed, .Release);
		}
	}

	public Result<void> Wait()
	{
		if (let completion = Completion) return completion;
		WaitHandle.WaitFor();
		return Completion.Value;
	}
}

public sealed class InvokeAsyncResult : IAsyncResult
{
	internal InvocationState State;

	internal this(InvocationState state) { State = state; }
	public ~this() { State.ReleaseRef(); }

	public void ReturnValueDiscarded() { delete this; }

	public bool IsCompleted => State.Completion.HasValue;
	public bool CompletedSynchronously => false;
	public Object AsyncState => null;
	public WaitEvent AsyncWaitHandle => State.WaitHandle;
}
