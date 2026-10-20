namespace System.Windows.Forms;

public enum MouseButtons
{
	None = 0, Left = 1, Right = 2, Middle = 4, XButton1 = 8, XButton2 = 16
}

public enum Keys
{
	None = 0, Back = 8, Tab = 9, Enter = 13, Escape = 27, Space = 32,
	PageUp = 33, PageDown = 34, End = 35, Home = 36, Left = 37, Up = 38, Right = 39, Down = 40,
	Insert = 45, Delete = 46,
	D0 = 48, D1, D2, D3, D4, D5, D6, D7, D8, D9,
	A = 65, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
	F1 = 112, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
	KeyCodeMask = 0xFFFF, Shift = 0x10000, Control = 0x20000, Alt = 0x40000
}

public class InputEventArgs : EventArgs
{
	public Control Source;
	public bool Handled;
}

public class MouseEventArgs : InputEventArgs
{
	public MouseButtons Button;
	public int32 Clicks, X, Y, Delta, DeltaX;

	public this(MouseButtons button, int32 clicks, int32 x, int32 y, int32 delta = 0, int32 deltaX = 0)
	{
		Button = button;
		Clicks = clicks;
		X = x;
		Y = y;
		Delta = delta;
		DeltaX = deltaX;
	}
}

public class KeyEventArgs : InputEventArgs
{
	public readonly Keys KeyData;
	public Keys KeyCode => KeyData & .KeyCodeMask;
	public bool Shift => KeyData.HasFlag(.Shift);
	public bool Control => KeyData.HasFlag(.Control);
	public bool Alt => KeyData.HasFlag(.Alt);
	private bool mSuppressKeyPress;
	public bool SuppressKeyPress
	{
		get => mSuppressKeyPress;
		set { mSuppressKeyPress = value; Handled = value; }
	}
	public this(Keys keyData) { KeyData = keyData; }
}

public class KeyPressEventArgs : InputEventArgs
{
	public char32 KeyChar;
	public this(char32 character) { KeyChar = character; }
}

public class TextInputEventArgs : InputEventArgs
{
	public readonly String Text ~ delete _;
	public this(StringView text) { Text = new .(text); }
}

public delegate void MouseEventHandler(Object sender, MouseEventArgs args);
public delegate void KeyEventHandler(Object sender, KeyEventArgs args);
public delegate void KeyPressEventHandler(Object sender, KeyPressEventArgs args);
public delegate void TextInputEventHandler(Object sender, TextInputEventArgs args);
