## Unreleased

- Fixed AXI4 subordinate memory transactions to use monitor-captured request fields rather than live signals after a handshake. Write data is captured only by its channel monitor, and write responses wait for both address and data.

## 0.3.1

- Fixed the published package's workspace metadata so consumers do not need the separate Confapp application.

## 0.3.0

### Behavioral models

- Uncertain memory writes now report through the active ROHD-VF test logger, falling back to a printed warning when no verification test is active.
- Added RTL configurator entries for cache compositions, cache scheduling and transaction transport, reusable replacement policies, and inferred SRAM. Experimental cache entries are labeled; the SRAM appears as a schematic cell inside a structural wrapper.
- Marked cache-specific controllers, ports, contracts, adapters, schedulers, replacement factories, and behavioral cache/backing-store APIs `@experimental`; they may change without a version bump. General associative, replacement-policy, and memory-storage APIs are not marked experimental by this change.
- CSR block bases, offsets, extents, logical chunk increments, and software state now support arbitrary-width addresses in RTL, Dart, and SystemC. RTL and software consistently reject overlapping or out-of-range chunks, and Verilog now matches four-state unknown-address read/write behavior.
- Preserved arbitrary-width sparse addresses in memory-file import/export and snapshots; added BigInt raw access and removed width limits from CSR frontdoor and clock-stepped associative SystemC decoding.
- Added a port-compatible parallel associative behavioral model with shared storage, state snapshots, and combinational four-state Dart and SystemC behavior. It can supply cache tags through the common associative factory. Unknown synchronous reset now consistently poisons parallel associative RTL state in both ROHD simulation and Verilog.
- Added directed wide-tag and wide-index associative regressions for concurrent updates, duplicate selection, masked matching, invalid aliases and snapshots, including RTL, Verilog, Dart and SystemC where applicable.
- Parallel associative Dart and four-state SystemC models now poison state on invalid clock transitions as ROHD RTL does. Invalid-clock Verilog edge semantics remain different and are documented.
- Corrected four-state associative key comparisons to retain definite mismatches despite unknown bits, consistently across RTL simulation, Verilog, and Dart and SystemC behavioral models.
- Added a standalone behavioral fixed-priority cache scheduler for Dart and SystemC, with three-way comparisons against generated Verilog including four-state inputs.
- Behavioral round-robin and tree pseudo-LRU replacement policies now preserve RTL four-state behavior and export standalone SystemC models with snapshots. Their synchronous reset and partial-index comparisons also agree between ROHD simulation and generated Verilog when inputs contain unknown bits.
- Added common register-file and one-cycle, single-port inferred SRAM array factories. The SRAM provides execution snapshots and standalone SystemC and can back serialized-cache data independently of flop-based tags. Serialized cache metadata can use a separate combinational-read array factory.
- Added an explicit two-state SystemC hierarchy exporter that substitutes selected portable behavioral models while retaining structural RTL elsewhere. An SRAM-backed serialized cache is compared across Dart, Verilog, and SystemC.

### Breaking changes

- CSR address, block-size, and logical-register-increment getters, description maps, `addressOf`, and software snapshot keys now use `BigInt`. Existing integer configuration constructors remain available; use the `.wide` constructors and BigInt lookup and state methods for arbitrary-width values.
- `MemoryStorageImage.entries` now uses `BigInt` address keys, and implementations of `MemoryStateAccess` must provide BigInt raw access.
- `Cache` and its named constructors now take `CacheLookupPort<T>` and `CacheFillPort<T>` instead of individual signals. Drive inputs and consume outputs on those ports, as with `MultiPortCache`. Cache lookup, fill, scheduler and transaction ports are cloneable ROHD pair interfaces.

- Multipliers, multiply-accumulates, dot products, partial-product building blocks and ones-complement adders now accept `StaticOrRuntimeParameter` controls instead of raw `bool` or `Logic` values. Construct static controls with `staticValue` and runtime controls with `runtime` or `fromLogic`. Multiplier-generator and adder callbacks use the same typed controls.
- `CarrySelectCompoundAdder` block-adder callbacks now accept `subtract` instead of `subtractIn`. `PartialProduct` custom `genPPG` callbacks and `PPGFunction` now use unified `signedMultiplicand` and `signedMultiplier` controls instead of separate static and runtime arguments.
- Automatic `PartialProduct` definition names now include radix and distinguish static from runtime signedness. Consumers that reference these generated HDL names must update them; explicit `definitionName` values are unchanged.
- Automatic `OnesComplementAdder`, `CarrySelectCompoundAdder`, and `CarrySelectOnesComplementCompoundAdder` definition names now distinguish static addition, static subtraction, and runtime subtraction. Explicit `definitionName` values are unchanged.
- SPI main and sub gaskets now asynchronously clear receive state and capture transmit data on the first enabled SPI rising edge instead of asynchronously loading `busIn` on reset. Hold `busIn` stable through the first falling SPI edge; `busOut` is zero immediately after reset. This avoids dynamic asynchronous reset values. See [SPI Gaskets](doc/components/spi_gaskets.md).
- Ready/valid interfaces no longer preserve the deprecated `PairInterface.modify` callback. Pass `uniquify` when connecting or registering an interface instead; naming is now configured at the connection rather than stored on the clone.

- Interface registration now uses ROHD's `addInterfacePorts` and `addPairInterfacePorts` APIs throughout components, tests, and examples. Tag selection, pair roles, typed payloads, and port naming are unchanged.

- Parity/ECC transmitters and receivers now preserve payload types. Receivers accept an optional `dataSchema` for typed original/corrected data; without it they retain ordinary `Logic` outputs. Custom error-checker subclasses should specify their payload type and return that type from `calculateCorrectedData`. Use explicit `<Logic>` when transmitting scalar constants. Encoded wire formats are unchanged.

- `ClockGate.controlled<T>` preserves payload type and width, fixing delayed multi-bit signals. Use `controlled<Logic>` for delayed scalar constants.
- `ReadyValidFifo<T>` now accepts any `Logic` payload.
- CSR write/read candidate builders and bit replacement now return structured `Csr` values.

- Floating-point swap/sort classes now take independent `<FpType, MetaType>` arguments and expose metadata as `MetaType?`. Explicit one-argument annotations must add the metadata type; inferred calls remain supported. Use `Logic` for scalar constant metadata. Metadata layouts, enum mappings, and codecs must match.

- Prefix topologies now preserve their payload type as `ParallelPrefix<T>`, `Ripple<T>`, `Sklansky<T>`, `KoggeStone<T>`, and `BrentKung<T>`. Use `<Logic>` for scalar constant inputs. Custom `ParallelPrefixAdder.ppGen` generators must use `ParallelPrefixGenerator<GeneratePropagate>` and preserve named `generate`/`propagate` fields instead of packed two-bit pairs. Built-in constructor tear-offs remain supported.

- `ShiftRegister<T>` and `AsyncFifo<T>` preserve payload types. Use explicit `<Logic>` for scalar constant inputs.
- `Extrema<T>` preserves payload types and defaults to the payload's comparison rather than flattening domain-specific signals into unsigned bits; pass `.packed` inputs for packed-bit ordering. Use explicit `<Logic>` for scalar constant inputs. Ordinary scalar width extension and earliest-index tie breaking are unchanged.

- Sorting now preserves payload types. Use `BitonicSort<Logic>` when scalar constant inputs should become mutable ports/state. Typed sorting uses the payload's numeric comparisons by default; pass `.packed` inputs for the prior unsigned packed ordering.
- Reduction now preserves payload types. Use `ReductionTree<Logic, Logic>` and `ReductionTreeGenerator<Logic, Logic>` when scalar constant inputs should become mutable ports/state. Structured reduction callbacks now own field/format alignment instead of receiving flattened, bit-extended operands.
- Toggle gating now preserves payload types. Use `ToggleGate<Logic>` when scalar constant inputs should become mutable ports/state.

- `condFlop` now preserves its input's static type and runtime payload schema. When registering a scalar `Const` or `LogicNet`, request `condFlop<Logic>(...)` explicitly to construct a driveable result. Null-clock calls still return their original input.

- `Serializer<T, V>` and `Deserializer<T, V>` now support typed array leaves while preserving outer-dimension transfer timing. Both data outputs are `TypedLogicArray<T, V>`; serialization of a one-dimensional input yields a rank-zero array, with the typed leaf accessible via `.scalar`. The deserializer constructor requires a leaf `valueCodec`; use `LogicValueCodec.logicValue` for existing plain-logic callers. See [Serialization](doc/components/serialization.md).
- The minimum supported Dart SDK is now 3.6.0. Applications using Dart 3.0 through 3.5 must upgrade their SDK before resolving ROHD-HCL.
- Removed `splitSelectAdderAlgorithm4Bit`, deprecated in v0.2.1; use `splitSelectAdderAlgorithmNBit(4)`.
- Removed the interface clone and divider match constructors deprecated in v0.2.1; use instance `clone()`.
- Removed the partial-product sign-extension wrappers deprecated in v0.2.1; use the corresponding `PartialProductSignExtension` strategy.
- Removed `Count.index`, deprecated in v0.2.1; use `count`.
- Removed the parity getters deprecated in v0.2.1; use `code`/`error`/`originalData`.
- `FixedPointValue` comparison operators now return `bool`, completing the transition announced in v0.2.1.
- Corrected AXI5 signal widths to match the configured protocol widths. Generated interfaces for affected `MMUSID`, `MMUSSID`, and `SUBSYSID` signals may have different port widths; designs that connect to those signals must use the corrected widths (<https://github.com/intel/rohd-hcl/pull/280>).
- `ChoiceConfigKnob<Type>` now requires a stable label for every choice, including on the Dart VM, because `Type.toString()` is not stable in minified builds. The labels are used as both display text and serialized JSON values. Existing custom configurators must migrate to the `choiceLabels` construction pattern:

  ```dart
  ChoiceConfigKnob<Type>(
    [BinaryToOneHot, OneHotToBinary],
    value: OneHotToBinary,
    choiceLabels: const {
      BinaryToOneHot: 'BinaryToOneHot',
      OneHotToBinary: 'OneHotToBinary',
    },
  );
  ```

  Labels matching the previous unminified type names, as used by the built-in configurators, preserve compatibility with existing saved values.
- `FloatingPointSqrtSimple` now rejects explicit-J-bit inputs. Use an implicit-J-bit format or normalize the input before connecting it to the square-root component.
- Explicit-J-bit NaN construction now requires at least one payload bit in addition to the J bit. Formats with a one-bit explicit mantissa are rejected because they cannot encode a quiet-NaN payload.
- Automatic definition names for `MultiplyAccumulate`, `CompressionTreeMultiplyAccumulate`, and `GenericMultiplyAccumulate` now include the effective `outputWidth`. Consumers that reference generated HDL definition names must update those names; explicitly supplied `definitionName` values are unchanged.
- Automatic `FixedToFloat`, `FloatingPointAdderSinglePath`, `FloatingPointConverter`, `FloatingPointSqrt`, and `FloatingPointSqrtSimple` definition names now include `roundingMode` so modules with different rounding logic cannot share an HDL definition. Consumers that reference generated HDL definition names must update those names; explicitly supplied `definitionName` values are unchanged.
- Automatic `DotProduct`, `CompressionTreeDotProduct`, and `GeneralDotProduct` definition names now include lane count, operand widths, radix, implementation identity, and signedness. Consumers that reference generated HDL definition names must update those names; explicitly supplied `definitionName` values are unchanged.
- Automatic `Count` definition names now include the tree radix.
- Automatic `Extrema` definition names now include the tree radix and input widths. Consumers referencing the generated `Count` or `Extrema` HDL definition names must update them; explicitly supplied `definitionName` values are unchanged.
- Removed `PartialProductMatrix.array`, which exposed the internal partial-product generator. Apply custom transformations through the `beforeGenerateOutputs` callback to `generateOutputs`.
- Made implementation-only hardware signals and connected interface clones non-public. Consumers must use documented module outputs and caller-owned interfaces instead of accessing child internals directly.
- Reorganized `lib/src` into a category/subcategory directory taxonomy. The public `package:rohd_hcl/rohd_hcl.dart` API is unchanged, but code that imports private `package:rohd_hcl/src/...` paths directly must update those paths or import the package barrel instead.
- Generated `Fifo` definitions retain their existing automatic definition names and latency, but now include the protocol-neutral `canEnqueue`, `outputValid`, and `slotReleased` output ports. External positional SystemVerilog instantiations of generated FIFO definitions must account for the additional outputs; named-port instantiations may leave them unconnected.
- `Counter.overflowed` and `Counter.underflowed` (including `GatedCounter`) are now nullable. The corresponding generated status port exists only when `trackOverflow` or `trackUnderflow`, respectively, is `true`; callers that disable tracking must handle a `null` getter instead of a tied-low signal.

### Deprecated APIs

- Deprecated `ReadyValidFifo` while retaining its existing behavior. Use `ReadyValidQueue` with registered policy and ring storage; unlike the legacy default, the queue permits a full dequeue and enqueue on the same edge.
- Deprecated `Cam` and `TagInterface` while retaining their existing behavior. Use `ParallelAssociativeMemory` and the role-specific associative ports, including typed ports for structured keys. Lookup enable and four-state comparison semantics differ; see [Memory](doc/components/memory.md).
- Restored the legacy `src/gaskets/gaskets.dart` barrel as a deprecated compatibility import. Import `package:rohd_hcl/rohd_hcl.dart` instead.
- Deprecated the unsigned-default `FixedPointValue` constructor and `FixedPointValue.populator` while preserving their existing behavior. Use `FixedPointValue.withSignedness` and `FixedPointValue.populatorWithSignedness`, which default to `signed: true` to match `FixedPoint` (<https://github.com/intel/rohd-hcl/issues/249>).
- Deprecated `FixedPoint.operator *` while preserving its previous unsigned result width and behavior. Use `FixedPoint.multiply` for a correctly signed, full-width product.
- Deprecated the `static_or_runtime_parameter.dart` import path. Import `static_or_runtime_control.dart` instead.
- Deprecated the `subtractIn` constructor parameter and protected member on `OnesComplementAdder` and `CarrySelectOnesComplementCompoundAdder`. Use `subtract` and `subtractParameter`, respectively.
- Kept the deprecated `FixedPointValue.eq`/`neq` compatibility methods. Use `==`/`!=` instead.
- Kept the deprecated `normal`/`subNormal` arguments to `FloatingPointValuePopulator.random`. Use `genNormal`/`genSubNormal` instead.
- Kept the deprecated `loadMemHex` compatibility method. Use `loadMemString` instead.

### New features and enhanced components

- Added simulation-only round-robin and tree pseudo-LRU replacement policies using the RTL replacement ports, including deferred commits and snapshots. Serialized-cache tests compare their timing with RTL replacement and data arrays at fixed read latencies of one through three cycles.
- Added `MemoryModel.registerFile` for finite `RegisterFile`-matching behavior, with synchronous reset, combinational reads, matching masked-write priority, static per-entry reset values, and behavioral SystemC export.
- Added four-state SystemC export and execution snapshots for plain-logic `MemoryModel` instances using built-in sparse storage. Generated RAM, CSR, and associative models share a sparse SystemC storage implementation; unsupported RAM storage, typed payloads, and two-state boundaries are rejected.

- Added direct-mapped, set-associative, and fully associative cache composition with blocking eviction, round-robin or tree pseudo-LRU replacement, typed payloads, pluggable replacement factories, and selectable register-file or behavioral data storage. Non-evicting fills can run alongside lookups with old-data or forwarding behavior. See [Associative Memory](doc/components/associative_memory.md).
- Added `MultiPortCache` with concurrent lookups, one accepted fill per set by default, optional distinct-way same-set fills, buffered evictions with parallel or serialized handshakes, and selectable old-data or forwarding behavior. Latency-bearing SRAM is not yet supported.
- Added a capability-checked typed `MemoryArrayFunctor` for custom cache data arrays with independent and combined concurrency limits, plus persistent replacement reservations and deferred policy commits by reserved entry. The current cache presets remain zero latency.
- `MemoryModel` supports full snapshots and restore of storage, read outputs, and in-flight delayed reads through direct methods and `stateTransactions`.
- `CsrSoftwareModel` supports execution snapshots of register state and sampled event bookkeeping at simulator tick boundaries; external signals and events remain the caller's responsibility.
- Added a clock-stepped associative software model with four-state exact and masked matching, in-flight snapshots, and a capability-limited four-state SystemC export.
- Behavioral CSR, associative memory, and cache state now reuse the sparse storage engine used by the default `MemoryModel`, while preserving each family's timing and state APIs.
- Associative-memory functors can optionally bind multiple indexed side reads without changing existing `AssociativeMemoryBuilder` callbacks.
- Added protocol-neutral transactional cache and resource-scheduler contracts, including typed request, response and eviction channels, along with a fixed-priority resource scheduler, globally serialized fixed-latency `SerializedCache`, and bounded ready/valid `CacheTransactionAdapter`. Protocol-specific miss handling and nonblocking SRAM cores remain separate work.
- Added simulation-only `BehavioralCache` with configurable concurrency, ordered same-set transactions, pluggable replacement, and persistent behavioral backing storage. Explicit extension operations provide read-through and write-allocate behavior without changing built-in cache operation semantics. Backing storage supports raw state images, and the cache supports full-state snapshot and restore including in-flight transactions with snapshot-capable replacement policies.

#### Flow control and clocking

- Added `ReadyValidInterface` and `ReadyValidFifo` in preparation for cache componentry (<https://github.com/intel/rohd-hcl/pull/281>).
- Finalized the ready/valid interface foundation with value-based `ReadyValidContract` metadata, typed payload port registration, accepted/stalled predicates, composability checks, clone-preserved contracts, and independent, ready-first, valid-first, and irrevocable interface variants. Typed registration preserves provider sidebands and nested pair subinterfaces, supports validated packed bridges between plain and structured payload ports, and applies `uniquify` naming consistently to payload, valid, ready, and recursive interface ports.
- Added `ReadyValidQueue` with registered or fall-through visibility, register or ring storage, occupancy thresholds, and synchronous flush, plus a configurator.
- Added the protocol-neutral `HardwareCoreFunctor` construction seam and a typed `FifoCoreFunctor` implementation over `Fifo`, including explicit full-replacement and empty-bypass capability requirements. FIFO core definition identities include a deterministic recursive payload-shape signature so equal-width but structurally different payloads cannot collide. Concrete ready/valid, credit, routing, and scheduling attachments remain later component work.
- Added `AsyncFifo` for safely transferring data between clock domains (<https://github.com/intel/rohd-hcl/issues/168>, <https://github.com/intel/rohd-hcl/pull/279>). Its ports and storage preserve structured, enum, and typed-array payloads without changing delay or CDC behavior (<https://github.com/intel/rohd-hcl/issues/257>).
- Synchronous FIFO storage preserves typed payloads; ready/valid adapters share recursive typed-array shape validation and FIFO definition identities.
- Exposed the module `name` argument on round-robin and related arbiters (<https://github.com/intel/rohd-hcl/pull/255>). `RotateRoundRobinArbiter` also handles zero or one request (<https://github.com/intel/rohd-hcl/pull/305>).
- `ToggleGate` preserves typed data and control through its storage and selection.

#### Memory

- Added `Cam` in preparation for cache componentry (<https://github.com/intel/rohd-hcl/pull/281>). `TagInterface<T>.typed(idWidth, schema)` and `Cam<T>` support typed tag ports, cloning, and storage; width-based scalar interfaces remain supported. CAM lookups retain bit-identity matching, duplicate-index priority, and write/invalidation behavior; layouts/codecs and index capacity are validated explicitly.
- Added parallel associative-memory contracts, lookup/update ports, typed key interfaces, and a parallel-flop implementation.
- `MemoryModel<T>` preserves typed payload interfaces and drives behavioral readback through raw leaf bits, supporting domain-specific structures such as `FixedPoint` without semantic value conversions. Raw storage, four-state values, latency, masks, and reset behavior are retained.
- Preserved typed payloads through `DataPortInterface.typed`, `MaskedDataPortInterface.typed`, and generic `Memory<T>`/`RegisterFile<T>`. Register files now use a `TypedLogicArray<T, LogicValue>` bank, including structured, enum, multidimensional, and rank-zero payloads (<https://github.com/intel/rohd-hcl/issues/256>). Existing width-based ports remain available.
- Added the `RegisterFile.setData` testbench hook for directly initializing register contents (<https://github.com/intel/rohd-hcl/pull/273>).
- Shift-register stages preserve structured, enum, and typed-array payloads without changing their delay (<https://github.com/intel/rohd-hcl/issues/257>). Added an optional `name` parameter to `ShiftRegister`.
- Expanded CSR support with heterogeneous block sizes (<https://github.com/intel/rohd-hcl/pull/285>), configurable asynchronous reset through `CsrTopConfig` (<https://github.com/intel/rohd-hcl/issues/295>, <https://github.com/intel/rohd-hcl/pull/310>), and write-only fields for command, trigger, and pulse semantics (<https://github.com/intel/rohd-hcl/issues/308>, <https://github.com/intel/rohd-hcl/pull/313>).
- Allowed configured hardware-backdoor writes to register-level read-only CSRs in RTL and the Dart and SystemC models, while retaining field access rules and frontdoor priority (<https://github.com/intel/rohd-hcl/pull/306>).

#### Interfaces

- Refactored AMBA support to add AXI4-Lite, AXI4-Stream, ACE, and ACE-Lite protocol variants while preserving the existing AXI APIs (<https://github.com/intel/rohd-hcl/pull/251>).
- Added an abstract `ApbCompleter` and an `ApbCsrCompleter` implementation for connecting APB transactions to CSR blocks (<https://github.com/intel/rohd-hcl/pull/270>).
- AXI4/AXI5 request and response channels and LTI read responses provide opt-in typed enum views. Raw ports remain unchanged; invalid-value normalization in functional simulation is not guaranteed in generated HDL. See [AXI](doc/components/amba/axi.md).

#### Dataflow and shared utilities

- Extrema selects typed payload/index candidates using typed muxes and supports a custom strict `isLessThan` comparator for record keys. Its `radix` parameter combines candidates with a balanced `ReductionTreeGenerator` tree instead of a linear comparison chain.
- Bitonic sort preserves typed data and control through its stages and supports a custom strict `isLessThan` comparator while transporting complete records and typed arrays.
- Both reduction implementations preserve typed data and control.
- Added optional early termination to `Serializer` and `Deserializer` for dynamically sized inputs (<https://github.com/intel/rohd-hcl/issues/277>, <https://github.com/intel/rohd-hcl/pull/278>).
- Shared swaps and optional flops preserve floating-point subtypes, fixed-point formats, enum mappings, and typed-array schemas.
- Floating-point swap/sort metadata ports retain structured payloads; arithmetic field operations and pipeline timing are unchanged.

#### Bit operations

- Added `Pad`, which widens to a minimum width with zeros or ones at the LSB or MSB end, `SetBits`, which sets a count of LSBs or MSBs to zeros or ones, and `WithSet`.
- Added `OneHotMux`, `PriorityMux`, and `BitwiseMux`, which supports N inputs and per-bit one-hot selects. The one-hot mux validates its cases and selector width and addresses <https://github.com/intel/rohd-hcl/issues/95>.
- Added `BitwisePopcount` with `XorPopcount` and `XnorPopcount`.
- Added a `radix` parameter to `Count` so its population count is combined with a balanced `ReductionTreeGenerator` tree instead of a linear accumulation chain.
- Rotation now also offers fixed left and right implementations.

#### Arithmetic building blocks

- Added `UnsignedAddWithOverflow`, `UnsignedMulWithOverflow`, `CeilDivide`, `Log2Ceil`, and `AbsoluteValue`, which widens by one bit so the minimum value is representable.
- Added `CircularPointer` for wrapping slot indices of any slot count.
- Preserved structures, enum mappings, and typed-array schemas through prefix ports, callback results, recursive networks, and internal aliases. Added explicit structured-layout validation while retaining scalar widths and operand order. Prefix adders use typed generate/propagate records internally; external arithmetic ports and carry behavior are unchanged.

#### Floating-point and fixed-point payloads

- `FloatToFixed<T>` accepts an optional signed `outFixed` schema, preserves its concrete subtype internally and on output, and validates explicit width compatibility. Scalar defaults remain unchanged. `Float8ToFixed` preserves structured input schemas while retaining its intentionally mode-dependent scalar output.
- Fixed-point square root retains its concrete output subtype; floating-point square-root selection preserves its fixed-point intermediate schema.
- Floating-point adders and the simple multiplier carry NaN payloads through typed optional pipeline stages and use whole-payload typed muxes for final propagated/default NaN selection.

#### IEEE rounding compatibility

- Added all `FloatingPointRoundingMode`s to floating-point value and logic operations, including adders, multipliers, converters, square root, `FixedToFloat`, and `FloatToFixed` (<https://github.com/intel/rohd-hcl/issues/191>).
- Added `roundingMode` to `FixedToFloat` and `FloatToFixed`, retaining their previous defaults of `roundNearestEven` and `truncate`, respectively.
- Unified fixed- and floating-point value rounding APIs (<https://github.com/intel/rohd-hcl/issues/173>).

#### Conversions

- Added exact, host-`double`-independent conversion between `FloatingPointValue` and `FixedPointValue`, with automatic-width lossless methods and width-constrained populator methods (<https://github.com/intel/rohd-hcl/issues/112>).
- Added `toLogic()` conversion from `FixedPointValue` and `FloatingPointValue` to constant corresponding signal types (<https://github.com/intel/rohd-hcl/issues/200>).

#### Arithmetic signal operations

- Added typed `add`, `subtract`, and `multiply` methods and direct `+` and `-` operators to `FixedPoint` signals, and arithmetic methods and operators to `FloatingPoint` signals (<https://github.com/intel/rohd-hcl/issues/199>).

#### Integer arithmetic components

- Added an optional `carryIn` to `SignMagnitudeAdder`.
- Added configurable `outputWidth` to `MultiplyAccumulate`, `CompressionTreeMultiplyAccumulate`, and `MultiplyOnly`.
- Added `GenericMultiplyAccumulate`, which composes configurable multiplier and adder generators.
- Added independent multiplicand and multiplier widths to `NativeMultiplier` and `GeneralDotProduct`; `CompressionTreeDotProduct` retains its equal-width fused-partial-product contract.

#### Accumulation

- Added the `Counter.upDown` convenience constructor for incrementing and decrementing by one (<https://github.com/intel/rohd-hcl/pull/271>).
- Added static reachable-range analysis to omit impossible overflow/underflow checks and normalization branches in `Sum` and `Counter`; `trackOverflow`/`trackUnderflow` can additionally omit unused status history flops (<https://github.com/intel/rohd-hcl/issues/90>).

#### Parameterized Configuration

- Added generic `StaticOrRuntimeControl<T>` support for statically configured values or multi-bit runtime `Logic` inputs while preserving `StaticOrRuntimeParameter` as the boolean specialization.
- Added child-module rebinding and static-pruned or runtime-mux selection to static-or-runtime controls. Low-level multiplier signedness and compound-adder block callbacks now use the same control model as top-level components.

#### Source Organization

- Grouped existing components into top-level categories: `arithmetic`, `bit_operations`, `clocking`, `dataflow`, `encodings`, `error_control`, `flow_control`, `interfaces`, `memory`, and `models`. Each category has functional subcategories, such as `arithmetic/addition`, `clocking/cdc`, `flow_control/arbitration`, `flow_control/ready_valid`, and `memory/csr`.
- Added category barrels and subcategory barrels where useful, so related components can be imported selectively. `lib/rohd_hcl.dart` now exports the category barrels.
- Moved tests under their matching category directories and subdivided larger families by source subcategory.
- Renamed the misspelled internal `mulitiplier_components.dart` barrel to `multiplication/multiplier_components.dart`.

#### Configurator Taxonomy

- Added `ComponentCategory` and `Configurator.category`/`Configurator.subcategory` so configurators can describe where a component belongs in the library taxonomy. Custom configurators default to `ComponentCategory.other` and `'uncategorized'`.
- Tagged all built-in configurators with their category and subcategory.

### Configuration application and schematics

- Migrated the configuration application and generated API-documentation schematics from the legacy D3 flow to `rohd_schematic_viewer`. The new flow renders native ROHD netlists, retains Yosys-based synthesized schematics, and redirects existing component schematic URLs to the new viewer.
- Added selectable ROHD schematic, ROHD source, generated SystemVerilog, and synthesized schematic views, including syntax highlighting, downloadable generated artifacts, configurable schematic expansion, and split-pane output.
- Migrated the configuration application to `material_ui`, including light and dark themes, and removed its legacy Flutter Material dependencies.
- Converted the root package and configuration application to a Pub workspace and added package-by-package hosted, Git, and local dependency-source selection for development.
- Updated the source-view asset mapping and generated asset list for the reorganized source tree.
- Replaced plain-text integer parameter fields in confapp with validated `IntegerKnobControl` steppers, supporting unit increment/decrement, hexadecimal input, optional blank values, and inline validation. The implementation is in `confapp/lib/hcl/view/screen/integer_knob_control.dart`, with tests mirrored under `confapp/test/hcl/view/screen/`.
- Added `PositiveIntConfigKnob` (minimum 1), `NonNegativeIntConfigKnob` (minimum 0), and optional `IntConfigKnob.minValue`; ordinary integer knobs retain signed values. Applicable component parameters declare their lower bounds while retaining defaults and saved JSON formats. Invalid integer text and below-minimum assignments now throw rather than silently retaining old values.
- Expanded the configuration application catalog, including configurators for absolute value, circular pointers, ceil division, mux and bitwise-popcount variants, bit manipulation, synchronizers, ready/valid FIFOs, and a two-register CSR example. The catalog excludes deprecated `ReadyValidFifo` and `Cam` in favor of their replacements; their configurators remain available programmatically. See [ready/valid](doc/components/ready_valid.md) and [memory](doc/components/memory.md) for behavioral differences.
- Grouped the component catalog into compact, expandable, initially collapsed category and subcategory menus using configurator metadata.
- Bundled Roboto Mono for generated source output.
- Added configuration controls for `Count`/`Extrema` radix and static-or-runtime summation values, Counter reset behavior, and overflow/underflow tracking.
- Added a lock toggle to the configuration application component menu; when unpinned, the menu slides out on hover from the left edge and hides when the pointer leaves.
- Added a lock toggle to the configuration application output toolbar; when unpinned, the toolbar slides down on hover from the top edge and hides when the pointer leaves.

### Documentation

- Reorganized the component list in `doc/README.md` by taxonomy and added a source-layout table that maps categories to their barrels and subcategories.
- Updated the new-component instructions in `CONTRIBUTING.md` and `doc/Component.md` to cover taxonomy directories, subcategory barrels, family-based test locations, configurator category tags, and confapp source assets.
- Added guides for protocol composition and associative-memory contracts, implementation selection, and migration from legacy CAM.
- Fixed stale source paths in component documentation.

### Bug fixes

- Reworked sum accumulation to avoid generated combinational feedback warnings.
- Added a divider state-case default. The multi-cycle divider retains its existing three-bit state machine using `LogicEnum`; invalid or unknown state/control behavior can differ from the untyped implementation.
- APB state comparisons now use the FSM's enum encoding.
- Corrected CAM functional lookup matching when stored tags or query bits contain X or Z, using ROHD's opt-in exact four-state case matching.
- Corrected CSR software and SystemC backdoor reads of write-only fields to preserve known bits when write data or enable contains unknown values.
- Corrected signed `FixedPoint` signal comparisons for negative and mixed-sign operands, enabling numeric ordering in typed sort modules.

- Ensured the `Serializer` counter has a valid width for single-element inputs and added regression coverage (<https://github.com/intel/rohd-hcl/issues/166>, <https://github.com/intel/rohd-hcl/pull/284>).
- Fixed `loadMemString` data loss across discontinuous sections whose starting addresses are not word-aligned (<https://github.com/intel/rohd-hcl/pull/293>).
- Prevented `FifoChecker` from reading an invalid previous error value and crashing the simulator (<https://github.com/intel/rohd-hcl/pull/292>).
- Fixed AXI4 memory-subordinate multi-beat writes so each beat is stored at its corresponding address and stale queued data cannot leak across bursts (<https://github.com/intel/rohd-hcl/issues/290>, <https://github.com/intel/rohd-hcl/pull/289>).
- Fixed CSR frontdoor decoding for non-power-of-two-aligned block base addresses and corrected the minimum required address width calculation (<https://github.com/intel/rohd-hcl/issues/294>, <https://github.com/intel/rohd-hcl/pull/309>).
- Implemented the documented write-ones-clear CSR behavior, with software writes clearing bits and backdoor hardware writes setting them (<https://github.com/intel/rohd-hcl/issues/296>, <https://github.com/intel/rohd-hcl/pull/311>).
- Enabled independent AXI4 subordinate read and write response-delay callbacks and corrected their timing behavior (<https://github.com/intel/rohd-hcl/issues/303>, <https://github.com/intel/rohd-hcl/pull/312>).
- Corrected the default `Counter` definition name.
- Made `GatedCounter` honor asynchronous reset for its count flops.
- Fixed `ClockGate` bypass mode to create module-owned free-clock and gated-clock ports rather than directly exposing parent logic.
- Corrected a fully initialized `Fifo` to wrap its reset write pointer, preserving same-cycle full dequeue/replacement behavior at depth one and non-power-of-two depths.

#### IEEE rounding compatibility bugs

- Corrected round-nearest-even sticky-bit handling in `FloatingPointMultiplierSimple` near the subnormal boundary (<https://github.com/intel/rohd-hcl/issues/194>).
- Replaced `FixedToFloat`'s custom rounding with the shared `FloatingPointRounder`.
- Verified round-nearest-even behavior across mantissa widths and subnormal boundaries (<https://github.com/intel/rohd-hcl/issues/190>).
- `FixedToFloat` overflow results now respect the selected rounding mode and use the largest finite value for formats without infinity.

#### Conversion fixes

- Fixed `FloatingPointConverter` when narrowing the mantissa and widening the exponent of a subnormal value (<https://github.com/intel/rohd-hcl/issues/241>).
- Fixed `FloatToFixed` conversion from explicit-j-bit formats.
- Fixed `FloatToFixed` overflow detection for reduced precision, rounding carry, and the exact negative power-of-two boundary.
- Fixed wide `FloatingPointValue.toString(integer: true)` conversions.

#### NaN and special values

- Fixed single-path floating-point addition of infinities and NaNs when input J-bit formats differ, including infinity signs and invalid-operation status. Shared NaN propagation preserves the selected input's format and payload.
- Corrected IEEE-754 NaN comparisons and added `hasSameEncoding()` (<https://github.com/intel/rohd-hcl/issues/252>).
- Fixed explicit-j-bit infinity and NaN encodings and quiet/signaling NaN classification.
- Fixed E4M3 exponent limits and prevented finite results from rounding into its reserved NaN encoding (<https://github.com/intel/rohd-hcl/issues/115>).
- Fixed `FloatingPointValuePopulator.random(excludeInfinity: true)` for formats without infinity.
- Fixed `FloatingPointValue.isLegalValue()` accepting explicit-j-bit unnormal encodings.

#### Subnormal handling

- Fixed `FloatingPointValue.ulp()` for subnormal values and removed its dependency on host `double` precision (<https://github.com/intel/rohd-hcl/issues/206>).
- Fixed zero multiplication with a widened output exponent in `FloatingPointMultiplierSimple` (<https://github.com/intel/rohd-hcl/issues/194>).
- `FloatingPointSqrtSimple` now reports underflow when an inexact result remains subnormal.

#### Fixed-point fixes

- Added `FixedPoint.multiply` to produce a correctly signed, full-width product.
- Fixed `FixedPointValuePopulator.canStore()` to use the rounded value and the asymmetric two's-complement range.

#### Integer arithmetic component fixes

- Preserved independent runtime signedness controls for multipliers and multiply-accumulates, including unnamed controls, and allowed one named signal to control both compression-tree multiplier operands. Conflicting scalar runtime-control input names now throw instead of silently aliasing.
- Fixed `GeneralDotProduct` truncating intermediate sums and sign-extending unsigned products in uneven reduction trees. Static and runtime operand signedness now control partial-sum extension.
- Fixed `GeneralDotProduct` passing static signedness to child multipliers as constant-valued runtime ports, and strengthened automatic definition names with lane count, operand widths, radix, implementation identity, and signedness.
- Fixed runtime-signed `GeneralDotProduct` synthesis by keeping its signed-extension control inside the inline reduction generator rather than capturing a parent signal across a reduction-module hierarchy boundary.
- Fixed `CarrySaveMultiplier` ignoring `enable` instead of stalling every pipeline stage.

#### Flow Control

- Fixed `AsyncFifo` incorrectly advancing its write pointer when full and its read pointer when empty.

#### Encodings

- Replaced `BinaryToGrayConverter` and `GrayToBinaryConverter`'s `O(2^width)` `Case`-based logic with linear XOR-based conversion.

#### Floating-point arithmetic

- Floating-point overflow uses a full magnitude comparison without an always-false mantissa comparison.
- Made `FloatingPointValue.operator /` exact and correctly rounded for arbitrary widths, removing its host-`double` dependency (<https://github.com/intel/rohd-hcl/issues/113>).
- Fixed `FloatingPointMultiplierSimple` when the output format is narrower than its inputs (<https://github.com/intel/rohd-hcl/issues/194>).
- Fixed `FloatingPointValue()` forwarding of the `signed` argument.

### Tooling and compatibility

- Updated analysis settings and added `pana` validation for pub.dev scoring (<https://github.com/intel/rohd-hcl/issues/262>, <https://github.com/intel/rohd-hcl/pull/263>).
- Updated source and analysis configuration for newer Dart lints (<https://github.com/intel/rohd-hcl/pull/282>, <https://github.com/intel/rohd-hcl/pull/300>).
- Updated GitHub workflows to Node.js 24 (<https://github.com/intel/rohd-hcl/pull/288>).
- Updated compatibility to ROHD 0.6.11 and set the Dart SDK range to `^3.6.0`.
- Pointed the root and confapp `dependency_overrides` for ROHD and its UI packages at `intel/rohd` `main`, so checked-in builds resolve from git rather than local paths.

### Verification and maintenance

- Added common smoke coverage for the generic `FloatingPointValue` and all named formats (<https://github.com/intel/rohd-hcl/issues/133>).
- Corrected the floating-point truncating exhaustive test's overflow oracle.
- Extended typed storage regressions to check unpacked payloads with Icarus and to compare plain and typed FIFOs with SystemC using explicit clock edges.
- Expanded exhaustive coverage for conversions, rounding, floating-point arithmetic, fixed-point multiplication, and multiply-accumulate widths.
- Reduced redundant randomized/exhaustive test matrices and deferred parameterized DUT construction until test execution, retaining boundary and configuration coverage while lowering test time and peak simulator memory.
- Re-enabled `previousFloatingPointValue` regressions after the upstream ROHD fix (<https://github.com/intel/rohd/pull/565>).
- Resolved stale arithmetic TODOs where exhaustive testing confirmed the existing implementation.
- Added copyright and author headers to all source, test, and example Dart files that lacked them.

### Known issues

- Berkeley TestFloat integration remains unimplemented (<https://github.com/intel/rohd-hcl/issues/135>).
- `MultiCycleDivider` improvements remain in a stale pull request (<https://github.com/intel/rohd-hcl/issues/139>).
- A 4:2 `ColumnCompressor` remains in a stale pull request (<https://github.com/intel/rohd-hcl/issues/120>).
- Static range analysis cannot prune overflow/underflow logic when bounds or initial-value ranges are dynamic; those checks are conservatively retained.
- `CompressionTreeMultiplyAccumulate` can discard precision when `c` exceeds its natural accumulation width; `GenericMultiplyAccumulate` does not.
- Potential optimizations remain in compact sign extension.
- Potential optimizations remain in `FixedToFloat` exponent prediction.
- Potential optimizations remain in the dual-path floating-point adder N-path.

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
