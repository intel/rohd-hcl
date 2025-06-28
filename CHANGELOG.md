## TBD

- Added variable-width floating-point support classes `FloatingPointLogic` and `FloatingPointValue` (<https://github.com/intel/rohd-hcl/pull/97>), (<https://github.com/intel/rohd-hcl/pull/110>), (<https://github.com/intel/rohd-hcl/pull/131>), (<https://github.com/intel/rohd-hcl/pull/175>), (<https://github.com/intel/rohd-hcl/pull/134>)
- Added `FloatingPointAdder` component (<https://github.com/intel/rohd-hcl/pull/106>), (<https://github.com/intel/rohd-hcl/pull/126>), (<https://github.com/intel/rohd-hcl/pull/145>), (<https://github.com/intel/rohd-hcl/pull/156>), (<https://github.com/intel/rohd-hcl/pull/182>), (<https://github.com/intel/rohd-hcl/pull/145>)
- Added `FloatingPointConverter` component (<https://github.com/intel/rohd-hcl/pull/123>), (<https://github.com/intel/rohd-hcl/pull/161>).
- Added `FloatingPointMultiplierSimple` component (<https://github.com/intel/rohd-hcl/pull/152>), (<https://github.com/intel/rohd-hcl/pull/160>)
- Added explicit J-Bit form of `FloatingPointAdder` (<https://github.com/intel/rohd-hcl/pull/193>).
- Added `CompoundAdder` component (<https://github.com/intel/rohd-hcl/pull/98>), (<https://github.com/intel/rohd-hcl/pull/178>)
- Added clock gating components (<https://github.com/intel/rohd-hcl/pull/96>).
- Added `ReductionTree` module and `ReductionTreeGenerator` component (<https://github.com/intel/rohd-hcl/pull/155>), (<https://github.com/intel/rohd-hcl/pull/180>), (<https://github.com/intel/rohd-hcl/pull/204>)
- Added square root components for floating-point (<https://github.com/intel/rohd-hcl/pull/188>).
- Added CSR capabilities (<https://github.com/intel/rohd-hcl/pull/151>), (<https://github.com/intel/rohd-hcl/pull/205>), (<https://github.com/intel/rohd-hcl/pull/197>).
- Added `Sum` and `Counter`(<https://github.com/intel/rohd-hcl/pull/89>).
- Added Integer Divider (<https://github.com/intel/rohd-hcl/pull/87>), (<https://github.com/intel/rohd-hcl/pull/117>), (<https://github.com/intel/rohd-hcl/pull/129>), (<https://github.com/intel/rohd-hcl/pull/141>)
- Added `Serializer` and `Deserializer` (<https://github.com/intel/rohd-hcl/pull/92>).
- Added fast `RecursiveModulePriorityEncoder` (<https://github.com/intel/rohd-hcl/pull/178>).
- Added `Extremma` component (<https://github.com/intel/rohd-hcl/pull/93>).
- added `StaticOrRuntimeParameter` configuration component.  (<https://github.com/intel/rohd-hcl/pull/214>).
- Added clock gating componentry (<https://github.com/intel/rohd-hcl/pull/96>), (<https://github.com/intel/rohd-hcl/pull/111>)
- Added fixed-point support classes `FixedPointLogic` and `FixedPointValue` (<https://github.com/intel/rohd-hcl/pull/99>), (<https://github.com/intel/rohd-hcl/pull/132>), (<https://github.com/intel/rohd-hcl/pull/167>), (<https://github.com/intel/rohd-hcl/pull/172>), (<https://github.com/intel/rohd-hcl/pull/208>)
- Added `CompressionTreeMultiplier` and `CompressionTreeMultiplyAccumulate` supporting signed and unsigned operands, both statically and logically controlled, rectangular multiplication, Booth encoding with radices 2,4,8, and 16, delay-driven Wallace tree, and configurable final adder, all  with exhaustive narrow-width testing  (<https://github.com/intel/rohd-hcl/pull/85>), (<https://github.com/intel/rohd-hcl/pull/102>), (<https://github.com/intel/rohd-hcl/pull/107>), (<https://github.com/intel/rohd-hcl/pull/118>), (<https://github.com/intel/rohd-hcl/pull/137>), (<https://github.com/intel/rohd-hcl/pull/138>) (<https://github.com/intel/rohd-hcl/pull/144>), (<https://github.com/intel/rohd-hcl/pull/154>).
- Added wrapper class `NativeMultiplier`  (<https://github.com/intel/rohd-hcl/pull/125>)
- Added Gray Binary conversion  (<https://github.com/intel/rohd-hcl/pull/54>)
-Added online schematic generation in the web generator application using yoWASP (WebAssembly form of the yosys synthesis tool) and d3schematics.  (<https://github.com/intel/rohd-hcl/pull/84>).
- Modified floating-point adders to support DAZ/FTZ (<https://github.com/intel/rohd-hcl/pull/212/>).
- Modified code to be compatible with ROHD 0.6.0 (<https://github.com/intel/rohd-hcl/pull/150>).
- Modified code to be lint-compatible with Dart 3.8 (<https://github.com/intel/rohd-hcl/pull/202>).
- Added Parallel Prefix Tree components:   adding `ParallelPrefixAdder`, `ParallelPrefixEncoder`, `ParallelPrefixIncr`, `ParallelPrefixDecr` and `ParallelPrefixOrScan` (<https://github.com/intel/rohd-hcl/pull/77>), finxing Issue (<https://github.com/intel/rohd-hcl/issues/12>).  The types of prefix trees supported are `Kogge-Stone`, `Sklansy`, `Brent-Kung`, and `Ripple`.
- Added Ready-Valid Bus Functional Model (<https://github.com/intel/rohd-hcl/pull/69>).
- Added `HammingEccTramsitter` and `HammingEccReceiver` componentry with SECC/SEDDED/SECDED, and SEDDEDTED. (<https://github.com/intel/rohd-hcl/pull/74>).
- Added `EdgeDetector` (<https://github.com/intel/rohd-hcl/pull/75>).
- Added SPI component (<https://github.com/intel/rohd-hcl/pull/148>)
- Added `Find-Nth` component (<https://github.com/intel/rohd-hcl/pull/187>).
- Modified `ShiftRegister` to support async reset and different stage reset values (<https://github.com/intel/rohd-hcl/pull/105>)
- Modified tree `OneHotToBinary` to add error generation (<https://github.com/intel/rohd-hcl/pull/211>)
- Fixed bugs in `FifoChecker` sampling at clock edges that caused failures. (<https://github.com/intel/rohd-hcl/pull/70>).
- Fixed bugs in memory model sampling, error handling.  Updated `ApbTracker` for configurable widths and data (<https://github.com/intel/rohd-hcl/pull/71>).
- Fixed memory model for read-after-write or read on non-zero latency (<https://github.com/intel/rohd-hcl/pull/72>).
- Fixed memory double-load bug (<https://github.com/intel/rohd-hcl/pull/195>)
- Improved memory storage read (<https://github.com/intel/rohd-hcl/pull/176>)
- Added configurator for `Find` (<https://github.com/intel/rohd-hcl/pull/78>).
- Added flutter to devcontainer (<https://github.com/intel/rohd-hcl/pull/79>).
- Fixed documentation linting for Dart 3.3.0 (<https://github.com/intel/rohd-hcl/pull/80>).
- Updated flutter to version 3.27.0 (<https://github.com/intel/rohd-hcl/pull/212/>).
- Updated ROHD-HCL description, default permissions (<https://github.com/intel/rohd-hcl/pull/67>).

## 0.1.0

- The first formally versioned release of ROHD-HCL.
