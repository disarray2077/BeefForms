using System.Windows.Forms;

namespace System.Drawing;

public enum ContentAlignment
{
	TopLeft = 1, TopCenter = 2, TopRight = 4,
	MiddleLeft = 16, MiddleCenter = 32, MiddleRight = 64,
	BottomLeft = 256, BottomCenter = 512, BottomRight = 1024
}

extension ContentAlignment
{
	internal HorizontalAlignment Horizontal
	{
		get
		{
			switch (this)
			{
			case .TopCenter, .MiddleCenter, .BottomCenter: return .Center;
			case .TopRight, .MiddleRight, .BottomRight: return .Right;
			default: return .Left;
			}
		}
	}

	internal VerticalAlignment Vertical
	{
		get
		{
			switch (this)
			{
			case .MiddleLeft, .MiddleCenter, .MiddleRight: return .Middle;
			case .BottomLeft, .BottomCenter, .BottomRight: return .Bottom;
			default: return .Top;
			}
		}
	}
}
