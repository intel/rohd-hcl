# Inference building blocks

Import `package:rohd_hcl/rohd_hcl.dart`. These components supply reusable
datapaths, addressing and local storage, not a complete accelerator.

## Build a small attention engine

The [runnable attention engine example](../../example/attention_engine_example.dart)
composes two `TensorScratchpad` instances with `ScratchpadFixedPointAttention`.
It loads typed key and value rows through independent ready/valid write ports,
issues a typed query with masks and a request ID, and checks that the result
remains stable while the consumer stalls. The datapath is fixed point: the
example uses signed 4-bit keys and signed 8-bit values and results.

From the package root:

```sh
dart run example/attention_engine_example.dart /tmp/attention_engine.sv
```

The simulation checks for `[3, 2]` and emits the same engine as SystemVerilog.
The host owns the preload and command sequence; there is no model loader,
external bus controller, or full transformer in this example.

## Choose building blocks

| Need | Components |
| --- | --- |
| Fixed-point attention | `FixedPointAttentionCore` for a complete bounded KV tile, `FixedPointAttentionRowCore` for explicitly scheduled rows; `FixedPointAttention`, `FixedPointAttentionRowEngine`, and `ScratchpadFixedPointAttention` for protocol-adapted operation |
| Numeric processing | `MixedPrecisionDotProduct`, `VectorReduce`, `RmsNorm`, `DynamicNumericNarrowing`, fixed-point approximations and online softmax state operations |
| Addressing and movement | `TensorStridedAddress` for random-access calculation, `TensorStridedAddressGeneratorCore` for scheduled traversal, `TensorStridedAddressGenerator` for ready/valid traversal, `TensorDmaEngine` for memory-transaction copies |
| Local storage | `TensorScratchpadCore` for scheduled banked access, `TensorScratchpad` for ready/valid access, `TensorMaskedSramBank` for byte-enabled protocol adaptation, `TensorAccumulatingMemoryBank` for scheduled masked read-modify-write with lane-wise wrapping |
| Tile layout | `TensorTileTranspose` for static spatial wiring, `SystolicMatrixTranspose` for stepped streaming, action-driven `TensorTileTiler` and `TensorTileUntiler` for framed conversion |
| Fan-out and pooling | `TensorTileMulticastCore` for explicit load/advance fan-out; `PoolingWindowSequencer` for coordinate traversal without storing samples or performing a reduction |

Use the [payload schema guide](payload_schemas.md) when composing typed ports.
An inference tile includes an element format and separate row and column masks.
Choose numeric formats and storage widths at the component boundary; equal
packed width is not enough to make two tile formats interchangeable.

`TensorTileMulticastCore` holds a tile until all selected outputs advance.
Drive each advance bit from completion of the currently offered copy. The final
advance can coincide with a new load; a zero selection consumes a load without
retaining it. `GroupedQueryAttentionTileDistributor` maps KV heads to query
heads and supplies ready/valid handshakes at its inference-specific boundary.

For an unsplit pooling window, omit all four split inputs to
`PoolingWindowSequencer`. Supply them together if the design needs runtime
horizontal splits; a runtime split count of zero selects the unsplit geometry.

`TensorTileTiler` and `TensorTileUntiler` require matching tile dimensions and
compatible element schemas. A packed `Logic` element can bridge a structured
element of the same width, but two distinct structured schemas cannot be
connected just because they pack to the same width.

## Choose action cores or protocol adapters

Reusable compute, traversal, and banked-storage state is independent of
ready/valid transport. A parent can drive synchronous actions directly for a
cycle-accurate schedule, or attach protocols using the existing independent
ingress and egress policies from [protocol composition](protocol_composition.md).
Retained results and explicit retirement belong to core state, just as
enqueue/dequeue actions do for a FIFO.

| Action core | Scheduling inputs | Ready/valid attachment shell |
| --- | --- | --- |
| `FixedPointAttentionCore` | `load`, optional `retire` | `FixedPointAttention` |
| `FixedPointAttentionRowCore` | `load`, `writeRow`, optional `retire` | `FixedPointAttentionRowEngine` |
| `TensorStridedAddressGeneratorCore` | `load`, optional `advance` | `TensorStridedAddressGenerator` |
| `TensorScratchpadCore<T>` | `readEnable`, `writeEnable`, optional `consumeResponses` vectors | `TensorScratchpad<T>` |
| `TensorAccumulatingMemoryBank` | `write`, `read`, optional `consumeResponse` | `ReadyValidTensorAccumulatingMemoryBank` |
| `TensorTileTiler` / `TensorTileUntiler` | `write` / `load` and optional `advance` | `ReadyValidTensorTileTiler` / `ReadyValidTensorTileUntiler` |

Omitted advance/retirement inputs are asserted automatically, permitting
operation without backpressure. Direct callers must respect the admission
outputs; these are capacity contracts, not protocols. Scratchpad enable vectors
are arbitration offers, as described below.

Bounded attention captures its typed request on `load` and processes exactly
`sequenceLength` physical positions before presenting `resultValid`, including
masked positions. Default retirement consumes that result on the following
edge, which can also capture another request. Row attention captures a command
before accepting rows on `writeRow`; the final accepted row contributes to the
result. Reset cancels partial work. An empty softmax state produces zero output
without overflow/inexact flags from the unused reciprocal lookup; existing
state diagnostics remain preserved.

Strided traversal presents its first address after command capture and advances
once per cycle by default. Commands are accepted only while idle: a new `load`
must follow, not coincide with, the final active advance.

Scratchpad enable vectors identify arbitration contenders. Only enabled
requests with capacity are admitted; denied requests are not retried internally.
With default backing, valid reads take one bank cycle and then one cycle into
a response slot.
Invalid reads produce zero/error responses on admission. Response-consumption
actions release those slots, including simultaneous next-request admission.
The default consumption vector is all ones.

The accumulating bank performs full overwrites on admission and serializes
partial writes and accumulation through read-modify-write. Writes have priority,
including zero-mask no-ops. Accumulation wraps independently per lane before
byte selection. Its adapter uses `TensorAccumulatingWriteRequest`, which combines
the existing `ByteMaskedWriteRequest` with an `accumulate` bit, and typed read
requests/responses. Response words may use an intentional packed bridge into a
structured or unpacked schema.

Some components intentionally orchestrate transport rather than define a
standalone algorithm. `TensorDmaEngine` bridges memory transactions and uses
action-driven address cores internally. `ScratchpadFixedPointAttention`
orchestrates KV reads and feeds the row action core directly. Byte-masked SRAM
adaptation, ready/valid queue compositions, and grouped-query distribution remain
protocol adapters. Their variable transaction timing is not a fixed-latency
compute contract.

## Choose scheduled or protocol-wrapped tile conversion

`TensorTileTiler` and `TensorTileUntiler` are protocol-neutral cores. Their
typed payloads and synchronous actions can be driven directly by a
cycle-accurate scheduler; no ready/valid interface is required.

```dart
final untiler = TensorTileUntiler(
  clk: clk,
  reset: reset,
  inputTile: tile,
  elementSchema: InferenceTensorStreamElement(
    Logic(name: 'sample', width: tile.format.elementWidth),
    rowCount: tile.rowCount,
    columnCount: tile.columnCount,
  ),
  load: start,
);
final tiler = TensorTileTiler(
  clk: clk,
  reset: reset,
  element: untiler.result,
  write: untiler.active,
  tileSchema: tile,
);
```

With `advance` omitted, the untiler captures on `load` and presents the first
element immediately after that edge. It then emits one element every cycle
for exactly `rowCount * columnCount` cycles. `active` marks those cycles and
`result.last` marks the final element. A new load on the final consumption edge
starts the next tile without a bubble. Do not load over an unfinished tile.
An explicit `advance` action is available when a parent owns another schedule.

The tiler writes on every asserted `write`, completing on the final physical
element or an early `last`. `complete` pulses immediately after that edge.
Consume or retain its result before the next write, which starts overwriting
the collection. Short frames, missing final markers, and inconsistent repeated
masks complete with diagnostic flags and cleared tile masks. Both cores use
synchronous reset to discard in-flight work without clearing payload storage.

For backpressure, use `ReadyValidTensorTileUntiler` and
`ReadyValidTensorTileTiler`. These are shells around the same cores, not
separate tensor algorithms. They use the existing ingress and egress attachment
policies described in [protocol composition](protocol_composition.md), just
like the FIFO composition. The untiler shell maps accepted tiles to `load`
and element transfers to `advance`. The tiler shell maps accepted elements to
`write` and retains completion until the output transfers. Stalled data and
diagnostics remain stable; consuming a completed tile can share an edge with
the first element of the next one. Neither shell adds datapath latency.

## Preserve tensor types through movement and storage

`SystolicMatrixTranspose<T, V>` accepts a nonempty, one-dimensional
`TypedLogicArray<T, V>` row. The row length determines the square matrix
dimension; the element schema determines its width. Input and output ports,
internal cells, selection, and shift registers retain the element type.
The output also retains the row's value codec and packed/unpacked layout.

```dart
final row = TypedLogicArray<FixedPoint, LogicValue>(
  [4],
  ({name}) => FixedPoint(integerWidth: 4, fractionWidth: 4, name: name),
);
final transpose = SystolicMatrixTranspose(
  clk: clk,
  reset: reset,
  step: step,
  dataIn: row,
);
```

`TensorScratchpad<T>` and `TensorDmaEngine<T>` move complete typed words.
Construct `TensorScratchpadWriteRequest<T>` and
`TensorScratchpadReadResponse<T>` with `data: wordSchema`, not a width.
The schema is cloned; drive the request's `data` field, not the supplied
prototype. A word may itself be a typed row, tile, or other structure.
Its type survives bank ports, backing arrays, retained read responses, and
DMA write buffering. Addresses and strides count words, not tensor elements.

Scratchpad words sharing storage and DMA source/destination words must have
compatible declared schemas. Array dimensions, value-codec identity, and
tensor numeric formats are part of that contract; equal packed width alone
does not establish compatibility. `InferenceTensorTile` includes its numeric
format in payload metadata. Selecting `Logic` as the word schema is an
intentional packed-bit boundary, not an automatic schema conversion.

Consult the [memory guide](memory.md) for backing initialization and latency
contracts. `TensorScratchpad` defaults to the register-file array factory and
accepts a `MemoryArrayFunctor<T>` with zero- or one-cycle reads, subject to
the selected bank policy and the factory's access limits. See the [ready/valid
guide](ready_valid.md) for holding data stable under backpressure. Reset of the
byte-masked SRAM bank cancels outstanding reads but does not clear stored bytes.

## Native backend validation

The native CI checks execute the same expected vectors in Dart, Icarus,
SystemC, and Verilator for scheduled tensor tiling/untiling and bounded
attention. Attention vectors include a signed singleton result, fully masked
normalization, retained-result stalls, simultaneous retirement/reload, and reset.
Verilator also checks nested unpacked scratchpad words with both register-file
and SRAM backing, including response retention under backpressure.

For nested scratchpad SystemC simulation, use the existing
`generateBehavioralSystemCHierarchy` export with `InferredSram` leaves selected.
The portable models provide actual storage and read latency; they are not empty
stubs. Scratchpad arbitration and protocol attachments remain generated hardware.
The test uses packed top-level bridges while retaining unpacked word schemas
inside the hierarchy. Direct SystemC generation of unpacked register-file
storage is limited by the current ROHD backend and is not validated by this path.
