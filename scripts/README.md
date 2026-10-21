# C# designer conversion

Requires Python 3.10 or newer, with no third-party dependencies.

```powershell
python scripts/convert_designer.py path/to/SettingsForm.Designer.cs --namespace BeefForms.Sample -o path/to/SettingsForm.Designer.bf
```

Without `-o`, the script writes a `.bf` file beside the source. It preserves the
source namespace unless `--namespace` is given. Existing output files are
protected; use `--force` to replace one. The C# input is never overwritten.

The output is an `extension` for a companion Beef class. That class must supply
the base (`Form`), a constructor calling `InitializeComponent()`, and the named
event handlers. The converter handles these common designer patterns:

- Retains control/Font heap allocations, properties, layout calls, and control order.
- Converts drawing struct allocations to value constructors.
- Converts named event subscriptions to `new => handler` delegates.
- Expands `Controls.AddRange` inline arrays to ordered `Controls.Add` calls.
- Handles file-scoped namespaces, `global::`, target-typed constructors, and
  ordinary/verbatim string literals without rewriting their contents as code.
- Removes the conventional `components` field/initialization and C# `Dispose(bool)`.
  It reports the removed disposal method: move custom cleanup, including non-control
  components, into the companion class's Beef destructor as needed.

This is a designer **syntax converter**, not a full C# compiler or a WinForms API
implementation. Unknown control types/properties remain in the output for a
manual port; resource loading and `ISupportInitialize` are flagged explicitly.
Event lambdas, interpolated/raw strings, and ambiguous class layouts are rejected
before writing output. Event handler implementations and resource files are not
converted. Compile the generated designer with its companion class to check API
compatibility with BeefForms.

Run the regression tests (including a generic settings form fixture compared
with its expected Beef output):

```powershell
python -m unittest discover -s scripts/tests -v
```
