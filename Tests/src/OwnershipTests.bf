using System;
using System.Windows.Forms;

using internal System.Windows.Forms;

namespace BeefForms.Tests;

class OwnershipTests
{
	private class CountedControl : Control
	{
		private int* mDeletions;
		public this(int* deletions) { mDeletions = deletions; }
		public ~this() { (*mDeletions)++; }
	}

	[Test]
	public static void IndependentDisposalDetachesBeforeNotificationAndReturnsOwnership()
	{
		int childDeletes = 0, descendantDeletes = 0, siblingDeletes = 0;
		let parent = new Control();
		let child = new CountedControl(&childDeletes);
		let descendant = new CountedControl(&descendantDeletes);
		let sibling = new CountedControl(&siblingDeletes);
		parent.Controls.Add(child);
		parent.Controls.Add(sibling);
		child.Controls.Add(descendant);
		int notifications = 0;
		child.Disposed.Add(new [&] (sender, args) =>
		{
			notifications++;
			Test.Assert(child.Disposing && !child.IsDisposed && !child.IsHandleCreated);
			Test.Assert(child.Parent == null && !parent.Controls.Contains(child));
			Test.Assert(parent.Controls.Count == 1 && parent.Controls[0] == sibling);
			Test.Assert(child.Controls.IsEmpty && descendant.Parent == null && descendant.IsDisposed);
			Test.Assert(childDeletes == 0 && descendantDeletes == 0);
		});
		child.Dispose();
		Test.Assert(notifications == 1 && child.IsDisposed && !child.Disposing);
		delete parent;
		Test.Assert(childDeletes == 0 && descendantDeletes == 0 && siblingDeletes == 1);
		delete child;
		Test.Assert(childDeletes == 1 && descendantDeletes == 1 && notifications == 1);
	}

	[Test]
	public static void CascadedDisposalClearsTheTreeAndRetainsAllocationsUntilDelete()
	{
		int deletions = 0;
		let parent = new Control();
		let first = new CountedControl(&deletions);
		let second = new CountedControl(&deletions);
		let third = new CountedControl(&deletions);
		parent.Controls.Add(first);
		parent.Controls.Add(second);
		parent.Controls.Add(third);
		let order = scope String();
		first.Disposed.Add(new (sender, args) =>
		{
			Test.Assert(first.Parent == null && parent.Controls.Count == 3);
			Test.Assert(!parent.Controls.Remove(first));
			order.Append('1');
		});
		second.Disposed.Add(new (sender, args) =>
		{
			Test.Assert(second.Parent == null && parent.Controls.Count == 3);
			order.Append('2');
		});
		third.Disposed.Add(new (sender, args) =>
		{
			Test.Assert(third.Parent == null && parent.Controls.Count == 3);
			order.Append('3');
		});
		parent.Disposed.Add(new [&] (sender, args) =>
		{
			Test.Assert(parent.Controls.IsEmpty && deletions == 0);
			Test.Assert(first.IsDisposed && second.IsDisposed && third.IsDisposed);
			order.Append('P');
		});
		parent.Dispose();
		Test.Assert(order == "123P" && deletions == 0);
		delete parent;
		Test.Assert(deletions == 3 && order == "123P");
	}

	[Test]
	public static void ExplicitControlDisposalRepeatsNotificationButDeleteDoesNot()
	{
		let control = new Control();
		int notifications = 0;
		control.Disposed.Add(new [&] (sender, args) =>
		{
			Test.Assert(control.Disposing && control.IsDisposed == (notifications > 0));
			notifications++;
			control.Dispose(); // Reentrant disposal is suppressed on either call.
		});
		control.Dispose();
		control.Dispose();
		Test.Assert(notifications == 2 && control.IsDisposed && !control.Disposing);
		delete control;
		Test.Assert(notifications == 2);
	}

	[Test]
	public static void DeletingAnAttachedChildLeavesNoDanglingCollectionEntry()
	{
		int deletions = 0;
		let parent = new Control();
		let first = new CountedControl(&deletions);
		let second = new CountedControl(&deletions);
		let third = new CountedControl(&deletions);
		parent.Controls.Add(first);
		parent.Controls.Add(second);
		parent.Controls.Add(third);
		delete second;
		Test.Assert(deletions == 1 && parent.Controls.Count == 2);
		Test.Assert(parent.Controls[0] == first && parent.Controls[1] == third);
		delete parent;
		Test.Assert(deletions == 3);
	}

	[Test]
	public static void DeletingACascadedChildBeforeItsOwnerDoesNotDeleteItTwice()
	{
		int deletions = 0;
		let parent = new Control();
		let first = new CountedControl(&deletions);
		let second = new CountedControl(&deletions);
		parent.Controls.Add(first);
		parent.Controls.Add(second);
		parent.Dispose();
		delete first;
		Test.Assert(deletions == 1 && parent.Controls.IsEmpty && second.IsDisposed);
		delete parent;
		Test.Assert(deletions == 2);
	}

	[Test]
	public static void ChildrenAddedByDisposalCallbacksJoinTheCascade()
	{
		int deletions = 0;
		let parent = new Control();
		let first = new CountedControl(&deletions);
		let sibling = new CountedControl(&deletions);
		Control added = null, descendant = null, last = null;
		let events = scope String();
		parent.Controls.Add(first);
		parent.Controls.Add(sibling);
		first.Disposed.Add(new [&] (sender, args) =>
		{
			events.Append('1');
			added = new CountedControl(&deletions);
			descendant = new CountedControl(&deletions);
			added.Controls.Add(descendant);
			descendant.Disposed.Add(new (sender, args) => { events.Append('D'); });
			added.Disposed.Add(new [&] (sender, args) =>
			{
				events.Append('A');
				last = new CountedControl(&deletions);
				last.Disposed.Add(new (sender, args) => { events.Append('L'); });
				parent.Controls.Add(last);
			});
			parent.Controls.Add(added);
		});
		sibling.Disposed.Add(new (sender, args) => { events.Append('2'); });
		parent.Dispose();
		Test.Assert(events == "12DAL" && parent.Controls.IsEmpty && deletions == 0);
		Test.Assert(added.IsDisposed && descendant.IsDisposed && last.IsDisposed);
		Test.Assert(added.Parent == null && descendant.Parent == null && last.Parent == null);
		delete parent;
		Test.Assert(deletions == 5 && events == "12DAL");
	}

	private static void VerifyReparentingDuringDisposal(Control destination, bool deleteChildFirst)
	{
		int deletions = 0, notifications = 0;
		bool reparent = true;
		let original = new Control();
		let child = new CountedControl(&deletions);
		child.Size = .(40, 20);
		original.Controls.Add(child);
		child.Disposed.Add(new [&] (sender, args) =>
		{
			notifications++;
			if (reparent)
			{
				reparent = false;
				Test.Assert(child.Disposing && !child.IsDisposed && child.Parent == null);
				destination.Controls.Add(child);
			}
		});
		original.Dispose();
		Test.Assert(child.IsDisposed && !child.Disposing && notifications == 1);
		Test.Assert(child.Parent == destination && destination.Controls.Count == 1);
		Test.Assert(child.IsHandleCreated == destination.IsHandleCreated);
		if (deleteChildFirst)
		{
			delete child;
			Test.Assert(destination.Controls.IsEmpty && deletions == 1 && notifications == 1);
			delete original;
			Test.Assert(deletions == 1);
		}
		else
		{
			delete original;
			Test.Assert(deletions == 0 && destination.Controls.Count == 1);
			child.Text = "still owned by the destination";
			destination.Dispose();
			Test.Assert(child.Parent == null && destination.Controls.IsEmpty && !child.IsHandleCreated);
			Test.Assert(notifications == 2 && deletions == 0);
			// The disposed destination retains the allocation until its own deletion.
			delete child;
			Test.Assert(deletions == 1 && notifications == 2);
		}
	}

	[Test]
	public static void ReparentingDuringDisposalTransfersDeletionOwnership()
	{
		let destination = scope Control();
		VerifyReparentingDuringDisposal(destination, false);
	}

	[Test]
	public static void DeletingTheDestinationDeletesTheTransferredChildExactlyOnce()
	{
		int deletions = 0;
		let original = new Control();
		let destination = new Control();
		let child = new CountedControl(&deletions);
		original.Controls.Add(child);
		child.Disposed.Add(new (sender, args) =>
		{
			if (!child.IsDisposed) destination.Controls.Add(child);
		});
		original.Dispose();
		delete original;
		Test.Assert(deletions == 0 && child.Parent == destination);
		delete destination;
		Test.Assert(deletions == 1);
	}

	[Test]
	public static void DeletingATransferredDisposedChildDetachesFromItsDestination()
	{
		let destination = scope Control();
		VerifyReparentingDuringDisposal(destination, true);
	}

	private static void VerifyCreatedDestination(ApplicationBackend backend, bool deleteChildFirst)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let destination = new Panel();
		defer delete destination;
		destination.Size = .(150, 100);
		form.Controls.Add(destination);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		VerifyReparentingDuringDisposal(destination, deleteChildFirst);
	}

	[Test]
	public static void SDLReparentingDuringDisposalToACreatedDestination() => VerifyCreatedDestination(.SDL2OpenGL, false);
	[Test]
	public static void SDLDeletingATransferredDisposedChildDestroysItsRecreatedHandle() => VerifyCreatedDestination(.SDL2OpenGL, true);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeReparentingDuringDisposalToACreatedDestination() => VerifyCreatedDestination(.Win32, false);
	[Test]
	public static void NativeDeletingATransferredDisposedChildDestroysItsRecreatedHandle() => VerifyCreatedDestination(.Win32, true);
#endif

	[Test]
	public static void DeletionCleansUpChildrenAddedAfterTheDisposalCascade()
	{
		int deletions = 0, notifications = 0;
		let parent = new Control();
		Control addedInNotification = null;
		parent.Disposed.Add(new [&] (sender, args) =>
		{
			notifications++;
			addedInNotification = new CountedControl(&deletions);
			parent.Controls.Add(addedInNotification);
		});
		parent.Dispose();
		let addedAfterDisposal = new CountedControl(&deletions);
		parent.Controls.Add(addedAfterDisposal);
		Test.Assert(parent.Controls.Count == 2 && notifications == 1);
		Test.Assert(addedInNotification.Parent == parent && !addedInNotification.IsDisposed);
		Test.Assert(addedAfterDisposal.Parent == parent && !addedAfterDisposal.IsDisposed);
		delete parent;
		Test.Assert(deletions == 2 && notifications == 1);
	}

	[Test]
	public static void CyclesAreRejectedBeforeChangingEitherTree()
	{
		let outer = scope Control();
		let ancestor = new Control();
		let descendant = new Control();
		outer.Controls.Add(ancestor);
		ancestor.Controls.Add(descendant);
		// Exercise the insertion operation without the public API's fatal-error policy.
		Test.Assert(descendant.Controls.[Friend]TryInsert(0, descendant) case .Err);
		Test.Assert(descendant.Parent == ancestor && ancestor.Controls.Count == 1);
		Test.Assert(descendant.Controls.[Friend]TryInsert(0, ancestor) case .Err);
		Test.Assert(ancestor.Parent == outer && descendant.Parent == ancestor);
		Test.Assert(outer.Controls.Count == 1 && ancestor.Controls.Count == 1 && descendant.Controls.IsEmpty);
		let sibling = new Control();
		outer.Controls.Add(sibling);
		sibling.Controls.Add(descendant);
		Test.Assert(ancestor.Controls.IsEmpty && descendant.Parent == sibling);
	}

	[Test(ShouldFail = true)]
	public static void PublicAddRejectsSelfParenting()
	{
		let control = scope Control();
		control.Controls.Add(control);
	}

	[Test(ShouldFail = true)]
	public static void PublicInsertRejectsAncestorParenting()
	{
		let parent = scope Control();
		let child = new Control();
		parent.Controls.Add(child);
		child.Controls.Insert(0, parent);
	}
}
