using System;
using System.Drawing;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class PreferredSizingTests
{
	private class TextSizedControl : Control
	{
		public Size LastProposal;
		public override Size GetPreferredSize(Size proposedSize)
		{
			LastProposal = proposedSize;
			return .((int32)Text.Length * 10, 30);
		}
	}
	private class PreferredPanel : Panel
	{
		public override Size GetPreferredSize(Size proposedSize) => .(80, 30);
	}

	[Test]
	public static void BaseControlsPreferTheirExplicitSizeAndDoNotCreateHandles()
	{
		let control = scope Control(); control.Size = .(90, 40);
		let child = new Control(); child.Location = .(100, 80); child.Size = .(50, 30); control.Controls.Add(child);
		Test.Assert(control.PreferredSize == .(90, 40) && control.GetPreferredSize(.(20, 10)) == .(90, 40));
		Test.Assert(!control.IsHandleCreated && !child.IsHandleCreated);
	}

	[Test]
	public static void PanelPreferredSizeIncludesVisibleChildrenAndBordersWithoutChangingBounds()
	{
		let panel = scope Panel(); panel.Size = .(200, 100); panel.BorderStyle = .FixedSingle;
		let child = new Control(); child.Location = .(10, 15); child.Size = .(40, 20); panel.Controls.Add(child);
		Test.Assert(panel.PreferredSize == .(52, 37) && panel.GetPreferredSize(.(20, 10)) == .(52, 37));
		Test.Assert(panel.Size == .(200, 100) && child.Location == .(10, 15) && child.Size == .(40, 20));
		child.Hide(); Test.Assert(panel.PreferredSize == .(2, 2));
		child.Show(); panel.Hide(); Test.Assert(panel.PreferredSize == .(52, 37));
	}

	private static void VerifyMode(AutoSizeMode mode)
	{
		let host = scope Control(); host.Size = .(1000, 800);
		let panel = new Panel(); panel.Size = .(200, 100); panel.AutoSizeMode = mode; panel.AutoSize = true;
		let child = new Control(); child.Location = .(10, 15); child.Size = .(40, 20); panel.Controls.Add(child);
		Test.Assert(panel.Size == .(200, 100));
		host.Controls.Add(panel);
		let small = mode == .GrowOnly ? Size(200, 100) : Size(50, 35);
		Test.Assert(panel.Size == small);
		child.Location = .(260, 150); Test.Assert(panel.Size == .(300, 170));
		child.Location = .(10, 15); Test.Assert(panel.Size == small);
		child.Hide(); Test.Assert(panel.Size == (mode == .GrowOnly ? Size(200, 100) : Size(0, 0)));
		child.Show(); panel.AutoSize = false; Test.Assert(panel.Size == .(200, 100));
		panel.AutoSize = true;
		panel.SuspendLayout(); child.Size = .(500, 300); Test.Assert(panel.Size == small);
		panel.ResumeLayout(true); Test.Assert(panel.Size == .(510, 315));
	}

	[Test] public static void GrowOnlyUsesTheExplicitSizeAsItsFloor() => VerifyMode(.GrowOnly);
	[Test] public static void GrowAndShrinkFollowsContentAndRestoresExplicitSizeWhenDisabled() => VerifyMode(.GrowAndShrink);

	[Test]
	public static void NestedAutoSizeContainersFollowGrowthRemovalAndVisibility()
	{
		let host = scope Control();
		let outer = new Panel(); outer.AutoSizeMode = .GrowAndShrink; outer.AutoSize = true;
		let inner = new Panel(); inner.Location = .(5, 8); inner.AutoSizeMode = .GrowAndShrink; inner.AutoSize = true;
		let child = new Control(); child.Location = .(10, 15); child.Size = .(40, 20);
		inner.Controls.Add(child); outer.Controls.Add(inner); host.Controls.Add(outer);
		Test.Assert(inner.Size == .(50, 35) && outer.Size == .(55, 43));
		child.Size = .(90, 50); Test.Assert(inner.Size == .(100, 65) && outer.Size == .(105, 73));
		child.Hide(); Test.Assert(inner.Size == .(0, 0) && outer.Size == .(5, 8));
		child.Show(); inner.Controls.Remove(child); delete child;
		Test.Assert(inner.Size == .(0, 0) && outer.Size == .(5, 8));
	}

	[Test]
	public static void ContainerMeasurementRespectsRightAndBottomAnchorDistances()
	{
		let panel = scope Panel(); panel.Size = .(200, 100);
		let child = new Control(); child.Location = .(10, 15); child.Size = .(40, 20); panel.Controls.Add(child);
		child.Anchor = .Top | .Right; Test.Assert(panel.PreferredSize == .(200, 35));
		child.Anchor = .Bottom | .Left; Test.Assert(panel.PreferredSize == .(50, 100));
		child.Anchor = .Top | .Left | .Right; Test.Assert(panel.PreferredSize == .(200, 35));
		child.Anchor = .None; Test.Assert(panel.PreferredSize == .(0, 35));
	}

	[Test]
	public static void VirtualPreferredSizeDrivesLayoutAndTextChangesPropagate()
	{
		let host = scope Control(); host.Size = .(500, 200);
		let panel = new Panel(); panel.AutoSizeMode = .GrowAndShrink; panel.AutoSize = true; host.Controls.Add(panel);
		let child = new TextSizedControl(); child.AutoSize = true; child.Text = "abc"; child.Location = .(5, 7);
		panel.Controls.Add(child);
		Test.Assert(child.Size == .(30, 30) && panel.Size == .(35, 37));
		child.Text = "abcdefgh"; Test.Assert(child.Size == .(80, 30) && panel.Size == .(85, 37));
		child.Text = "a"; Test.Assert(child.Size == .(10, 30) && panel.Size == .(15, 37));
		Test.Assert(!panel.IsHandleCreated && !child.IsHandleCreated);
	}

	[Test]
	public static void AutoSizeGrowthPreservesRightAndBottomEdgesAndStretchedFloors()
	{
		for (let mode in scope AutoSizeMode[](.GrowOnly, .GrowAndShrink))
		{
			let host = scope Panel(); host.Size = .(300, 200);
			let child = new PreferredPanel(); child.Size = .(40, 20); child.Location = .(100, 50);
			child.AutoSizeMode = mode; child.AutoSize = true; child.Anchor = .Top | .Right; host.Controls.Add(child);
			Test.Assert(child.Size == .(80, 30) && child.Location == .(60, 50));
			host.Size = .(400, 300); Test.Assert(child.Location == .(160, 50));
			child.AutoSize = false; child.Size = .(40, 20); child.Location = .(100, 50);
			host.Size = .(300, 200); child.Location = .(100, 50); child.Anchor = .Top | .Left | .Right; child.AutoSize = true;
			host.Size = .(400, 300);
			Test.Assert(child.Size == (mode == .GrowOnly ? Size(140, 30) : Size(80, 30)));
		}
	}

	[Test]
	public static void SizeChangedCallbacksCanChangeTheContentAgain()
	{
		let host = scope Control();
		let panel = new Panel(); panel.AutoSizeMode = .GrowAndShrink; panel.AutoSize = true; host.Controls.Add(panel);
		let child = new Control(); child.Size = .(40, 20); panel.Controls.Add(child);
		int changes = 0;
		panel.SizeChanged.Add(new [&] (sender, args) => { if (++changes == 1) child.Size = .(140, 120); });
		child.Size = .(80, 60);
		Test.Assert(panel.Size == .(140, 120) && child.Size == .(140, 120) && changes == 2);
	}

	[Test]
	public static void ParentSuspensionDefersAutoSizeAndResumeFalseKeepsItDeferred()
	{
		let host = scope Control();
		let panel = new Panel(); panel.AutoSize = true; panel.AutoSizeMode = .GrowAndShrink; host.Controls.Add(panel);
		let child = new Control(); child.Size = .(40, 20); panel.Controls.Add(child);
		host.SuspendLayout(); child.Size = .(80, 60); host.ResumeLayout(false);
		Test.Assert(panel.Size == .(40, 20));
		host.PerformLayout(); Test.Assert(panel.Size == .(80, 60));
	}

	private static void VerifyTextMeasurement(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let label = scope Label(); label.Text = "one two three four five six seven eight nine ten"; label.AutoEllipsis = true;
		let original = label.Size;
		let natural = label.PreferredSize; let wrapped = label.GetPreferredSize(.(60, 0));
		Test.Assert(natural.width > 60 && wrapped.height > natural.height);
		Test.Assert(label.Size == original && !label.AutoSize && label.AutoEllipsis && !label.IsHandleCreated);
		let editor = scope TextBox(); editor.Size = .(200, 90); editor.Text = "A long editor line";
		Test.Assert(editor.PreferredSize.height == editor.Size.height && editor.PreferredSize.width > 0);
		Test.Assert(editor.GetPreferredSize(.(10, 5)) == editor.PreferredSize && editor.Size.width == 200);
		Test.Assert(Application.CreatedControlCount == 0);
	}

	[Test] public static void SDLPreferredTextMeasurementHonorsWidthWithoutCreatingWindows() => VerifyTextMeasurement(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativePreferredTextMeasurementHonorsWidthWithoutCreatingWindows() => VerifyTextMeasurement(.Win32);
#endif

	private static void VerifyCreatedContainers(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(500, 300);
		let panel = new Panel(); panel.AutoSizeMode = .GrowAndShrink; panel.AutoSize = true; panel.BorderStyle = .FixedSingle;
		let label = new Label(); label.AutoSize = true; label.Text = "Short"; label.Location = .(5, 7);
		panel.Controls.Add(label); form.Controls.Add(panel); form.Show();
		Test.Assert(panel.Size == .(label.Size.width + 7, label.Size.height + 9));
		let previous = panel.Size;
		label.Text = "A much longer label grows the containing panel";
		Test.Assert(panel.Size.width > previous.width && panel.Size.height == previous.height);
		label.Font = new Font("Segoe UI", 24);
		Test.Assert(panel.Size.height > previous.height);
		panel.AutoScroll = true; panel.ScrollPosition = .(100, 100);
		Test.Assert(panel.ScrollPosition == .(0, 0) && !panel.HorizontalScrollVisible && !panel.VerticalScrollVisible);
		form.Close(); Test.Assert(Application.CreatedControlCount == 0);
	}

	[Test] public static void SDLAutoSizeTracksTextFontBordersAndScrollingAfterShow() => VerifyCreatedContainers(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeAutoSizeTracksTextFontBordersAndScrollingAfterShow() => VerifyCreatedContainers(.Win32);
#endif

	private static void VerifyForm(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(200, 100); form.AutoSizeMode = .GrowAndShrink; form.AutoSize = true;
		let child = new Control(); child.Location = .(10, 15); child.Size = .(160, 80); form.Controls.Add(child);
		form.Show();
		Test.Assert(form.ClientSize.width >= 170 && form.ClientSize.height >= 95);
		let previous = form.Size;
		child.Size = .(360, 180); Test.Assert(form.Size.width > previous.width && form.Size.height > previous.height);
		child.Size = .(160, 80); Test.Assert(form.Size == previous);
		let pinned = new Control(); pinned.Size = .(40, 20);
		pinned.Location = .(form.LayoutSize.width - 50, form.LayoutSize.height - 30); pinned.Anchor = .Right | .Bottom;
		form.Controls.Add(pinned);
		child.Size = .(500, 300);
		Test.Assert(pinned.Location == .(form.LayoutSize.width - 50, form.LayoutSize.height - 30));
		form.MinimumSize = .(400, 260); form.PerformLayout(); Test.Assert(form.Size.width >= 400 && form.Size.height >= 260);
		form.Close(); Test.Assert(Application.CreatedControlCount == 0);
	}

	[Test] public static void SDLFormsAutoSizeTheirClientContentAndRespectTheirMinimumSize() => VerifyForm(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeFormsAutoSizeTheirClientContentAndRespectTheirMinimumSize() => VerifyForm(.Win32);
#endif
}
