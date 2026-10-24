using internal System.Collections;

namespace System.Collections;

public abstract class ReadOnlyCollectionBase<T> : IEnumerable<T>
{
	protected append List<T> InnerList = .();
	public virtual int Count => InnerList.Count;
	public Enumerator GetEnumerator() => .(InnerList);

	public struct Enumerator : IEnumerator<T>
	{
		private List<T>.Enumerator mEnumerator;
		internal this(List<T> items) { mEnumerator = items.GetEnumerator(); }
		public Result<T> GetNext() mut => mEnumerator.GetNext();
	}
}
