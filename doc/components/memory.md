# Memory

ROHD-HCL provides a generic `abstract`
[`Memory`](https://intel.github.io/rohd-hcl/rohd_hcl/Memory-class.html) class
which accepts a dynamic number of `writePorts` and `readPorts`, where each port
is of type
[`DataPortInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/DataPortInterface-class.html).
A `DataPortInterface` is a simple interface with `en` and `addr` as `control`
signals and `data` signal(s).  In a write interface, all signals are in the same
direction.  In a read interface, the `control` signals are in the opposite
direction of the `data` signal(s).

## Typed Payloads

`DataPortInterface<T>.typed(schema, addrWidth)` clones a payload schema without
connecting it to the supplied signal. Structures, enums, and `TypedLogicArray`
payloads retain their type through port registration and cloning:

```dart
final schema = TypedLogicArray<Logic, LogicValue>(
  [2, 3],
  ({String? name}) => Logic(name: name, width: 8),
);
final write = DataPortInterface.typed(schema, 4);
final read = DataPortInterface.typed(schema, 4);
final rf = RegisterFile(clk, reset, [write], [read], numEntries: 16);
write.data.at([1, 2]) <= sourceByte;
final resultByte = rf.rdData(0).at([1, 2]);
```

Drive the write port's `en`, `addr`, and payload, and the read port's `en` and
`addr`, as usual. Declared structured layouts and array codecs must match across
ports. Plain packed bridges remain supported.

The existing `DataPortInterface(dataWidth, addrWidth)` constructor still creates
plain `Logic` data ports. When a register file has an empty read or write list,
specify its payload type explicitly if Dart cannot infer it, for example
`RegisterFile<Logic>(clk, reset, [], [read])`.

## Masks

A subclass of `DataPortInterface` is the
[`MaskedDataPortInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/MaskedDataPortInterface-class.html),
which adds `mask` to the `control` group of signals. The `mask` signal is a
byte-enable signal, where each bit of `mask` controls one byte of packed `data`.
`MaskedDataPortInterface<T>.typed(schema, addrWidth)` preserves typed payloads
with byte-granular total widths.

## Register Files

A subclass of `Memory` is the
[`RegisterFile`](https://intel.github.io/rohd-hcl/rohd_hcl/RegisterFile-class.html),
which inherits the same flexible interface from `Memory`.  It has a configurable
number of entries via `numEntries`.

The `RegisterFile` accepts masks on writes, but not on reads.

Currently, `RegisterFile` only generates flop-based memory (no latches).

`RegisterFile<T>` stores entries in a `TypedLogicArray<T, LogicValue>` bank. For
scalar entries, the generated SystemVerilog uses one indexed packed array for
the bank rather than a separate storage signal for each entry. The bank's
`LogicValue` codec describes each complete entry's packed bits; an array-valued
payload retains its own dimensions, leaf types, and codec. Rank-zero array
payloads remain wrappers whose typed leaf is accessible via `.scalar`.
`rdData(index)` returns the typed module output.

Reset values and masked writes still operate on packed entry bits. For enum
payloads (including enum fields), choose reset encodings present in their
mappings; an unmapped encoding is not a valid enum value.

Packed and mixed packed/unpacked payloads are checked with Icarus, with
additional Verilator coverage for unpacked payloads. SystemC checks cover both
plain and unpacked typed register files and FIFOs, including depth-three wrap,
full replacement, and empty bypass. Explicit clock vectors are honored by the
SystemC comparison harness rather than replaced by an automatic clock.

The read path is combinational, so data is provided immediately according to the
control signals.

The `RegisterFile` can be initialized with data on reset using `resetValue`
following the conventions of `ResettableEntries`.

Values entering register-file state, including reset and testbench writes, have
Z bits converted to X. Unknown write enables and address bits make only
potentially selected entries unknown; an unknown byte mask affects only its
byte. A disabled mask byte remains unchanged. Reads with an unknown enable or an
enabled read with an unknown address return X. Disabled reads return zero.

For testbench initialization without driving a clocked write port, use
`RegisterFile.setData(LogicValue address, LogicValue value)`. This helper
directly sets one entry and is intended for simulation setup, not synthesized
hardware.

[RegisterFile Schematic](https://intel.github.io/rohd-hcl/RegisterFile.html)

## Shared array factories and SRAM

`MemoryArrayFunctor<T>` is the common construction contract for typed addressed
arrays. It validates port geometry, read latency, masking, collision
requirements, and the maximum simultaneous accesses promised by the caller. The
same factory can be used by any compatible memory consumer; it does not itself
arbitrate requests.

The supplied factories are `registerFileArray<T>()`,
`behavioralRegisterFileArray<T>()`, and `inferredSramArray<T>()`. The first two
have matching register-file semantics and combinational reads. The SRAM factory
emits a synthesizable Verilog array intended for single-port SRAM inference; the
synthesis flow determines whether it maps to a particular physical macro. Its
single shared port permits at most one read or write per edge, has one-cycle
registered reads, holds the output when no read is performed, and does not clear
stored words on reset. Reset does clear the read output. Masked writes are not
supported; an adapter can perform a read-modify-write if needed. Unknown and
out-of-range read addresses produce X; unknown and out-of-range write addresses
leave storage unchanged.

For example, a small controller can instantiate eight 16-bit SRAM words:

```dart
final write = DataPortInterface<Logic>(16, 3);
final read = DataPortInterface<Logic>(16, 3);
final sram = InferredSram<Logic>(
  clk, reset, [write], [read], entryCount: 8,
);
// Drive write.en/addr/data or read.en/addr, never both in one cycle.
// Consume read.data after the enabled read edge.
```

For a write of `0x1234` to address 2, assert the write enable and address/data
before an edge. On a later edge, deassert write enable and assert the read
enable with address 2; the registered read output then holds `0x1234` until
another enabled read or reset. `DataPortInterface` names the address signal
`addr`. In the configurator, this SRAM is shown as a cell in a small structural
wrapper: its hand-written Verilog array is not expanded into ROHD logic in the
ROHD schematic. The generated SystemVerilog contains the SRAM definition; actual
macro inference depends on the synthesis flow.

`InferredSram` provides `peek`, `poke`, `snapshot`, `restore`, and
`stateTransactions` for simulation. Its execution image includes the stored
words and registered read output. The same array provides standalone behavioral
SystemC with four-state or two-state ports and snapshots. Restore after signals
and delta cycles settle; external signals and scheduled events are not part of
the image. Dart, generated Verilog, and behavioral SystemC are compared on the
same cycle-by-cycle stimuli, including X/Z and replay. The [behavioral hierarchy
exporter](./behavioral_models.md#the-behavioral-model-capability) can explicitly
substitute the SRAM in an otherwise structural, two-state SystemC hierarchy. A
serialized cache with inferred SRAM data and flop-based tags is tested across
Dart, Verilog, and this SystemC hierarchy.

## First-In First-Out (FIFO) Buffers

Please see [`Fifo`](./fifo.md)

## Memory Models

There are two different things called a "memory model" in ROHD-HCL:

- **Synthesizable RTL memories** (`Memory`, `RegisterFile`, `Cam`, `Fifo`)
  produce hardware. Their behavior is what the generated SystemVerilog does.
- **Simulation models** are non-synthesizable software that stands in for a
  memory or register block during simulation or verification.

`MemoryModel` is the second kind. It has the same port interface as a `Memory`,
but is backed by a software `SparseMemoryStorage` instead of generated flops.
This is useful for testing systems that have large memories, because only
populated addresses use storage.

`MemoryModel<T>` preserves the same typed payload interfaces as `Memory<T>`:

```dart
final write = DataPortInterface<FloatingPoint32>.typed(FloatingPoint32(), 8);
final read = DataPortInterface<FloatingPoint32>.typed(FloatingPoint32(), 8);
final model = MemoryModel(clk, reset, [write], [read], readLatency: 2);
final FloatingPoint32 result = model.reads.single.data;
```

Structures (including nested fixed-point fields), enums, and typed arrays retain
their schemas and value codecs. Behavioral readback drives raw leaf bits rather
than passing a `LogicValue` to a domain-specific `put` method. Storage remains
word-addressed `LogicValue` data: NaNs, signed zeros, wide values, and X are not
decoded, rounded, or canonicalized. The supplied sparse storage converts Z to X
when writing state; the generic value codec can still preserve Z on signals and
in serialized values. Normal signal constraints still apply; for example, enum
wires normalize invalid encodings to X.

Read latencies, synchronous/asynchronous reset options, disabled reads, byte
masks, and simultaneous-write priority remain configurable as before. Disabled
`MemoryModel` reads return X, unlike disabled register-file reads. An unknown
read enable or an enabled read with an unknown address returns X. This remains a
simulation-only model, not a new synthesizable memory backend.

To model a specific `RegisterFile`, use its matching configuration:

```dart
final model = MemoryModel<Logic>.registerFile(
  clk, reset, [write], [read], numEntries: 16,
  resetValues: List.filled(16, LogicValue.ofInt(0, 32)),
);
```

This mode uses synchronous reset, combinational reads, zero for disabled or
out-of-range reads, and the RTL's same-word write priority. Each masked write
uses the pre-edge word for its unmasked bytes, so the last enabled port wins the
entire word. Reset values default to zero and may be supplied as a static
per-entry list; runtime `Logic` reset-value inputs are not supported. This mode
uses the built-in sparse storage and rejects custom storage and masked reads.

The default `MemoryModel` remains a general sparse memory, not a claim of
equivalence to `RegisterFile`: in particular, its reset clears stored entries,
disabled reads produce X, and sequential same-word masked writes can merge. The
register-file configuration is checked against generated `RegisterFile`
SystemVerilog and its SystemC export with the same two-state inputs, including
reset, disabled and out-of-range reads, simultaneous writes, and masks.
Four-state transactions are additionally compared with ROHD's RTL simulation.

For generic sparse models, an unknown write enable at a known address makes the
selected bits X. An uncertain address affects only compatible words and enabled
or uncertain mask bytes, including words not yet allocated. Later definite
writes can restore affected words. Multiple write ports are processed in port
order. An `onInvalidWrite` callback reports uncertain writes; by default it logs
a warning to the active ROHD-VF test, or prints one if no test is active. An
uncertain write is a four-state simulation event, not inherently an exception:
the model continues with X in the affected state. A custom callback replaces the
default and may throw if the testbench considers the event an error.
Alternatively, an ROHD-VF test can configure its warning failure level. A
throwing callback does not guarantee storage rollback.

`MemoryModel.generateSystemC` exports a standalone four-state behavioral model
for plain `Logic` payloads using the built-in sparse storage. It supports
multiple ports, masks, uncertain writes, reset, read latency, and execution
snapshots. Typed payloads, caller-supplied storage, and two-state SystemC
boundaries are not supported by this exporter and are rejected explicitly.
SystemC snapshots omit external signals and scheduled delta-cycle events; take
and restore them after delta cycles settle and coordinate external peers.

`MemoryStorageState` exposes the contents of a `MemoryStorage` through word
addresses, so tests can `peek`, `poke`, `snapshot`, and `load` state without
driving ports. It bypasses alignment and invalid-transaction callbacks, so it is
not a timing-accurate RAM model. Snapshots use `MemoryStorageImage`, containing
explicit `entries` and symbolic uncertain-address writes. Entry addresses are
`BigInt`; use `MemoryStorageImage.wide` to construct images with wide addresses
and `peekBigInt`/`pokeBigInt` for raw access. The original integer methods and
image constructor remain available. An unallocated word remains absent from
`peek`; architectural reads apply matching symbolic writes to the storage's
invalid-read value. Restore the complete image rather than just its entries.

An uncertain address can represent a very large number of locations, so
`SparseMemoryStorage` records it symbolically rather than enumerating words.
Custom address alignment requires an `unknownAddressMatcher` and a stable
`unknownAddressMappingId` to describe which physical words an uncertain logical
address can reach. Images with symbolic writes can only be restored to storage
with the same mapping ID. Unsupported custom storage or missing matching
capabilities throw rather than silently discarding uncertainty.

`MemoryModel.snapshot()` captures that storage image together with the current
read outputs and all outstanding fixed-latency reads. `restore()` replaces the
model state and cancels later pending read completions before reinstating the
saved ones. The same operations are available through `stateTransactions`.
Images require matching port shapes, timing, reset configuration, and storage
geometry. Clock and input signals, external consumers, and custom storage
callback behavior are not captured; coordinate them when restoring.

`MemoryStorage` also reads and writes Verilog-compliant memory files:
`loadMemString` loads a `readmemh`-style string, and `dumpMemString` writes one.
The older `loadMemHex` is deprecated in favor of `loadMemString`.

For a model that can be exported as a SystemC software model, and for how
software models differ from RTL in simulation, see [Behavioral
Models](./behavioral_models.md).

## Parallel Associative Memory

`ParallelAssociativeMemory` provides indexed updates and combinational lookups
with typed-key support. See the [associative memory
guide](associative_memory.md) for ports, supported contracts, implementation
selection, matcher/selector building blocks, and important differences from the
deprecated `Cam`.

## Legacy Cam

A content-addressable memory or `Cam` is provided which allows for associative
lookup using a `tag` that produces an index to help with building specialized
forms of caches where the actual data is stored in a separate register file. The
index is to be separately used as a linear address in another component (like a
`RegisterFile`) to find the associated data.  In this case the `tag` is matched
during a read and the position in memory is returned, which is the index. For
the fill ports, the user can simply write a new tag at a given index location.
This means the `Cam` is a fine-grained component for use in building associative
look of positions of objects in another memory.

Both write and lookup ports use the `TagInterface`, which provides a consistent
interface for CAM operations:

- For **writes**: `en` enables the write, `idx` specifies the destination
  address, `tag` is the data to write, and `hit` sets/clears the valid bit for
  the entry (hit=1 marks entry valid, hit=0 marks entry invalid).
- For **lookups**: `tag` is the query, `idx` returns the matching index, and
  `hit` indicates whether a valid match was found. Only entries with their valid
  bit set will match.

Each CAM entry has a valid bit that must be set for the entry to participate in
lookups. This allows distinguishing between "entry contains tag 0x00" and "entry
is empty/invalid".

### Typed Tags

`TagInterface<T>` and `Cam<T>` preserve the tag's type through interface clones,
module ports, and typed-array storage. The width-based `TagInterface(idWidth,
tagWidth)` constructor remains available for ordinary `Logic` tags. Supply a
schema to the typed constructor:

```dart
final writePort = TagInterface<CacheTag>.typed(idWidth, CacheTag());
final lookupPort = TagInterface<CacheTag>.typed(idWidth, CacheTag());
final cam = Cam<CacheTag>(clk, reset, [writePort], [lookupPort],
    numEntries: 8, enableValidTracking: true);
writePort.tag.key <= requestedKey;
lookupPort.tag.context <= requestedContext;
```

The schema is cloned, not connected to the interface; drive the returned
interface's tag fields. Structures, enums, floating/fixed-point signals, and
typed arrays retain their layouts, mappings, dimensions, and value codecs. All
CAM ports must declare matching recursive tag layouts, and each index port must
be wide enough to address every entry.

Matching remains **bit identity**, not numeric equality. Floating-point signed
zeros are distinct tags; a NaN matches its own encoding without quieting or
canonicalizing its payload. Packing is restricted to the existing case-match
boundary, including the valid bit; tag transport and storage remain typed.
Existing case-statement four-state behavior is unchanged.

Lookups remain combinational and are not gated by the lookup interface's `en`.
The lowest-index valid duplicate wins; on simultaneous writes to one entry, the
last enabled write port wins for both tag and validity. Reset clears all tags
and valid bits. Optional occupancy tracking and the read-with-invalidate pattern
below are unchanged.

### Read-with-Invalidate Pattern

A read-with-invalidate operation can be implemented by using a dedicated write
port wired to the lookup port's outputs:

- Wire `invalidatePort.idx <= lookupPort.idx` to target the found entry
- Wire `invalidatePort.tag <= lookupPort.tag` to match the lookup
- Set `invalidatePort.hit = 0` (always invalidate, never validate)
- Set `invalidatePort.en = lookupPort.hit` (only invalidate if found)

This pattern allows atomic "find and remove" operations where the lookup returns
the matching index while simultaneously invalidating that entry.

An example use is:

```dart
      const tagWidth = 8;
      const numEntries = 4;
      const idWidth = 2;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = TagInterface(idWidth, tagWidth);
      final invalidatePort = TagInterface(idWidth, tagWidth);
      final lookupPort = TagInterface(idWidth, tagWidth);

      final cam = Cam(
        clk,
        reset,
        [writePort, invalidatePort],
        [lookupPort],
        numEntries: numEntries,
      );

      // Wire invalidatePort to use lookupPort's combinational output
      invalidatePort.idx <= lookupPort.idx;
      invalidatePort.tag <= lookupPort.tag;
      invalidatePort.hit.inject(0);  // Always clear valid bit

      // Write tag 0x99 to index position 1 (hit=1 marks it valid)
      writePort.en.inject(1);
      writePort.hit.inject(1);
      writePort.idx.inject(1);
      writePort.tag.inject(0x99);
      await clk.nextPosedge;

      // Lookup tag 0x99 without invalidate
      lookupPort.tag.inject(0x99);
      invalidatePort.en.inject(0);
      await clk.nextPosedge;
      // We found our matching tag at index 1 where we stored it!
      expect(lookupPort.idx.value.toInt(), equals(1),
          reason: 'Should return index 1');

      // Lookup and invalidate: enable invalidatePort when hit
      invalidatePort.en.inject(1);  // Invalidate on hit
      await clk.nextPosedge;
      // Entry is now invalidated - subsequent lookup will miss
```
