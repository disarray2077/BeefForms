using System.Collections;
using internal System.Windows.Forms;

namespace System.Windows.Forms;

extension Control
{
	// Remains set after dequeue and during destruction to reject reentrant requests.
	private bool mDeletionCommitted;
	internal LinkedListNode<Control> mDeferredDeleteNode;

	/// May be called from any thread for a UI-owned control. Deletion runs on the UI thread.
	/// Requests before Run wait for the loop to start; requests during final main-form release or after the loop stops are ignored.
	/// Do not use with scope/append objects. Only scheduling is thread-safe;
	/// dispose explicitly on the UI thread if resources must be released before deletion.
	public void DeleteLater()
	{
		let dispatcher = Application.DispatcherCore;
		using (dispatcher.SyncRoot.Enter())
		{
			if (mDeletionCommitted)
				return;
			mDeletionCommitted = true;
			if (!dispatcher.QueueDeleteLocked(this))
				mDeletionCommitted = false;
		}
	}
}
