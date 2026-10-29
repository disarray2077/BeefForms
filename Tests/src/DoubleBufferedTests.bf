using System;
using System.Windows.Forms;
using BeefForms.Backends;
using SDL2;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class DoubleBufferedTests
{
	[Test]
	public static void BufferingIsLocalAndDoesNotCreateHandles()
	{
		let parent = scope Control();
		let child = new Control();
		parent.Controls.Add(child);
		Test.Assert(!parent.[Friend]DoubleBuffered && !child.[Friend]DoubleBuffered);
		parent.NeedsPaint = false;
		parent.[Friend]DoubleBuffered = false;
		Test.Assert(!parent.NeedsPaint);
		parent.[Friend]DoubleBuffered = true;
		Test.Assert(parent.[Friend]DoubleBuffered && parent.NeedsPaint && !child.[Friend]DoubleBuffered);
		Test.Assert(!parent.IsHandleCreated && !child.IsHandleCreated);
		parent.[Friend]DoubleBuffered = false;
		Test.Assert(!parent.[Friend]DoubleBuffered);
	}

	[Test]
	public static void LabelsStartBufferedAndCanOptOut()
	{
		let parent = scope Label();
		let child = new Label();
		parent.Controls.Add(child);
		Test.Assert(parent.[Friend]DoubleBuffered && child.[Friend]DoubleBuffered);
		parent.[Friend]DoubleBuffered = false;
		Test.Assert(!parent.[Friend]DoubleBuffered && child.[Friend]DoubleBuffered);
		Test.Assert(!parent.IsHandleCreated && !child.IsHandleCreated);
	}

	[Test]
	public static void SDLKeepsSharedBufferingWhenThePropertyChanges()
	{
		Application.UseBackend(.SDL2OpenGL);
		let form = scope Form();
		form.ClientSize = .(240, 100);
		let label = new Label();
		label.Size = .(160, 40);
		label.Text = "Buffered label";
		form.Controls.Add(label);
		form.Show();
		let backend = (SDLBackend)Application.Backend;
		Test.Assert(backend.[Friend]RenderIfNeeded());
		Test.Assert(label.[Friend]DoubleBuffered && !label.NeedsPaint);
		let handle = label.Handle;
		label.[Friend]DoubleBuffered = false;
		Test.Assert(label.NeedsPaint);
		Test.Assert(backend.[Friend]RenderIfNeeded());
		Test.Assert(!label.[Friend]DoubleBuffered && !label.NeedsPaint && label.Handle == handle);
		backend.GetSession(form).MakeCurrent();
		Test.Assert(SDL.GL_GetAttribute(.GL_DOUBLEBUFFER, var buffered) == 0 && buffered == 1);
		SDLTestInput.AssertNoGLError(form);
	}

#if BF_PLATFORM_WINDOWS
	[Import("gdi32.dll"), CLink]
	private static extern uint32 GetPixel(void* context, int32 x, int32 y);
	[Import("user32.dll"), CLink]
	private static extern uint32 GetGuiResources(void* process, uint32 flags);
	[Import("kernel32.dll"), CLink]
	private static extern void* GetCurrentProcess();

	[Test]
	public static void NativeBitmapCacheReusesStorageAndBoundsRetention()
	{
		let context = Win32.GetDC(null);
		Test.Assert(context != null);
		defer Win32.ReleaseDC(null, context);
		let resources = GetGuiResources(GetCurrentProcess(), 0);
		{
			let backend = scope Win32Backend();
			let cache = backend.[Friend]mPaintBitmapCache;
			void* initial;
			using (var bitmap = cache.Acquire(context, 200, 50))
			{
				Test.Assert(bitmap.Bitmap != null);
				initial = bitmap.Bitmap;
				using (var nested = cache.Acquire(context, 100, 25))
				{
					Test.Assert(nested.Bitmap != null && nested.Bitmap != initial);
					Test.Assert(cache.[Friend]mBitmap == initial);
				}
				Test.Assert(GetGuiResources(GetCurrentProcess(), 0) == resources + 1);
			}
			using (var bitmap = cache.Acquire(context, 100, 25))
				Test.Assert(bitmap.Bitmap == initial);
			using (var failed = cache.Acquire((void*)1, 300, 80))
			{
				Test.Assert(failed.Bitmap == null);
				Test.Assert(cache.[Friend]mBitmap == initial);
			}
			using (var bitmap = cache.Acquire(context, 300, 80))
			{
				Test.Assert(bitmap.Bitmap != null && bitmap.Bitmap != initial);
				Test.Assert(cache.[Friend]mSize == .(300, 80));
			}
			using (var bitmap = cache.Acquire(context, 2048, 400))
				Test.Assert(bitmap.Bitmap != null);
			using (var bitmap = cache.Acquire(context, 400, 2048))
			{
				Test.Assert(bitmap.Bitmap != null);
				Test.Assert(cache.[Friend]mSize == .(400, 2048));
				initial = bitmap.Bitmap;
			}
			using (var oversized = cache.Acquire(context, 2048, 1024))
			{
				Test.Assert(oversized.Bitmap != null && oversized.Bitmap != initial);
				Test.Assert(cache.[Friend]mBitmap == initial);
				Test.Assert(GetGuiResources(GetCurrentProcess(), 0) == resources + 2);
			}
			Test.Assert(GetGuiResources(GetCurrentProcess(), 0) == resources + 1);
		}
		Test.Assert(GetGuiResources(GetCurrentProcess(), 0) == resources);
	}

	[Test]
	public static void NativeDisplayChangesInvalidateTheCacheAfterItsLeaseEnds()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(240, 100);
		let label = new Label();
		label.Size = .(160, 40);
		label.Text = "Shared bitmap";
		form.Controls.Add(label);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		Win32.UpdateWindow(label.Handle);
		let cache = ((Win32Backend)Application.Backend).[Friend]mPaintBitmapCache;
		let context = Win32.GetDC(label.Handle);
		defer Win32.ReleaseDC(label.Handle, context);
		using (var bitmap = cache.Acquire(context, 160, 40))
		{
			Test.Assert(bitmap.Bitmap != null);
			Win32.SendMessage(form.Handle, Win32.WM_DISPLAYCHANGE, null, null);
			Test.Assert(cache.[Friend]mBitmap == bitmap.Bitmap);
		}
		Test.Assert(cache.[Friend]mBitmap == null);
		label.Invalidate();
		Win32.UpdateWindow(label.Handle);
		Test.Assert(!label.NeedsPaint && cache.[Friend]mBitmap != null);
		Win32.SendMessage(form.Handle, Win32.WM_DISPLAYCHANGE, null, null);
		Test.Assert(cache.[Friend]mBitmap == null);
	}

	private static void AssertBufferedPixelsMatch(Label label)
	{
		label.[Friend]DoubleBuffered = false;
		label.Invalidate();
		Win32.UpdateWindow(label.Handle);
		Win32.GetClientRect(label.Handle, var bounds);
		let pixels = new:ScopedAlloc! uint32[bounds.right * bounds.bottom];
		let windowContext = Win32.GetDC(label.Handle);
		defer Win32.ReleaseDC(label.Handle, windowContext);
		let context = Win32.CreateCompatibleDC(windowContext);
		Test.Assert(context != null);
		defer Win32.DeleteDC(context);
		let bitmap = Win32.CreateCompatibleBitmap(windowContext, bounds.right, bounds.bottom);
		Test.Assert(bitmap != null);
		defer Win32.DeleteObject(bitmap);
		let previous = Win32.SelectObject(context, bitmap);
		Test.Assert(previous != null);
		defer Win32.SelectObject(context, previous);
		let backend = (Win32Backend)Application.Backend;
		backend.[Friend]DrawLabel(label, context, bounds);
		bool hasText = false;
		for (int32 y < bounds.bottom)
		{
			for (int32 x < bounds.right)
			{
				let pixel = GetPixel(context, x, y);
				Test.Assert(pixel != uint32.MaxValue);
				pixels[y * bounds.right + x] = pixel;
				if (pixel != Win32.GetSysColor(Win32.COLOR_BTNFACE))
					hasText = true;
			}
		}
		Test.Assert(hasText);
		label.[Friend]DoubleBuffered = true;
		Win32.UpdateWindow(label.Handle);
		Test.Assert(backend.[Friend]PaintBufferedLabel(label, context, bounds));
		for (int32 y < bounds.bottom)
		{
			for (int32 x < bounds.right)
			{
				let actual = GetPixel(context, x, y);
				Test.Assert(actual == pixels[y * bounds.right + x], scope $"Pixel ({x}, {y}) in {bounds.right}x{bounds.bottom}: {pixels[y * bounds.right + x]:X} != {actual:X}");
			}
		}
		Test.Assert(!label.NeedsPaint);
	}

	[Test]
	public static void NativeBufferedLabelsPreservePixelsAndReleaseResources()
	{
		Application.UseBackend(.Win32);
		let form = scope Form();
		form.ClientSize = .(260, 120);
		let label = new Label();
		label.Text = "Buffered label";
		label.Size = .(160, 40);
		Test.Assert(label.[Friend]DoubleBuffered);
		form.Controls.Add(label);
		let secondLabel = new Label();
		secondLabel.Location = .(0, 60);
		secondLabel.Size = .(120, 30);
		secondLabel.Text = "Second label";
		form.Controls.Add(secondLabel);
		form.Show();
		defer { form.Close(); Application.Backend.Run(form); }
		let handle = label.Handle;
		AssertBufferedPixelsMatch(label);
		let backend = (Win32Backend)Application.Backend;
		let cached = backend.[Friend]mPaintBitmapCache.[Friend]mBitmap;
		AssertBufferedPixelsMatch(secondLabel);
		Test.Assert(backend.[Friend]mPaintBitmapCache.[Friend]mBitmap == cached);
		AssertBufferedPixelsMatch(label);
		Test.Assert(!backend.[Friend]PaintBufferedLabel(label, null, .(0, 0, 0, 0)));
		let resources = GetGuiResources(GetCurrentProcess(), 0);
		for (int i < 30)
		{
			label.Size = .(160 + (int32)i, 40 + (int32)(i % 5));
			label.Invalidate();
			Win32.UpdateWindow(label.Handle);
		}
		Test.Assert(GetGuiResources(GetCurrentProcess(), 0) == resources);
		label.Enabled = false;
		label.TextAlign = .MiddleRight;
		AssertBufferedPixelsMatch(label);
		label.Enabled = true;
		label.AutoEllipsis = true;
		label.Size = .(70, 25);
		AssertBufferedPixelsMatch(label);
		label.Size = .(0, 0);
		label.Invalidate();
		Win32.UpdateWindow(label.Handle);
		label.Size = .(160, 40);
		AssertBufferedPixelsMatch(label);
		Test.Assert(label.Handle == handle);
		const uint composited = 0x02000000;
		Test.Assert(((uint)(void*)Win32.GetWindowLongPtr(form.Handle, Win32.GWL_EXSTYLE) & composited) == 0);
		Test.Assert(((uint)(void*)Win32.GetWindowLongPtr(label.Handle, Win32.GWL_EXSTYLE) & composited) == 0);
	}
#endif
}
