namespace System.Windows.Forms;

// Delegates and Event Args
public class PaintEventArgs : System.EventArgs { }
public delegate void PaintEventHandler(Object sender, PaintEventArgs e);

// Enums
public enum AnchorStyles { None = 0, Top = 1, Bottom = 2, Left = 4, Right = 8 }
public enum BorderStyle { None, FixedSingle, Fixed3D }
public enum AutoScaleMode { None, Font, Dpi, Inherit }
public enum HorizontalAlignment { Left = 0, Center = 1, Right = 2 }
public enum VerticalAlignment { Top = 0, Middle = 1, Bottom = 2 }
