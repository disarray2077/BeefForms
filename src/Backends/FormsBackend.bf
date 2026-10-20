using System;
using System.Drawing;
using System.Windows.Forms;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal abstract class FormsBackend
{
	public abstract void CreateControl(Control control);
	public abstract void DestroyControl(Control control);
	public abstract void UpdateControl(Control control, ControlChange change);
	public abstract Size GetClientSize(Form form);
	public abstract void SetClientSize(Form form, Size size);
	public abstract void Show(Form form);
	public abstract void Close(Form form);
	public abstract void Run(Form form);
	public virtual void EnableVisualStyles() {}
}
