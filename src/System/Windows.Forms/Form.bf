

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public class Form : ContainerControl
{
	private bool mLoaded, mClosing, mClosed;
	private System.Drawing.Size mMinimumSize;
	private System.Drawing.Size mInitialClientSize;
	internal bool HasInitialClientSize;
	internal System.Drawing.Size InitialClientSize => mInitialClientSize;
	public override System.Drawing.Size Size
	{
		get => base.Size;
		set { HasInitialClientSize = false; base.Size = value; }
	}
	public System.Drawing.Size MinimumSize
	{
		get => mMinimumSize;
		set
		{
			if (value.width < 0 || value.height < 0) Runtime.FatalError("MinimumSize must not be negative");
			mMinimumSize = value;
			UpdateBackend(.Constraints);
		}
	}
	public ref Event<FormClosingEventHandler> FormClosing { get; set; } ~ _.Dispose();
	public ref Event<FormClosedEventHandler> FormClosed { get; set; } ~ _.Dispose();
	protected virtual void OnFormClosing(FormClosingEventArgs args) => FormClosing.Invoke(this, args);
	protected virtual void OnFormClosed(FormClosedEventArgs args) => FormClosed.Invoke(this, args);
	public bool KeyPreview { get; set; }

	internal void NotifyLoad()
	{
		if (mLoaded) return;
		mLoaded = true;
		Load.Invoke(this, .Empty);
	}

	public override System.Drawing.Size ClientSize
	{
		get => !IsHandleCreated && HasInitialClientSize ? mInitialClientSize : Application.Backend.GetClientSize(this);
		set
		{
			if (IsHandleCreated)
				Application.Backend.SetClientSize(this, value);
			else
			{
				mInitialClientSize = value;
				HasInitialClientSize = true;
				base.Size = value;
			}
		}
	}

	public override void Show()
	{
		if (mClosed) Runtime.FatalError("Cannot show a closed form");
		Visible = true;
		CreateHandle();
		NotifyLoad();
		if (!mClosed) Application.Backend.Show(this);
	}

	public void Close()
	{
		if (mClosing || mClosed) return;
		mClosing = true;
		defer { mClosing = false; }
		let args = scope FormClosingEventArgs(.UserClosing);
		OnFormClosing(args);
		if (args.Cancel) return;
		mClosed = true;
		if (IsHandleCreated) Application.Backend.Close(this);
		DestroyHandle();
		OnFormClosed(scope .(.UserClosing));
	}
}
