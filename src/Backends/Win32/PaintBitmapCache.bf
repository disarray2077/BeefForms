using System;
using System.Drawing;

using internal BeefForms.Backends;

namespace BeefForms.Backends;

internal class PaintBitmapCache
{
	public const int64 MaxPixels = 1024 * 1024;
	private void* mBitmap;
	private Size mSize;
	private int32 mBitsPerPixel, mPlanes;
	private bool mBusy, mInvalidateWhenFree;

	public ~this()
	{
		Invalidate();
	}

	public struct Lease : IDisposable
	{
		private PaintBitmapCache mCache;
		public readonly void* Bitmap;

		public this(PaintBitmapCache cache, void* bitmap)
		{
			mCache = cache;
			Bitmap = bitmap;
		}

		public void Dispose()
		{
			if (mCache != null)
			{
				mCache.mBusy = false;
				if (mCache.mInvalidateWhenFree)
					mCache.Invalidate();
			}
			else if (Bitmap != null)
				Win32.DeleteObject(Bitmap);
		}
	}

	public Lease Acquire(void* context, int32 width, int32 height)
	{
		if (width <= 0 || height <= 0)
			return .(null, null);
		if (mBusy || (int64)width * height > MaxPixels)
			return .(null, Win32.CreateCompatibleBitmap(context, width, height));

		let bitsPerPixel = Win32.GetDeviceCaps(context, Win32.BITSPIXEL);
		let planes = Win32.GetDeviceCaps(context, Win32.PLANES);
		let compatible = mBitmap != null && bitsPerPixel == mBitsPerPixel && planes == mPlanes;
		if (!compatible || width > mSize.width || height > mSize.height)
		{
			var capacity = Size(width, height);
			if (compatible)
				capacity = .(Math.Max(width, mSize.width), Math.Max(height, mSize.height));
			if ((int64)capacity.width * capacity.height > MaxPixels)
				capacity = .(width, height);
			let bitmap = Win32.CreateCompatibleBitmap(context, capacity.width, capacity.height);
			if (bitmap == null)
				return .(null, null);
			if (mBitmap != null)
				Win32.DeleteObject(mBitmap);
			mBitmap = bitmap;
			mSize = capacity;
			mBitsPerPixel = bitsPerPixel;
			mPlanes = planes;
		}
		mBusy = true;
		return .(this, mBitmap);
	}

	public void Invalidate()
	{
		if (mBusy)
		{
			mInvalidateWhenFree = true;
			return;
		}
		if (mBitmap != null)
			Win32.DeleteObject(mBitmap);
		mBitmap = null;
		mSize = default;
		mInvalidateWhenFree = false;
	}
}