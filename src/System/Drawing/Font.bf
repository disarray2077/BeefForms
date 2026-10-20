namespace System.Drawing;

public enum FontStyle
{
	Regular = 0, Bold = 1, Italic = 2, Underline = 4, Strikeout = 8
}

public enum GraphicsUnit
{
	World, Display, Pixel, Point, Inch, Document, Millimeter
}

public class Font
{
	public readonly String FamilyName ~ delete _;
	public readonly float Size;
	public readonly FontStyle Style;
	public readonly GraphicsUnit Unit;

	public this(String familyName, float emSize, FontStyle style, GraphicsUnit unit)
	{
		FamilyName = new .(familyName);
		Size = emSize;
		Style = style;
		Unit = unit;
	}
	public this(String familyName, float emSize, FontStyle style) : this(familyName, emSize, style, .Point) {}
	public this(String familyName, float emSize) : this(familyName, emSize, .Regular, .Point) {}
}
