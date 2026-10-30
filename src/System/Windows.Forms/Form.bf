

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public class Form : ContainerControl
{
	private bool mLoaded, mClosing, mClosed;
	private bool mShowCalled;
	private bool mAutoSizing;
	public AutoSizeMode AutoSizeMode
	{
		get => GetAutoSizeMode();
		set => SetAutoSizeMode(value);
	}

	public override System.Drawing.Size GetPreferredSize(System.Drawing.Size proposedSize)
	{
		let content = base.GetPreferredSize(proposedSize);
		let client = LayoutSize;
		return .(Math.Max(MinimumSize.width, content.width + Math.Max(0, Size.width - client.width)),
			Math.Max(MinimumSize.height, content.height + Math.Max(0, Size.height - client.height)));
	}

	public override void PerformLayout()
	{
		if (mAutoSizing)
		{
			if (LayoutSuspended)
				base.PerformLayout();
			return;
		}
		mAutoSizing = true;
		defer { mAutoSizing = false; }

		base.PerformLayout();
		for (int pass < MaxLayoutPasses)
		{
			if (!AutoSize || LayoutSuspended || !IsHandleCreated || IsDisposingOrDisposed)
				break;
			let previous = Size;
			HasInitialClientSize = false;
			ApplyAutoSize();
			if (Size == previous)
				break;
			base.PerformLayout();
		}
	}

	protected override void UpdateAutoSize()
	{
		base.UpdateAutoSize();
		if (AutoSize)
			PerformLayout();
	}

	private System.Drawing.Size mMinimumSize;
	private System.Drawing.Size mInitialClientSize;
	internal bool HasInitialClientSize;
	internal System.Drawing.Size InitialClientSize => mInitialClientSize;
	public override System.Drawing.Size Size
	{
		get => base.Size;
		set
		{
			HasInitialClientSize = false;
			base.Size = value;
		}
	}
	public System.Drawing.Size MinimumSize
	{
		get => mMinimumSize;
		set
		{
			if (value.width < 0 || value.height < 0)
				Runtime.FatalError("MinimumSize must not be negative");
			mMinimumSize = value;
			UpdateBackend(.Constraints);
		}
	}
	public ref Event<EventHandler> Load { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> Shown { get; set; } ~ _.Dispose();
	public ref Event<FormClosingEventHandler> FormClosing { get; set; } ~ _.Dispose();
	public ref Event<FormClosedEventHandler> FormClosed { get; set; } ~ _.Dispose();

	protected virtual void OnFormClosing(FormClosingEventArgs args)
	{
		FormClosing.Invoke(this, args);
	}

	protected virtual void OnFormClosed(FormClosedEventArgs args)
	{
		FormClosed.Invoke(this, args);
	}

	public bool KeyPreview { get; set; }
	public FormStartPosition StartPosition { get; set; } = .Manual;

	public this()
	{
		this.[Friend]mVisible = false;
	}

	private void NotifyLoad()
	{
		if (mLoaded || mClosing || mClosed || IsDisposingOrDisposed)
			return;
		mLoaded = true;
		Application.RegisterForm(this);
		OnLoad(.Empty);
	}

	protected virtual void OnLoad(EventArgs args)
	{
		Load.Invoke(this, args);
		if (IsHandleCreated)
			BeginInvoke(new () => OnShown(.Empty));
	}

	protected virtual void OnShown(EventArgs args)
	{
		Shown.Invoke(this, args);
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

	public void Activate()
	{
		if (Visible && IsHandleCreated)
		{
			VerifyThreadAccess();
			Application.Backend.Activate(this);
		}
	}

	public override void Show()
	{
		if (mClosed || IsDisposingOrDisposed)
			Runtime.FatalError("Cannot show a closed or disposed form");
		Visible = true;
	}

	protected override void SetVisibleCore(bool value)
	{
		if (!value || (LocallyVisible && mShowCalled))
		{
			base.SetVisibleCore(value);
			return;
		}
		if (mClosed || IsDisposingOrDisposed)
			Runtime.FatalError("Cannot show a closed or disposed form");
		mShowCalled = true;
		if (mLoaded)
			Application.RegisterForm(this);
		base.SetVisibleCore(true);
		if (!mClosed && !IsDisposingOrDisposed)
		{
			base.SetVisibleCore(true);
			if (Visible && Created && IsHandleCreated && !mClosed && !IsDisposingOrDisposed)
				Application.Backend.Show(this);
		}
	}

	protected override void OnCreateControl()
	{
		base.OnCreateControl();
		if (!mShowCalled || mLoaded || mClosing || mClosed || IsDisposingOrDisposed)
			return;
		if (StartPosition == .CenterScreen)
		{
			let area = Application.Backend.GetScreenWorkingArea();
			Location = .(area.X + Math.Max(0, area.Width - Size.width) / 2,
				area.Y + Math.Max(0, area.Height - Size.height) / 2);
		}
		NotifyLoad();
	}

	public void Close()
	{
		if (mClosing || mClosed || IsDisposingOrDisposed)
			return;
		if (!IsHandleCreated)
		{
			mClosed = true;
			Dispose();
			return;
		}
		mClosing = true;
		defer { mClosing = false; }

		let args = scope FormClosingEventArgs(.UserClosing);
		NotifyOwnedClosing(args);
		OnFormClosing(args);
		if (args.Cancel || mClosed || IsDisposingOrDisposed)
			return;
		NotifyOwnedClosed();
		CompleteClose(.UserClosing);
		Dispose();
	}

	internal bool QueryApplicationExit()
	{
		if (mClosed || IsDisposingOrDisposed)
			return false;
		let args = scope FormClosingEventArgs(.ApplicationExitCall);
		NotifyOwnedClosing(args, true);
		OnFormClosing(args);
		return args.Cancel;
	}

	internal void CloseForApplicationExit()
	{
		if (mClosed || IsDisposingOrDisposed)
			return;
		let closing = mClosing;
		mClosing = true;
		defer { mClosing = closing; }
		NotifyOwnedClosed(true);
		CompleteClose(.ApplicationExitCall);
	}

	private void CompleteClose(CloseReason reason)
	{
		mClosed = true;
		Application.UnregisterForm(this);
		OnFormClosed(scope .(reason));
	}
}
