# Static or Runtime Controls

Some component options can be fixed when hardware is generated or selected by a
`Logic` signal at runtime. ROHD-HCL provides a generic control class and a
boolean specialization so components can support both forms through one
constructor parameter:

- `StaticOrRuntimeParameter` is the boolean specialization. It holds a static
  `bool` or a one-bit runtime `Logic`.
- `StaticOrRuntimeControl<T>` supports any static value type and an
  arbitrary-width runtime `Logic`.

`BooleanConfig` and `RuntimeConfig` are deprecated convenience wrappers. Use
`StaticOrRuntimeParameter` directly instead.

## Boolean Controls

Construct typed controls explicitly:

```dart
final fixedSign = StaticOrRuntimeParameter.staticValue(value: true);
final signParameter = StaticOrRuntimeParameter.runtime(
    signedMultiplicand, name: 'signedMultiplicand');
final signed = signParameter.getLogic(this);
```

`getLogic` returns a constant for a static option or creates and returns the
module's internal input for a runtime option. `fromLogic` retains a named
signal's name and uses its required `fallbackName` for an unnamed signal.
`ofDynamic` remains available for boundaries that must interpret legacy input;
prefer typed controls in component APIs.

For boolean choices, `select` returns the selected input directly when the
control is static and uses a mux when it is runtime-configurable:

```dart
final operand = signParameter.select(signedOperand, unsignedOperand,
    module: this);
```

In an inline generator that does not own ports, omit `module` and supply a
control already bound to the enclosing module. As with ROHD's `mux`, use
`select<Logic>(Const(1), Const(0))` when both inputs are scalar constants and
the selector is runtime-configurable. Declared payload formats must match;
plain packed signals can bridge formats. A dynamic runtime selection preserves
the false operand's declared schema, even when its static type is `Logic`; a
constant runtime selector returns the selected input directly. Structured
constant operands with matching formats are supported.

## General Controls

For non-boolean controls, use `StaticOrRuntimeControl<T>`. The caller supplies
the static value, optionally supplies a runtime signal, and defines how the
static value becomes hardware:

```dart
final resetControl = StaticOrRuntimeControl<int>(
  name: 'resetValue',
  staticConfig: 0,
  runtimeConfig: resetValue,
);
final internalResetValue = resetControl.resolve(
  this,
  staticToLogic: (value) => Const(value, width: dataWidth),
);
```

With no `runtimeConfig`, `internalResetValue` is a constant. Otherwise `resolve`
creates a module input with the signal's width. A runtime value takes precedence
over the static default. `ofDynamic` is available for legacy input boundaries
that need to validate or convert untyped values.

By default, runtime inputs are flattened. Use `resolveTyped` or
`getTypedRuntimeInput` to use ROHD's typed input registration, including its
handling of constants. Structured signals containing constants retain their
schema when their clone is driveable; a plain scalar constant becomes a `Logic`
input. An incompatible existing input is rejected rather than silently reused.
Set `reuseExisting: false` to require a new input instead of reusing one.

## Passing Parameters to Child Components

Use `forChild(parent)` to preserve the static choice or pass the parent's
internal runtime input to a child component. It creates that input if needed;
the optional `name` changes the child's input name. The boolean specialization
retains its type. For a structured runtime control, call
`getTypedRuntimeInput(parent)` first and use `getTypedRuntimeInput(child)` on
the returned control to preserve its schema across both boundaries.

Use `tryRuntimeInput` to retrieve an already-created input without creating it,
or `getRuntimeInput` to create one if needed. Reusing an input name for a
different source throws rather than silently connecting the wrong signal;
reusing the same source is supported. If an output `LogicStructure` was
registered directly with `addInput`, pass the resulting internal input to the
control, because packing that output again creates a different signal.
