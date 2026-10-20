using System;
using System.Collections;

namespace System.Windows.Forms;

public class Control : System.ComponentModel.Component
{
	public class ControlCollection : List<Control>
	{
		private Control mOwner;

		public this(Control owner) { mOwner = owner; }

	    public new void Add(Control value)
	    {
			value.mParent = mOwner;
	        base.Add(value);
			if (mOwner.Handle != null)
			{
				value.CreateHandle();
			}
			value.UpdateAnchorDistances();
			value.PerformLayout();
	    }
	}

	private struct AnchorInfo : this(int32 Left, int32 Top, int32 Right, int32 Bottom)
	{
	}
    
    protected void* mHwnd;
	protected Control mParent;
	private String mText ~ delete _;
	private System.Drawing.Font mFont ~ delete _;
	private System.Drawing.Point mLocation;
	private System.Drawing.Size mSize;
	private AnchorInfo mAnchorInfo;
	private bool mLayoutSuspended = false;
	private bool mEnabled = true;

	public ref Event<EventHandler> LocationChanged { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> SizeChanged { get; set; } ~ _.Dispose();
    public ref Event<EventHandler> Layout { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> Load { get; set; } ~ _.Dispose();

	public void* Handle => mHwnd;

	public virtual String Text
	{
		get => mText;
		set
		{
			String.NewOrSet!(mText, value);
			if (mHwnd != null)
			{
				Win32.SetWindowText(mHwnd, mText.CStr());
			}
		}
	}

	public virtual System.Drawing.Font Font
	{
		get => mFont;
		set
		{
			mFont = value;
			if (mHwnd != null)
			{
				// Font handling is complex. We'll just set the default GUI font for now.
				void* hFont = Win32.GetStockObject(Win32.DEFAULT_GUI_FONT);
				Win32.SendMessage(mHwnd, Win32.WM_SETFONT, (uint*)hFont, (int*)(void*)1);
			}
		}
	}


	public System.Drawing.Point Location
	{
		get => mLocation;
		set
		{
			mLocation = value;
			if (mHwnd != null)
			{
				Win32.SetWindowPos(mHwnd, null, mLocation.x, mLocation.y, 0, 0, 0x0001 | 0x0004); // SWP_NOSIZE | SWP_NOZORDER
			}
			else
			{
				OnLocationChanged(null);
			}
		}
	}

	public System.Drawing.Size Size
	{
		get => mSize;
		set
		{
			mSize = value;
			if (mHwnd != null)
			{
				Win32.SetWindowPos(mHwnd, null, 0, 0, mSize.width, mSize.height, 0x0002 | 0x0004); // SWP_NOMOVE | SWP_NOZORDER
			}
			else
			{
				OnSizeChanged(null);
			}
		}
	}

	public bool Enabled
	{
		get => mEnabled;
		set
		{
			mEnabled = value;
			if (mHwnd != null)
			{
				Win32.EnableWindow(mHwnd, value);
			}
		}
	}

	public String Name { get; set; }
	public int TabIndex { get; set; }
	public AnchorStyles Anchor { get; set; } = .Top | .Left;
	public bool AutoSize { get; set; }
	public readonly ControlCollection Controls ~ DeleteContainerAndItems!(_);
	public virtual BorderStyle BorderStyle { get; set; }
	
	protected virtual char8* WindowClassName => Win32.STATIC_CLASS;
	protected virtual uint WindowStyle => Win32.WS_CHILD | Win32.WS_VISIBLE | (TabIndex >= 0 ? Win32.WS_TABSTOP : 0);
	protected virtual uint WindowExStyle => 0;

	public this()
	{
		Controls = new .(this);
	}

	public ~this()
	{
		if (mHwnd != null)
		{
			Application.UnregisterControl(this);
			Win32.DestroyWindow(mHwnd);
			mHwnd = null;
		}
	}

    public virtual void SuspendLayout()
		=> mLayoutSuspended = true;

    public virtual void ResumeLayout(bool performLayout)
	{
		mLayoutSuspended = false;
		if (performLayout)
			PerformLayout();
	}

    public virtual void PerformLayout()
	{
		if (mLayoutSuspended)
			return;
		ApplyAnchoring();
		Layout.Invoke(this, null);
	}

	internal void UpdateAnchorDistances()
	{
		if (mParent == null) return;

		var parentClientSize = mParent.Size;
		mAnchorInfo.Left = mLocation.x;
		mAnchorInfo.Top = mLocation.y;
		mAnchorInfo.Right = parentClientSize.width - (mLocation.x + mSize.width);
		mAnchorInfo.Bottom = parentClientSize.height - (mLocation.y + mSize.height);
	}

	internal void ApplyAnchoring(System.Drawing.Size? newParentClientSize = null)
	{
		if (mLayoutSuspended)
			return;

		var newBounds = System.Drawing.Rectangle(mLocation.x, mLocation.y, mSize.width, mSize.height);
		bool didChange = true;

		if (newParentClientSize != null)
		{
			bool isAnchoredLeft = (Anchor & .Left) != 0;
			bool isAnchoredRight = (Anchor & .Right) != 0;
			bool isAnchoredTop = (Anchor & .Top) != 0;
			bool isAnchoredBottom = (Anchor & .Bottom) != 0;
	
			// Horizontal anchoring
			if (isAnchoredLeft && isAnchoredRight)
			{
				newBounds.Width = newParentClientSize->width - mAnchorInfo.Left - mAnchorInfo.Right;
			}
			else if (isAnchoredRight)
			{
				newBounds.X = newParentClientSize->width - mSize.width - mAnchorInfo.Right;
			}
	
			// Vertical anchoring
			if (isAnchoredTop && isAnchoredBottom)
			{
				newBounds.Height = newParentClientSize->height - mAnchorInfo.Top - mAnchorInfo.Bottom;
			}
			else if (isAnchoredBottom)
			{
				newBounds.Y = newParentClientSize->height - mSize.height - mAnchorInfo.Bottom;
			}

			didChange = newBounds.X != mLocation.x || newBounds.Y != mLocation.y ||
						newBounds.Width != mSize.width || newBounds.Height != mSize.height;
		}

		if (!didChange)
			return;

		if (newParentClientSize != null)
		{
			mLocation.x = newBounds.X;
			mLocation.y = newBounds.Y;
			mSize.width = newBounds.Width;
			mSize.height = newBounds.Height;

			Win32.SetWindowPos(mHwnd, null, newBounds.X, newBounds.Y, newBounds.Width, newBounds.Height, 0x0004); // SWP_NOZORDER
		}

		for (var child in Controls)
		{
			child.ApplyAnchoring(Size);
		}
	}

	protected virtual void OnLocationChanged(EventArgs e)
	{
		LocationChanged.Invoke(this, e);
		UpdateAnchorDistances();
	}

	protected virtual void OnSizeChanged(EventArgs e)
	{
		SizeChanged.Invoke(this, e);
		ApplyAnchoring();
		UpdateAnchorDistances();
	}

	protected internal virtual void CreateHandle()
	{
		if (mHwnd != null) return;

		void* parentHwnd = (mParent != null) ? mParent.Handle : null;
		var hInstance = Win32.GetModuleHandle(null);

		uint style = WindowStyle;
		if (BorderStyle == .FixedSingle) style |= Win32.WS_BORDER;
		if (BorderStyle == .Fixed3D) style |= Win32.SS_FIXEDRECT; // Approximation

		var exStyle = WindowExStyle;

		var rect = Win32.RECT(0, 0, mSize.width, mSize.height);
		Win32.AdjustWindowRectEx(ref rect, (uint)style, false, (uint)exStyle);
		int windowWidth = rect.right - rect.left;
		int windowHeight = rect.bottom - rect.top;

		mHwnd = Win32.CreateWindowEx(
			WindowExStyle,
			WindowClassName,
			mText?.CStr() ?? null,
			style,
			mLocation.x, mLocation.y,
			windowWidth, windowHeight,
			parentHwnd,
			null,
			hInstance,
			Internal.UnsafeCastToPtr(this)
		);

		if (mHwnd != null)
		{
			Application.RegisterControl(this);

			// Set initial font
			void* hFont = Win32.GetStockObject(Win32.DEFAULT_GUI_FONT);
			Win32.SendMessage(mHwnd, Win32.WM_SETFONT, (uint*)hFont, (int*)(void*)1);

			// Set initial enabled state
			if (!mEnabled)
			{
				Win32.EnableWindow(mHwnd, false);
			}

			// Create handles for all child controls
			for (var child in Controls)
			{
				child.CreateHandle();
			}
		}
	}
}