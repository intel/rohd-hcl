# Control/Status Registers (CSRs)

ROHD HCL provides an infrastructure for creating CSRs at a few different granularities. These granularities are:

- Individual register (as an extension of ROHD's `LogicStructure`).
- A block of registers in which each register is uniquely addressable.
- A top-level module that contains arbitrarily many register blocks, each being uniquely addressable.

Each granularity will be discussed herein.

## Using a CSR Top in Simulation

A `CsrTop` can be built as RTL, as a software model, or both, depending on the
`CsrImplementationConfiguration`:

- `CsrImplementationConfiguration.software` builds no RTL blocks. The top exposes
  `softwareModel`, which supports `poke`, `peek`, `snapshot`, and `load` without
  driving ports. It can export a SystemC software model with `generateModelSystemC`.
  Calling `dumpSystemVerilog` on it throws `UnsupportedError`.
- The default RTL configuration builds hardware. `generateModelSystemC` throws
  `StateError` on an RTL top, so an RTL top is not a software model.

```dart
final top = CsrTop(
  config: config,
  clk: clk,
  reset: reset,
  frontRead: DataPortInterface(16, 8),
  frontWrite: DataPortInterface(16, 8),
  implementationConfiguration: CsrImplementationConfiguration.software,
);
await top.build();

final state = top.softwareModel!;
final command = state.addressOf('control', 'command');
state.poke(command, LogicValue.ofInt(0xbeef, 16));
print(state.peek(command)); // 16'hbeef

final header = top.generateModelSystemC(
  className: 'DeviceCsrs',
  options: const SystemCModelOptions(
    portType: SystemCModelPortType.twoState,
    unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
  ),
);
```

A runnable version is in
[`example/behavioral_model_example.dart`](../../example/behavioral_model_example.dart).
For the general behavioral-model capability, the SystemC options, and the
verification matrix that checks RTL, software, and SystemC legs against the same
register behavior, see [Behavioral Models](./behavioral_models.md).

## Individual CSR Definition

An individual CSR is an extension of a `LogicStructure` and its members are the fields of the register. The class in HW to create a CSR is called `Csr`. It is constructed by passing a configuration object of type `CsrInstanceConfig`.

`Csr.withSet`, `getWriteData`, and `getBackdoorReadData` return `Csr` values,
preserving the register configuration, named fields, and reserved-field layout.
Whole-register write selection also uses typed CSR values internally, including
split writes to registers wider than the frontdoor. Architectural frontdoor
and backdoor buses remain packed bits; access policies and write priority are
unchanged.

### CsrInstanceConfig

The `CsrInstanceConfig` is associated with a particular instantiation of an architecturally defined CSR. As such, it is constructed by passing a `CsrConfig` which defines the architectural CSR being instantiated. In addition to the properties of the architectural configuration, the instance configuration offers the following functionality:

- An address or unique ID for this CSR instance (called `addr`).
- A bit width for this CSR instance (called `width`).
- The ability to override the architectural reset value for this CSR upon construction.
- The ability to override the architectural readability and writability of this CSR (frontdoor, backdoor).
- Validation to check for configuration correctness and consistency.

#### Validation of CsrInstanceConfig

The following checks are run:

- The `resetValue` for this CSR must fit within its `width`.
- Every field of this CSR must fit within its `width`.

### CsrConfig

The `CsrConfig` contains the architectural definition of a CSR (i.e., applies to every instance). An architectural CSR is logically comprised of 1 more fields. As such, it is constructed by providing a list of `CsrFieldConfig`s which defines its fields. The `CsrConfig` exposes the following functionality:

- A name for the CSR (called `name`).
- An access mode for the CSR (called `access`).
- An optional architectural reset value for the CSR (called `resetValue`).
- Configuration for the readability and writeability of the CSR (Booleans called `isFrontdoorReadable`, `isFrontdoorWriteable`, `isBackdoorReadable`, `isBackdoorWriteable`). All of these values default to `true` if not provided.
- Validation to check for configuration correctness and consistency.
- A method `resetValueFromFields()` that computes an implicit reset value for the CSR based on the reset values for its individual fields.

#### CSR Access Modes

At the full CSR granularity, the access modes, defined in the Enum `CsrAccess`, are:

- Read only
- Read/write

Note that access rules only apply to frontdoor accesses. I.e., a read only register is still backdoor writeable if the configuration indicates as such.

#### CSR Readability and Writeability Configuration

We define a "frontdoor" access as one performed by an external agent (i.e., software or some external hardware). For frontdoor accesses, the access (read or write) occurs using the address of the register and only one register is typically accessed via the frontdoor in a given cycle. A status register typically must be frontdoor readable while a control register typically must be frontdoor writeable.

We define a "backdoor" access as one performed by the encompassing hardware module (i.e., parent module reads or writes the register directly). For backdoor accesses, each register is individually and simultaneously accessible. A status register typically must be backdoor writeable while a control register typically must be backdoor readable.

#### Register Field Implications

There are certain special cases that are worth addressing regarding the fields of a CSR.

- It is a legal to have a `CsrConfig` with an empty field list. In this case, a single implicit field is added at hardware generation time that spans the entirety of the register. This field's access rules match the access rules of the register.
- If there are any gap bits between fields within a register, an implicit reserved field is added at hardware generation time to fill the gap. These reserved fields are always read only.

#### Validation of CsrConfig

The following checks are run:

- No two fields in the register have the same `name`.
- No field overlaps with another field in the register.

### CsrFieldConfig

The `CsrFieldConfig` contains the architectural definition of an individual field within a CSR. The `CsrFieldConfig` exposes the following functionality:

- A name for the field (called `name`).
- A starting bit position for the field within the register (called `start`).
- A bit width for the field (called `width`).
- An access mode for the field (called `access`).
- An optional reset value for the field (called `resetValue`). If not provided, the reset value defaults to 0.
- An optional list of legal values for the field (called `legalValues`).
- Validation to check for configuration correctness and consistency.
- A method `transformIllegalValue()` to map illegal field values to some legal one. The default implementation statically maps to the first legal value in the `legalValues` list.

#### CSR Field Access Modes

At the CSR field granularity, the access modes, defined in the Enum `CsrFieldAccess`, are:

- Read only
- Read/write
- Write ones clear (read only from the frontdoor's perspective, but writing 1 has a side effect)
- Read/write legal (can only write a legal value)
- Write only (no persistent storage; frontdoor reads always return the reset value)

Note that field access rules apply to both frontdoor and backdoor accesses of the register. The one exception is "write ones clear": a frontdoor (software) write of `1` clears the corresponding bit, while a backdoor (hardware) write of `1` instead sets the bit, allowing hardware to raise a flag that software later clears.

A "write only" field has no persistent storage of its own: frontdoor writes never change what is stored, so frontdoor reads always return the field's reset value regardless of what was last written. Instead, a frontdoor write is combinationally reflected on the field's backdoor read for that same cycle, letting hardware observe the written value without adding a new port; on any cycle without such a write, the backdoor read shows the field's reset value.

To support the read/write legal mode, the configuration must provide a non-empty list of legal values to check against. In the hardware's logic construction, if a write is attempting to place an illegal value in the field, this write data is remapped to a legal value per the `transformIllegalValue()` method. This method can be custom defined in a derived class of `CsrFieldConfig` but has a default implementation that can be used as is.

#### Validation of CsrFieldConfig

The following checks are run:

- The `resetValue` must fit within the field's `width`.
- If the field has read/write legal access, the `legalValues` must not be empty.
- If the field has read/write legal access, the `resetValue` must appear in the `legalValues`.
- If the field has read/write legal access, every value in `legalValues` must fit within the field's `width`.

### API for Csr

As the `Csr` class is an extension of `LogicStructure`, it inherits all of the functionality of `LogicStructure`. This includes the ability to directly assign and/or consume it like any ROHD `Logic`.

In addition, the following attributes and methods are exposed:

- Accessors to all of the member attributes of the underlying `CsrInstanceConfig`.
- `Logic getField(String name)` which returns a `Logic` for the field within the CSR with the name `name`. This enables easy read/write access to the fields of the register if needed for logic in the parent hardware module.
- `Logic getWriteData(Logic wd)` which returns a `Logic` tranforming the input `Logic` in such a way as to be a legal value to write to the given register. For example, if a field is read only, the current data for that field is grafted into the input data in the appropriate bit position.

## CSR Block Definition

A CSR block is a `Module` that wraps a collection of `Csr` objects, making them accessible to reads and writes. The class in HW to create a CSR block is called `CsrBlock`. It is constructed by passing a configuration object of type `CsrBlockConfig`.

The `CsrBlock` constructor also accepts an `asyncReset` flag that defaults to `false`. When `asyncReset` is `true`, the block's registers treat `reset` as asynchronous. When `false`, `reset` is treated as synchronous.

### CsrBlockConfig

The `CsrBlockConfig` defines the contents of a register block. As such, it is constructed by passing a list of `CsrInstanceConfig`s which defines the registers contained within the block. In addition to the register instance configurations, the block configuration offers the following functionality:

- A name for the block (called `name`).
- A base address or unique ID for the block (called `baseAddr`).
- Methods to retrieve a given register instance's configuration by name or address (`getRegisterByName` and `getRegisterByAddr`).
- Validation to check for configuration correctness and consistency.
- A method `minAddrBits()` that returns the minimum number of address bits required to uniquely address every register instance in the given block. The return value is based on the largest `addr` across all register instances.
- A method `maxRegWidth()` that returns the number of bits in the largest register instance within the block.

#### Heterogeneity in CSR Widths

The `CsrBlock` hardware supports having registers of different widths if desired. As such, the hardware must ensure that the frontdoor data signals are wide enough to cover all registers within the block.

#### Validation of CsrBlockConfig

The following checks are run:

- There must be at least 1 register instance in the block.
- No two register instances in the block have the same `name`.
- No two register instances in the block have the same `addr`.

### Frontdoor CSR Access - Block

The `CsrBlock` module provides frontdoor read/write access to its registers through a read `DataPortInterface` and a write `DataPortInterface`. These are passed to the module in its constructor.

To access a given register, in addition to asserting the enable signal, the encapsulating module must drive the address of the `DataPortInterface` to the address of one of the registers in the block (must be an exact match). If the address does not match any register, for writes, this is treated as a NOP and for reads the data returned is 0x0.

When performing a write, the write data driven on the write `DataPortInterface` is transformed using the target register's `getWriteData` function so as to enforce writing only valid values. If the target register's width is less than the width of the write `DataPortInterface`'s input data signal, the LSBs of the write data up to the width of the register are used.

When performing a read, if the target register's width is less than the width of the read `DataPortInterface`'s output data signal, the register's contents are zero-extended to match the target width. Read data from any register is always correct/legal by construction.

If a given register is configured as not frontdoor writeable, there is no hardware instantiated to write the register through the write `DataPortInterface`. In this case, even on an address match, the operation becomes a NOP.

If a given register is configured as not frontdoor readable, there is no hardware instantiated to read the register through the read `DataPortInterface`. In this case, even on an address match, the data returned will always be 0x0.

On module build, the width of the address signal on both `DataPortInterface`s is checked to ensure that it is at least as wide as the block's `minAddrBits`. On module build, the width of the input and output data signals on the `DataPortInterface`s are checked to ensure that they are at least as wide as the block's `maxRegWidth`.

#### Larger Width Registers in a Block

There is a special mode called `allowLargerRegisters` where any register in the block can have a width that exceeds the width of the frontdoor interface data. In this case, HW generation will assign multiple logical addresses to the given register. Each logical address points to a contiguous chunk of bits in the register. Each chunk is at most the width of the frontdoor data, but can be less (if the register width is not evenly divisible by the frontdoor data width, the last chunk will be smaller). The number of logical addresses (chunks) is `ceil(register.width / frontdoor.data.width)`. The 0th chunk contains the LSBs of the register and has a logical address of `register.address` as defined in its config object. Each subsequent chunk contains the next LSBs of the register and has a logical address of `prior_chunk_address + logicalRegisterIncrement` where `logicalRegisterIncrement` is another construction parameter (with a default value of 1).

Note that there is additional validation to ensure that the implicit addresses "added" by this mechanism do not overlap with any other existing address in the block.

### Backdoor CSR Access - Block

The `CsrBlock` module provides backdoor read/write access to its registers through a `CsrBackdoorInterface`. One interface is instantiated per register that is backdoor accessible in the block and ported out of the module on build.

If a given register is configured as not backdoor writeable, the write related signals on its `CsrBackdoorInterface` will not be present.

If a given register is configured as not backdoor readable, the read related signals on its `CsrBackdoorInterface` will not be present.

The width of the data signals on the `CsrBackdoorInterface` will exactly match the associated register's `width` by construction.

#### CsrBackdoorInterface

The `CsrBackdoorInterface` has the following ports:

- `rdData` (width = `dataWidth`) => the data currently in the associated CSR
- `wrEn` (width = 1) => perform a backdoor write of the associated CSR in this cycle
- `wrData` (width = `dataWidth`) => the data to write to the associated CSR for a backdoor write

The `CsrBackdoorInterface` is constructed with a `CsrInstanceConfig`. This config enables the following:

- Populate the parameter `dataWidth` using the associated register config's `width`.
- Conditionally instantiate the `rdData` signal only if the associated register is backdoor readable.
- Conditionally instantiate the `wrEn` and `wrData` signals only if the associated register is backdoor writeable.

Note that `rdData` actually returns a `Csr` (i.e., a `LogicStructure`). This can be useful for subsequently retrieving fields.

### API for CsrBlock

The following attributes and methods of `CsrBlock` are exposed:

- Accessors to all of the member attributes of the underlying `CsrBlockConfig`.
- `CsrBackdoorInterface getBackdoorPortsByName(String name)` which returns the `CsrBackdoorInterface` for the register within the block with the name `name`. This enables encapsulating module's to drive/consume the backdoor read/write outputs.
- `CsrBackdoorInterface getBackdoorPortsByAddr(int addr)` which returns the `CsrBackdoorInterface` for the register within the block with the address `addr`. This enables encapsulating module's to drive/consume the backdoor read/write outputs.

## CSR Top Definition

A CSR top is a `Module` that wraps a collection of `CsrBlock` objects, making them and their underlying registers accessible to reads and writes. The class in HW to create a CSR top is called `CsrTop`. It is constructed by passing a configuration object of type `CsrTopConfig`.

### CsrTopConfig

The `CsrTopConfig` defines the contents of the top module. As such, it is constructed by passing a list of `CsrBlockConfig`s which defines the blocks contained within the top module. In addition to the register block configurations, the top configuration offers the following functionality:

- A name for the module (called `name`).
- A block size that defines how many addresses of space live in each block (called `blockSize`).
- Methods to retrieve a given register block's configuration by name or base address (`getBlockByName` and `getBlockByAddr`).
- Validation to check for configuration correctness and consistency.
- A method `minAddrBits()` that returns the minimum number of address bits required to uniquely address every register instance in every block. The return value is based on both the largest block `baseAddr` and its largest `minAddrBits`.
- A method `maxRegWidth()` that returns the number of bits in the largest register instance across all blocks.
- An `asyncReset` flag (default `false`) that is propagated down to every `CsrBlock` in the module, controlling whether each block's registers treat `reset` as asynchronous or synchronous. See [CSR Block Definition](#csr-block-definition) for details.

#### Validation of CsrTopConfig

The following checks are run:

- There must be at least 1 register block in the module.
- No two register blocks in the module have the same `name`.
- No two register blocks in the module have the same `baseAddr`.
- No two register blocks in the module have `baseAddr`s that are too close together such there would be an address collision. This is based on the `minAddrBits` of each block to determine how much room that block needs before the next `baseAddr`.
- The `blockSize` must be large enough to cover the largest register address in each block.

### Frontdoor CSR Access - Top

Similar to `CsrBlock`, the `CsrTop` module provides frontdoor read/write access to its blocks/registers through a read `DataPortInterface` and a write `DataPortInterface`. Each of these arguments are optional. These are passed to the module in its constructor.

To access a particular register in a particular block, drive the address of the appropriate `DataPortInterface` to the block's `baseAddr` + the register's `addr`.

In the hardware's construction, each `CsrBlock`'s `DataPortInterface` is driven by the `CsrTop`'s associated `DataPortInterface`. For the address signal, the LSBs of the `CsrTop`'s `DataPortInterface` are used per the offset width derived from `blockSize`. All other signals are direct pass-throughs.

If an access drives an address that doesn't map to any block, writes are NOPs and reads return 0x0.

On module build, the width of the address signal on both `DataPortInterface`s is checked to ensure that it is at least as wide as the module's `minAddrBits`. On module build, the width of the input and output data signals on the `DataPortInterface`s are checked to ensure that they are at least as wide as the module's `maxRegWidth`.

Note that the same parameters `allowLargerRegisters` and `logicalRegisterIncrement` that are found in `CsrBlock` can be passed at the top and propagated down to all blocks within the module. The top-level `asyncReset` flag (see [CsrTopConfig](#csrtopconfig)) is likewise propagated down to every block.

### Backdoor CSR Access - Top

The `CsrTop` module provides backdoor read/write access to its blocks' registers through a `CsrBackdoorInterface`. One interface is instantiated per register in every block that is backdoor accessible and ported out of the module on build.

### API for CsrTop

The following attributes and methods of `CsrTop` are exposed:

- Accessors to all of the member attributes of the underlying `CsrTopConfig`.
- `CsrBackdoorInterface getBackdoorPortsByName(String block, String reg)` which returns the `CsrBackdoorInterface` for the register with name `reg` within the block with name `block`. This enables encapsulating modules to drive/consume the backdoor read/write outputs.
- `CsrBackdoorInterface getBackdoorPortsByAddr(int blockAddr, int regAddr)` which returns the `CsrBackdoorInterface` for the register with address `regAddr` within the block with base address `blockAddr`. This enables encapsulating modules to drive/consume the backdoor read/write outputs.

## Whole-top software implementation

`CsrTop` accepts an optional `implementationConfiguration`, independent of
`CsrTopConfig`. Existing callers still construct synthesizable RTL with the
existing concrete type and hardware backdoor interfaces. `CsrBlock` and
`CsrBlock.csrs` are unchanged.

For a large simulation-only map, select software state before construction:

```dart
final top = CsrTop(
  config: config,
  clk: clk,
  reset: reset,
  frontRead: readPort,
  frontWrite: writePort,
  implementationConfiguration: CsrImplementationConfiguration.software,
);
await top.build();
```

This models the entire top without constructing RTL blocks, individual register
modules, register state signals, or internal forwarding networks. Clock/reset
handling is shared across the top. Normal frontdoor writes use indexed state;
reset and full snapshot/load operations necessarily visit the register map.
The software state starts unknown, just as RTL does before reset.

### Hardware exposure versus software inspection

`CsrImplementationConfiguration.software` exposes **no** per-register hardware
ports. All registers remain available through the frontdoor and software state
API, subject to their respective semantics. Select hardware-connected registers
explicitly when parent logic needs live structured reads or hardware writes:

```dart
const policy = CsrImplementationConfiguration(
  implementation: CsrImplementation.software,
  hardwareRegisters: {'control/command', 'status/value'},
);
```

Keys are `block/register` configuration names. Requested names and architectural
backdoor accessibility are validated. Existing backdoor lookup methods work for
exposed registers and throw for unexposed registers. An empty set exposes none;
`null` exposes all architecturally backdoor-accessible registers. In particular,
selecting `implementation: CsrImplementation.software` without specifying the
set retains full hardware exposure; it does not provide the same connectivity
savings as the `software` convenience constant.

Only selected hardware views allocate `CsrBackdoorInterface`/`Csr` signals and
input listeners. Their cost scales with exposure, not the complete register map.
Selective exposure is not supported by the RTL implementation.

`top.softwareModel` is non-null only for software tops. Its raw state API does
not allocate signals:

```dart
final state = top.softwareModel!;
final address = state.addressOf('control', 'command');
final value = state.peek(address);
final saved = state.snapshot();
state.poke(address, value);
state.load(saved); // Overlay: unspecified registers retain their state.
state.load({}, replace: true); // Unspecified registers take reset values.
```

Addresses are absolute logical register addresses, `block.baseAddr + reg.addr`,
with no implicit conversion to bytes. Wide-register chunk addresses are
frontdoor accesses, not separate entries in the raw state API. Values must have
the exact register width; unknown addresses and width mismatches throw. Loads
validate every entry before changing state. Raw poke/load bypass write
permissions and field side effects: they do not perform W1C operations or emit
write-only command pulses. Connected read outputs update immediately.

The model preserves combinational frontdoor reads (including the existing
read-enable behavior), synchronous write timing, configured reset mode,
frontdoor-over-hardware-write priority, reserved/read-only fields, W1C
hardware-set/software-clear behavior, legal-value transformations, and
write-only command visibility. As in the current RTL implementation,
register-level `readOnly` also prevents architectural hardware-backdoor writes;
raw software loading is distinct. Four-state handling follows ROHD 0.6.11,
including its procedural Z-to-X conversion and mux invalid-value propagation.

`allowLargerRegisters` and `logicalRegisterIncrement` apply to both
implementations. The top now forwards a non-default increment to RTL blocks
as documented; older top construction inadvertently ignored that parameter.

### Indirect construction

A zone-local policy can select models for code that constructs concrete
`CsrTop` instances internally:

```dart
final system = CsrImplementationScope.run(
  CsrImplementationConfiguration.software,
  () => buildSystem(),
);
```

An explicit constructor policy overrides the scope; outside it RTL remains
the default. Selection must surround construction, not just `build()`. Parent
code that enumerates every configured hardware backdoor must itself understand
selective exposure, or disable its backdoor forwarding.

The downstream `CsrHub` was construction-tested unchanged in both same-domain
and CDC paths with two 6,325-register software tops. For that hub, disable
hardware forwarding with `backdoorAccess: false` and raise
`maxBlocksPerCsrTop`/`maxCsrTopsPerHub` to avoid RTL-oriented sharding. This is
not automatic hub-policy integration or a CDC transaction-conformance result.
Loader-side splits can remain configuration metadata without constructing RTL
blocks. Selective hub forwarding and automatic model-aware sharding remain
downstream integration work.

### Dart behavioral output scheduling

Stored-state updates refresh only the affected exposed backdoors. Frontdoor
signal changes separately refresh write-only command views, and outputs already
holding the desired value are not deposited again. Reset and invalid-clock or
unknown-address updates still refresh every affected register. This preserves
command visibility, four-state values, and write priority without scanning all
hardware readers after every ordinary clock edge or frontdoor signal change.
Exposed field-level ROHD signals still incur the simulator's per-wire overhead;
software state alone does not eliminate that cost.

### Behavioral SystemC and unsupported RTL export

After building the top:

```dart
final header = top.generateModelSystemC(className: 'DeviceCsrs');
```

This emits a standalone SystemC header with software-held register metadata and
state, indexed address maps, and two shared processes, not thousands of RTL
submodules. Bind the top's existing port names using `sc_signal<sc_logic>` for
one-bit ports and `sc_signal<sc_lv<W>>` for wider ports. `peek` and `poke` are
also available on the generated class. Custom `transformIllegalValue()`
fallbacks are evaluated during Dart construction and serialized as constants.
Addresses above 63 bits are explicitly unsupported by this backend.

Backdoor port declarations retain their existing names. Width-grouped port
tables connect them to shared write and read-driving loops; the behavioral
algorithms are not unrolled once per register. Register and field metadata and
port-table entries still grow with the exposed map size.

The standalone backend works with released ROHD 0.6.11; no SystemC synthesizer
dependency or ROHD upgrade is required. Its default ports preserve four states.

For a generated two-state hierarchy, use
`generateModelSystemC(className: 'DeviceCsrs', options: options)` with
`SystemCModelOptions(portType: SystemCModelPortType.twoState,
unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset)`. Ports then
use `bool`, `sc_uint<W>` up to 64 bits, and `sc_biguint<W>` above 64 bits, while
register storage and field operations remain four-state. Before the first
reset, an output containing unknown bits drives zero. After the first reset,
such an output raises `SC_REPORT_ERROR("CSR_UNKNOWN_OUTPUT", portName)` and is
not written. Unknown bits are never silently coerced after reset. Raw `peek`
still observes the four-state state. Reset must be applied before normal use.

The downstream `rohd_tools` exporter now accepts a `behavioralDefinition`
callback, also available through `ScBehavioralScope` for indirect generator
calls. The callback selects software tops during synthesis:

```dart
String? behavioralDefinition(Module module, String className) =>
    generateBehavioralSystemC(module, className,
        options: const SystemCModelOptions(
            portType: SystemCModelPortType.twoState,
            unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset));

final result = await ScBehavioralScope.run(
  behavioralDefinition,
  () => writeScSynthFiles(system, outputDirectory, naming, baseName),
);
await writeScPerModuleHeaders(outputDirectory, naming, result.headerDecls);
```

These exporter APIs are in the separate downstream package, not HCL. Once the
provider is installed, nested software tops are substituted automatically;
ordinary parent/APB/CDC logic continues through its normal backend. Existing
generator entry points can be enclosed in the scope without changing their
internal export calls. Construction must separately use the software policy.
The downstream consumer must explicitly resolve an HCL revision containing
this API and its existing ROHD SystemC backend; dependency pins are not changed
by the adapter.

The integrated exporter preserves builder-assigned unique type names,
device-prefix naming, per-module header/source splitting, and umbrella
finalization. Register metadata remains part of each class declaration so
different CSR maps are not deduplicated accidentally. Unsupported custom
leaves without a provider fail explicitly. Using a raw
`SynthBuilder(..., SystemCSynthesizer())` bypasses this downstream adapter.

### Portable memory-model foundation

`CsrTop` implements the opt-in `BehavioralModelProvider` capability. Its
`behavioralModel` is null for RTL and exposes the selected portable model for
software instances. Exporters use `generateBehavioralSystemC` instead of CSR
type checks; unrelated objects and RTL instances return null, while supported
model export failures propagate. No existing memory class must adopt this
capability to retain its current behavior.

`CsrModelDescription.fromConfig` elaborates immutable metadata directly from
architectural configuration, without constructing a top, signals, runtime
state, or simulator listeners. It captures frontdoor `MemoryPortGeometry`,
reset mode, chunk addresses, selected hardware-port names, and deep-copied
register/field configuration. Custom `transformIllegalValue` callbacks are
evaluated once and frozen as four-state values. Both `CsrSoftwareModel` and
the description's `generateSystemC` use that same metadata; export does not
capture runtime state or reevaluate callbacks. A description can be shared by
independent runtimes or exported without ever creating a ROHD module.

`SystemCModelOptions` describes the execution boundary, not memory backing.
Four-state ports are the default. Two-state ports default to reporting
**all** unknown outputs as errors, including before reset. The
`zeroUntilReset` policy above is an explicit CSR integration choice, not an
implicit convention for every future memory family.

`MemoryStateAccess<Image>` is an optional raw-state contract. CSR implements
it with `Map<int, LogicValue>` images and absolute logical register addresses.
`MemoryStorageState` adapts existing `MemoryStorage` using word addresses:
an unpopulated sparse entry returns null, distinct from a stored X value.
Its raw access bypasses alignment and invalid-transaction callbacks. Images
are immutable snapshots; loads validate completely before mutation and support
overlay or replace. Replace resets omitted CSR registers to their reset values
and clears omitted sparse-storage entries. Raw access does not apply
architectural field-write side effects.

`MemoryValueCodec` serializes exact `{width, bits}` values with X/Z and widths
beyond native integers. It rejects malformed/truncated values and never
silently discards bits.

These are reusable foundations, not a generic RAM timing engine. Register-file,
CAM, and legacy storage APIs remain unchanged. Full backing stores, loaders,
banking, SRAM/RF variants, and RAM timing/collision/mask semantics remain later
work; those engines must supply paired ROHD and compiled SystemC conformance
using family-specific descriptions rather than inheriting CSR semantics.

Integration checks compiled and executed two distinct 6,325-register models in
a generated parent (three definitions total), and a 1,000-register software
model behind generated `ApbCsrCompleter` logic, including byte-strobed write
and readback. CDC transaction conformance remains a separate follow-up.

Software tops deliberately reject SystemVerilog synthesis with an
`UnsupportedError`; they never emit an empty functional shell or silently
construct RTL. Use the default RTL policy for synthesizable output. A custom
Verilog software-memory/DPI bridge has not been located or integrated, so
behavioral Verilog remains a follow-up.

### Conformance and scale measurements

The software tests compare RTL, Dart, and compiled/executed SystemC traces,
including unknown controls/data, reset modes, write-only fields spanning
chunks, scalar ports, and data wider than 64 bits or the stored registers.
Additional tests exercise synchronous upstream sampling, non-default address
increments, software loads, explicit scope overrides, APB response latency,
and 1,000/6,325-register construction with zero or fixed selected exposure.

For reproducible measurements, run each implementation in a fresh process:

```sh
dart run tool/csr_model_benchmark.dart --count=1000
dart run tool/csr_model_benchmark.dart --count=1000 --software
dart run tool/csr_model_benchmark.dart --count=6325 --software
dart run tool/csr_model_benchmark.dart --software --yaml=/path/to/map.yaml
```

The optional YAML adapter supports the inspected module/blocks/registers schema;
it is not a replacement for the downstream loader. No external map is included.
`--systemc-output=/path/to/model.h` writes behavioral output for software runs.
JSON output separates configuration, construction, build, export, simulation,
module count, and process peak RSS. Compare like-for-like exposure and workload;
YAML parsing and shared-host conditions can dominate memory/timing.
