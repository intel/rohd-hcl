# Toggle Gate

The `ToggleGate` component is intended to help save power by avoiding unnecessary toggles through combinational logic. It accomplishes this by flopping the previous value of data and muxing the previous value to the `gatedData` output if the `enable` is low. By default, the flops within the `ToggleGate` are also clock gated for extra power savings, but it can be controlled via a `ClockGateControlInterface`.

As an example use case, if you have a large arithmetic unit but only care about the result when a `valid` bit is high, you could use a `ToggleGate` so that the inputs to that combinational logic do not change unless `valid` is high.

```dart
final toggleGate = ToggleGate(
  clk: clk,
  reset: reset,
  enable: arithmeticDataValid,
  data: arithmeticData,
);

BigArithmeticUnit(dataIn: toggleGate.gatedData);
```

`ToggleGate<T>` retains the payload type on its data port, saved value,
selection, and `gatedData` output. For example, a `FloatingPoint32` input
produces a statically typed `FloatingPoint32` output without a cast. Structures,
enum signals, and typed arrays retain their layouts and codecs.

Both constant and signal-driven reset values are supported. A structured reset
signal retains its schema as a typed input; its layout must match the payload.
Clock-gating controls, reset priority, capture timing, and enable-low hold
behavior are unchanged. As with the underlying typed ROHD operations, use
`ToggleGate<Logic>(...)` for a scalar `Const` payload.
