# Static or Runtime Parameters

Some component options can be fixed when hardware is generated or selected by
a `Logic` signal at runtime. ROHD-HCL provides two related classes so components
can support both forms through one constructor parameter:

- `StaticOrRuntimeParameter` is the boolean specialization. It accepts a static
  `bool`, a one-bit runtime `Logic`, or `null` (which defaults to `false`).
- `StaticOrRuntimeValue<T>` supports any static value type and an
  arbitrary-width runtime `Logic`.

## Boolean Parameters

Use `StaticOrRuntimeParameter.ofDynamic` for boolean component options:

```dart
final signParameter =
    StaticOrRuntimeParameter.ofDynamic(signedMultiplicand);
final signed = signParameter.getLogic(this);
```

`getLogic` returns a constant for a static option or creates and returns the
module's internal input for a runtime option.

## General Values

For non-boolean values, use `StaticOrRuntimeValue<T>.ofDynamic`. The caller
provides the default static value, validates or converts accepted static input
types, and defines how the static value becomes hardware:

```dart
final resetParameter = StaticOrRuntimeValue<int>.ofDynamic(
  resetValue,
  name: 'resetValue',
  defaultValue: 0,
  convertStatic: (value) => value as int,
);
final internalResetValue = resetParameter.resolve(
  this,
  staticToLogic: (value) => Const(value, width: dataWidth),
);
```

When `resetValue` is an `int`, `internalResetValue` is a constant. When it is a
`Logic`, `resolve` creates a module input with the signal's width. A runtime
value takes precedence over the static default.

## Passing Parameters to Child Components

Use `tryRuntimeInput` when passing an already-created internal runtime input to
a child component. Use `getRuntimeInput` when the input should be created if it
does not exist. Both methods reuse an existing input with the configured name.
