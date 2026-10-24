using System;
using System.Windows.Forms;
using BeefForms.Backends;

using internal BeefForms.Backends;

namespace BeefForms.Tests;

class SDLMessageBoxResultTests
{
	[Test]
	public static void WindowDismissalDoesNotInventAnUnavailableCancelChoice()
	{
		DialogResult[7] expected = .(.OK, .Cancel, .None, .Cancel, .None, .Cancel, .Cancel);
		for (int i < expected.Count)
			Test.Assert(SDLMessageBox.[Friend]ResolveMessageBoxResult((MessageBoxButtons)i, -1) == expected[i]);
	}

	[Test]
	public static void SelectedButtonsKeepTheirNativeResult()
	{
		Test.Assert(SDLMessageBox.[Friend]ResolveMessageBoxResult(.OK, (int32)DialogResult.OK) == .OK);
		Test.Assert(SDLMessageBox.[Friend]ResolveMessageBoxResult(.OKCancel, (int32)DialogResult.Cancel) == .Cancel);
		Test.Assert(SDLMessageBox.[Friend]ResolveMessageBoxResult(.YesNo, (int32)DialogResult.Yes) == .Yes);
		Test.Assert(SDLMessageBox.[Friend]ResolveMessageBoxResult(.AbortRetryIgnore, (int32)DialogResult.Retry) == .Retry);
		Test.Assert(SDLMessageBox.[Friend]ResolveMessageBoxResult(.CancelTryContinue, (int32)DialogResult.Continue) == .Continue);
	}
}
