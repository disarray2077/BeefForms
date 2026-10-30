<h1 align="center">
  <img src="Resources/BeefForms.png" alt="BeefForms" height="24">
  BeefForms
</h1>

A cross-platform [Beef](https://www.beeflang.org/) GUI framework, implementing the .NET Windows Forms API.

## Key Features

- A [WinForms-style API](#quick-start).
- Native Win32 controls on Windows, with an optional SDL2/OpenGL cross-platform backend.
- Full support for WebAssembly.
- A [C# designer converter](scripts/README.md) to help bring existing WinForms layouts into Beef.

> [!NOTE]
> BeefForms is under development. WinForms API coverage and behavior are still \*very\* incomplete.

## Component Support Table

✅ **Complete:** No known gaps in the component's API or behavior.

✅\* **Core supported:** The component's defining behavior works. Additional features and APIs are missing.

⚠️ **Limited:** Usable, but a significant everyday use case is missing or restricted.

❌ **Unimplemented:** The component's defining behavior is missing, even if inherited functionality works.

| Component | Support | Implemented scope | Coverage gaps (not exhaustive) |
| --- | :---: | --- | --- |
| `Control` | ⚠️ | Lifecycle and child ownership, visibility, input and focus, anchoring, automatic sizing, and UI thread invocation. | Layout lacks docking, padding, and margins. Appearance lacks color and background image APIs. Custom drawing through a WinForms `Graphics` API is unavailable. |
| `ScrollableControl` | ✅\* | Automatic overflow detection, scrollbars, wheel scrolling, and programmatic scroll positions. | No `AutoScrollMargin`, `ScrollControlIntoView`, or WinForms `HorizontalScroll` and `VerticalScroll` configuration objects. |
| `ContainerControl` | ⚠️ | Child containment, inherited scrolling, and preferred size calculation. | Automatic scaling is not implemented despite exposing `AutoScaleMode` and `AutoScaleDimensions`. Active control management and validation APIs are missing. |
| `UserControl` | ✅\* | Load events, automatic sizing, borders, and scrolling. | Automatic scaling, active control management, and validation APIs are missing. Custom painting is restricted to notification. |
| `Form` | ⚠️ | Modeless windows, client sizing, minimum size, screen centering, keyboard preview, and cancellable closing. | No modal dialogs or dialog results, owner and owned window APIs, or MDI support. Window configuration lacks `FormBorderStyle` and `WindowState`. |
| `ButtonBase` | ✅\* | Shared click events, `PerformClick()`, and tab focus for button controls. | Image content, text and image alignment, and flat appearance APIs are missing. `UseVisualStyleBackColor` stores a value without applying it. |
| `Button` | ✅\* | Text buttons with mouse and keyboard activation, `Click`, and `PerformClick()`. | No dialog result or default button integration. Image content and configurable button appearance are missing. |
| `CheckBox` | ⚠️ | Checked and unchecked states, automatic toggling, `CheckedChanged`, and mouse and keyboard activation. | Cannot represent an indeterminate state. `ThreeState` and `CheckState` are missing, along with check alignment and button appearance options. |
| `Label` | ✅\* | Text display, alignment, automatic sizing, and ellipsis. | Image content and image alignment are missing. No `UseMnemonic` API to configure mnemonic processing. |
| `Panel` | ⚠️ | Child containment, anchoring, automatic sizing, borders, and scrolling. | Custom painting is restricted to notification. Background color and image APIs are missing. |
| `GroupBox` | ✅\* | Captioned child grouping, automatic sizing, and anchored child layout. | No `FlatStyle` configuration. Custom caption and background colors are unavailable through the control API. |
| `FlowLayoutPanel` | ⚠️ | Horizontal and vertical flow in either direction, optional wrapping, and content sizing. | Flow breaks, margins, padding, and row or column anchor alignment are missing. |
| `TextBoxBase` | ⚠️ | Plain text editing, selection by UTF16 code units, `ReadOnly` mode, and text and input events. | Public clipboard commands, undo APIs, and `SelectedText` are missing. SDL also lacks undo keyboard behavior. |
| `TextBox` | ⚠️ | Single line and multiline input with inherited editing and selection. | Password masking and input length limits are missing. Text alignment, word wrapping, and scrollbar configuration APIs are unavailable. |
| `RichTextBox` | ❌ | Inherited plain text editing with multiline input enabled by default. | Rich text is not implemented. RTF content, selection formatting, and embedded objects are missing. |
| `ProgressBar` | ✅\* | Range and value updates, determinate styles, and marquee animation with configurable speed. | No `Step`, `PerformStep()`, or `Increment()` APIs. Color and right to left layout configuration are missing. |
| `Timer` | ✅ | UI thread ticks, interval changes, start and stop, container registration, and disposal. | No known component specific gaps. |
| `MessageBox` | ⚠️ | Desktop dialogs with standard button sets, results, icons, default buttons, and an optional owner. | Wasm only supports OK alerts and rejects other button sets. SDL maps the Question icon to Information. Help and advanced message box options are missing. |

## Dependencies

- **BeefForms** has no dependency and includes the Win32 API backend.
- **BeefForms.SDL** is optional. It depends on Beef's bundled SDL2 bindings, and [BeefGL](https://github.com/disarray2077/BeefGL).

## How to Use

In the Beef IDE, use **Add Remote Project** with [https://github.com/disarray2077/BeefForms](https://github.com/disarray2077/BeefForms), then enable `BeefForms` in your application's project dependencies.

For SDL support, add another remote project using [https://github.com/disarray2077/BeefForms?path=/BeefForms.SDL](https://github.com/disarray2077/BeefForms?path=/BeefForms.SDL), then enable `BeefForms.SDL` in the same dependencies list.

## Quick Start

```cs
using System;
using System.Windows.Forms;

namespace BeefForms.Example;

class MainForm : Form
{
    public this()
    {
        Text = "BeefForms";
        ClientSize = .(220, 80);
        StartPosition = .CenterScreen;

        let button = new Button();
        button.Text = "Click me";
        button.Location = .(20, 20);
        button.Size = .(180, 32);
        button.Click.Add(new (sender, args) =>
        {
            ((Button)sender).Text = "Hello from Beef!";
        });
        Controls.Add(button);
    }
}

class Program
{
    public static void Main()
    {
        // Windows uses Win32 API by default.
        // With BeefForms.SDL referenced, select SDL using:
        // Application.UseBackend(.SDL2OpenGL);
        Application.EnableVisualStyles();
        Application.Run(new MainForm());
    }
}
```

> [!WARNING]
> On Wasm, `Application.Run()` registers Emscripten's main loop and returns immediately. Put work that depends on closure in a `FormClosed` handler.

## Deferred deletion

Under Beef's memory management model, parents own their child controls, so removing
a control from its parent makes you responsible for deleting it. Since deleting a
control from one of its own callbacks is unsafe, use `DeleteLater()` in that case
to defer deletion until control returns to the main event loop:

```beef
private void OnDismiss(Object sender, EventArgs args)
{
	Parent?.Controls.Remove(this);
	DeleteLater();
	Dismissed.Invoke();
}
```

> [!NOTE]
> Calling `DeleteLater()` is thread-safe for UI-owned controls. Deletion runs on the UI thread.

## C# Designer Conversion

The Python converter produces a Beef extension containing the designer's initialization code and control fields:

```powershell
python scripts/convert_designer.py SettingsForm.Designer.cs --namespace MyApp
```

Provide the companion Beef class, constructor, and event handlers. The converter reports cleanup and resource code that needs manual attention. Unsupported WinForms APIs still need to be ported. See the [converter guide](scripts/README.md) for more options and limitations.

## Contributing

Bug reports, compatibility improvements, and new controls are welcome. Open an issue or submit a pull request with your changes.
