## 0.2.1

- New Components:
  - Added an integer `DotProduct` component (<https://github.com/intel/rohd-hcl/pull/243>).
  - Added a `ResettableEntries` capability allowing us to initialize memories (<https://github.com/intel/rohd-hcl/pull/253>).
  - Added a new value type, `SignMagnitudeValue`, to use in testing (<https://github.com/intel/rohd-hcl/pull/232/>) and potentially for components.
- Added constraint generation to `random()` for `FixedPointValuePopulator` and `FloatingPointValuePopulator` which allows for generating random values in those types constrained by a fixed range, inclusive or exclusive (`gte`, `gt`, `lt`, `lte`), and in the case of `FloatingPointValue`, normal or subnormal numbers in that range (<https://github.com/intel/rohd-hcl/pull/232/>).
- Improved SystemVerilog output:
  - Improved default `Module` definition and instance naming throughout (<https://github.com/intel/rohd-hcl/pull/227>).
  - Improved output of SystemVerilog internal signal names throughout (<https://github.com/intel/rohd-hcl/pull/237>, <https://github.com/intel/rohd-hcl/pull/244>).
- Added `FixedPointValue` and `FloatingPointValue` operators including negation, and comparison.
  - For `FixedPointValue` this is a deprecating change as previous operators returned `LogicValue` and their future operators will return `bool` (<https://github.com/intel/rohd-hcl/pull/232/>).  For now, `bool` return methods are provided for transitioning:  `.ltBool`, `.lteBool`, `.gtBool`, and `.gteBool`.  They will be deprecated in the future for `operator <`, `operator <=`, `operator >` and `operator >=`, respectively.
- Added dynamic sign extension capability to `ReductionTree` (<https://github.com/intel/rohd-hcl/pull/246/>).
- Bug fixes:
  - Fixed bug (<https://github.com/intel/rohd-hcl/issues/239>) denormals-as-zero (DAZ) support when computing effective subtraction in floating point addition.
  - Fixed build failure (<https://github.com/intel/rohd-hcl/issues/240>) in `MultiplyAccumulate`.
- Updates for current ROHD version 0.6.6 (<https://github.com/intel/rohd/releases/tag/v0.6.6>) compatibility:
  - Updated `FIFO` to return the `LogicType` instead of just `Logic` (<https://github.com/intel/rohd-hcl/pull/254>), leveraging ROHD 0.6.6's `addTypedInput` and `addTypedOutput` capabilities.
  - Fixed use of deprecated `Port` (<https://github.com/intel/rohd-hcl/pull/231>), which is now `Logic.port` in ROHD.
  - Updated implementations of `Interface` classes to add the required `clone()` method (<https://github.com/intel/rohd-hcl/pull/245>)
- Improved internal code documentation to use more references of types (<https://github.com/intel/rohd-hcl/pull/223>).

## 0.2.0

- Added extensive variable-width floating-point support:
  - Added support classes `FloatingPointLogic` and `FloatingPointValue` (<https://github.com/intel/rohd-hcl/pull/97>), (<https://github.com/intel/rohd-hcl/pull/110>), (<https://github.com/intel/rohd-hcl/pull/131>), (<https://github.com/intel/rohd-hcl/pull/156>), (<https://github.com/intel/rohd-hcl/pull/175>), (<https://github.com/intel/rohd-hcl/pull/134>).
  - Added `FloatingPointAdder` abstract component API with implementations `FloatingPointSinglePathAdder` and `FloatingPointDualPathAdder` (<https://github.com/intel/rohd-hcl/pull/106>), with pipelining (<https://github.com/intel/rohd-hcl/pull/126>), (<https://github.com/intel/rohd-hcl/pull/182>).
  - Added explicit J-Bit option for `FloatingPointValue`  and `FloatingPointLogic` (<https://github.com/intel/rohd-hcl/pull/193>) as well as in the `FloatingPointAdderSinglePath` and `FloatingPointAdderDualPath`.  This allows for unnormalized floating-point representation by storing the leading '1' or j-bit in the mantissa.
  - Modified `FloatingPointValue` and `FloatingPointLogic` to support denormal-as-zero (DAZ) and flush-to-zero (FTZ) (<https://github.com/intel/rohd-hcl/pull/212/>).  Implemented in `FloatingPointAdderSinglePath` and `FloatingPointAdderDualPath`.
  - Added `FloatingPointConverter` component (<https://github.com/intel/rohd-hcl/pull/123>), (<https://github.com/intel/rohd-hcl/pull/161>) to convert between different widths of `FloatingPointLogic`.
  - Added `FloatingPointMultipler` base API with `FloatingPointMultiplierSimple` implementation component (<https://github.com/intel/rohd-hcl/pull/152>), (<https://github.com/intel/rohd-hcl/pull/160>).
  - Added square root components for floating-point (<https://github.com/intel/rohd-hcl/pull/188>).
- Added fixed-point support classes `FixedPointLogic` and `FixedPointValue` (<https://github.com/intel/rohd-hcl/pull/99>), (<https://github.com/intel/rohd-hcl/pull/132>), (<https://github.com/intel/rohd-hcl/pull/167>), (<https://github.com/intel/rohd-hcl/pull/172>), (<https://github.com/intel/rohd-hcl/pull/208>).
- Added `StaticOrRuntimeParameter` configuration class which provides API support for configuration of a hardware feature within a component using a single parameter for either static configuration with a `bool` or dynamic configuration with a `Logic` signal (<https://github.com/intel/rohd-hcl/pull/214>).
- Added AXI4 interface with functional model (<https://github.com/intel/rohd-hcl/pull/159>).
- Added Control Status Register capabilities (<https://github.com/intel/rohd-hcl/pull/151>), (<https://github.com/intel/rohd-hcl/pull/205>), (<https://github.com/intel/rohd-hcl/pull/197>).
- Added `Sum` and `Counter` components (<https://github.com/intel/rohd-hcl/pull/89>) which are fully-featured capabilities to track counters with multiple inputs and various options to handle overflow.
- Added `Serializer` and `Deserializer` components (<https://github.com/intel/rohd-hcl/pull/92>) which handle marshalling and unmarshalling of data onto wider or narrower interfaces.
- Added `ReductionTree` module and `ReductionTreeGenerator` component (<https://github.com/intel/rohd-hcl/pull/155>), (<https://github.com/intel/rohd-hcl/pull/180>), (<https://github.com/intel/rohd-hcl/pull/204>) which allow generalized reduction operations of arbitrary radix with pipelining.
- Added `Extrema` component (<https://github.com/intel/rohd-hcl/pull/93>).
- Added clock gating componentry (<https://github.com/intel/rohd-hcl/pull/96>), (<https://github.com/intel/rohd-hcl/pull/111>).
- Added fast `RecursiveModulePriorityEncoder` (<https://github.com/intel/rohd-hcl/pull/178>) to complement `ParallelPrefixPriorityEncoder`.
- Added `OnesComplementAdder` component (<https://github.com/intel/rohd-hcl/pull/85>).
- Added `CompoundAdder` and `CarrySelectOnesComplement` adder components (<https://github.com/intel/rohd-hcl/pull/98>), (<https://github.com/intel/rohd-hcl/pull/178>).
- Added extensive integer multiplication support:
  - Added multiplier componentry such as parameterizable Booth-encoders, different kinds of sign extension on a partial-product array, delay-driven Wallace tree compression, and selection of differnt kinds for final adders (<https://github.com/intel/rohd-hcl/pull/85>).
    - Added special visualization of partial-product arrays for debug (<https://github.com/intel/rohd-hcl/pull/102>),  (<https://github.com/intel/rohd-hcl/pull/107>).
    - Added support for pipelining (<https://github.com/intel/rohd-hcl/pull/118>), (<https://github.com/intel/rohd-hcl/pull/137>), (<https://github.com/intel/rohd-hcl/pull/138>).
    - Added support for rectangular multiplication and multiple kinds of sign extension (<https://github.com/intel/rohd-hcl/pull/154>).
  - Added components `CompressionTreeMultiplier` and `CompressionTreeMultiplyAccumulate` supporting signed and unsigned operands, both statically and logically controlled, rectangular multiplication, Booth encoding with radices 2,4,8, and 16, delay-driven Wallace tree, and configurable final adder, all  with exhaustive narrow-width testing (<https://github.com/intel/rohd-hcl/pull/144>).
  - Added wrapper class `NativeMultiplier`  (<https://github.com/intel/rohd-hcl/pull/125>).
- Added integer `MultiCycleDivider` (<https://github.com/intel/rohd-hcl/pull/87>), (<https://github.com/intel/rohd-hcl/pull/117>), (<https://github.com/intel/rohd-hcl/pull/129>), (<https://github.com/intel/rohd-hcl/pull/141>).
- Added Parallel Prefix Tree components:   adding `ParallelPrefixAdder`, `ParallelPrefixEncoder`, `ParallelPrefixIncr`, `ParallelPrefixDecr` and `ParallelPrefixOrScan` (<https://github.com/intel/rohd-hcl/pull/77>), fixing Issue (<https://github.com/intel/rohd-hcl/issues/12>).  The types of prefix trees supported are `Kogge-Stone`, `Sklansky`, `Brent-Kung`, and `Ripple`.
- Added Ready-Valid Bus Functional Model (<https://github.com/intel/rohd-hcl/pull/69>).
- Added `HammingEccTramsitter` and `HammingEccReceiver` componentry with SECC/SEDDED/SECDED, and SEDDEDTED (<https://github.com/intel/rohd-hcl/pull/74>).
- Added `BinaryToGray` and `GrayToBinary` conversion components (<https://github.com/intel/rohd-hcl/pull/54>).
- Added `EdgeDetector` component (<https://github.com/intel/rohd-hcl/pull/75>).
- Added Serial Peripheral Interface componentry and functional modeling (<https://github.com/intel/rohd-hcl/pull/148>).
- Added `Find-Nth` component (<https://github.com/intel/rohd-hcl/pull/187>).
- Modified `ShiftRegister` component to support async reset and different stage reset values (<https://github.com/intel/rohd-hcl/pull/105>).
- Modified tree form of `OneHotToBinary` to add error generation (<https://github.com/intel/rohd-hcl/pull/211>).
- Fixed bugs in `FifoChecker` sampling at clock edges that caused failures. (<https://github.com/intel/rohd-hcl/pull/70>).
- Updated `ApbTracker` for configurable widths and data (<https://github.com/intel/rohd-hcl/pull/71>).
- Breaking:  `ParityTransmitter` deprecates `parity` for `code`,`checkError` for `error` and `originalData` for `data`.
- Fixed memory model for read-after-write or read on non-zero latency (<https://github.com/intel/rohd-hcl/pull/72>).
- Fixed bug in `SparseMemoryStorage` (<https://github.com/intel/rohd-hcl/pull/195>).
- Improved `MemoryStorage` read (<https://github.com/intel/rohd-hcl/pull/176>).
- Added online schematic generation in the web generator application using [yoWASP](https://yowasp.org/) (WebAssembly form of the [yosys](https://github.com/YosysHQ/yosys) logic synthesis tool) and [d3schematics](https://github.com/Nic30/d3-hwschematic) graphics ([SVG](https://en.wikipedia.org/wiki/SVG)) generation (<https://github.com/intel/rohd-hcl/pull/84>).
- Modified code to be compatible with ROHD 0.6.0 (<https://github.com/intel/rohd-hcl/pull/150>).
- Modified code to be lint-compatible with Dart 3.8 (<https://github.com/intel/rohd-hcl/pull/202>).
- Updated flutter to version 3.27.0 (<https://github.com/intel/rohd-hcl/pull/212/>).
- Added flutter to devcontainer (<https://github.com/intel/rohd-hcl/pull/79>).
- Fixed documentation linting to be compatible with Dart 3.3.0  and above (<https://github.com/intel/rohd-hcl/pull/80>).

## 0.1.0

- The first formally versioned release of ROHD-HCL.
