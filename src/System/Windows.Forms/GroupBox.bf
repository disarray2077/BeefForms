using System.Drawing;
using internal BeefForms.Backends;
using internal System.Windows.Forms;

namespace System.Windows.Forms;

public class GroupBox : Control
{
	public AutoSizeMode AutoSizeMode
	{
		get => GetAutoSizeMode();
		set => SetAutoSizeMode(value);
	}

	public override Size GetPreferredSize(Size proposedSize)
	{
		let content = GetPreferredContainerSize();
		return .(content.width, content.height + Application.Backend.GetFontHeight(this));
	}

	protected override bool CanSelectCore() => false;
}
