using System;

namespace System.Drawing;

[CRepr]
public struct Rectangle : this(int32 X, int32 Y, int32 Width, int32 Height)
{
	public int32 Right => X + Width;
	public int32 Bottom => Y + Height;

	public bool Contains(int32 x, int32 y) =>
		x >= X && y >= Y && x < Right && y < Bottom;

	public Rectangle Intersect(Rectangle other)
	{
		let x = Math.Max(X, other.X), y = Math.Max(Y, other.Y);
		return .(x, y,
			Math.Max(0, Math.Min(Right, other.Right) - x),
			Math.Max(0, Math.Min(Bottom, other.Bottom) - y));
	}
}
