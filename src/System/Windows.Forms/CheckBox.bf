using internal System.Windows.Forms;

namespace System.Windows.Forms;

public class CheckBox : ButtonBase
{
	private bool mChecked;
	public bool AutoCheck { get; set; } = true;
	public bool Checked
	{
		get => mChecked;
		set
		{
			if (mChecked == value) return;
			mChecked = value;
			UpdateBackend(.Value);
			CheckedChanged.Invoke(this, .Empty);
		}
	}
	public ref Event<EventHandler> CheckedChanged { get; set; } ~ _.Dispose();
	protected override void OnClick(EventArgs args)
	{
		if (AutoCheck) Checked = !Checked;
		base.OnClick(args);
	}
}
