using System;
using System.Collections;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class TextChangeTests
{
	[Test]
	public static void UncreatedAssignmentRestoresSelectionAfterTextRegrows()
	{
		let editor = scope TextBox();
		editor.Text = "abcdef"; editor.Select(4, 2);
		editor.Text = "x";
		Test.Assert(editor.SelectionStart == 1 && editor.SelectionLength == 0);
		editor.Text = "abcdef";
		Test.Assert(editor.SelectionStart == 4 && editor.SelectionLength == 2 && !editor.IsHandleCreated);
	}

	[Test]
	public static void UncreatedSelectionCacheUsesUTF16AcrossTextReplacements()
	{
		let editor = scope TextBox();
		editor.Text = "aé😀z"; editor.Select(2, 3);
		editor.Text = "é";
		Test.Assert(editor.SelectionStart == 1 && editor.SelectionLength == 0);
		editor.Text = "aé😀z";
		Test.Assert(editor.SelectionStart == 2 && editor.SelectionLength == 3);
		editor.Text = "x"; editor.Select(0, 1);
		editor.Text = "aé😀z";
		Test.Assert(editor.SelectionStart == 0 && editor.SelectionLength == 1);
	}

	private static void VerifyCreatedSelectionCache(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let editor = new TextBox(); form.Controls.Add(editor);
		editor.Text = "abcdef"; editor.Select(4, 2); editor.Text = "x";
		form.Show();
		// Once created, assigning different text resets the native selection.
		editor.Text = "abcdef";
		Test.Assert(editor.SelectionStart == 0 && editor.SelectionLength == 0);
		form.Close();
	}

	[Test] public static void SDLCreatedAssignmentDoesNotRestoreTheUncreatedSelection() => VerifyCreatedSelectionCache(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeCreatedAssignmentDoesNotRestoreTheUncreatedSelection() => VerifyCreatedSelectionCache(.Win32);
#endif

	private static void VerifySelectionAfterHandleDestruction(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let editor = new TextBox(); form.Controls.Add(editor);
		editor.Text = "abcdef"; editor.Select(4, 2); editor.Text = "x";
		form.Show();
		editor.[Friend]DestroyHandle();
		editor.Text = "abcdef";
		Test.Assert(!editor.IsHandleCreated && editor.SelectionStart == 1 && editor.SelectionLength == 0);
		form.Close();
	}

	[Test] public static void SDLHandleCreationCommitsTheClampedSelection() => VerifySelectionAfterHandleDestruction(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeHandleCreationCommitsTheClampedSelection() => VerifySelectionAfterHandleDestruction(.Win32);
#endif

	// Expected text/selection states were captured with .NET 9.0.4 WinForms.
	private class Snapshot
	{
		public String Text ~ delete _;
		public int Start, Length;
		public this(TextBox editor)
		{
			Text = new .(editor.Text);
			Start = editor.SelectionStart;
			Length = editor.SelectionLength;
#if BF_PLATFORM_WINDOWS
			if (Application.Backend is Win32Backend && editor.IsHandleCreated)
			{
				uint32 start = 0, end = 0;
				Win32.SendMessage(editor.Handle, Win32.EM_GETSEL, (uint*)&start, (int*)&end);
				Test.Assert(start == Start && end == Start + Length);
			}
#endif
		}
		public void AssertState(StringView text, int start, int length)
		{
			Test.Assert(Text == text && Start == start && Length == length);
		}
	}

	private class ProbeEditor : TextBox
	{
		public List<Snapshot> Changes = new .() ~ DeleteContainerAndItems!(_);
		private bool mRecording;
		public this()
		{
			TextChanged.Add(new (sender, args) =>
			{
				let editor = (ProbeEditor)sender;
				if (editor.mRecording) editor.Changes.Add(new .(editor));
			});
		}
		public void Prepare(String text, int start, int length)
		{
			mRecording = false;
			Text = text;
			Select(start, length);
			ClearAndDeleteItems(Changes);
			mRecording = true;
		}
		public void AssertChange(StringView text, int start, int length)
		{
			Test.Assert(Changes.Count == 1);
			Changes[0].AssertState(text, start, length);
			let current = scope Snapshot(this);
			current.AssertState(text, start, length);
		}
	}

	private static void WithEditor<F>(ApplicationBackend backend, F test) where F : delegate void(ProbeEditor)
	{
		Application.UseBackend(backend);
		let form = scope Form();
		form.ClientSize = .(300, 150);
		let editor = new ProbeEditor();
		editor.Size = .(200, 30);
		form.Controls.Add(editor);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		if (let sdl = Application.Backend as SDLBackend) SDLTestInput.Activate(sdl);
		editor.Focus();
		test(editor);
	}

	private static void VerifyReplacement(ProbeEditor editor)
	{
		editor.Prepare("abcd", 1, 2);
		editor.ReplaceSelection("X");
		editor.AssertChange("aXd", 2, 0);
		editor.Prepare("aé😀z", 0, 5);
		editor.ReplaceSelection("😀");
		editor.AssertChange("😀", 2, 0);
		editor.Prepare("aé😀z", 1, 3);
		editor.ReplaceSelection("");
		editor.AssertChange("az", 1, 0);
	}

	[Test]
	public static void UncreatedReplacementCommitsSelectionBeforeTextChanged()
	{
		let editor = scope ProbeEditor();
		VerifyReplacement(editor);
	}
	[Test]
	public static void SDLReplacementCommitsSelectionBeforeTextChanged() => WithEditor(.SDL2OpenGL, => VerifyReplacement);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeReplacementCommitsSelectionBeforeTextChanged() => WithEditor(.Win32, => VerifyReplacement);
#endif

	private static void VerifyAssignment(ProbeEditor editor)
	{
		let created = editor.IsHandleCreated;
		editor.Prepare("aé😀z", 2, 3);
		editor.Text = "é";
		editor.AssertChange("é", created ? 0 : 1, 0);
		editor.Prepare("aé😀z", 2, 2);
		editor.Text = "éééé";
		editor.AssertChange("éééé", created ? 0 : 2, created ? 0 : 2);
		editor.Prepare("abcd", 1, 2);
		editor.Text = "abcd";
		Test.Assert(editor.Changes.IsEmpty && editor.SelectionStart == 1 && editor.SelectionLength == 2);
	}

	[Test]
	public static void UncreatedAssignmentClampsUTF16SelectionBeforeTextChanged()
	{
		let editor = scope ProbeEditor();
		VerifyAssignment(editor);
	}
	[Test]
	public static void SDLAssignmentResetsSelectionBeforeTextChanged() => WithEditor(.SDL2OpenGL, => VerifyAssignment);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeAssignmentResetsSelectionBeforeTextChanged() => WithEditor(.Win32, => VerifyAssignment);
#endif

	private static void VerifyReentrantSelection(ProbeEditor editor)
	{
		editor.Prepare("abcd", 1, 2);
		editor.TextChanged.Add(new (sender, args) => { ((TextBox)sender).Select(0, 1); });
		editor.ReplaceSelection("X");
		Test.Assert(editor.Changes.Count == 1);
		editor.Changes[0].AssertState("aXd", 2, 0);
		let current = scope Snapshot(editor);
		current.AssertState("aXd", 0, 1);
	}

	[Test]
	public static void SDLReplacementPreservesSelectionChosenByTextChanged() => WithEditor(.SDL2OpenGL, => VerifyReentrantSelection);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeReplacementPreservesSelectionChosenByTextChanged() => WithEditor(.Win32, => VerifyReentrantSelection);
#endif

	private static void VerifyReentrantText(ProbeEditor editor)
	{
		editor.Prepare("abcd", 1, 2);
		editor.TextChanged.Add(new (sender, args) =>
		{
			let target = (ProbeEditor)sender;
			if (target.Changes.Count == 1)
			{
				target.Text = "é";
				target.Select(1, 0);
			}
		});
		editor.ReplaceSelection("X");
		Test.Assert(editor.Changes.Count == 2);
		editor.Changes[0].AssertState("aXd", 2, 0);
		editor.Changes[1].AssertState("é", 0, 0);
		let current = scope Snapshot(editor);
		current.AssertState("é", 1, 0);
	}

	[Test]
	public static void SDLReplacementPreservesTextChosenByTextChanged() => WithEditor(.SDL2OpenGL, => VerifyReentrantText);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeReplacementPreservesTextChosenByTextChanged() => WithEditor(.Win32, => VerifyReentrantText);
#endif

	private static void VerifyIdenticalReplacement(ProbeEditor editor)
	{
		editor.Prepare("abcd", 1, 2);
		editor.ReplaceSelection("bc");
		editor.AssertChange("abcd", 3, 0);
	}
	[Test]
	public static void SDLIdenticalReplacementNotifiesWithCollapsedSelection() => WithEditor(.SDL2OpenGL, => VerifyIdenticalReplacement);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeIdenticalReplacementNotifiesWithCollapsedSelection() => WithEditor(.Win32, => VerifyIdenticalReplacement);
#endif

	private static void TypeText(ProbeEditor editor, String text)
	{
		if (let sdl = Application.Backend as SDLBackend) SDLTestInput.TypeText(sdl, text);
#if BF_PLATFORM_WINDOWS
		else
		{
			let units = text.ToScopedNativeWChar!();
			for (var cursor = units; *cursor != 0; cursor++)
				Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)(uint)(*cursor), null);
		}
#endif
	}

	private static void Backspace(ProbeEditor editor)
	{
		if (let sdl = Application.Backend as SDLBackend)
		{
			SDL.Event input = .();
			input.type = .KeyDown;
			input.key.keysym.sym = .BACKSPACE;
			SDLTestInput.SetWindow(ref input, (Form)editor.Parent);
			sdl.[Friend]ProcessEvent(ref input);
		}
#if BF_PLATFORM_WINDOWS
		else
		{
			Win32.SendMessage(editor.Handle, Win32.WM_KEYDOWN, (uint*)(void*)(uint)Keys.Back, null);
			Win32.SendMessage(editor.Handle, Win32.WM_CHAR, (uint*)(void*)8, null);
		}
#endif
	}

	private static void VerifyInput(ProbeEditor editor)
	{
		editor.Prepare("aé😀z", 0, 5);
		TypeText(editor, "😀");
		editor.AssertChange("😀", 2, 0);
		editor.Prepare("abcd", 1, 1);
		TypeText(editor, "b");
		editor.AssertChange("abcd", 2, 0);
		editor.Prepare("aé😀z", 1, 3);
		Backspace(editor);
		editor.AssertChange("az", 1, 0);
		editor.Prepare("abcd", 0, 0);
		Backspace(editor);
		Test.Assert(editor.Changes.IsEmpty && editor.Text == "abcd" && editor.SelectionStart == 0);
	}

	[Test]
	public static void SDLInputCommitsTextAndSelectionTogether() => WithEditor(.SDL2OpenGL, => VerifyInput);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeInputCommitsTextAndSelectionTogether() => WithEditor(.Win32, => VerifyInput);
#endif

	private static void VerifyInputReentrancy(ProbeEditor editor)
	{
		editor.Prepare("abcd", 1, 2);
		editor.TextChanged.Add(new (sender, args) =>
		{
			let target = (ProbeEditor)sender;
			if (target.Changes.Count == 1) target.Text = "";
		});
		TypeText(editor, "X");
		Test.Assert(editor.Changes.Count == 2);
		editor.Changes[0].AssertState("aXd", 2, 0);
		editor.Changes[1].AssertState("", 0, 0);
		let current = scope Snapshot(editor);
		current.AssertState("", 0, 0);
	}

	[Test]
	public static void SDLInputPreservesTextChangedReentrantEdits() => WithEditor(.SDL2OpenGL, => VerifyInputReentrancy);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeInputPreservesTextChangedReentrantEdits() => WithEditor(.Win32, => VerifyInputReentrancy);
#endif

	private static void VerifyBackspaceFiltering(ProbeEditor editor)
	{
		bool cancel = true, replace = false;
		let events = scope String();
		editor.KeyDown.Add(new (sender, args) => { events.Append('D'); });
		editor.KeyPress.Add(new [&] (sender, args) =>
		{
			events.Append('K');
			Test.Assert(args.KeyChar == '\b');
			args.Handled = cancel;
			if (replace) args.KeyChar = 'X';
		});
		editor.TextChanged.Add(new (sender, args) => { events.Append('C'); });
		editor.Prepare("aé😀z", 1, 3);
		events.Clear();
		Backspace(editor);
		Test.Assert(events == "DK" && editor.Changes.IsEmpty);
		Test.Assert(editor.Text == "aé😀z" && editor.SelectionStart == 1 && editor.SelectionLength == 3);
		cancel = false;
		Backspace(editor);
		Test.Assert(events == "DKDKC");
		editor.AssertChange("az", 1, 0);
		editor.Prepare("aé😀z", 1, 3);
		events.Clear();
		replace = true;
		Backspace(editor);
		Test.Assert(events == "DKC");
		editor.AssertChange("aXz", 2, 0);
	}

	[Test]
	public static void SDLBackspaceHonorsKeyPressCancellationAndReplacement() => WithEditor(.SDL2OpenGL, => VerifyBackspaceFiltering);
#if BF_PLATFORM_WINDOWS
	[Test]
	public static void NativeBackspaceHonorsKeyPressCancellationAndReplacement() => WithEditor(.Win32, => VerifyBackspaceFiltering);
#endif
}
