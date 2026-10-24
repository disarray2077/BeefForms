using System;
using System.Windows.Forms;

namespace BeefForms.Backends;

#if BF_PLATFORM_WINDOWS
extension Win32Backend
{
	public override DialogResult ShowMessageBox(Control owner, StringView text, StringView caption,
		MessageBoxButtons buttons, MessageBoxIcon icon, MessageBoxDefaultButton defaultButton)
	{
		let window = owner != null ? Win32.GetAncestor(owner.Handle, Win32.GA_ROOT) : Win32.GetActiveWindow();
		let style = (uint32)buttons | (uint32)icon | (uint32)defaultButton;
		let result = Win32.MessageBox(window, text.ToScopedNativeWChar!(), caption.ToScopedNativeWChar!(), style);
		if (result == 0) Runtime.FatalError("Could not show the message box");
		return (DialogResult)result;
	}
}
#endif
