

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public class Form : ContainerControl
{
	public override System.Drawing.Size ClientSize
	{
		get => IsHandleCreated ? Application.Backend.GetClientSize(this) : Size;
		set
		{
			if (IsHandleCreated)
				Application.Backend.SetClientSize(this, value);
			else
				Size = value;
		}
	}

	public override void Show()
	{
		Visible = true;
		CreateHandle();
		Application.Backend.Show(this);
	}

	public void Close() => Application.Backend.Close(this);
}
