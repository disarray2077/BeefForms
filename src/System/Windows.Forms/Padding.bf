using System.Drawing;

namespace System.Windows.Forms;

[CRepr]
public struct Padding : this(int32 Left, int32 Top, int32 Right, int32 Bottom)
{
	public static Padding Empty => default;
	public int32 Horizontal => Left + Right;
	public int32 Vertical => Top + Bottom;
	public Size Size => .(Horizontal, Vertical);
	public int32 All
	{
		get => Left == Top && Left == Right && Left == Bottom ? Left : -1;
		set mut => Left = Top = Right = Bottom = value;
	}

	public this(int32 all) : this(all, all, all, all)
	{
	}

	internal Padding NonNegative => .(Math.Max(0, Left), Math.Max(0, Top), Math.Max(0, Right), Math.Max(0, Bottom));
	internal Size SubtractFrom(Size size)
		=> .(Math.Max(0, size.width - Horizontal), Math.Max(0, size.height - Vertical));
}
