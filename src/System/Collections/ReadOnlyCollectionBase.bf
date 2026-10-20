namespace System.Collections;

public abstract class ReadOnlyCollectionBase<T> : IEnumerable<T>
{
    // A minimal implementation to satisfy the compiler
    public virtual int Count => 0;
    public IEnumerator<T> GetEnumerator() { return null; }
}