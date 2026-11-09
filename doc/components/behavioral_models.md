# Behavioral Models

A component in ROHD-HCL can exist in several forms. Each form answers a
different question, so it is worth separating them before using any of them.

| Form | What it is | Synthesizable | Typical use |
| --- | --- | --- | --- |
| **ROHD RTL** | A `Module` built from `Logic`, flops, and operations | Yes (SystemVerilog via `dumpSystemVerilog`) | The hardware that ships |
| **ROHD behavioral module** | A simulation-only `Module` implementing a supported component's ports in Dart | No | Substitute a behavioral implementation inside a ROHD hierarchy |
| **Software reference** | A plain Dart object holding state, with no hardware ports | No | Testbench reference and state inspection |
| **SystemC behavioral model** | A generated C++ implementation of a supported behavioral boundary | No | Substitute a selected leaf in a generated SystemC hierarchy, or bind it in a testbench |

RTL and port-compatible behavioral modules are alternative implementations of
the same component boundary where the relevant model is available. The
behavioral implementation runs in place in simulation; a software reference can
also be used independently to predict and inspect behavior. Models do not
replace RTL verification; they are checked against it.

## API Maturity

| API boundary | Maturity and scope |
| --- | --- |
| CSR and parallel associative memory | Not experimental; use their documented implementation choices, configurations and limitations |
| General associative, replacement-policy and memory-storage building blocks | Not marked experimental as part of the cache API; support is governed by each building block's contract |
| Cache-specific APIs | `@experimental`: controllers, lookup/fill and transaction ports and contracts, adapters, schedulers, cache replacement factories, and behavioral cache and backing-store APIs may change or be removed without a version bump |
| Legacy `Cam` | Deprecated; its behavior differs from parallel associative memory |

`@experimental` describes API stability, not whether an existing mode is tested.
Conversely, an unmarked API is not a promise that every configuration or backend
is supported or equivalent. Analyzer feedback for experimental APIs depends on
the tooling; consult this documentation as well as annotations. The
[associative-memory guide](associative_memory.md) describes the supported
parallel contract and cache mode boundaries.

## Current Substitution Boundaries

| Component | ROHD implementation choice | SystemC hierarchy | Scope |
| --- | --- | --- | --- |
| `CsrTop` | RTL or software configuration | Select software `CsrTop` instances as behavioral leaves | Frontdoor and selected hardware backdoors; preserve the required backdoors when configuring software |
| `ParallelAssociativeMemory` | RTL or `behavioralParallelAssociativeMemoryFunctor` | Select `BehavioralParallelAssociativeMemory` instances as behavioral leaves | Exact-match parallel memory with the supported timing, reset and priority contract |
| Legacy `Cam` | RTL | No port-compatible behavioral replacement for the legacy interface | Deprecated; see [migration differences](associative_memory.md#migrating-from-legacy-cam) |
| Cache controllers | RTL controllers, with selected behavioral components | Supported behavioral leaves can be substituted in a generated structural hierarchy | A complete behavioral replacement is not available for every controller |

Hierarchy substitution currently uses two-state SystemC ports. Four-state
behavior and known limitations, including invalid clock and asynchronous CSR
reset transitions, are described in the
[CSR](csr.md#whole-top-software-implementation) and
[associative-memory](associative_memory.md#port-compatible-associative-behavioral-model)
documentation. The standalone clock-stepped associative software reference is a
different interface and is not a replacement for the parallel module.

## The Behavioral Model Capability

A component that can produce a model implements the opt-in
`BehavioralModelProvider` interface. Its `behavioralModel` getter returns either
a `BehavioralModel` or `null`:

- A software instance returns the portable model for its architecture.
- An RTL instance normally returns `null`, unless it also supplies a matching
  portable behavioral implementation, as `InferredSram` does.

Export code should use `generateBehavioralSystemC(candidate, className, options:
...)` rather than checking concrete types. The function returns `null` for
unrelated objects and RTL instances without a provider. A supported model that
fails to export throws, rather than producing silently incomplete output.

Existing components do not need to implement this capability to keep their
current behavior.

For a structural hierarchy, `generateBehavioralSystemCHierarchy` explicitly
selects modules to replace with their portable implementations. It validates
their input and output names and widths and uses ROHD's normal SystemC
generation for the rest. The result contains `source` and the uniquified
`topClassName`. Selected modules without a model and unsupported unselected
modules cause errors; they are not replaced with stubs. The selector is
evaluated once per module. ROHD's builder still visits descendants of selected
modules, so unsupported descendants must themselves be handled.

```dart
final hierarchy = generateBehavioralSystemCHierarchy(
  top,
  select: (module) => module is InferredSram,
  unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
);
```

This hierarchy uses ROHD's **two-state** SystemC ports; selecting
`zeroUntilReset` suppresses unknown output values only until reset, not
afterwards. Selecting a model is an explicit choice: matching port geometry does
not prove behavioral or cycle equivalence. The standard ROHD
`SimCompare.checkSystemCVector` does not use this exporter automatically.

## Shared Storage and Family Behavior

The built-in Dart models reuse `SparseMemoryStorage` for stored bits:
`MemoryModel` uses it by default, while the CSR, associative, and behavioral
cache models use it internally for register values, indexed keys/validity,
resident lines, and backing blocks. Records with multiple fields are packed into
storage words; CSR registers retain their individual logical widths. This shares
four-state value storage and Z-to-X normalization without making the models'
interfaces or state images interchangeable.

The outer models still define their own behavior: CSR field side effects,
associative matching and collision policies, cache replacement and transaction
ordering, and RAM address and mask handling. In particular, symbolic
uncertain-address writes and caller-supplied storage callbacks are RAM storage
features; sharing the built-in storage engine does not add those behaviors to
other models. The generated RAM, CSR, and associative SystemC models also share
a sparse four-state storage implementation, with family-specific logic for
timing and access.

`BehavioralCache`, the concurrent transactional cache model, does not currently
provide a whole-cache SystemC behavioral implementation. This does not preclude
generating a SystemC cache hierarchy: supported leaves, such as behavioral
associative tags and replacement policies, can be substituted while the cache
controller and other supported logic are generated by ROHD. See [Associative
Memory](associative_memory.md#rtl-and-behavioral-implementations) for the
selection and integration process and its current limitations.

`InferredSram` is an inferable RTL memory with a port-compatible SystemC
behavioral implementation. Its ROHD simulation uses `SparseMemoryStorage`; its
SystemC model uses the shared SystemC sparse storage. Both implement the SRAM's
one-cycle registered read and synchronous reset of the read output; reset does
not clear stored words. The SystemC hierarchy exporter can select it as a
behavioral leaf independently of the cache controller.

Each model exposes a `BehavioralModelDescription` with its `kind`, `inputPorts`,
and `outputPorts`. Port widths are validated through `MemoryPortGeometry`, which
requires positive widths.

## Using a Software Model in Simulation

The CSR example below builds a software top, then uses raw state access. It is
adapted from
[`example/behavioral_model_example.dart`](../../example/behavioral_model_example.dart):

```dart
final top = CsrTop(
  config: exampleCsrConfig(),
  clk: Logic(name: 'clk'),
  reset: Logic(name: 'reset'),
  frontRead: DataPortInterface(16, 8),
  frontWrite: DataPortInterface(16, 8),
  implementationConfiguration: CsrImplementationConfiguration.software,
);
await top.build();

final state = top.softwareModel!;
final command = state.addressOf('control', 'command');

state.pokeBigInt(command, LogicValue.ofInt(0xbeef, 16));
print(state.peekBigInt(command));  // 16'hbeef
```

A software top does not construct RTL blocks, so it cannot be turned into
SystemVerilog. `dumpSystemVerilog` on a software top throws `UnsupportedError`.
Use the default RTL configuration for synthesizable output.

Run the full example with:

```sh
dart run example/behavioral_model_example.dart
```

## Raw State Access

`MemoryStateAccess<Image>` is an optional contract for reading and writing a
model's state directly, outside the architectural interface:

- `peek(address)` returns the value. For sparse storage (`MemoryStorageState`),
  it returns `null` for an unpopulated entry, which is distinct from a stored X.
- `poke(address, value)` writes without architectural side effects. Field write
  permissions and write side effects are not applied.
- `peekBigInt(address)` and `pokeBigInt(address, value)` accept arbitrary-width
  logical addresses; the `int` methods remain available for existing callers.
- `snapshot()` returns an immutable image.
- `load(image, {replace = false})` applies an image. Loads validate the whole
  image before mutating anything. With `replace: true`, omitted entries are
  reset: CSR registers return to their reset values, and omitted sparse entries
  are cleared.

CSR implements this with `Map<BigInt, LogicValue>` images keyed by absolute
register address. `MemoryStorageState` adapts existing `MemoryStorage` (used by
`MemoryModel`), keyed by word address. Its `MemoryStorageImage` uses `BigInt`
entry keys and contains explicit entries and symbolic uncertain-address writes;
restoring only the entries would lose information. Its raw access bypasses
alignment and invalid-transaction callbacks, so it is a state tool, not a RAM
timing model. For a complete timed `MemoryModel` image, use the model's
`snapshot`, `restore`, or `stateTransactions`; those include pending read
completions and read outputs in addition to the storage image. The generated
SystemC RAM provides its own `snapshot()` and `restore()` images including
storage, sampled inputs, outputs, and pending reads. Coordinate external signals
and simulator events when restoring; those events, including the model's
delta-cycle notifications, are not part of the image. Take and restore images
after the relevant delta cycles have settled. `AssociativeSoftwareModel`
provides raw entry images and separate execution snapshots with pending lookups
and updates. Its currently supported SystemC configuration and clock-stepped
boundary are described in [Associative
Memory](./associative_memory.md#clock-stepped-software-reference). For CSR execution
state, `snapshotExecution`, `restoreExecution`, and `stateTransactions`
additionally capture sampled inputs and pending simulator-edge bookkeeping. They
must be called between simulator ticks; images can only be restored to the
originating model. External signals and scheduled events are not included and
must be coordinated by the caller. `BehavioralCacheBackingStore` also implements
this contract with an image containing data and opaque metadata. The cache
itself exposes a separate full-state image and `stateTransactions`, including
in-flight transactions and replacement state; see [Concurrent behavioral
cache](./associative_memory.md#concurrent-behavioral-cache). `InferredSram`
similarly offers raw `peek`/`poke` and a complete execution image through
`snapshot`, `restore`, and `stateTransactions`.

These APIs do not imply that every model is interchangeable with every RTL
configuration. The parallel associative RTL has a matching port-level behavioral
model; the separate clock-stepped associative software model does not expose
that four-state port protocol. The concurrent behavioral cache is not
cycle-equivalent to `SerializedCache`, and neither currently provides a complete
standalone SystemC equivalent for all cache configurations. Register-file
runtime reset values and some typed/custom-storage SystemC exports also remain
unsupported.

## Serializing Values

`MemoryValueCodec.encode` and `MemoryValueCodec.decode` round-trip a
`LogicValue` as `{width, bits}`. X and Z are preserved, and widths are not
limited to native integers. Malformed or truncated input throws
`FormatException`; bits are never silently dropped.

## SystemC Options

`SystemCModelOptions` controls the execution boundary of a generated model. It
does not depend on the storage family:

- `portType`: `SystemCModelPortType.fourState` (default) or `twoState`.
- `unknownOutputs`: `SystemCUnknownOutputPolicy.error` (default) or
  `zeroUntilReset`.

With two-state ports, unknown outputs are reported as errors by default,
including before reset. `zeroUntilReset` is an explicit integration choice; the
example uses it for a CSR header:

```dart
final header = top.generateModelSystemC(
  className: 'DeviceCsrs',
  options: const SystemCModelOptions(
    portType: SystemCModelPortType.twoState,
    unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
  ),
);
```

## CSR as the First Case

CSR is the first family to use this capability, and its design is documented in
[Control/Status Registers](./csr.md), especially [Portable memory-model
foundation](./csr.md#portable-memory-model-foundation).

Other memory families use the same capability interface, raw-state contract,
value codec, and SystemC options with their own descriptions and conformance
tests. CSR register semantics and field write side effects do not apply to them
automatically. `MemoryModel` and `InferredSram` provide portable behavioral
implementations; see [Memory](./memory.md) for their supported ports, storage,
and SystemC boundaries.

## Verification Matrix

The CSR matrix test covers every form of one register map, in both synchronous
and asynchronous reset modes:

| Leg | Compared against |
| --- | --- |
| Dart software model | ROHD RTL golden trace |
| SystemVerilog RTL (Icarus Verilog) | ROHD RTL golden trace |
| SystemC RTL | ROHD RTL golden trace, two-state prefix |
| SystemC software, four-state | ROHD RTL golden trace |
| SystemC software, two-state | ROHD RTL golden trace, prefix |

The fixture is a single `ctl` register with `readWrite`, `writeOnly`,
`writeOnesClear`, and `readWriteLegal` (legal values `0` and `1`) fields, plus a
read-only register, a 1-bit scalar port, and a 32-bit register. Each test has a
bounded timeout. Legs that need `iverilog` or `g++` are skipped when those tools
are not on `PATH`.

```sh
dart test test/memory/csr/csr_matrix_test.dart
```

Memory families can reuse this structure: one fixture, one golden RTL trace, and
one leg per form, kept short enough to run in the default suite.
