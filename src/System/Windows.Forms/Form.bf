

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public class Form : ContainerControl
{
	private bool mLoaded;
	public bool KeyPreview { get; set; }

	internal void NotifyLoad()
	{
		if (mLoaded) return;
		mLoaded = true;
		Load.Invoke(this, .Empty);
	}

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
		NotifyLoad();
		Application.Backend.Show(this);
	}

	public void Close() => Application.Backend.Close(this);
}
