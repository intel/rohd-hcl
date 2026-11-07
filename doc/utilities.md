# Utilities and Building Blocks

ROHD-HCL provides reusable helpers as well as complete components. This guide
groups them by the family where they are most useful. Import the public APIs
from `package:rohd_hcl/rohd_hcl.dart`; the examples also use ROHD types from
`package:rohd/rohd.dart`.

## Shared Signal Utilities

### Optional Register

`condFlop<T>(clk, data)` inserts a positive-edge register when `clk` is
provided. With a null clock it returns `data` unchanged, without applying
enable or reset. With a clock, optional `en`, `reset`, `resetValue`, and
`asyncReset` control the register. A reset without an explicit value uses
zero.

The registered result preserves the payload type and structured layout.
An `outputGenerator` can supply the registered output schema. When a scalar
constant or net needs a driveable registered result, request `Logic`
explicitly instead of inferring the constant's or net's type:

```dart
final registered = condFlop<Logic>(clk, Const(3, width: 8), reset: reset);
final bypassed = condFlop(null, data); // Identical to data.
```

### Conditional Swap

`swap<T>(select, (a, b))` returns a pair in the original order when `select`
is zero and in reverse order when it is one. It preserves compatible typed
payloads, including structured layouts.

```dart
final (first, second) = swap<Logic>(select, (a, b));
```

### Width Calculation

`widthFor(count)` returns the bits required to represent `count` distinct
values, with a minimum of one bit. This is a Dart elaboration-time helper;
it does not construct hardware. For example, `widthFor(9)` is 4.

## Arithmetic Utilities

`SignedBigInt` provides value-level helpers for interpreting an integer with
a fixed width: `value.toCondSigned(width, signed: ...)` and
`SignedBigInt.fromSignedInt(value, width, signed: ...)`. The default is
unsigned; setting `signed: true` interprets the width-limited value as
two's complement. These are Dart value operations, not hardware modules.

```dart
final signed = BigInt.from(255).toCondSigned(8, signed: true); // -1
final unsigned = SignedBigInt.fromSignedInt(-1, 8); // 255
```

For arithmetic visualization, `List<Logic>.listString` formats bit lists
with optional alignment, headers, shifts, and Markdown output. The
[multiplier building blocks](components/multiplier_components.md) also
describe partial-product and compressor visualization.

For reusable arithmetic hardware, see
[arithmetic primitives](components/arithmetic_primitives.md) and
[parallel prefix operations](components/parallel_prefix_operations.md).

## Bit-Operation Utilities

`LogicValue.bitString` formats a value without its width. `firstOne()` returns
the least-significant set-bit index or `null` for zero or an invalid value.
`majority()` returns true when more than half the bits are one; it returns
false for an invalid value. These operate on simulation values, not signals.

```dart
final value = LogicValue.ofInt(12, 4);
final bits = value.bitString; // '1100'
final first = value.firstOne(); // 2
final hasMajority = value.majority(); // false
```

The [rotation guide](components/rotate.md) covers `Logic` extensions that
construct hardware and `LogicValue` extensions for value-level rotations.
See [bit operations](components/bit_operations.md) for mux, count, padding,
and bit-replacement modules.

## Other Family Building Blocks

- **Clocking:** [clock gating](components/clock_gating.md) includes
  `ClockGate.controlled<T>`; the
  [synchronizer](components/async_fifo.md#synchronizer-module) handles
  appropriate clock-domain-crossing control signals.
- **Dataflow:** [reduction trees](components/reduction_tree.md) and
  [sorting](components/sort.md) support typed payloads and custom operations
  or comparisons.
- **Flow control:** [ready/valid](components/ready_valid.md) describes
  register, fall-through, and elastic-pipeline buffers;
  [protocol composition](components/protocol_composition.md) describes
  action-driven cores and directional attachments.
- **Memory:** [associative memory](components/associative_memory.md)
  describes independent matcher and selector modules as well as the complete
  memory.
