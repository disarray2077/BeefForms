namespace System.ComponentModel;

public class CancelEventArgs : System.EventArgs
{
	public bool Cancel { get; set; }
	public this(bool cancel = false) { Cancel = cancel; }
}
