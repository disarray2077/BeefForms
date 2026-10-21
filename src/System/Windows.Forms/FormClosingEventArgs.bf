namespace System.Windows.Forms;

public enum CloseReason
{
	None, WindowsShutDown, MdiFormClosing, UserClosing, TaskManagerClosing, FormOwnerClosing, ApplicationExitCall
}

public class FormClosingEventArgs : System.ComponentModel.CancelEventArgs
{
	public readonly CloseReason CloseReason;
	public this(CloseReason reason, bool cancel = false) : base(cancel) { CloseReason = reason; }
}

public class FormClosedEventArgs : EventArgs
{
	public readonly CloseReason CloseReason;
	public this(CloseReason reason) { CloseReason = reason; }
}

public delegate void FormClosingEventHandler(Object sender, FormClosingEventArgs args);
public delegate void FormClosedEventHandler(Object sender, FormClosedEventArgs args);
