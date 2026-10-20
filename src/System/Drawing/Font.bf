using System;

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
    World = 0,
    Display = 1,
    Pixel = 2,
    Point = 3,
    Inch = 4,
    Document = 5,
    Millimeter = 6
}

public class Font
{
    public this(String familyName, float emSize, FontStyle style, GraphicsUnit unit) { }
    public this(String familyName, float emSize, FontStyle style) { }
    public this(String familyName, float emSize) { }
}