using System;
using System.Drawing;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class SDLEditorRenderingTests
{
	[Test]
	public static void CaretCyclesAreIndependentAndRestartVisible()
	{
		let first = scope TextBox();
		let second = scope TextBox();
		first.RestartCaretBlink(100);
		second.RestartCaretBlink(400);
		Test.Assert(first.IsCaretVisible(649) && !first.IsCaretVisible(650));
		Test.Assert(second.IsCaretVisible(650));
		Test.Assert(first.GetNextCaretTick(650) == 1100 && second.GetNextCaretTick(650) == 950);
		Test.Assert(!first.IsCaretVisible(1099) && first.IsCaretVisible(1100));
		first.RestartCaretBlink(700);
		Test.Assert(first.IsCaretVisible(700) && first.GetNextCaretTick(700) == 1250);
	}

	[Test]
	public static void MarqueeCyclesBelongToTheirControls()
	{
		let first = scope ProgressBar(); first.Style = .Marquee; first.MarqueeAnimationSpeed = 100;
		let second = scope ProgressBar(); second.Style = .Marquee; second.MarqueeAnimationSpeed = 100;
		first.RestartMarquee(100);
		second.RestartMarquee(150);
		Test.Assert(first.GetMarqueeStep(300) == 2 && second.GetMarqueeStep(300) == 1);
		Test.Assert(first.GetNextMarqueeTick(300) == 400 && second.GetNextMarqueeTick(300) == 350);
		first.MarqueeAnimationSpeed = 0;
		Test.Assert(first.GetNextMarqueeTick(300) == uint64.MaxValue);
	}

	private static void WithEditor<F>(F test) where F : delegate void(RichTextBox, TextBox, SDLBackend)
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(320, 180);
		let editor = new RichTextBox(); editor.Size = .(130, 70);
		let content = scope String();
		for (int row < 20)
		{
			for (int column < 60) content.Append('W');
			content.Append('\n');
		}
		content.Append("last line with a long ending WWWWWWWWWWWWWWWWWWWWW");
		editor.Text = content;
		let other = new TextBox(); other.Location = .(0, 100); other.Size = .(130, 25);
		form.Controls.Add(editor); form.Controls.Add(other); form.Show();
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend);
		editor.Focus(); editor.SetCaret(editor.Text.Length, false);
		backend.[Friend]RenderIfNeeded(true);
		Test.Assert(editor.ScrollX > 0 && editor.ScrollY > 0);
		test(editor, other, backend);
	}

	[Test]
	public static void RepaintsPreserveExplicitScrollUntilCaretMovement()
	{
		WithEditor(scope (editor, other, backend) =>
		{
			editor.SetScrollOffset(.(0, 0));
			backend.[Friend]RenderIfNeeded(true);
			Test.Assert(editor.ScrollX == 0 && editor.ScrollY == 0 && !editor.NeedsScrollPreparation);
			editor.Invalidate();
			backend.[Friend]RenderIfNeeded(true);
			Test.Assert(editor.ScrollX == 0 && editor.ScrollY == 0);
			editor.SetCaret(editor.Caret - 1, false);
			backend.[Friend]RenderIfNeeded(true);
			Test.Assert(editor.ScrollX > 0 && editor.ScrollY > 0);
		});
	}

	[Test]
	public static void UnfocusedTextReplacementClampsBothScrollAxes()
	{
		WithEditor(scope (editor, other, backend) =>
		{
			other.Focus();
			editor.Text = "short";
			backend.[Friend]RenderIfNeeded(true);
			Test.Assert(editor.ScrollX == 0 && editor.ScrollY == 0);
		});
	}

	[Test]
	public static void DeletingSelectionClampsScrollAndRevealsTheNewCaret()
	{
		WithEditor(scope (editor, other, backend) =>
		{
			editor.SelectAll(); editor.ReplaceSelection("x");
			backend.[Friend]RenderIfNeeded(true);
			Test.Assert(editor.Caret == 1 && editor.ScrollX == 0 && editor.ScrollY == 0);
		});
	}

	[Test]
	public static void GeometryChangesClampWithoutRequestingCaretReveal()
	{
		WithEditor(scope (editor, other, backend) =>
		{
			editor.SetScrollOffset(.(0, 0));
			backend.[Friend]RenderIfNeeded(true);
			editor.Size = .(110, 60);
			editor.Font = new System.Drawing.Font("Segoe UI", 16);
			backend.[Friend]RenderIfNeeded(true);
			Test.Assert(editor.ScrollX == 0 && editor.ScrollY == 0);
			editor.SetCaret(editor.Text.Length, false);
			backend.[Friend]RenderIfNeeded(true);
			Test.Assert(editor.ScrollX > 0 && editor.ScrollY > 0);
			editor.Size = .(2000, 2000);
			backend.[Friend]RenderIfNeeded(true);
			Test.Assert(editor.ScrollX == 0 && editor.ScrollY == 0);
		});
	}

	[Test]
	public static void TrailingEmptyLineIsIncludedInTheScrollRange()
	{
		WithEditor(scope (editor, other, backend) =>
		{
			editor.Text = "first\n\n";
			let lineHeight = backend.TextService.LineHeight(editor);
			editor.Size = .(130, lineHeight + 8);
			editor.SetCaret(editor.Text.Length, false);
			backend.[Friend]RenderIfNeeded(true);
			let caret = backend.TextService.TextPosition(editor, editor.Caret);
			Test.Assert(editor.ScrollY > 0 && caret.y + lineHeight - editor.ScrollY <= editor.Size.height - 8);
		});
	}

	[Test]
	public static void FocusTypingAndCaretMovementRestartBlinking()
	{
		WithEditor(scope (editor, other, backend) =>
		{
			editor.RestartCaretBlink(uint64.MaxValue);
			editor.SetCaret(editor.Caret - 1, false);
			Test.Assert(editor.[Friend]mCaretBlinkStartedAt <= SDL.GetTicks64());
			editor.RestartCaretBlink(uint64.MaxValue);
			SDLTestInput.TypeText(backend, "x");
			Test.Assert(editor.[Friend]mCaretBlinkStartedAt <= SDL.GetTicks64());
			other.Focus(); editor.RestartCaretBlink(uint64.MaxValue); editor.Focus();
			Test.Assert(editor.[Friend]mCaretBlinkStartedAt <= SDL.GetTicks64());
			SDLTestInput.SetActive(backend, false);
			editor.RestartCaretBlink(uint64.MaxValue);
			SDLTestInput.SetActive(backend, true);
			Test.Assert(editor.[Friend]mCaretBlinkStartedAt <= SDL.GetTicks64());
		});
	}
}
