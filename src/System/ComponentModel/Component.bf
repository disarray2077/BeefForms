namespace System.ComponentModel;

public class Component : IComponent
{
    private bool mDisposeNotified;
    public ref Event<System.EventHandler> Disposed { get; set; } ~ _.Dispose();
    public virtual ISite Site { get; set; }

    /// Releases resources without deleting the Beef object.
    public void Dispose() => Dispose(true);

    protected virtual void Dispose(bool disposing)
    {
        if (disposing) NotifyDisposed();
    }

    private void NotifyDisposed()
    {
        mDisposeNotified = true;
        Disposed.Invoke(this, System.EventArgs.Empty);
    }

	public ~this()
	{
		if (!mDisposeNotified) NotifyDisposed();
	}
}
