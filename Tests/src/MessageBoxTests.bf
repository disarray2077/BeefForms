using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

#if BF_PLATFORM_WINDOWS
class MessageBoxTests
{
	private const StringView Caption = "BeefForms message box test — 😀";
	private static delegate void(void*) sInspect;
	private static int sTicks;
	private static bool sHandled;

	[Import("user32.dll"), CLink]
	private static extern void* GetDlgItem(void* window, int32 id);

	// The native modal loop dispatches this timer on the test thread.
	private static DialogResult ShowAndInspect(delegate DialogResult() show, delegate void(void*) inspect)
	{
		sInspect = inspect;
		sTicks = 0;
		sHandled = false;
		let timer = Win32.SetTimer(null, 0, 20, => InspectDialog);
		defer
		{
			Win32.KillTimer(null, timer);
			sInspect = null;
		}
		Test.Assert(timer != 0);
		let result = show();
		Test.Assert(sHandled);
		return result;
	}

	private static void InspectDialog(void* window, uint32 message, uint timer, uint32 time)
	{
		if (++sTicks > 250) Runtime.FatalError("Timed out waiting for the test message box");
		if (sHandled) return;
		let dialog = Win32.GetActiveWindow();
		char16[96] title = ?;
		let length = Win32.GetWindowText(dialog, &title, title.Count);
		if (scope String(Span<char16>(&title, length)) != Caption) return;
		// Native dialog construction can pump timers before its buttons exist.
		if (Application.Backend.Type == .Win32 && GetDlgItem(dialog, 1) == null && GetDlgItem(dialog, 2) == null &&
			GetDlgItem(dialog, 3) == null && GetDlgItem(dialog, 4) == null && GetDlgItem(dialog, 6) == null) return;
		sHandled = true;
		Test.Assert(Application.MessageBoxCount == 1);
		sInspect(dialog);
	}

	private static void Click(void* dialog, int32 id)
	{
		if (Application.Backend.Type == .SDL2OpenGL)
			Win32.SendMessage(dialog, 0x0466 /* TDM_CLICK_BUTTON */, (uint*)(void*)(int)id, null);
		else
		{
			let button = Win32Button(dialog, id);
			Test.Assert(button != null);
			Win32.SendMessage(button, 0x00F5 /* BM_CLICK */, null, null);
		}
	}

	private static void* Win32Button(void* dialog, int32 id)
	{
		// Windows can assign IDCANCEL to the single OK button.
		let button = GetDlgItem(dialog, id);
		return button == null && id == 1 ? GetDlgItem(dialog, 2) : button;
	}

	private static void VerifyButtons(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		DialogResult[7][3] expected = .(
			.(.OK, .None, .None), .(.OK, .Cancel, .None), .(.Abort, .Retry, .Ignore),
			.(.Yes, .No, .Cancel), .(.Yes, .No, .None), .(.Retry, .Cancel, .None),
			.(.Cancel, .TryAgain, .Continue));
		for (int32 set < expected.Count)
			for (int32 index < 3)
			{
				let result = expected[set][index];
				if (result == .None) break;
				let actual = ShowAndInspect(
					scope () => MessageBox.Show("更新 😀\nSecond line", Caption, (.)set, .Information, (.)(index << 8)),
					scope (dialog) =>
					{
						if (backend == .Win32) Test.Assert(Win32.GetFocus() == Win32Button(dialog, (int32)result));
						Test.Assert(Application.CreatedControlCount == 0 && Application.OpenForms.Count == 0);
						Win32.PostMessage(Win32.GetFocus(), Win32.WM_KEYDOWN, (uint*)(void*)13 /* VK_RETURN */, (int*)(void*)1);
					});
				Test.Assert(actual == result);
				Test.Assert(Application.MessageBoxCount == 0 && Application.CreatedControlCount == 0);
			}
	}

	[Test] public static void Win32ButtonsReturnTheirResultsAndHonorDefaults() => VerifyButtons(.Win32);
	[Test] public static void SDLButtonsReturnTheirResultsAndHonorDefaults() => VerifyButtons(.SDL2OpenGL);

	private static void* NativeWindow(Form form)
	{
		if (Application.Backend.Type == .Win32) return form.Handle;
		SDL.SDL_SysWMinfo info = .();
		SDL.GetVersion(out info.version);
		Test.Assert(SDL.GetWindowWMInfo(((SDLBackend)Application.Backend).GetSession(form).mWindow, ref info) == .True);
		return (void*)(int)info.info.win.window;
	}

	private static void VerifyHiddenOwner(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let owner = scope Form();
		int loads = 0;
		owner.Load.Add(new [&] (sender, args) => loads++);
		let result = ShowAndInspect(
			scope () => MessageBox.Show(owner, "A hidden owner", Caption),
			scope (dialog) =>
			{
				let window = NativeWindow(owner);
				if (backend == .SDL2OpenGL) Test.Assert(SDL.GL_GetCurrentContext() == default);
				Test.Assert(Win32.GetWindow(dialog, 4 /* GW_OWNER */) == window);
				Test.Assert(Win32.IsWindowEnabled(window) == 0);
				Test.Assert(owner.IsHandleCreated && !owner.Visible && !owner.Created);
				Test.Assert(loads == 0 && Application.OpenForms.Count == 0);
				Click(dialog, backend == .Win32 ? (int32)DialogResult.OK : 2);
			});
		Test.Assert(result == .OK);
		Test.Assert(Win32.IsWindowEnabled(NativeWindow(owner)) != 0);
		Test.Assert(!owner.Visible && !owner.Created && loads == 0);
		owner.Dispose();
		Test.Assert(Application.CreatedControlCount == 0 && Application.MessageBoxCount == 0);
	}

	[Test] public static void Win32CreatesOnlyTheHiddenOwnersHandleAndRestoresIt() => VerifyHiddenOwner(.Win32);
	[Test] public static void SDLCreatesOnlyTheHiddenOwnersHandleAndRestoresIt() => VerifyHiddenOwner(.SDL2OpenGL);

	private static void VerifyChildOwner(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(240, 120);
		let panel = new Panel(); panel.Size = form.ClientSize; form.Controls.Add(panel);
		let child = new Button(); child.Size = .(120, 25); panel.Controls.Add(child);
		form.Show(); Application.DoEvents();
		let result = ShowAndInspect(
			scope () => MessageBox.Show(child, "A child owner", Caption),
			scope (dialog) =>
			{
				let window = NativeWindow(form);
				Test.Assert(Win32.GetWindow(dialog, 4 /* GW_OWNER */) == window);
				Test.Assert(Win32.IsWindowEnabled(window) == 0);
				Click(dialog, backend == .Win32 ? (int32)DialogResult.OK : 2);
			});
		Test.Assert(result == .OK && Win32.IsWindowEnabled(NativeWindow(form)) != 0);
	}

	[Test] public static void Win32ChildOwnersDisableTheirContainingForm() => VerifyChildOwner(.Win32);
	[Test] public static void SDLChildOwnersDisableTheirContainingForm() => VerifyChildOwner(.SDL2OpenGL);

	private static void VerifyClose(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		for (let buttons in scope MessageBoxButtons[](.OK, .OKCancel, .YesNoCancel, .RetryCancel, .CancelTryContinue))
		{
			let result = ShowAndInspect(
				scope () => MessageBox.Show("Close with the window button", Caption, buttons),
				scope (dialog) => Win32.PostMessage(dialog, Win32.WM_CLOSE, null, null));
			Test.Assert(result == (buttons == .OK ? .OK : .Cancel));
		}
	}

	[Test] public static void Win32CloseReturnsOKOrCancel() => VerifyClose(.Win32);
	[Test] public static void SDLCloseReturnsOKOrCancel() => VerifyClose(.SDL2OpenGL);

	private static void VerifyDefaultOverloads(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		// A StringView can describe a non-terminated substring.
		let caption = scope String(Caption, "ignored suffix");
		let result = ShowAndInspect(
			scope () => MessageBox.Show(null, "message", caption.Substring(0, Caption.Length), .OK, .Question, .Button3),
			scope (dialog) => Click(dialog, backend == .Win32 ? 1 : 2));
		Test.Assert(result == .OK);
	}

	[Test] public static void Win32AcceptsNullOwnersAndCaptionSlices() => VerifyDefaultOverloads(.Win32);
	[Test] public static void SDLAcceptsNullOwnersAndCaptionSlices() => VerifyDefaultOverloads(.SDL2OpenGL);
}
#endif
