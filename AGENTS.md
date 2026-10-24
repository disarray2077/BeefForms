# Agent instructions

## Repository state

Before starting substantial changes, inspect the working tree. If those changes could involve modifying files that already contain unrelated pre-existing changes, stop and ask whether the user wants those changes committed before continuing. Avoid mixing unrelated pre-existing changes into the new work unless explicitly requested.

## Environment

- If a path for the Beef compiler isn't given by the user, locate Beef in `%BEEFDIR%\IDE\dist` (Windows) or `$BEEFDIR/IDE/dist` (Unix) when using a source checkout, or `%PROGRAMFILES%\Beef\bin` for a Windows installation. Prefer the source checkout if available. Verify paths before using them.
- Store temporary files in `$TMPDIR` (Unix) or `%TEMP%` (Windows). On Linux, avoid assuming that the `/tmp` directory is the directory in `$TMPDIR`, even if most of the times it will be.

## Code comments

Use comments to explain non-obvious intent, constraints, or invariants rather than information
already apparent from the code. In particular, avoid:

- **Restating the code.** Do not describe operations already clear from the statements, such as
  incrementing a counter, calling a handler, or iterating over modules.
- **Section headers inside functions.** Do not use comment banners or numbered steps to divide
  a function into phases such as setup and cleanup. Let the code's structure make those phases clear.
- **Narrating edits or reasoning.** Do not describe what changed, why an edit was made, or why
  an implementation is safe as a message to the reviewer. Such comments quickly become stale.
  If a constraint matters to future readers, document the constraint itself instead.
- **Docstrings that repeat signatures.** Do not spell out a function's name, parameters, or
  return type in prose when its declaration already provides that information.
- **Obvious type or scope information.** Do not add comments that merely identify what a
  declaration already makes clear, such as labeling a pointer to a process.

## Post-implementation Beef design review

After implementing the requested behavior and verifying it as far as the environment allows, make
a deliberate second pass over the code you changed and the code it directly interacts with
(callers, callees, and the types involved). Use what the implementation revealed to ask whether
the code merely works or whether its structure makes responsibilities, lifetimes, and invariants
obvious.

### Ground rules

- **Scale the pass to the change.** A small fix needs a quick look; a new feature or subsystem
  deserves a careful review. Finding nothing worth changing is a valid outcome. Do not refactor
  just to apply this checklist.
- **Stay in scope.** Apply improvements within the code you changed and its directly related code.
  If you find opportunities outside it, or ones that would require big changes across many
  unrelated files, list them instead of implementing them.
- **Preserve behavior and public API.** Refactors in this pass must not change observable
  behavior, observable ordering, or public API. If a worthwhile improvement would, propose
  it as a separate decision instead of including it as incidental cleanup.
- **Re-verify.** After refactoring, rebuild and rerun the same checks you used for the
  implementation.
- **Report.** In your summary, briefly list each design refactor you applied and why, plus any
  opportunities you deferred, particularly those requiring broader changes or separate decisions. If no improvements were warranted, say so briefly.

### What to look for

- **Behavior living away from its data.** Look for helpers or backend/manager methods that mostly
  operate on another type's state. Consider moving them onto that type as an instance method,
  property, constructor, factory, or type extension when the resulting API makes ownership
  clearer. For example, geometry operations belong with geometry types; text-offset conversions
  belong with text rather than a text box; capturing and applying a context snapshot belongs to
  the snapshot type rather than the backend.
- **Manual paired operations.** Replace hand-written setup/defer-cleanup pairs with the construct that
  fits what is being paired:
  - **State pairs** (acquire/release, capture/restore, begin/end, lock/unlock): use a small `IDisposable`
    struct with `using` only when the enclosed work meaningfully depends on the acquired resource or state, directly or indirectly. For
    example, the work runs while the lock is held, or it relies on the captured state until that state is
    restored. The `using` block should visibly enclose the work that depends on the resource. Prefer
    returning such a struct from a method instead of constructing it directly in the `using` statement.
  - **Setup/cleanup around unrelated work:** when a pair only wraps work that never touches the resource
    (for example, starting a timer at the beginning and cleaning it up at the end), do not model it as an
    `IDisposable` struct. Instead, consider a method that does the setup, calls a delegate with the work,
    and does the cleanup (using `defer` inside the method when needed), such as
    `WithTimer(scope () => { ... });`. This keeps the pairing in one place without pretending the block
    uses a resource.
  - **Plain allocations:** `scope`, or `new:ScopedAlloc!` when the size may be large or unbounded
    (for example, an array with a caller-chosen initial size).
  - **Allocations that need extra paired work**, such as retaining elements on capture and
    releasing them before deletion: a mixin using `scope:mixin` and `defer:mixin`, like
    `ToScopedArray` in `src/Helpers/ScopedArray.bf`. Use this only for such special cases.
  Preserve ordering, failure behavior, and lifetime guarantees. Leave simple one-off pairs alone
  if a wrapper adds more ceremony than clarity.
- **Ownership that could be expressed directly.** For reference-type fields created once and
  destroyed with their owner, evaluate `append` instead of a separate `new` allocation and
  destructor deletion. Exclude replaceable, nullable/lazy, shared, or independently owned objects,
  and verify construction and destruction semantics.
- **Unexplained domain values.** Notice repeated magic numbers, bit masks, and positional groups
  of related values. Prefer existing or well-named constants, enums, and small value types when
  they reveal meaning. Keep interop values equivalent; do not invent a type just to rename one
  obvious literal.
- **Mutable APIs that bypass invariants.** A property that exposes a mutable object, such as a
  `String`, lets callers change state without going through setters, notifications, layout, or
  backend updates. Consider exposing a read-only view instead (for example, `StringView`), keeping
  the owned backing field and having the setter copy the value in. Because the API mirrors C#,
  where `String` values are immutable, callers should treat their view as temporary and copy it if
  they need to keep it, unless holding it is clearly safe and worth it for performance. This
  counts as routine cleanup if callers still compile, none relied on the setter taking
  ownership, and callers do not require retaining it beyond its safe lifetime.
- **Repetition that points to a real shared concept.** Consider a cohesive type, method, mixin,
  generic, or extension when several implementations reveal the same responsibility or
  invariant. Do not deduplicate merely because code looks similar, and prefer readable call
  sites over line-count reduction.

## Task mismatches

If anything does not work, look, or behave as the user described or expected in their prompt, and that discrepancy is not itself what the user has asked you to investigate or resolve, stop immediately and ask the user how to proceed. Clearly explain the mismatch. Do not attempt to resolve it yourself, choose a workaround, or reinterpret the requirements. Mark any active to-do tasks as blocked and wait for the user's response before continuing.

Apply this rule to expectations expressed or clearly implied by the user's request, not to your own assumptions about how implementation should proceed. Where the user leaves implementation choices to you, an unsuccessful attempt is not a task mismatch. Continue investigating and iterating within the authorized scope.

## False premises

If the user makes a claim or requests an action based on a false premise—for example, “Our "list.cool_sort()" returns the sorted list, so replace "numbers.sort()" with "numbers = numbers.cool_sort()",” when "list.cool_sort()" actually sorts in place and returns "None"—you MUST NOT proceed with the task. Apply this instruction exactly as written, without reinterpreting it or silently correcting the premise to continue. Immediately halt task execution, mark any active to-do tasks as blocked (if applicable in your harness), and explain the contradiction to the user.
