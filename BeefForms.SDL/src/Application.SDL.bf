namespace System.Windows.Forms;

public extension Application
{
	private static String sSDLFontPath = new .() ~ delete _;

	/// SDL font file override. Empty keeps the platform default (the packaged font on Wasm).
	/// Set this before creating any control handles.
	public static StringView SDLFontPath
	{
		get => sSDLFontPath;
		set
		{
			if (sRunning || sProcessingEvents || CreatedControlCount != 0)
				Runtime.FatalError("Set SDLFontPath before creating control handles");
			sSDLFontPath.Set(value);
		}
	}
}
