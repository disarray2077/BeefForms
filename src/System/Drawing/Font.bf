namespace System.Drawing;

public enum FontStyle
{
	Regular = 0,
	Bold = 1,
	Italic = 2,
	Underline = 4,
	Strikeout = 8
}

public enum GraphicsUnit
{
	World,
	Display,
	Pixel,
	Point,
	Inch,
	Document,
	Millimeter
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
		switch (unit)
		{
		case .World, .Pixel, .Point, .Inch, .Document, .Millimeter:
			break;
		default:
			Runtime.FatalError("Unsupported font unit");
		}
		mFamilyName.Set(familyName);
		Size = emSize;
		Style = style;
		Unit = unit;
	}

	public this(String familyName, float emSize, FontStyle style) : this(familyName, emSize, style, .Point)
	{
	}

	public this(String familyName, float emSize) : this(familyName, emSize, .Regular, .Point)
	{
	}

	internal float GetPixelSize(float dpi)
	{
		switch (Unit)
		{
		// GDI+ font World units are device pixels, independent of DPI.
		case .World, .Pixel:
			return Size;
		case .Point:
			return Size * dpi / 72;
		case .Inch:
			return Size * dpi;
		case .Document:
			return Size / 300 * dpi;
		case .Millimeter:
			return Size / 25.4f * dpi;
		default:
			Runtime.FatalError("Unsupported font unit");
		}
	}

	// Assigned fonts are shared by controls and released by the last owner.
	internal void Retain()
	{
		mControlReferences++;
	}

	internal void Release()
	{
		if (--mControlReferences == 0)
			delete this;
	}
}
