using System;
using System.Drawing;
using System.Windows.Forms;
using BeefForms.Backends;

using internal BeefForms.Backends;
using internal System.Windows.Forms;

namespace BeefForms.Tests;

class AutoSizeReviewTests
{
	private class TextSizedControl : Control
	{
		public override Size GetPreferredSize(Size proposedSize) => .((int32)Text.Length * 10, 30);
	}
	private class OscillatingPanel : Panel
	{
		public bool Oscillate;
		public int Queries;
		public override Size GetPreferredSize(Size proposedSize)
		{
			Queries++;
			return .(Oscillate && Queries % 2 == 0 ? 120 : 80, 30);
		}
	}
	private class OscillatingForm : Form
	{
		public bool Oscillate;
		public int Queries;
		public override Size GetPreferredSize(Size proposedSize)
		{
			Queries++;
			return .(Oscillate && Queries % 2 == 0 ? 240 : 200, 100);
		}
	}

	private static void VerifySibling(Control parent)
	{
		let first = new TextSizedControl(); first.Margin = .Empty; first.AutoSize = true; first.Text = "abc";
		let second = new TextSizedControl(); second.Margin = .Empty; second.AutoSize = true; second.Text = "b"; second.Location = .(0, 60);
		parent.Controls.Add(first); parent.Controls.Add(second);
		second.SizeChanged.Add(new (sender, args) => first.Text = "abcdefgh");
		second.Text = "bb";
		Test.Assert(first.Size == .(80, 30) && second.Size == .(20, 30));
	}

	[Test]
	public static void DeferredLayoutResizesAnAlreadyProcessedSibling()
	{
		let parent = scope Panel(); parent.Size = .(300, 200);
		VerifySibling(parent);
	}
	private static void VerifyCreatedSibling(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(300, 200); form.Show();
		VerifySibling(form);
		form.Close(); Test.Assert(Application.CreatedControlCount == 0);
	}
	[Test] public static void SDLFormsKeepDeferredSiblingRequests() => VerifyCreatedSibling(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeFormsKeepDeferredSiblingRequests() => VerifyCreatedSibling(.Win32);
#endif

	[Test]
	public static void OscillatingPreferredSizesYieldAndCanSettleOnALaterRequest()
	{
		let host = scope Panel();
		let child = new OscillatingPanel(); child.AutoSizeMode = .GrowAndShrink; child.AutoSize = true; host.Controls.Add(child);
		child.Oscillate = true; let before = child.Queries;
		host.PerformLayout();
		Test.Assert(child.Queries > before && child.Queries - before < 128);
		child.Oscillate = false; host.PerformLayout();
		Test.Assert(child.Size == .(80, 30));
	}

	[Test]
	public static void OscillatingSizeChangedCallbacksYieldAndCanRecover()
	{
		let host = scope Panel();
		let panel = new Panel(); panel.Margin = .Empty; panel.AutoSize = true; panel.AutoSizeMode = .GrowAndShrink;
		let child = new Control(); child.Margin = .Empty; child.Size = .(80, 30); panel.Controls.Add(child); host.Controls.Add(panel);
		bool oscillate = true; int changes = 0;
		panel.SizeChanged.Add(new [&] (sender, args) =>
		{
			changes++;
			if (oscillate) child.Size = .(child.Size.width == 80 ? 120 : 80, 30);
		});
		child.Size = .(120, 30);
		Test.Assert(changes > 1 && changes < 128);
		oscillate = false; child.Size = .(80, 30); host.PerformLayout();
		Test.Assert(panel.Size == .(80, 30));
	}

	private static void VerifyOscillatingForm(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope OscillatingForm(); form.AutoSizeMode = .GrowAndShrink; form.AutoSize = true; form.Show();
		form.Oscillate = true; let before = form.Queries;
		form.PerformLayout();
		Test.Assert(form.Queries > before && form.Queries - before < 128);
		form.Oscillate = false; form.PerformLayout(); Test.Assert(form.Size == .(200, 100));
		form.Close(); Test.Assert(Application.CreatedControlCount == 0);
	}
	[Test] public static void SDLAutoSizeFormsBoundOscillatingPreferredSizes() => VerifyOscillatingForm(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeAutoSizeFormsBoundOscillatingPreferredSizes() => VerifyOscillatingForm(.Win32);
#endif

	private static void VerifyLabelAnchors(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let parent = scope Panel(); parent.Size = .(500, 300);
		let label = new Label(); label.Margin = .Empty; label.Location = .(100, 100); label.Text = "Short"; label.AutoSize = true;
		label.Anchor = .Right | .Bottom; parent.Controls.Add(label);
		let before = label.Size;
		label.Text = "A much longer label";
		Test.Assert(label.Size.width > before.width && label.Location == .(100, 100));
		label.Font = new Font("Segoe UI", 24);
		Test.Assert(label.Size.height > before.height && label.Location == .(100, 100));
		parent.Size = .(600, 400);
		Test.Assert(label.Location == .(200, 200) && !label.IsHandleCreated);
	}
	[Test] public static void SDLIntrinsicLabelGrowthMatchesWinFormsAnchorBehavior() => VerifyLabelAnchors(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeIntrinsicLabelGrowthMatchesWinFormsAnchorBehavior() => VerifyLabelAnchors(.Win32);
#endif

	private static void VerifyGroupBox(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let parent = scope Panel();
		let group = new GroupBox(); group.AutoSize = true; group.AutoSizeMode = .GrowAndShrink; group.Text = "Caption";
		parent.Controls.Add(group);
		let height = Application.Backend.GetFontHeight(group);
		Test.Assert(group.PreferredSize == .(0, height) && group.Size == group.PreferredSize);
		group.Text = "A much longer caption does not impose a preferred width in WinForms";
		Test.Assert(group.PreferredSize == .(0, height));
		let child = new Control(); child.Margin = .Empty; child.Location = .(10, 15); child.Size = .(40, 20); group.Controls.Add(child);
		Test.Assert(group.PreferredSize == .(50, 35 + height) && group.Size == group.PreferredSize);
		group.Font = new Font("Segoe UI", 24);
		Test.Assert(group.Size.height > 35 + height && group.Size == group.PreferredSize);
		Test.Assert(!group.IsHandleCreated && Application.CreatedControlCount == 0);
	}
	[Test] public static void SDLGroupBoxPreferredSizeReservesTheTitleBand() => VerifyGroupBox(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeGroupBoxPreferredSizeReservesTheTitleBand() => VerifyGroupBox(.Win32);
#endif

	[Test]
	public static void SDLPreferredSizeIgnoresDisplayEllipsisAndKeepsTheStoredText()
	{
		Application.UseBackend(.SDL2OpenGL);
		let label = scope Label(); label.Size = .(40, 30); label.AutoEllipsis = true; label.Text = "A much longer caption than the displayed label";
		let backend = (SDLBackend)Application.Backend;
		let display = scope String(); backend.TextService.GetDisplayText(label, display);
		Test.Assert(display != label.Text && display.EndsWith("..."));
		let preferred = label.PreferredSize;
		Test.Assert(preferred.width > label.Size.width && preferred.width > backend.MeasureText(label).width);
		label.AutoEllipsis = false; Test.Assert(label.PreferredSize == preferred);
		Test.Assert(label.Text == "A much longer caption than the displayed label" && !label.IsHandleCreated);
	}
}
