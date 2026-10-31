using System.Collections;
using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

public class RadioButton : ButtonBase
{
	private bool mChecked;
	private bool mAutoCheck = true;

	public this()
	{
		TabStop = false;
		Size = .(104, 24);
	}

	public bool AutoCheck
	{
		get => mAutoCheck;
		set
		{
			if (mAutoCheck == value)
				return;
			mAutoCheck = value;
			UpdateGroup();
		}
	}

	public bool Checked
	{
		get => mChecked;
		set
		{
			if (mChecked == value)
				return;
			mChecked = value;
			UpdateBackend(.Value);
			UpdateGroup();
			if (!IsDisposingOrDisposed)
				OnCheckedChanged(.Empty);
		}
	}

	public ref Event<EventHandler> CheckedChanged { get; set; } ~ _.Dispose();

	protected virtual void OnCheckedChanged(EventArgs args)
	{
		CheckedChanged.Invoke(this, args);
	}

	private void UpdateGroup()
	{
		if (!mAutoCheck)
			return;
		TabStop = mChecked;
		let parent = Parent;
		if (!mChecked || parent == null)
			return;
		let siblings = ToScopedArray!(parent.Controls);
		for (let sibling in siblings)
		{
			if (!parent.Controls.Contains(sibling))
				continue;
			if (let radio = sibling as RadioButton)
			{
				if (radio != this && radio.Parent == parent && radio.AutoCheck && radio.Checked)
					radio.Checked = false;
			}
			if (IsDisposingOrDisposed || parent.IsDisposingOrDisposed || Parent != parent)
				return;
		}
	}

	protected override void OnClick(EventArgs args)
	{
		if (AutoCheck)
			Checked = true;
		base.OnClick(args);
	}

	protected override void OnKeyDown(KeyEventArgs args)
	{
		base.OnKeyDown(args);
		if (args.Handled || args.SuppressKeyPress || args.Shift || args.Control || args.Alt ||
			IsDisposingOrDisposed || Parent == null)
			return;
		let backward = args.KeyCode == .Left || args.KeyCode == .Up;
		if (!backward && args.KeyCode != .Right && args.KeyCode != .Down)
			return;
		args.Handled = true;
		let parent = Parent;
		let radios = scope List<RadioButton>();
		for (let sibling in parent.Controls)
		{
			if (let radio = sibling as RadioButton)
			{
				if (radio.CanSelect && radio.TabIndex >= 0)
					radios.Add(radio);
			}
		}
		radios.Sort(scope (a, b) =>
		{
			let order = a.TabIndex <=> b.TabIndex;
			return order != 0 ? order : parent.Controls.IndexOf(b) <=> parent.Controls.IndexOf(a);
		});
		let index = radios.IndexOf(this);
		if (index < 0)
			return;
		let next = radios[(index + radios.Count + (backward ? -1 : 1)) % radios.Count];
		let handle = next.HandleGeneration;
		if (next.Focus() && parent.Controls.Contains(next) && next.IsCurrentHandle(handle))
			next.PerformClick();
	}
}
