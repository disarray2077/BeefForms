using System.Collections;

namespace System.Windows.Forms;

public enum SizeType
{
	AutoSize,
	Absolute,
	Percent
}

public struct ColumnStyle
{
	public SizeType SizeType;
	public float Width;

	public this(SizeType sizeType = .AutoSize, float width = 0)
	{
		SizeType = sizeType;
		Width = width;
	}
}

public struct RowStyle
{
	public SizeType SizeType;
	public float Height;

	public this(SizeType sizeType = .AutoSize, float height = 0)
	{
		SizeType = sizeType;
		Height = height;
	}
}

public class TableLayoutStyleCollection<T> where T : struct
{
	private TableLayoutPanel mOwner;
	private append List<T> mItems = .();

	internal this(TableLayoutPanel owner)
	{
		mOwner = owner;
	}

	public int Count => mItems.Count;
	public T this[int index]
	{
		get => mItems[index];
		set
		{
			mItems[index] = value;
			mOwner.PerformLayout();
		}
	}

	public int Add(T style)
	{
		let index = mItems.Count;
		mItems.Add(style);
		mOwner.PerformLayout();
		return index;
	}

	public void Insert(int index, T style)
	{
		mItems.Insert(index, style);
		mOwner.PerformLayout();
	}

	public void RemoveAt(int index)
	{
		mItems.RemoveAt(index);
		mOwner.PerformLayout();
	}

	public void Clear()
	{
		mItems.Clear();
		mOwner.PerformLayout();
	}
}
