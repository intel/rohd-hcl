# P01: Compute Primitives

**Branch:** `P01_compute` (`hcl-compute-primitives` family)
**Requires:** `P00_arithmetic`

Use this family for arithmetic, numeric representation, binary algebra, encoding, bit manipulation, and clocking primitives. It provides the datapaths required by the priority inference family and later component families.

## Choosing components

- Use `arithmetic` for numeric operations, accumulation, normalization, and fixed/floating-point conversion.
- Use `binary_math`, `bit_operations`, and `encodings` for GF(2) transforms, recurrence/LFSR logic, search/count operations, and representation conversion.
- Use `clocking` for synchronization, event detection, and clock-enable/gating structures.
- Use `IterativeDividerEngine` for direct start/busy/done control, or
  `ReadyValidIterativeDivider` to wrap that engine with ready/valid command
  and retained-result channels. The valid-only multiplier similarly wraps
  `CarrySaveMultiplier`.

## ROHD alignment and adoption

ROHD owns fundamental signal/value operations and their width, signedness,
X/Z, simulation, and generated-HDL semantics. P01 owns configurable hardware
topologies and arithmetic policies built on that baseline.

- Preserve existing `NumericNarrowing` and overflow-reporting arithmetic
  behavior. Adopt any future ROHD full-width or low-bit truncation helpers only
  after reference-model and generated-RTL coverage for rounding, saturation,
  signed bounds, and discarded bits.
- Do not change ROHD `+` or `*` behavior from HCL. An upstream full-width
  helper must specify unequal-width and signed-input behavior. ROHD's `>>`
  is arithmetic and `>>>` is logical.
- Keep design-choice operations here: encoders, popcount, rotate networks,
  prefix scans, and muxes. A move to ROHD requires a capability review,
  compatibility analysis, and migration plan.
- Prefer clock enables for divided-rate work. Actual divided clocks require
  technology-specific implementation and timing constraints. P01 does not
  introduce a clock/domain type system.
- `Synchronizer` reduces metastability risk but does not guarantee coherent
  multi-bit transfers or capture of short pulses. Reset and pulse/event
  crossings need explicit loss and rate guarantees; arbitrary changing
  multi-bit data requires a protocol such as `AsyncFifo`.
- 8b/10b line coding is deferred until a communication component needs it; it
  is not a prerequisite for the current compute datapaths.

## Start here

- [Component list](../README.md)
- [Arithmetic source](../../lib/src/arithmetic/)
- [Binary math source](../../lib/src/binary_math/)

## Component catalog

The partition is the authoritative ownership inventory. This table lists the current public module types by source subfamily; add new types to the same family when they share its responsibility and dependency contract.

| Source subfamily | Module types |
| --- | --- |
| `arithmetic` | `Log2Ceil` |
| `arithmetic/accumulation` | `Accumulator`, `CircularPointer`, `Counter`, `GatedCounter`, `Sum`, `SummationBase` |
| `arithmetic/addition` | `Adder`, `CarrySelectCompoundAdder`, `CarrySelectOnesComplementCompoundAdder`, `CompoundAdder`, `FullAdder`, `NativeAdder`, `OnesComplementAdder`, `RippleCarryAdder`, `SignMagnitudeAdder`, `SignMagnitudeAdderBase`, `SignMagnitudeDualAdder`, `TrivialCompoundAdder`, `UnsignedAddWithOverflow` |
| `arithmetic/conversion` | `FixedToFloat`, `Float8ToFixed`, `FloatToFixed`, `NumericNarrowing` |
| `arithmetic/division-and-roots` | `CeilDivide`, `FixedPointSqrt`, `FixedPointSqrtBase`, `IterativeDividerEngine`, `MultiCycleDivider`, `ReadyValidIterativeDivider` |
| `arithmetic/finite-field` | `GfConstantMultiplier`, `GfInverse`, `GfPolynomialEvaluator` |
| `arithmetic/floating-point` | `FloatingPointAdder`, `FloatingPointAdderDualPath`, `FloatingPointAdderSinglePath`, `FloatingPointClassifier`, `FloatingPointComparator`, `FloatingPointConditionalSwap`, `FloatingPointConverter`, `FloatingPointMultiplier`, `FloatingPointMultiplierSimple`, `FloatingPointSort`, `FloatingPointSortByExp`, `FloatingPointSqrt`, `FloatingPointSqrtSimple`, `FloatingPointSwap` |
| `arithmetic/multiplication` | `BitCompressor`, `CarrySaveMultiplier`, `ColumnCompressor`, `CompressionTreeMultiplier`, `Compressor2`, `Compressor3`, `Multiplier`, `NativeMultiplier`, `PartialProduct`, `PartialProductMatrix`, `UnsignedMulWithOverflow`, `ValidOnlyCarrySaveMultiplier` |
| `arithmetic/multiply-accumulate` | `CompressionTreeDotProduct`, `CompressionTreeMultiplyAccumulate`, `DotProductBase`, `GeneralDotProduct`, `GenericMultiplyAccumulate`, `MultiplyAccumulate`, `MultiplyOnly` |
| `arithmetic/normalization` | `AbsoluteValue`, `LeadingDigitAnticipate`, `LeadingZeroAnticipate`, `LeadingZeroAnticipateBase`, `LeadingZeroAnticipateCarry` |
| `arithmetic/prefix-networks` | `BrentKung`, `KoggeStone`, `ParallelPrefix`, `ParallelPrefixAdder`, `ParallelPrefixDecr`, `ParallelPrefixIncr`, `ParallelPrefixOrScan`, `ParallelPrefixPriorityFinder`, `Ripple`, `Sklansky` |
| `binary_math/algebra` | `BinaryLinearTransform` |
| `binary_math/prbs` | `PrbsChecker`, `PrbsGenerator` |
| `binary_math/recurrence` | `BinaryLinearRecurrence`, `ParallelLfsr`, `SerialLfsr`, `SignatureAnalyzer` |
| `bit_operations/population-count` | `BitwisePopcount`, `Count`, `XnorPopcount`, `XorPopcount` |
| `bit_operations/search` | `CountLeadingZeros`, `CountTrailingZeros`, `Find`, `FindPattern`, `FirstMatchPrefix` |
| `bit_operations/selection` | `BitwiseMux`, `OneHotMux`, `PriorityMux` |
| `bit_operations/shifting` | `Pad`, `RotateLeft`, `RotateLeftFixed`, `RotateRight`, `RotateRightFixed`, `SetBits`, `SignedShifter`, `WithSet` |
| `clocking/cdc` | `Synchronizer` |
| `clocking/event-detection` | `EdgeDetector` |
| `clocking/generation` | `ClockDivider` |
| `clocking/gating` | `ClockGate`, `ToggleGate` |
| `dataflow/reduction` | `ReductionTree` |
| `encodings/gray` | `BinaryToGrayConverter`, `GrayToBinaryConverter` |
| `encodings/one-hot` | `BinaryToOneHot`, `CaseOneHotToBinary`, `OneHotToBinary`, `TreeOneHotToBinary` |
| `encodings/priority` | `ParallelPrefixPriorityEncoder`, `PriorityEncoder`, `RecursiveModulePriorityEncoder`, `RecursiveModulePriorityEncoderNode`, `RecursivePriorityEncoder` |
| `encodings/thermometer` | `BinaryToThermometer`, `ThermometerToBinary` |
| `memory/sequential` | `ShiftRegister` |

## Adding a component

Place a new component in this family when it shares the responsibility and
dependency contract above. Update the branch partition, this catalog, the
public barrel, focused tests, and any applicable Confapp/source-view exposure
in the same change. Do not move a component solely because its boundary uses
a transport interface; a domain engine remains with its domain family.
