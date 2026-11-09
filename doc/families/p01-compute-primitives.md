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

## Start here

- [Component list](../README.md)
- [Arithmetic source](../../lib/src/arithmetic/)
- [Binary math source](../../lib/src/binary_math/)

## Component catalog

The partition is the authoritative ownership inventory. This table lists the current public module types by source subfamily; add new types to the same family when they share its responsibility and dependency contract.

| Source subfamily | Module types |
| --- | --- |
| `arithmetic/accumulation` | `Accumulator`, `Counter`, `GatedCounter`, `Sum`, `SummationBase` |
| `arithmetic/addition` | `Adder`, `CarrySelectCompoundAdder`, `CarrySelectOnesComplementCompoundAdder`, `CompoundAdder`, `FullAdder`, `NativeAdder`, `OnesComplementAdder`, `RippleCarryAdder`, `SignMagnitudeAdder`, `SignMagnitudeAdderBase`, `SignMagnitudeDualAdder`, `TrivialCompoundAdder` |
| `arithmetic/conversion` | `FixedToFloat`, `Float8ToFixed`, `FloatToFixed`, `NumericNarrowing` |
| `arithmetic/division-and-roots` | `FixedPointSqrt`, `FixedPointSqrtBase`, `IterativeDividerEngine`, `MultiCycleDivider`, `ReadyValidIterativeDivider` |
| `arithmetic/finite-field` | `GfConstantMultiplier`, `GfInverse`, `GfPolynomialEvaluator` |
| `arithmetic/floating-point` | `FloatingPointAdder`, `FloatingPointAdderDualPath`, `FloatingPointAdderSinglePath`, `FloatingPointConditionalSwap`, `FloatingPointConverter`, `FloatingPointMultiplier`, `FloatingPointMultiplierSimple`, `FloatingPointSort`, `FloatingPointSortByExp`, `FloatingPointSqrt`, `FloatingPointSqrtSimple`, `FloatingPointSwap` |
| `arithmetic/multiplication` | `BitCompressor`, `CarrySaveMultiplier`, `ColumnCompressor`, `CompressionTreeMultiplier`, `Compressor2`, `Compressor3`, `Multiplier`, `NativeMultiplier`, `PartialProduct`, `PartialProductMatrix`, `ValidOnlyCarrySaveMultiplier` |
| `arithmetic/multiply-accumulate` | `CompressionTreeDotProduct`, `CompressionTreeMultiplyAccumulate`, `DotProductBase`, `GeneralDotProduct`, `MultiplyAccumulate`, `MultiplyOnly` |
| `arithmetic/normalization` | `AbsoluteValue`, `LeadingDigitAnticipate`, `LeadingZeroAnticipate`, `LeadingZeroAnticipateBase`, `LeadingZeroAnticipateCarry` |
| `arithmetic/prefix-networks` | `BrentKung`, `KoggeStone`, `ParallelPrefix`, `ParallelPrefixAdder`, `ParallelPrefixDecr`, `ParallelPrefixIncr`, `ParallelPrefixOrScan`, `ParallelPrefixPriorityFinder`, `Ripple`, `Sklansky` |
| `binary_math/algebra` | `BinaryLinearTransform` |
| `binary_math/prbs` | `PrbsChecker`, `PrbsGenerator` |
| `binary_math/recurrence` | `BinaryLinearRecurrence`, `ParallelLfsr`, `SerialLfsr`, `SignatureAnalyzer` |
| `bit_operations/population-count` | `BitwisePopcount`, `Count`, `XnorPopcount`, `XorPopcount` |
| `bit_operations/search` | `Find`, `FindPattern`, `FirstMatchPrefix` |
| `bit_operations/shifting` | `SignedShifter` |
| `clocking/cdc` | `Synchronizer` |
| `clocking/event-detection` | `EdgeDetector` |
| `clocking/gating` | `ClockGate`, `ToggleGate` |
| `dataflow/reduction` | `ReductionTree` |
| `encodings/gray` | `BinaryToGrayConverter`, `GrayToBinaryConverter` |
| `encodings/one-hot` | `BinaryToOneHot`, `CaseOneHotToBinary`, `OneHotToBinary`, `TreeOneHotToBinary` |
| `encodings/priority` | `ParallelPrefixPriorityEncoder`, `PriorityEncoder`, `RecursiveModulePriorityEncoder`, `RecursiveModulePriorityEncoderNode`, `RecursivePriorityEncoder` |
| `memory/sequential` | `ShiftRegister` |

## Adding a component

Place a new component in this family when it shares the responsibility and
dependency contract above. Update the branch partition, this catalog, the
public barrel, focused tests, and any applicable Confapp/source-view exposure
in the same change. Do not move a component solely because its boundary uses
a transport interface; a domain engine remains with its domain family.
