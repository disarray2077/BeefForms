using System;
using System.Windows.Forms;
using SDL2;

namespace BeefForms.Backends;

internal static class SDLMessageBox
{
	private static readonly DialogResult[7][3] sMessageBoxButtonSets = .(
		.(.OK, .None, .None), .(.OK, .Cancel, .None), .(.Abort, .Retry, .Ignore),
		.(.Yes, .No, .Cancel), .(.Yes, .No, .None), .(.Retry, .Cancel, .None),
		.(.Cancel, .TryAgain, .Continue));
	private static readonly char8*[12] sMessageBoxButtonLabels = .(
		null, "OK", "Cancel", "Abort", "Retry", "Ignore", "Yes", "No", null, null, "Try Again", "Continue");

	public static DialogResult Show(Control owner, StringView text, StringView caption,
		MessageBoxButtons buttons, MessageBoxIcon icon, MessageBoxDefaultButton defaultButton)
	{
#if BF_PLATFORM_WASM
		if (buttons != .OK)
			Runtime.FatalError("Browser message boxes support only the OK button");
#endif
		let form = owner?.FindForm();
		let window = form != null ? (SDL.Window*)form.Handle : SDL.GetKeyboardFocus();
		SDL.MessageBoxFlags flags = .ButtonsLeftToRight;
		switch (icon)
		{
		case .Error:
			flags |= .Error;
		case .Warning:
			flags |= .Warning;
		case .Information, .Question:
			flags |= .Information;
		default:
		}
#if BF_PLATFORM_WASM
		if (SDL.SimpleMessageBox(flags, caption.ToScopeCStr!(), text.ToScopeCStr!(), window) < 0)
			Runtime.FatalError(scope $"Could not show the message box: {StringView(SDL.GetError())}");
		return .OK;
#else
		SDL.MessageBoxButtonData[3] nativeButtons;
		let count = FillMessageBoxButtons(buttons, defaultButton, out nativeButtons);
		SDL.MessageBoxData data = .();
		data.flags = flags;
		data.window = window;
		data.title = caption.ToScopeCStr!();
		data.message = text.ToScopeCStr!();
		data.numbuttons = count;
		data.buttons = &nativeButtons[0];
		if (SDL.ShowMessageBox(ref data, let result) < 0)
			Runtime.FatalError(scope $"Could not show the message box: {StringView(SDL.GetError())}");
		return ResolveMessageBoxResult(buttons, result);
#endif
	}

	private static DialogResult ResolveMessageBoxResult(MessageBoxButtons buttons, int32 result)
	{
		if (result >= 0)
			return (DialogResult)result;
		if (buttons == .OK)
			return .OK;
		for (let button in sMessageBoxButtonSets[(int)buttons])
		{
			if (button == .Cancel)
				return .Cancel;
		}
		return .None;
	}

	private static int32 FillMessageBoxButtons(MessageBoxButtons buttons, MessageBoxDefaultButton defaultButton,
		out SDL.MessageBoxButtonData[3] nativeButtons)
	{
		nativeButtons = default;
		let results = sMessageBoxButtonSets[(int)buttons];
		int32 count = 0;
		while (count < results.Count && results[count] != .None)
			count++;
		let requestedDefault = (int32)defaultButton >> 8;
		let defaultIndex = requestedDefault < count ? requestedDefault : 0;
		for (int32 i < count)
		{
			let result = results[i];
			nativeButtons[i].buttonid = (int32)result;
			nativeButtons[i].text = sMessageBoxButtonLabels[(int)result];
			if (i == defaultIndex)
				nativeButtons[i].flags |= .ReturnkeyDefault;
			if (result == .Cancel || buttons == .OK)
				nativeButtons[i].flags |= .EscapekeyDefault;
		}
		return count;
	}
}
