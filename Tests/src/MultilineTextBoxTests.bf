using System;
using System.Drawing;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;
using BeefGL;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class MultilineTextBoxTests
{
	private static void VerifySizing(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let editor = scope TextBox();
		let rich = scope RichTextBox();
		Test.Assert(!editor.Multiline && editor.AutoSize && rich.Multiline && !rich.AutoSize);
		let initialHeight = editor.Size.height;
		editor.Multiline = true;
		Test.Assert(editor.Size.height == initialHeight);
		editor.Multiline = false;
		editor.Size = .(200, 90);
		let singleHeight = editor.Size.height;
		Test.Assert(singleHeight < 90);
		int changes = 0;
		editor.MultilineChanged.Add(new [&] (sender, args) =>
		{
			changes++;
			Test.Assert(editor.Size.height == (editor.Multiline ? 90 : singleHeight));
		});
		editor.Multiline = true;
		editor.Multiline = true;
		editor.Multiline = false;
		editor.Multiline = true;
		Test.Assert(changes == 3 && editor.Size == .(200, 90));
		editor.Text = "first\r\nsecond";
		let multiple = editor.PreferredSize;
		editor.Multiline = false;
		Test.Assert(editor.PreferredSize.height < multiple.height && editor.Text == "first\r\nsecond");
		editor.AutoSizeChanged.Add(new [&] (sender, args) => Test.Assert(editor.Size == .(200, 90)));
		editor.AutoSize = false;
		Test.Assert(editor.Size == .(200, 90));
		Test.Assert(!editor.IsHandleCreated && !rich.IsHandleCreated);
	}

	[Test] public static void SDLMultilineRestoresRequestedHeightWithoutCreatingHandles() => VerifySizing(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeMultilineRestoresRequestedHeightWithoutCreatingHandles() => VerifySizing(.Win32);
#endif

	private static void VerifyProposedSize(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let editor = scope TextBox(); editor.Multiline = true;
		editor.Text = "one two three four five six seven eight nine ten";
		for (let style in scope BorderStyle[](.FixedSingle, .Fixed3D))
		{
			editor.BorderStyle = style;
			let border = editor.BorderWidth * 2;
			editor.BorderStyle = .None;
			let content = editor.GetPreferredSize(.(100 - border, 0));
			editor.BorderStyle = style;
			let bordered = editor.GetPreferredSize(.(100, 0));
			Test.Assert(bordered == .(content.width + border, content.height + border));
			Test.Assert(bordered.width <= 100 && bordered.height > editor.PreferredSize.height);
		}
		Test.Assert(!editor.IsHandleCreated);
	}

	[Test] public static void SDLMultilinePreferredSizeReservesBordersInsideTheProposal() => VerifyProposedSize(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeMultilinePreferredSizeReservesBordersInsideTheProposal() => VerifyProposedSize(.Win32);
#endif

	private static void VerifyModeChange(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(320, 180);
		let editor = new TextBox(); editor.Size = .(220, 100); editor.Text = "aé😀\r\nz";
		form.Controls.Add(editor); form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		if (let sdl = Application.Backend as SDLBackend) SDLTestInput.Activate(sdl);
		editor.Focus(); editor.Select(1, 3);
		int textChanges = 0;
		editor.TextChanged.Add(new [&] (sender, args) => textChanges++);
		for (int iteration < 2)
		{
			let generation = editor.HandleGeneration;
			editor.Multiline = !editor.Multiline;
			Test.Assert(editor.IsHandleCreated && editor.Created && editor.Focused);
			Test.Assert(editor.Text == "aé😀\r\nz" && editor.SelectionStart == 1 && editor.SelectionLength == 3);
			Test.Assert(editor.Size.height == (editor.Multiline ? 100 : Application.Backend.GetTextBoxHeight(editor)));
#if BF_PLATFORM_WINDOWS
			if (backend == .Win32)
			{
				Test.Assert(!editor.HandleGeneration.IsCurrent(generation));
				let style = (uint)(void*)Win32.GetWindowLongPtr(editor.Handle, Win32.GWL_STYLE);
				Test.Assert(((style & Win32.ES_MULTILINE) != 0) == editor.Multiline);
				let selection = (uint)(void*)Win32.SendMessage(editor.Handle, Win32.EM_GETSEL, null, null);
				Test.Assert((selection & 0xFFFF) == 1 && (selection >> 16) == 4);
			}
#endif
		}
		Test.Assert(textChanges == 0);
		editor.Hide(); editor.Multiline = true;
		Test.Assert(editor.IsHandleCreated && !editor.Visible && editor.SelectionStart == 1 && editor.SelectionLength == 3);
	}

	[Test] public static void SDLModeChangesPreserveTextSelectionAndFocus() => VerifyModeChange(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeModeChangesPreserveTextSelectionAndFocus() => VerifyModeChange(.Win32);
#endif

	private static void Key(SDLBackend backend, SDL.Keycode key, SDL.KeyMod modifiers = 0)
	{
		SDL.Event input = .(); input.type = .KeyDown;
		input.key.keysym.sym = key; input.key.keysym.mod = modifiers;
		SDLTestInput.PushEvent(ref input); backend.ProcessEvents();
	}

	[Test]
	public static void SDLMultilineEditingNavigatesAndDeletesCRLFPairs()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(320, 180);
		let editor = new TextBox(); editor.Multiline = true; editor.Size = .(220, 100);
		form.Controls.Add(editor); form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend); editor.Focus();
		SDLTestInput.TypeText(backend, "abc"); Key(backend, .RETURN); SDLTestInput.TypeText(backend, "def");
		Test.Assert(editor.Text == "abc\r\ndef" && editor.SelectionStart == 8);
		Key(backend, .HOME); Test.Assert(editor.SelectionStart == 5);
		Key(backend, .LEFT); Test.Assert(editor.SelectionStart == 3);
		Key(backend, .RIGHT); Test.Assert(editor.SelectionStart == 5);
		Key(backend, .BACKSPACE); Test.Assert(editor.Text == "abcdef" && editor.SelectionStart == 3);
		Key(backend, .RETURN); Key(backend, .HOME); Key(backend, .UP);
		Test.Assert(editor.SelectionStart == 0);
		Key(backend, .END); Test.Assert(editor.SelectionStart == 3);
		Key(backend, .DOWN); Test.Assert(editor.SelectionStart == 8);
		Key(backend, .HOME, .CTRL); Test.Assert(editor.SelectionStart == 0);
		Key(backend, .END, .CTRL | .SHIFT); Test.Assert(editor.SelectionStart == 0 && editor.SelectionLength == 8);
		editor.Select(3, 0); Key(backend, .DELETE);
		Test.Assert(editor.Text == "abcdef" && editor.SelectionStart == 3);
		let deadline = SDL.GetTicks64() + 1000;
		// Other applications can briefly hold the system clipboard. SDL 2.26
		// reports an empty read in that case, so retry only an unchanged edit.
		repeat
		{
			if (SDL.SetClipboardText("x\r\ny") == 0)
				Key(backend, .V, .CTRL);
			if (editor.Text != "abcdef")
				break;
			SDL.Delay(1);
		}
		while (SDL.GetTicks64() < deadline);
		Test.Assert(editor.Text == "abcx\r\nydef");
		editor.ReadOnly = true; Key(backend, .RETURN); Test.Assert(editor.Text == "abcx\r\nydef");
		editor.ReadOnly = false;
		bool handled = true;
		editor.KeyPress.Add(new [&] (sender, args) =>
		{
			if (args.KeyChar == '\r') { args.Handled = handled; args.KeyChar = '!'; }
		});
		Key(backend, .RETURN); Test.Assert(editor.Text == "abcx\r\nydef");
		handled = false; Key(backend, .RETURN); Test.Assert(editor.Text == "abcx\r\ny!def");
	}

	[Test]
	public static void SDLSingleLineIgnoresEnterAndVerticalNavigation()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form(); form.ClientSize = .(320, 180);
		let editor = new TextBox(); editor.Size = .(220, 100); editor.Text = "a\r\nb";
		form.Controls.Add(editor); form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend); editor.Focus(); editor.Select(2, 0);
		Key(backend, .UP); Key(backend, .DOWN); Key(backend, .RETURN);
		Test.Assert(editor.SelectionStart == 2 && editor.Text == "a\r\nb");
		Key(backend, .HOME); Test.Assert(editor.SelectionStart == 0);
		Key(backend, .END); Test.Assert(editor.SelectionStart == 4);
		let display = scope String(); backend.TextService.GetDisplayText(editor, display);
		Test.Assert(display == "a  b" && backend.TextService.TextPosition(editor, 4).y == 0);
	}

	[Test]
	public static void SDLModeChangesLeaveAnotherWindowsTexturesIntact()
	{
		Application.UseBackend(.SDL2OpenGL, render: true);
		let first = scope Form(); first.ClientSize = .(240, 140);
		let second = scope Form(); second.ClientSize = first.ClientSize;
		let editor = new TextBox(); editor.Multiline = true; editor.Size = .(200, 100); editor.Text = "first\r\nsecond";
		let other = new TextBox(); other.Multiline = true; other.Size = editor.Size; other.Text = editor.Text;
		first.Controls.Add(editor); second.Controls.Add(other);
		first.Show(); second.Show();
		defer { first.Close(); second.Close(); }
		let backend = (SDLBackend)Application.Backend;
		backend.[Friend]RenderIfNeeded(true);
		let session = backend.GetSession(second);
		session.MakeCurrent(); defer SDL.GL_MakeCurrent(null, default);
		let context = SDL.GL_GetCurrentContext();
		let image = session.[Friend]mTextRenderer.[Friend]mText[other].Image.Handle;
		editor.Multiline = false;
		Test.Assert(SDL.GL_GetCurrentContext() == context && GL.glIsTexture(image) == 1);
		backend.[Friend]RenderIfNeeded(true);
		Test.Assert(SDL.GL_GetCurrentContext() == context && GL.glIsTexture(image) == 1);
		Test.Assert(GL.glGetError() == GL.GL_NO_ERROR);
	}

	[Test]
	public static void SDLMultilineMeasurementHitTestingAndScrollingUseTheSameLines()
	{
		Application.UseBackend(.SDL2OpenGL, render: true);
		let form = scope Form(); form.ClientSize = .(320, 180);
		let editor = new TextBox(); editor.Multiline = true; editor.Size = .(120, 40); editor.Text = "abc\r\ndef\r\n";
		form.Controls.Add(editor); form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		let backend = (SDLBackend)Application.Backend;
		SDLTestInput.Activate(backend); editor.Focus();
		let service = backend.TextService;
		let display = scope String(); service.GetDisplayText(editor, display);
		Test.Assert(display == "abc\ndef\n");
		let lineHeight = service.LineHeight(editor);
		Test.Assert(service.TextPosition(editor, 3).x == service.TextPosition(editor, 4).x);
		Test.Assert(service.TextPosition(editor, 5) == .(0, lineHeight));
		Test.Assert(service.TextPosition(editor, 10) == .(0, lineHeight * 2));
		let inset = SDLTextService.EditorTextInset - editor.BorderWidth;
		Test.Assert(service.HitText(editor, inset, inset + lineHeight) == 5);
		Test.Assert(service.HitText(editor, 1000, inset) == 3);
		editor.Select(10, 0); backend.[Friend]RenderIfNeeded(true);
		Test.Assert(editor.ScrollY > 0);
		let renderer = backend.GetSession(form).[Friend]mTextRenderer;
		let multilineHeight = renderer.[Friend]mText[editor].Height;
		editor.Multiline = false; backend.[Friend]RenderIfNeeded(true);
		Test.Assert(editor.ScrollY == 0);
		Test.Assert(renderer.[Friend]mText[editor].Height < multilineHeight);
		service.GetDisplayText(editor, display); Test.Assert(display == "abc  def  ");
		SDLTestInput.AssertNoGLError(form);
	}

#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeMultilineAcceptsEnterAndReadOnlyPreventsEditing()
	{
		Application.UseBackend(.Win32);
		let form = scope Form(); form.ClientSize = .(320, 180);
		let editor = new TextBox(); editor.Multiline = true; editor.Size = .(220, 100); editor.Text = "ab";
		form.Controls.Add(editor); form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		editor.Focus(); editor.Select(1, 0);
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)13, null);
		Test.Assert(editor.Text == "a\r\nb" && editor.SelectionStart == 3);
		editor.ReadOnly = true;
		Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)13, null);
		Test.Assert(editor.Text == "a\r\nb");
	}
#endif
}
