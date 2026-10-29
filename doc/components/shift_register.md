# Shift Register

The `ShiftRegister` in ROHD-HCL is a configurable shift register including:

- support for any width data
- a configurable `depth` (which corresponds to the latency)
- an optional `enable`
- an optional `reset` (synchronous or asynchronous)
- if `reset` is provided, an optional `resetValue` for all stages or each stage indvidually (following `ResettableEntries` conventions)
- access to each of the `stages` output from each flop

`ShiftRegister<T>` preserves the payload schema on the input, `dataOut`, and
every entry of `stages`. This includes structures, floating/fixed-point
signals, enums, and typed arrays with their dimensions and value codecs:

```dart
final delay = ShiftRegister<FloatingPoint32>(sample, clk: clk, depth: 3);
final FloatingPoint32 delayedSample = delay.dataOut;
final FloatingPoint32 firstStage = delay.stages.first;
```

A zero-depth register remains combinational. Enable stalls, reset priority,
and synchronous/asynchronous reset timing are unchanged. Constant and live
reset values, including per-stage lists/maps, remain supported. When both the
reset signal and payload are structured, their layouts must match.

For scalar constant data, use `ShiftRegister<Logic>(Const(...), ...)` to request
driveable ports and stages rather than infer the immutable `Const` type.
Making the delay line typed does not make arbitrary buses safe for CDC;
`Synchronizer` retains its existing control-signal API.
