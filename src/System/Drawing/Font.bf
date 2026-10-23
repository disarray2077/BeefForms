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
	private int mControlReferences;

	private append String mFamilyName = .();
	public StringView FamilyName => mFamilyName;
	public readonly float Size;
	public readonly FontStyle Style;
	public readonly GraphicsUnit Unit;

	public this(String familyName, float emSize, FontStyle style, GraphicsUnit unit)
	{
		mFamilyName.Set(familyName);
		Size = emSize;
		Style = style;
		Unit = unit;
	}
	public this(String familyName, float emSize, FontStyle style) : this(familyName, emSize, style, .Point) {}
	public this(String familyName, float emSize) : this(familyName, emSize, .Regular, .Point) {}

	// Assigned fonts are shared by controls and released by the last owner.
	internal void Retain() => mControlReferences++;
	internal void Release()
	{
		if (--mControlReferences == 0)
			delete this;
	}
}
