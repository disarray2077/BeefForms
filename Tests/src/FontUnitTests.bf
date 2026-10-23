using System;
using System.Drawing;
using System.Windows.Forms;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal System.Drawing;
using internal BeefForms.Backends;

namespace BeefForms.Tests;

class FontUnitTests
{
	private struct UnitCase
	{
		public GraphicsUnit Unit;
		public float Size;
		public this(GraphicsUnit unit, float size) { Unit = unit; Size = size; }
	}

	// .NET 9: 18 pt = 1/4 inch = 75 document units = 6.35 mm.
	// World and Pixel are device-sized fonts, independent of the requested DPI.
	private static void VerifyEquivalentFonts(Form form, Label label, TextBox editor)
	{
		for (let style in scope FontStyle[](.Regular, .Bold | .Italic))
		{
			form.Font = new .("Segoe UI", 18, style, .Point);
			let measured = Application.Backend.MeasureText(label);
			let labelSize = label.Size, editorSize = editor.Size;
			Test.Assert(measured.width > 0 && measured.height > 0);
			for (let value in scope UnitCase[](.(.Inch, 0.25f), .(.Document, 75), .(.Millimeter, 6.35f)))
			{
				form.Font = new .("Segoe UI", value.Size, style, value.Unit);
				Test.Assert(form.Font.Size == value.Size && form.Font.Unit == value.Unit);
				Test.Assert(label.Font == form.Font && editor.Font == form.Font);
				Test.Assert(Application.Backend.MeasureText(label) == measured);
				Test.Assert(label.Size == labelSize && editor.Size == editorSize);
			}
			form.Font = new .("Segoe UI", 24, style, .Pixel);
			let pixelMeasurement = Application.Backend.MeasureText(label);
			let pixelLabelSize = label.Size, pixelEditorSize = editor.Size;
			form.Font = new .("Segoe UI", 24, style, .World);
			Test.Assert(Application.Backend.MeasureText(label) == pixelMeasurement);
			Test.Assert(label.Size == pixelLabelSize && editor.Size == pixelEditorSize);
		}
	}

	private static void VerifyMeasurement(ApplicationBackend backend)
	{
		Application.UseBackend(backend);
		let form = scope Form(); form.ClientSize = .(420, 180);
		let label = new Label(); label.AutoSize = true; label.Text = "Font unit measurement";
		form.Controls.Add(label);
		let editor = new TextBox(); editor.Size = .(200, 90); form.Controls.Add(editor);
		VerifyEquivalentFonts(form, label, editor);
		Test.Assert(!form.IsHandleCreated && !label.IsHandleCreated && !editor.IsHandleCreated && Application.CreatedControlCount == 0);
		form.Show();
		VerifyEquivalentFonts(form, label, editor);
	}

	[Test] public static void SDLFontUnitsMatchBeforeAndAfterHandleCreation() => VerifyMeasurement(.SDL2OpenGL);
#if BF_PLATFORM_WINDOWS
	[Test] public static void NativeFontUnitsMatchBeforeAndAfterHandleCreation() => VerifyMeasurement(.Win32);
#endif

	[Test]
	public static void PhysicalUnitsScaleWithDpiAndDeviceUnitsRemainFixed()
	{
		for (let dpi in scope float[](96, 144, 192))
			for (let value in scope UnitCase[](.(.World, 24), .(.Pixel, 24), .(.Point, 18),
				.(.Inch, 0.25f), .(.Document, 75), .(.Millimeter, 6.35f)))
			{
				let font = scope System.Drawing.Font("Segoe UI", value.Size, .Bold | .Italic, value.Unit);
				let expected = value.Unit == .World || value.Unit == .Pixel ? 24 : dpi / 4;
				Test.Assert(Math.Abs(font.GetPixelSize(dpi) - expected) < 0.001f);
				Test.Assert(font.Size == value.Size && font.Unit == value.Unit && font.Style == (.Bold | .Italic));
			}
		let fractional = scope System.Drawing.Font("Segoe UI", 10.5f, .Regular, .Point);
		Test.Assert(fractional.GetPixelSize(96) == 14 && fractional.GetPixelSize(144) == 21);
	}

	[Test(ShouldFail = true)]
	public static void DisplayUnitIsRejectedLikeDotNet()
	{
		let font = scope System.Drawing.Font("Segoe UI", 12, .Regular, .Display);
		Test.Assert(font != null);
	}

	[Test(ShouldFail = true)]
	public static void NegativeUnitIsRejectedLikeDotNet()
	{
		let font = scope System.Drawing.Font("Segoe UI", 12, .Regular, (GraphicsUnit)(-1));
		Test.Assert(font != null);
	}

	[Test(ShouldFail = true)]
	public static void OutOfRangeUnitIsRejectedLikeDotNet()
	{
		let font = scope System.Drawing.Font("Segoe UI", 12, .Regular, (GraphicsUnit)7);
		Test.Assert(font != null);
	}
}
