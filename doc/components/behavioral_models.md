# Behavioral Models

A component in ROHD-HCL can exist in several forms. Each form answers a
different question, so it is worth separating them before using any of them.

| Form | What it is | Synthesizable | Typical use |
| --- | --- | --- | --- |
| **ROHD RTL** | A `Module` built from `Logic`, flops, and operations | Yes (SystemVerilog via `dumpSystemVerilog`) | The hardware that ships |
| **Software model** | A plain Dart object holding state, with no hardware | No | Fast, deterministic testbench reference and state inspection |
| **SystemC behavioral model** | A generated C++ header that models the same behavior | No | Driving a model from an external SystemC or C++ simulation |

The RTL is the design. A software or SystemC model is a *reference* for the
same architectural behavior: it lets a testbench predict what the RTL should
do, or lets an outside simulator stand in for the hardware. Models do not
replace RTL verification; they are checked against it.

## The Behavioral Model Capability

A component that can produce a model implements the opt-in
`BehavioralModelProvider` interface. Its `behavioralModel` getter returns
either a `BehavioralModel` or `null`:

- A software instance returns the portable model for its architecture.
- An RTL instance returns `null`.

Export code should use
`generateBehavioralSystemC(candidate, className, options: ...)` rather than
checking concrete types. The function returns
`null` for unrelated objects and RTL instances. A supported model that fails
to export throws, rather than producing silently incomplete output.

Existing components do not need to implement this capability to keep their
current behavior.

Each model exposes a `BehavioralModelDescription` with its `kind`,
`inputPorts`, and `outputPorts`. Port widths are validated through
`MemoryPortGeometry`, which requires positive widths.

## Using a Software Model in Simulation

The CSR example below builds a software top, then uses raw state access. It
is adapted from
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

state.poke(command, LogicValue.ofInt(0xbeef, 16));
print(state.peek(command));  // 16'hbeef
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
- `poke(address, value)` writes without architectural side effects. Field
  write permissions and write side effects are not applied.
- `snapshot()` returns an immutable image.
- `load(image, {replace = false})` applies an image. Loads validate the whole
  image before mutating anything. With `replace: true`, omitted entries are
  reset: CSR registers return to their reset values, and omitted sparse
  entries are cleared.

CSR implements this with `Map<int, LogicValue>` images keyed by absolute
register address. `MemoryStorageState` adapts existing `MemoryStorage` (used
by `MemoryModel`), keyed by word address. Its raw access bypasses alignment
and invalid-transaction callbacks, so it is a state tool, not a RAM timing
model.

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
including before reset. `zeroUntilReset` is an explicit integration choice;
the example uses it for a CSR header:

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

CSR is the first family to use this capability, and its design is documented
in [Control/Status Registers](./csr.md), especially
[Portable memory-model foundation](./csr.md#portable-memory-model-foundation).

Memory families would follow the same shape, as parallel families with their
own descriptions and conformance tests. Nothing in the CSR design is inherited
automatically by memories. The reusable parts are the capability interface,
the raw-state contract, the value codec, and the SystemC options. The
CSR-specific parts are register semantics, field write side effects, and the
`zeroUntilReset` choice. The existing [Memory](./memory.md) classes keep their
current behavior until they adopt the capability.

## Verification Matrix

The CSR matrix test covers every form of one register map, in both
synchronous and asynchronous reset modes:

| Leg | Compared against |
| --- | --- |
| Dart software model | ROHD RTL golden trace |
| SystemVerilog RTL (Icarus Verilog) | ROHD RTL golden trace |
| SystemC RTL | ROHD RTL golden trace, two-state prefix |
| SystemC software, four-state | ROHD RTL golden trace |
| SystemC software, two-state | ROHD RTL golden trace, prefix |

The fixture is a single `ctl` register with `readWrite`, `writeOnly`,
`writeOnesClear`, and `readWriteLegal` (legal values `0` and `1`) fields, plus
a read-only register, a 1-bit scalar port, and a 32-bit register. Each test
has a bounded timeout. Legs that need `iverilog` or `g++` are skipped when
those tools are not on `PATH`.

```sh
dart test test/memory/csr_matrix_test.dart
```

Memory families can reuse this structure: one fixture, one golden RTL
trace, and one leg per form, kept short enough to run in the default suite.
