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
