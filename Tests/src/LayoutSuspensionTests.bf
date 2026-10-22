using System;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class LayoutSuspensionTests
{
	// Expected suspension, event, and anchor behavior was captured with .NET 9.0.4.
	private class RecordingControl : Control
	{
		public int LayoutCount, Depth, MaxDepth;
		public bool Reenter;
		public this()
		{
			Layout.Add(new (sender, args) =>
			{
				let control = (RecordingControl)sender;
				control.LayoutCount++;
				control.Depth++;
				control.MaxDepth = Math.Max(control.MaxDepth, control.Depth);
				if (control.Reenter && control.LayoutCount == 1) control.PerformLayout();
				control.Depth--;
			});
		}
	}

	[Test]
	public static void NestedRequestsWaitForTheOutermostResume()
	{
		for (let inner in scope bool[](false, true))
			for (let outer in scope bool[](false, true))
			{
				let control = scope RecordingControl();
				control.SuspendLayout();
				control.SuspendLayout();
				control.PerformLayout();
				control.PerformLayout();
				Test.Assert(control.LayoutCount == 0);
				control.ResumeLayout(inner);
				Test.Assert(control.LayoutCount == 0);
				control.PerformLayout();
				Test.Assert(control.LayoutCount == 0);
				control.ResumeLayout(outer);
				Test.Assert(control.LayoutCount == (outer ? 1 : 0));
				control.ResumeLayout(true);
				Test.Assert(control.LayoutCount == (outer ? 1 : 0));
				control.PerformLayout();
				Test.Assert(control.LayoutCount == (outer ? 2 : 1));
			}
	}

	[Test]
	public static void IdleAndExtraResumesDoNotRequestLayout()
	{
		let control = scope RecordingControl();
		control.ResumeLayout(true);
		control.ResumeLayout(false);
		control.ResumeLayout(true);
		Test.Assert(control.LayoutCount == 0);
		control.SuspendLayout();
		control.SuspendLayout();
		control.ResumeLayout(true);
		control.ResumeLayout(true);
		control.ResumeLayout(true);
		Test.Assert(control.LayoutCount == 0);
		// Extra resumes must not underflow the depth and suppress the next layout.
		control.SuspendLayout();
		control.PerformLayout();
		control.ResumeLayout(true);
		Test.Assert(control.LayoutCount == 1);
	}

	[Test]
	public static void ResumeFalseRetainsTheRequestForALaterBalancedResume()
	{
		let control = scope RecordingControl();
		control.SuspendLayout();
		control.PerformLayout();
		control.ResumeLayout(false);
		Test.Assert(control.LayoutCount == 0);
		control.SuspendLayout();
		control.ResumeLayout(true);
		Test.Assert(control.LayoutCount == 1);
	}

	[Test]
	public static void LayoutHandlersCannotRecursivelyPerformLayout()
	{
		let control = scope RecordingControl();
		control.Reenter = true;
		control.PerformLayout();
		Test.Assert(control.LayoutCount == 1 && control.MaxDepth == 1);
		control.ResumeLayout(true);
		Test.Assert(control.LayoutCount == 1);
		control.PerformLayout();
		Test.Assert(control.LayoutCount == 2 && control.MaxDepth == 1);
	}

	[Test]
	public static void ChildBoundsChangesQueueLayoutWhileTheParentIsSuspended()
	{
		let parent = scope RecordingControl();
		let child = new Control();
		parent.Controls.Add(child);
		parent.LayoutCount = 0;
		parent.SuspendLayout();
		parent.SuspendLayout();
		child.Location = .(0, 200);
		Test.Assert(parent.LayoutCount == 0);
		parent.ResumeLayout(true);
		Test.Assert(parent.LayoutCount == 0);
		parent.ResumeLayout(true);
		Test.Assert(parent.LayoutCount == 1);
	}

	private static void VerifyAnchors(RecordingControl parent, bool inner, bool outer)
	{
		parent.Size = .(200, 100);
		let child = new Control();
		defer delete child;
		child.Location = .(10, 10);
		child.Size = .(180, 80);
		child.Anchor = .Top | .Bottom | .Left | .Right;
		parent.Controls.Add(child);
		parent.LayoutCount = 0;
		parent.SuspendLayout();
		parent.SuspendLayout();
		parent.Size = .(300, 150);
		Test.Assert(parent.LayoutCount == 0 && child.Size.width == 180 && child.Size.height == 80);
		parent.ResumeLayout(inner);
		Test.Assert(parent.LayoutCount == 0 && child.Size.width == 180 && child.Size.height == 80);
		parent.ResumeLayout(outer);
		Test.Assert(parent.LayoutCount == (outer ? 1 : 0));
		let expanded = inner && outer;
		Test.Assert(child.Size.width == (expanded ? 280 : 180) && child.Size.height == (expanded ? 130 : 80));
		parent.PerformLayout();
		Test.Assert(parent.LayoutCount == (outer ? 2 : 1));
		Test.Assert(child.Size.width == (expanded ? 280 : 180) && child.Size.height == (expanded ? 130 : 80));
		parent.Size = .(400, 200);
		Test.Assert(child.Size.width == (expanded ? 380 : 280) && child.Size.height == (expanded ? 180 : 130));
		Test.Assert(child.Location.x == 10 && child.Location.y == 10);
	}

	[Test]
	public static void UncreatedAnchorsFollowBalancedResumesAndFalseRefreshesTheirBaseline()
	{
		let parent = scope RecordingControl();
		for (let inner in scope bool[](false, true))
			for (let outer in scope bool[](false, true)) VerifyAnchors(parent, inner, outer);
	}

	private static void VerifyCreatedAnchors(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(500, 300);
		let parent = new RecordingControl();
		parent.Size = .(200, 100);
		form.Controls.Add(parent);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		for (let inner in scope bool[](false, true))
			for (let outer in scope bool[](false, true)) VerifyAnchors(parent, inner, outer);
	}

	[Test]
	public static void SDLCreatedAnchorsRespectNestedSuspension() => VerifyCreatedAnchors(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeCreatedAnchorsRespectNestedSuspension() => VerifyCreatedAnchors(.Win32);
#endif

	private static void VerifyLayoutEventBeforeAnchoring(RecordingControl parent)
	{
		parent.Size = .(200, 100);
		let child = new Control();
		defer delete child;
		child.Location = .(10, 10);
		child.Size = .(180, 80);
		child.Anchor = .Top | .Bottom | .Left | .Right;
		parent.Controls.Add(child);
		let events = scope String();
		bool recording = true, resizeFromHandler = false;
		int observedWidth = 0, observedHeight = 0;
		EventHandler layoutHandler = new [&] (sender, args) =>
		{
			if (!recording) return;
			events.Append('L');
			observedWidth = child.Size.width;
			observedHeight = child.Size.height;
			if (resizeFromHandler) parent.Size = .(300, 150);
		};
		parent.Layout.Add(layoutHandler);
		defer { parent.Layout.Remove(layoutHandler); delete layoutHandler; }
		EventHandler sizeHandler = new [&] (sender, args) =>
		{
			if (recording) events.Append('A');
		};
		child.SizeChanged.Add(sizeHandler);
		defer { child.SizeChanged.Remove(sizeHandler); delete sizeHandler; }

		parent.LayoutCount = 0;
		parent.Size = .(300, 150);
		Test.Assert(events == "LA" && parent.LayoutCount == 1);
		Test.Assert(observedWidth == 180 && observedHeight == 80);
		Test.Assert(child.Size.width == 280 && child.Size.height == 130);

		recording = false;
		parent.Size = .(200, 100);
		events.Clear();
		parent.LayoutCount = 0;
		resizeFromHandler = true;
		recording = true;
		parent.PerformLayout();
		Test.Assert(events == "LA" && parent.LayoutCount == 1);
		Test.Assert(observedWidth == 180 && observedHeight == 80);
		Test.Assert(child.Size.width == 280 && child.Size.height == 130);
		Test.Assert(child.Location.x == 10 && child.Location.y == 10);
	}

	[Test]
	public static void UncreatedLayoutEventPrecedesAnchoringAndCanResizeTheParent()
	{
		let parent = scope RecordingControl();
		VerifyLayoutEventBeforeAnchoring(parent);
	}

	private static void VerifyCreatedLayoutEventOrder(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(400, 250);
		let parent = new RecordingControl();
		parent.Size = .(200, 100);
		form.Controls.Add(parent);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		VerifyLayoutEventBeforeAnchoring(parent);
	}

	[Test]
	public static void SDLLayoutEventPrecedesAnchoringAndCanResizeTheParent() => VerifyCreatedLayoutEventOrder(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeLayoutEventPrecedesAnchoringAndCanResizeTheParent() => VerifyCreatedLayoutEventOrder(.Win32);
#endif

	[Test]
	public static void SuspendingAChildDoesNotBlockItsParentFromAnchoringIt()
	{
		let parent = scope Control();
		parent.Size = .(200, 100);
		let child = new RecordingControl();
		child.Location = .(10, 10);
		child.Size = .(180, 80);
		child.Anchor = .Top | .Bottom | .Left | .Right;
		parent.Controls.Add(child);
		child.LayoutCount = 0;
		child.SuspendLayout();
		child.SuspendLayout();
		parent.Size = .(300, 150);
		Test.Assert(child.Size.width == 280 && child.Size.height == 130 && child.LayoutCount == 0);
		child.ResumeLayout(true);
		Test.Assert(child.LayoutCount == 0);
		child.ResumeLayout(true);
		Test.Assert(child.LayoutCount == 1);
	}

	private static void VerifyScrollBounds(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(240, 160);
		let panel = new Panel();
		panel.Size = .(100, 100);
		panel.AutoScroll = true;
		let child = new Control();
		child.Size = .(50, 30);
		panel.Controls.Add(child);
		form.Controls.Add(panel);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		panel.SuspendLayout();
		panel.SuspendLayout();
		child.Location = .(0, 200);
		Test.Assert(!panel.VerticalScrollVisible);
		panel.ResumeLayout(true);
		Test.Assert(!panel.VerticalScrollVisible);
		panel.ResumeLayout(true);
		Test.Assert(panel.VerticalScrollVisible && !panel.HorizontalScrollVisible);
		panel.ScrollPosition = .(0, 100);
		Test.Assert(panel.ScrollPosition.y > 0);
		panel.SuspendLayout();
		panel.SuspendLayout();
		child.Location = .(0, 0);
		panel.ResumeLayout(true);
		Test.Assert(panel.VerticalScrollVisible && panel.ScrollPosition.y > 0);
		panel.ResumeLayout(true);
		Test.Assert(!panel.VerticalScrollVisible && panel.ScrollPosition.y == 0);
		panel.SuspendLayout();
		panel.SuspendLayout();
		panel.AutoScrollMinSize = .(50, 250);
		Test.Assert(!panel.VerticalScrollVisible);
		panel.ResumeLayout(true);
		Test.Assert(!panel.VerticalScrollVisible);
		panel.ResumeLayout(true);
		Test.Assert(panel.VerticalScrollVisible && !panel.HorizontalScrollVisible);
	}

	[Test]
	public static void SDLScrollBoundsWaitForTheOutermostResume() => VerifyScrollBounds(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeScrollBoundsWaitForTheOutermostResume() => VerifyScrollBounds(.Win32);
#endif
}
