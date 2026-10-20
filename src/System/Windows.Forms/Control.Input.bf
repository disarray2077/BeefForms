using BeefForms.Backends;

using internal System.Windows.Forms;
using internal BeefForms.Backends;

namespace System.Windows.Forms;

internal enum InputEventKind
{
	MouseDown, MouseUp, MouseMove, MouseWheel, MouseDoubleClick, KeyDown, KeyUp, KeyPress, TextInput
}

extension Control
{
	public bool TabStop { get; set; }
	public bool Focused => IsHandleCreated && Application.Backend.IsFocused(this);
	public bool IsMouseOver { get; private set; }
	public bool Capture
	{
		get => IsHandleCreated && Application.Backend.HasCapture(this);
		set { if (IsHandleCreated) Application.Backend.SetCapture(this, value); }
	}
	public bool Focus() => IsHandleCreated && IsEffectivelyEnabled && Application.Backend.FocusControl(this);

	public ref Event<MouseEventHandler> MouseDown { get; set; } ~ _.Dispose();
	public ref Event<MouseEventHandler> MouseUp { get; set; } ~ _.Dispose();
	public ref Event<MouseEventHandler> MouseMove { get; set; } ~ _.Dispose();
	public ref Event<MouseEventHandler> MouseWheel { get; set; } ~ _.Dispose();
	public ref Event<MouseEventHandler> MouseDoubleClick { get; set; } ~ _.Dispose();
	public ref Event<KeyEventHandler> KeyDown { get; set; } ~ _.Dispose();
	public ref Event<KeyEventHandler> KeyUp { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> MouseEnter { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> MouseLeave { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> GotFocus { get; set; } ~ _.Dispose();
	public ref Event<EventHandler> LostFocus { get; set; } ~ _.Dispose();
	public ref Event<KeyPressEventHandler> KeyPress { get; set; } ~ _.Dispose();
	public ref Event<TextInputEventHandler> TextInput { get; set; } ~ _.Dispose();

	protected virtual void OnMouseDown(MouseEventArgs args) => MouseDown.Invoke(this, args);
	protected virtual void OnMouseUp(MouseEventArgs args) => MouseUp.Invoke(this, args);
	protected virtual void OnMouseMove(MouseEventArgs args) => MouseMove.Invoke(this, args);
	protected virtual void OnMouseWheel(MouseEventArgs args) => MouseWheel.Invoke(this, args);
	protected virtual void OnMouseDoubleClick(MouseEventArgs args) => MouseDoubleClick.Invoke(this, args);
	protected virtual void OnKeyDown(KeyEventArgs args) => KeyDown.Invoke(this, args);
	protected virtual void OnKeyUp(KeyEventArgs args) => KeyUp.Invoke(this, args);
	protected virtual void OnMouseEnter(EventArgs args) => MouseEnter.Invoke(this, args);
	protected virtual void OnMouseLeave(EventArgs args) => MouseLeave.Invoke(this, args);
	protected virtual void OnGotFocus(EventArgs args) => GotFocus.Invoke(this, args);
	protected virtual void OnLostFocus(EventArgs args) => LostFocus.Invoke(this, args);
	protected virtual void OnKeyPress(KeyPressEventArgs args) => KeyPress.Invoke(this, args);
	protected virtual void OnTextInput(TextInputEventArgs args) => TextInput.Invoke(this, args);

	internal void DispatchInput(InputEventKind kind, InputEventArgs args)
	{
		if (args.Source == null)
			args.Source = this;
		switch (kind)
		{
		case .MouseDown: OnMouseDown((MouseEventArgs)args);
		case .MouseUp: OnMouseUp((MouseEventArgs)args);
		case .MouseMove: OnMouseMove((MouseEventArgs)args);
		case .MouseWheel: OnMouseWheel((MouseEventArgs)args);
		case .MouseDoubleClick: OnMouseDoubleClick((MouseEventArgs)args);
		case .KeyDown: OnKeyDown((KeyEventArgs)args);
		case .KeyUp: OnKeyUp((KeyEventArgs)args);
		case .KeyPress: OnKeyPress((KeyPressEventArgs)args);
		case .TextInput: OnTextInput((TextInputEventArgs)args);
		}
		if (args.Handled || Parent == null)
			return;
		if (let mouse = args as MouseEventArgs)
		{
			let offsetX = Location.x - Parent.ContentOffset.x;
			let offsetY = Location.y - Parent.ContentOffset.y;
			mouse.X += offsetX;
			mouse.Y += offsetY;
			Parent.DispatchInput(kind, args);
			mouse.X -= offsetX;
			mouse.Y -= offsetY;
		}
		else
			Parent.DispatchInput(kind, args);
	}

	internal void NotifyFocus(bool focused)
	{
		if (focused) OnGotFocus(.Empty);
		else OnLostFocus(.Empty);
	}

	internal static void UpdateMouseOver(Control previous, Control next)
	{
		if (previous == next)
			return;
		for (var control = previous; control != null; control = control.Parent)
			if (!IsAncestorOf(control, next))
			{
				control.IsMouseOver = false;
				control.OnMouseLeave(.Empty);
			}
		for (var control = next; control != null; control = control.Parent)
			if (!IsAncestorOf(control, previous))
			{
				control.IsMouseOver = true;
				control.OnMouseEnter(.Empty);
			}
	}

	internal static bool IsAncestorOf(Control ancestor, Control control)
	{
		for (var current = control; current != null; current = current.Parent)
			if (current == ancestor)
				return true;
		return false;
	}
}
