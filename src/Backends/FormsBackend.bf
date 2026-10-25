using System;
using System.Drawing;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal abstract class FormsBackend
{
	public abstract ApplicationBackend Type { get; }

	public abstract void CreateControl(Control control);
	public abstract void DestroyControl(Control control);
	public abstract void UpdateControl(Control control, ControlChange change);
	public abstract Size GetClientSize(Form form);
	public abstract Rectangle GetScreenWorkingArea();
	public abstract void SetClientSize(Form form, Size size);
	public abstract void Show(Form form);
	public abstract DialogResult ShowMessageBox(Control owner, StringView text, StringView caption,
		MessageBoxButtons buttons, MessageBoxIcon icon, MessageBoxDefaultButton defaultButton);
#if !BF_PLATFORM_WASM
	public abstract void Run(Form form);
#endif
	public abstract void DoEvents();
	public abstract bool FocusControl(Control control);
	public abstract bool IsFocused(Control control);
	public abstract void SetCapture(Control control, bool capture);
	public abstract bool HasCapture(Control control);
	public abstract Size MeasureText(Control control);
	public virtual Size MeasureText(Control control, Size proposedSize) => MeasureText(control);
	public abstract int32 GetTextBoxHeight(TextBoxBase editor);
	public abstract int32 GetFontHeight(Control control);

	/// Client area available before scrollbars are applied.
	public virtual Size GetScrollClientSize(Control control) => control.ClientSize;
	/// Vertical scrollbar width and horizontal scrollbar height.
	public virtual Size GetScrollBarSize(Control control) => .(16, 16);
	public virtual void EnableVisualStyles() {}
}
