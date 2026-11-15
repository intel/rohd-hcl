# Binary Math

Use binary math for GF(2) transforms, finite-field operations, recurrence
state, pseudorandom test sequences, and signatures. These are not ordinary
integer arithmetic: binary polynomial addition is XOR, with multiplication
and reduction determined by the selected field or recurrence.

Import the public package surface:

```dart
import 'package:rohd_hcl/rohd_hcl.dart';
```

## Algebra and Finite Fields

Separate elaboration/reference data from hardware:

| Need | Components and helpers |
| --- | --- |
| Describe binary matrices, polynomials, and affine transforms | `BinaryMatrix`, `BinaryPolynomial`, and `BinaryAffineTransform` value utilities |
| Apply a configured XOR transform to signals | `BinaryLinearTransform` |
| Describe a binary extension field and its values/operations | `BinaryExtensionField`, `GfValue`, and `GfLogic` |
| Multiply by a construction-time field constant | `GfConstantMultiplier`, composed using a binary linear transform |
| Compute a field inverse | `GfInverse` |
| Evaluate a field polynomial | `GfPolynomialEvaluator` |

Choose consistent field and polynomial representations for every operand.
The three field modules are combinational and expose `result`.
`GfInverse` maps zero to zero explicitly; this is a hardware convention, not a
claim that zero has a multiplicative inverse. `GfPolynomialEvaluator` takes
coefficients from highest degree to constant term and uses Horner evaluation.

Use these primitives to compose algorithms such as error-control codecs,
rather than adding a separate implementation of field arithmetic per codec.
For signed/unsigned integer multiplication, use the
[integer multiplier components](multiplier.md) instead.

## Recurrences and Signatures

`BinaryLinearRecurrence` describes registered state advancement using a
`BinaryLinearRecurrenceDescriptor`. Select it when the state and input
transforms themselves are the reusable operation.

`SerialLfsr` and `ParallelLfsr` specialize this mechanism for a right-shifting
Fibonacci LFSR. The serial output is state bit zero, sampled before an enabled
advance. The parallel output contains `stepsPerCycle` consecutive serial bits,
with the earliest bit in bit zero; an enabled edge advances by the same number
of serial steps. Select the descriptor, initial state, and enable pattern
together when reproducing a known sequence.

`Lfsr` provides the same right-shifting implementation with a tap list instead
of a polynomial descriptor. `feedbackTaps` contains unique zero-based state-bit
indices in `0..stateWidth - 1`; their XOR enters the most-significant bit on
each step. For example, `[0, 1]` with a four-bit state corresponds to
`x^4 + x + 1`. Tap zero is not mandatory, and neither a nonzero seed nor a
maximal-length sequence is guaranteed by the tap list.

```dart
final lfsr = Lfsr(
  clk: clk,
  reset: reset,
  enable: enable,
  stateWidth: 4,
  feedbackTaps: [0, 1],
  stepsPerCycle: 2,
  initialState: BigInt.one,
);
```

`dataOut` contains consecutive output bits, earliest in bit zero. Reset has
priority over load, which has priority over enable; load works even when
enable is low. Supply `load` and `loadState` together. The default initial
state is zero, which remains zero under XOR feedback; a nonzero initial state
requires reset. `asyncReset` selects asynchronous rather than synchronous
reset.

`SignatureAnalyzer` accumulates input words into a multiple-input signature
register using a `SignatureAnalyzerDescriptor`. Reset and optional clear
restore the initial signature, with reset before clear and clear before
enabled accumulation. Use it to compact observations; a signature is not a
proof that two arbitrary streams are identical.

These recurrence components do not by themselves provide a complete
configurable CRC generator/checker.

## PRBS Generation and Checking

`PrbsConfiguration` selects the sequence and nonzero reset seed.
`PrbsGenerator` emits `bitsPerCycle` consecutive sequence bits, earliest first
in bit zero; select one bit per cycle for serial operation.

`PrbsChecker` compares against the same seed-aligned sequence. Generator and
checker must reset to the same seed and advance under the same enable pattern.
It does **not** acquire phase or resynchronize an arbitrarily aligned stream.

`lockThreshold` counts consecutive enabled, error-free words before asserting
`locked`; any enabled mismatch clears that indication. `errorCount` saturates
while counting mismatching bits. Clearing errors clears that counter, not the
sequence state or phase. Use the checker for deterministic link/datapath tests,
not as an implicit receiver synchronization protocol.

## Related Components

- [Bit operations](bit_operations.md) for popcount, selection, and shifts.
- [Prefix networks](parallel_prefix_operations.md) for configurable parallel
  scans and XOR networks.
- [Encodings](../README.md#encodings) for representation conversion.
- [Component index](../README.md) for arithmetic and error-control components.
