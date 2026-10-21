<p align="center">
  <img src="Resources/BeefForms.png" alt="BeefForms" width="112">
</p>

<h1 align="center">BeefForms</h1>

A cross-platform [Beef](https://www.beeflang.org/) implementation of the Windows Forms API.

## Key Features

- A [WinForms-style API](#quick-start).
- Native Win32 controls on Windows, with an optional SDL2/OpenGL cross-platform backend.
- Full support for WebAssembly.
- A [C# designer converter](scripts/README.md) to help bring existing WinForms layouts into Beef.

> [!NOTE]
> BeefForms is under development. WinForms API coverage and behavior are still \*very\* incomplete.

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

## C# Designer Conversion

The Python converter produces a Beef extension containing the designer's initialization code and control fields:

```powershell
python scripts/convert_designer.py SettingsForm.Designer.cs --namespace MyApp
```

Provide the companion Beef class, constructor, and event handlers. The converter reports cleanup and resource code that needs manual attention. Unsupported WinForms APIs still need to be ported. See the [converter guide](scripts/README.md) for more options and limitations.

## Contributing

Bug reports, compatibility improvements, and new controls are welcome. Open an issue or submit a pull request with your changes.
