namespace System.Windows.Forms;

public class FlowLayoutPanel : Panel
{
	protected override char8* WindowClassName => Win32.STATIC_CLASS;

	protected override uint WindowStyle
	{
		get
		{
			uint style = base.WindowStyle;
			if (AutoScroll)
			{
				style |= Win32.WS_HSCROLL | Win32.WS_VSCROLL;
			}
			return style;
		}
	}
}