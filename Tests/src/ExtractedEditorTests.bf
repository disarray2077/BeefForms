using System;
using System.Windows.Forms;
using BeefForms.Backends;

using internal BeefForms.Backends;
using internal System.Windows.Forms;

namespace BeefForms.Tests;

#if BF_DEPENDS_BEEFFORMS_SDL
class ExtractedEditorTests
{
	[Test]
	public static void DraftUsesTextInputKeyPreviewAndKeyPressBeforeChangingText()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.KeyPreview = true;
		let editor = new TextBox();
		editor.Text = "keep [] suffix";
		form.Controls.Add(editor);
		form.Show();
		let order = scope String();
		editor.TextInput.Add(new (sender, args) =>
		{
			Test.Assert(editor.Text == "keep [] suffix" && args.Text == "a!");
			args.Text.Set("b!");
			order.Append('T');
		});
		form.KeyPress.Add(new (sender, args) => order.Append('P'));
		editor.KeyPress.Add(new (sender, args) =>
		{
			order.Append('K');
			if (args.KeyChar == '!')
				args.Handled = true;
			else
				args.KeyChar = 'B';
		});
		editor.TextChanged.Add(new (sender, args) => order.Append('C'));
		let session = ((SDLBackend)Application.Backend).GetSession(form);
		session.ApplyExtractedDraft(editor, "keep [] suffix", "keep [a!] suffix");
		Test.Assert(editor.Text == "keep [B] suffix" && order == "TPKPKC");
		form.Close();
		Application.Backend.Run(form);
	}

	[Test]
	public static void RejectedDraftAndDeletionLeaveTextUnchanged()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		let editor = new TextBox();
		editor.Text = "original";
		form.Controls.Add(editor);
		form.Show();
		int changes = 0, deletionFilters = 0;
		editor.TextChanged.Add(new [&] (sender, args) => changes++);
		editor.TextInput.Add(new (sender, args) => args.Handled = true);
		editor.KeyPress.Add(new [&] (sender, args) =>
		{
			Test.Assert(args.KeyChar == '\b');
			deletionFilters++;
			args.Handled = true;
		});
		let session = ((SDLBackend)Application.Backend).GetSession(form);
		session.ApplyExtractedDraft(editor, "original", "replacement");
		session.ApplyExtractedDraft(editor, "original", "");
		Test.Assert(editor.Text == "original" && changes == 0 && deletionFilters == 1);
		form.Close();
		Application.Backend.Run(form);
	}

	[Test]
	public static void DraftHandlesUnicodeDeletionAndBrowserLineEndings()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		let editor = new TextBox();
		editor.Multiline = true;
		editor.Text = "©😀\r\nkeep";
		form.Controls.Add(editor);
		form.Show();
		let session = ((SDLBackend)Application.Backend).GetSession(form);
		session.ApplyExtractedDraft(editor, "©😀\r\nkeep", "é😀\nkeep");
		Test.Assert(editor.Text == "é😀\r\nkeep");
		session.ApplyExtractedDraft(editor, "é😀\r\nkeep", "é\nkeep");
		Test.Assert(editor.Text == "é\r\nkeep");
		session.ApplyExtractedDraft(editor, "é\r\nkeep", "");
		Test.Assert(editor.Text.IsEmpty);
		form.Close();
		Application.Backend.Run(form);
	}

	[Test]
	public static void DraftDoesNotOverwriteExternalChangesOrReadOnlyText()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		let editor = new TextBox();
		editor.Text = "updated";
		form.Controls.Add(editor);
		form.Show();
		let session = ((SDLBackend)Application.Backend).GetSession(form);
		session.ApplyExtractedDraft(editor, "original", "draft");
		Test.Assert(editor.Text == "updated");
		editor.ReadOnly = true;
		session.ApplyExtractedDraft(editor, "updated", "draft");
		Test.Assert(editor.Text == "updated");
		editor.ReadOnly = false;
		editor.TextInput.Add(new (sender, args) => editor.Text = "handler owns the result");
		session.ApplyExtractedDraft(editor, "updated", "draft");
		Test.Assert(editor.Text == "handler owns the result");
		form.Close();
		Application.Backend.Run(form);
	}

	[Test]
	public static void ClosingFromDraftFilterStopsTheCommit()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		let editor = new TextBox();
		editor.Text = "original";
		form.Controls.Add(editor);
		form.Show();
		editor.KeyPress.Add(new (sender, args) => form.Close());
		let session = ((SDLBackend)Application.Backend).GetSession(form);
		using (session.Retain())
		{
			session.ApplyExtractedDraft(editor, "original", "draft");
		}
		Test.Assert(form.IsDisposed && editor.IsDisposed && editor.Text == "original");
		Application.Backend.Run(form);
	}
}
#endif
