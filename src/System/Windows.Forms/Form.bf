

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
	public FormStartPosition StartPosition { get; set; } = .Manual;

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
		if (mClosed || IsDisposingOrDisposed) Runtime.FatalError("Cannot show a closed or disposed form");
		Visible = true;
		let created = IsHandleCreated;
		CreateHandle();
		if (mClosed || IsDisposingOrDisposed) return;
		if (!created && StartPosition == .CenterScreen)
		{
			let area = Application.Backend.GetScreenWorkingArea();
			Location = .(area.X + Math.Max(0, area.Width - Size.width) / 2,
				area.Y + Math.Max(0, area.Height - Size.height) / 2);
		}
		NotifyLoad();
		if (!mClosed && !IsDisposingOrDisposed) Application.Backend.Show(this);
	}

	public void Close()
	{
		if (mClosing || mClosed || IsDisposingOrDisposed) return;
		mClosing = true;
		defer { mClosing = false; }
		let args = scope FormClosingEventArgs(.UserClosing);
		OnFormClosing(args);
		if (args.Cancel || mClosed || IsDisposingOrDisposed) return;
		CompleteClose(.UserClosing);
		Dispose();
	}

	internal bool QueryApplicationExit()
	{
		if (mClosed || IsDisposingOrDisposed) return false;
		let args = scope FormClosingEventArgs(.ApplicationExitCall);
		OnFormClosing(args);
		return args.Cancel;
	}

	internal void CloseForApplicationExit()
	{
		if (mClosed || IsDisposingOrDisposed) return;
		let closing = mClosing;
		mClosing = true;
		defer { mClosing = closing; }
		CompleteClose(.ApplicationExitCall);
	}

	private void CompleteClose(CloseReason reason)
	{
		mClosed = true;
		if (IsHandleCreated) Application.Backend.Close(this);
		DestroyHandle();
		OnFormClosed(scope .(reason));
	}
}
