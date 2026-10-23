using System;
using System.Windows.Forms;

namespace BeefForms.Tests;

class FindFormTests
{
	[Test]
	public static void FindFormTracksParentageWithoutCreatingHandles()
	{
		let first = scope Form();
		let second = scope Form();
		let panel = new Panel();
		let child = new Control(); panel.Controls.Add(child);
		Test.Assert(child.FindForm() == null && panel.FindForm() == null);
		first.Controls.Add(panel);
		Test.Assert(first.FindForm() == first && child.FindForm() == first);
		second.Controls.Add(panel);
		Test.Assert(panel.FindForm() == second && child.FindForm() == second);
		second.Controls.Remove(panel);
		Test.Assert(child.FindForm() == null && panel.FindForm() == null);
		Test.Assert(!first.IsHandleCreated && !second.IsHandleCreated && !panel.IsHandleCreated && !child.IsHandleCreated);
		delete panel;
	}

	[Test]
	public static void FindFormReturnsTheNearestFormIncludingItself()
	{
		let outer = scope Form();
		let inner = new Form(); outer.Controls.Add(inner);
		let panel = new Panel(); inner.Controls.Add(panel);
		let child = new Control(); panel.Controls.Add(child);
		Test.Assert(outer.FindForm() == outer && inner.FindForm() == inner && child.FindForm() == inner);
		Test.Assert(!outer.IsHandleCreated && !inner.IsHandleCreated && !child.IsHandleCreated);
	}
}
