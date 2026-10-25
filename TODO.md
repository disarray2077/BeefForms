# TODO

Confirmed gaps in the current source, reviewed on 2026-10-23 and updated on
2026-10-25. This is a backlog, not a commitment to implement these features next
or a complete WinForms API inventory.

## Stubbed components

- [ ] **FlowLayoutPanel**: currently an empty `Panel` subclass. It has no flow
  layout engine, `FlowDirection`, `WrapContents`, or flow-break API.
  [Source](src/System/Windows.Forms/FlowLayoutPanel.bf)

## Very incomplete components and contracts

- [ ] **RichTextBox**: currently provides plain editing through
  `TextBoxBase.Multiline`, enabled by default. Win32 uses the ordinary EDIT class;
  SDL supports multiline text. Rich-text storage, formatting, and RTF APIs are
  absent. Rich-text implementation remains deferred.
  [Control](src/System/Windows.Forms/RichTextBox.bf),
  [Win32 mapping](src/Backends/Win32/Win32Backend.bf),
  [SDL editing](BeefForms.SDL/src/SDLWindowSession.Input.bf)
- [ ] **Custom painting**: `Panel.Paint` raises an event, but `PaintEventArgs`
  contains neither a graphics object nor a clipping rectangle. There is no
  portable public drawing context or general `Control.Paint` contract. SDL
  redraws built-in visuals every rendered frame but raises paint notifications
  only for dirty controls; persistent custom drawing needs a defined contract.
  [Event arguments](src/System/Windows.Forms/Utils.bf),
  [Panel](src/System/Windows.Forms/Panel.bf),
  [SDL painting](BeefForms.SDL/src/SDLWindowSession.Rendering.bf)

## Accepted settings without operational behavior

- [ ] **ContainerControl.AutoScaleMode / AutoScaleDimensions**: values are stored
  but do not drive automatic scaling or layout. Drawable-resolution text
  rasterization is implemented separately and does not provide form autoscaling.
  [Source](src/System/Windows.Forms/ContainerControl.bf)
- [ ] **ButtonBase.UseVisualStyleBackColor**: the property is stored but is not
  read by either backend. Button activation and click handling are implemented.
  [Source](src/System/Windows.Forms/ButtonBase.bf)
- [ ] **Application.SetCompatibleTextRenderingDefault**: the method is empty;
  its argument does not select a text-rendering mode.
  [Source](src/System/Windows.Forms/Application.bf)

## Missing supporting APIs

- [ ] **Layout spacing**: general `Control.Margin` and `Padding` APIs are absent.
  Account for these when flow layout or other container layout is implemented.
  [Source](src/System/Windows.Forms/Control.bf)

## Explicitly deferred

- [ ] **SDL font-family resolution**: SDL uses one configured or fallback font
  file rather than resolving `Font.FamilyName`. Win32 already uses the requested
  family. Keep this deferred; GraphicsUnit conversion, CPU-only measurement,
  and drawable-resolution text rasterization have been addressed.
  [SDL text service](BeefForms.SDL/src/SDLTextService.bf),
  [Win32 fonts](src/Backends/Win32/Win32Backend.Font.bf)
- [ ] **Advanced SDL editing**: IME composition handling, word navigation, and
  richer editing behavior remain outside the current basic-editing scope.
  Committed text input and basic selection/editing already work.
  [Source](BeefForms.SDL/src/SDLWindowSession.Input.bf)

## Verification maintenance (ArchitectureReview F9)

Deferred for now, including reproducible .NET compatibility checks.

- [ ] Preserve small, self-contained .NET reference probes for already supported
  lifecycle, text/selection, layout, and font-unit behavior, with reproducible
  instructions and expected results. Current probes are machine-local or
  temporary, so a clean checkout cannot reproduce all the comparisons.
- [ ] Keep generated captures, binaries, and temporary outputs ignored.
- [ ] Keep public-behavior assertions distinct from native-message and GL checks
  as affected tests are maintained. Retain useful backend integration coverage.

Empty subclasses such as `Button`, `TextBox`, and `GroupBox` are not listed as
stubs: their behavior is supplied by their base classes and backend adapters.
