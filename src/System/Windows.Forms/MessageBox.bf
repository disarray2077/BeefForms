using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

/// Displays a native modal dialog and waits for the user's choice.
/// On Wasm, only OK alerts are supported. SDL2 uses Information for the Question icon.
public static class MessageBox
{
	public static DialogResult Show(StringView text, StringView caption = "", MessageBoxButtons buttons = .OK,
		MessageBoxIcon icon = .None, MessageBoxDefaultButton defaultButton = .Button1)
		=> Show(null, text, caption, buttons, icon, defaultButton);

	public static DialogResult Show(Control owner, StringView text, StringView caption = "", MessageBoxButtons buttons = .OK,
		MessageBoxIcon icon = .None, MessageBoxDefaultButton defaultButton = .Button1)
	{
		if (owner?.IsDisposingOrDisposed == true)
			Runtime.FatalError("Cannot show a message box owned by a disposed control");

		Application.MessageBoxCount++;
		defer { Application.MessageBoxCount--; }
		return Application.Backend.ShowMessageBox(owner, text, caption, buttons, icon, defaultButton);
	}
}
