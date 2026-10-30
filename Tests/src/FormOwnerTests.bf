using System;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class FormOwnerTests
{
	private class Lifetime
	{
		public int Deletes;
	}

	private class TrackedForm : Form
	{
		private Lifetime mLifetime;

		public this(Lifetime lifetime)
		{
			mLifetime = lifetime;
		}

		public ~this()
		{
			mLifetime.Deletes++;
		}
	}

	private static void VerifyNativeOwner(Form child, Form owner)
	{
#if BF_PLATFORM_WINDOWS
		void* window = child.Handle;
		void* expected = owner?.Handle;
#if BF_DEPENDS_BEEFFORMS_SDL
		if (Application.Backend is SDLBackend)
		{
			window = SDLBackend.GetNativeWindow(child);
			expected = owner == null ? null : SDLBackend.GetNativeWindow(owner);
		}
#endif
		Test.Assert(Win32.GetWindowLongPtr(window, Win32.GWLP_HWNDPARENT) == expected);
#endif
	}

	private static void VerifyShowAndReassignment(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let owner = scope Form();
		let other = scope Form();
		let child = scope Form();
		child.Owner = owner;
		Test.Assert(!owner.IsHandleCreated && !child.IsHandleCreated);
		bool loadedWithOwner = false;
		child.Load.Add(new [&] (sender, args) => loadedWithOwner = child.Owner == owner && owner.IsHandleCreated);
		child.Show(owner);
		Test.Assert(loadedWithOwner && child.Visible && owner.IsHandleCreated && !owner.Visible);
		Test.Assert(child.Parent == null && owner.Controls.IsEmpty && owner.Enabled);
		VerifyNativeOwner(child, owner);
		child.Owner = other;
		Test.Assert(child.Owner == other && other.IsHandleCreated && !other.Visible);
		VerifyNativeOwner(child, other);
		child.Owner = null;
		VerifyNativeOwner(child, null);
		child.Owner = owner;
		child.Hide();
		child.Show(null);
		Test.Assert(child.Owner == owner);
		VerifyNativeOwner(child, owner);
		child.Close();
		Test.Assert(child.Owner == null && !owner.IsDisposed && owner.IsHandleCreated);
		owner.Close();
		other.Close();
		Application.Backend.Run(owner);
	}

	private static void VerifyControlOwnerAndRecreation(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let owner = scope Form();
		owner.ClientSize = .(240, 140);
		let button = new Button();
		button.Size = .(100, 30);
		owner.Controls.Add(button);
		owner.Show();
		let child = scope Form();
		child.Show(button);
		Test.Assert(child.Owner == owner && child.Parent == null);
		VerifyNativeOwner(child, owner);
		let childHandle = child.Handle;
		owner.RecreateHandle();
		Test.Assert(child.IsHandleCreated && child.Handle == childHandle && !child.IsDisposed);
		VerifyNativeOwner(child, owner);
		child.RecreateHandle();
		VerifyNativeOwner(child, owner);
		owner.Close();
		Test.Assert(child.IsDisposed && child.Owner == null);
		Application.Backend.Run(owner);
	}

	private static void VerifyClosing(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		for (let hidden in scope bool[](false, true))
		{
			let order = scope String();
			let owner = scope Form();
			let first = scope Form();
			let second = scope Form();
			let grandchild = scope Form();
			int grandchildClosing = 0, grandchildClosed = 0;
			grandchild.FormClosing.Add(new [&] (sender, args) => grandchildClosing++);
			grandchild.FormClosed.Add(new [&] (sender, args) => grandchildClosed++);
			first.Owner = owner;
			second.Owner = owner;
			grandchild.Owner = first;
			first.FormClosing.Add(new (sender, args) =>
			{
				Test.Assert(args.CloseReason == .FormOwnerClosing);
				order.Append('A');
			});
			second.FormClosing.Add(new (sender, args) =>
			{
				Test.Assert(args.CloseReason == .FormOwnerClosing);
				order.Append('B');
			});
			owner.FormClosing.Add(new (sender, args) => order.Append('O'));
			first.FormClosed.Add(new (sender, args) =>
			{
				Test.Assert(args.CloseReason == .FormOwnerClosing && first.Owner == owner);
				order.Append('a');
			});
			second.FormClosed.Add(new (sender, args) => order.Append('b'));
			owner.FormClosed.Add(new (sender, args) => order.Append('o'));
			second.Disposed.Add(new (sender, args) =>
			{
				Test.Assert(second.Owner == null);
				order.Append('2');
			});
			grandchild.Disposed.Add(new (sender, args) => order.Append('G'));
			first.Disposed.Add(new (sender, args) => order.Append('1'));
			owner.Disposed.Add(new (sender, args) => order.Append('0'));
			owner.Show();
			if (!hidden)
			{
				first.Show();
				second.Show();
				grandchild.Show();
			}
			owner.Close();
			Test.Assert(order == "BAObao2G10");
			Test.Assert(grandchildClosing == 0 && grandchildClosed == 0);
			Test.Assert(owner.IsDisposed && first.IsDisposed && second.IsDisposed && grandchild.IsDisposed);
			Test.Assert(first.Owner == null && second.Owner == null && grandchild.Owner == null);
			Application.Backend.Run(owner);
		}
	}

	private static void VerifyCancellationAndTransfer(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let owner = scope Form();
		let other = scope Form();
		let child = scope Form();
		owner.Show();
		child.Show(owner);
		bool cancel = true, receivedCancel = false;
		child.FormClosing.Add(new [&] (sender, args) => args.Cancel = cancel);
		owner.FormClosing.Add(new [&] (sender, args) => receivedCancel = args.Cancel);
		owner.Close();
		Test.Assert(receivedCancel && !owner.IsDisposed && !child.IsDisposed && child.Owner == owner);
		VerifyNativeOwner(child, owner);
		cancel = false;
		child.Owner = other;
		owner.Close();
		Test.Assert(owner.IsDisposed && !child.IsDisposed && child.Owner == other);
		VerifyNativeOwner(child, other);
		other.Close();
		Test.Assert(child.IsDisposed && child.Owner == null);
		Application.Backend.Run(owner);
	}

	private static void VerifyIndependentAllocationAndExit(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let lifetime = scope Lifetime();
		let owner = scope Form();
		let child = new TrackedForm(lifetime);
		defer delete child;
		child.Owner = owner;
		int closing = 0, closed = 0;
		child.FormClosing.Add(new [&] (sender, args) =>
		{
			Test.Assert(args.CloseReason == .FormOwnerClosing);
			closing++;
		});
		child.FormClosed.Add(new [&] (sender, args) =>
		{
			Test.Assert(args.CloseReason == .FormOwnerClosing);
			closed++;
		});
		owner.Show();
		Application.Exit();
		Test.Assert(owner.IsDisposed && child.IsDisposed && child.Owner == null);
		Test.Assert(closing == 1 && closed == 1 && lifetime.Deletes == 0);
		Application.Backend.Run(owner);
	}

	private static void VerifyDisposedOwnershipAssignments(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		{
			let owner = scope Form();
			let child = scope Form();
			owner.Dispose();
			child.Owner = owner;
			Test.Assert(child.Owner == owner && owner.IsDisposed && !child.IsDisposed);
			Test.Assert(!owner.IsHandleCreated && !child.IsHandleCreated);
			child.Owner = null;
			Test.Assert(child.Owner == null);
		}
		{
			let owner = scope Form();
			let child = scope Form();
			child.Dispose();
			child.Owner = owner;
			Test.Assert(child.Owner == owner && child.IsDisposed && !owner.IsDisposed);
			Test.Assert(!owner.IsHandleCreated && !child.IsHandleCreated);
			child.Owner = null;
			Test.Assert(child.Owner == null);
		}
	}

	private static void ShowWithDisposedOwner(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let owner = scope Form();
		let child = scope Form();
		owner.Dispose();
		child.Owner = owner;
		child.Show();
	}

	private static void VerifyOwnershipAddedDuringClosing(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		for (let hidden in scope bool[](false, true))
		{
			let order = scope String();
			let owner = scope Form();
			let child = scope Form();
			int childClosing = 0;
			child.FormClosing.Add(new [&] (sender, args) =>
			{
				childClosing++;
				args.Cancel = true;
			});
			owner.FormClosing.Add(new (sender, args) =>
			{
				order.Append('A');
				child.Owner = owner;
			});
			child.FormClosed.Add(new (sender, args) =>
			{
				Test.Assert(args.CloseReason == .FormOwnerClosing && child.Owner == owner);
				order.Append('B');
			});
			owner.FormClosed.Add(new (sender, args) => order.Append('C'));
			child.Disposed.Add(new (sender, args) => order.Append('D'));
			owner.Disposed.Add(new (sender, args) => order.Append('E'));
			owner.Show();
			if (!hidden)
				child.Show();
			owner.Close();
			Test.Assert(childClosing == 0 && order == "ABCDE");
			Test.Assert(owner.IsDisposed && child.IsDisposed && child.Owner == null);
			Application.Backend.Run(owner);
		}
	}

	private static void VerifyParentingRetainsOwner(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let owner = scope Form();
		let parent = scope Form();
		let child = new Form();
		child.Owner = owner;
		parent.Controls.Add(child);
		Test.Assert(child.Parent == parent && child.Owner == owner);
		Test.Assert(parent.Controls.Contains(child) && owner.Controls.IsEmpty);
		parent.Dispose();
		Test.Assert(child.IsDisposed && child.Owner == null && !owner.IsDisposed);
	}

	[Test(ShouldFail = true)]
	public static void SelfOwnershipIsRejected()
	{
		let form = scope Form();
		form.Owner = form;
	}

	[Test(ShouldFail = true)]
	public static void OwnershipCyclesAreRejected()
	{
		let first = scope Form();
		let second = scope Form();
		second.Owner = first;
		first.Owner = second;
	}

	[Test(ShouldFail = true)]
	public static void DisabledOwnedShowIsRejected()
	{
		let owner = scope Form();
		let form = scope Form();
		form.Enabled = false;
		form.Show(owner);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeDisposedOwnershipAssignmentsAreAllowed()
	{
		VerifyDisposedOwnershipAssignments(.Win32);
	}
	[Test(ShouldFail = true)]
	public static void NativeShowingWithDisposedOwnerIsRejected()
	{
		ShowWithDisposedOwner(.Win32);
	}
	[Test]
	public static void NativeOwnershipAddedDuringClosingSkipsClosingNotification()
	{
		VerifyOwnershipAddedDuringClosing(.Win32);
	}
	[Test]
	public static void NativeParentingRetainsOwner()
	{
		VerifyParentingRetainsOwner(.Win32);
	}
	[Test]
	public static void NativeOwnedShowAndReassignment()
	{
		VerifyShowAndReassignment(.Win32);
	}
	[Test]
	public static void NativeControlOwnerAndHandleRecreation()
	{
		VerifyControlOwnerAndRecreation(.Win32);
	}
	[Test]
	public static void NativeOwnerClosingOrderAndDisposal()
	{
		VerifyClosing(.Win32);
	}
	[Test]
	public static void NativeOwnedCloseCancellationAndTransfer()
	{
		VerifyCancellationAndTransfer(.Win32);
	}
	[Test]
	public static void NativeOwnerExitKeepsAllocationsCallerOwned()
	{
		VerifyIndependentAllocationAndExit(.Win32);
	}
#endif

#if BF_DEPENDS_BEEFFORMS_SDL
	[Test]
	public static void SDLDisposedOwnershipAssignmentsAreAllowed()
	{
		VerifyDisposedOwnershipAssignments(.SDL2OpenGL);
	}
	[Test(ShouldFail = true)]
	public static void SDLShowingWithDisposedOwnerIsRejected()
	{
		ShowWithDisposedOwner(.SDL2OpenGL);
	}
	[Test]
	public static void SDLOwnershipAddedDuringClosingSkipsClosingNotification()
	{
		VerifyOwnershipAddedDuringClosing(.SDL2OpenGL);
	}
	[Test]
	public static void SDLParentingRetainsOwner()
	{
		VerifyParentingRetainsOwner(.SDL2OpenGL);
	}
	[Test]
	public static void SDLOwnedShowAndReassignment()
	{
		VerifyShowAndReassignment(.SDL2OpenGL);
	}
	[Test]
	public static void SDLControlOwnerAndHandleRecreation()
	{
		VerifyControlOwnerAndRecreation(.SDL2OpenGL);
	}
	[Test]
	public static void SDLOwnerClosingOrderAndDisposal()
	{
		VerifyClosing(.SDL2OpenGL);
	}
	[Test]
	public static void SDLOwnedCloseCancellationAndTransfer()
	{
		VerifyCancellationAndTransfer(.SDL2OpenGL);
	}
	[Test]
	public static void SDLOwnerExitKeepsAllocationsCallerOwned()
	{
		VerifyIndependentAllocationAndExit(.SDL2OpenGL);
	}
#endif
}
