# Inference building blocks

Import `package:rohd_hcl/rohd_hcl.dart`. These components supply reusable
datapaths, addressing and local storage, not a complete accelerator.

| Need | Components |
| --- | --- |
| Fixed-point attention | `FixedPointAttention` for a complete bounded KV tile, `FixedPointAttentionRowEngine` for streamed rows, `ScratchpadFixedPointAttention` for scratchpad-backed operation |
| Numeric processing | `MixedPrecisionDotProduct`, `VectorReduce`, `RmsNorm`, `DynamicNumericNarrowing`, fixed-point approximations and online softmax state operations |
| Addressing and movement | `TensorStridedAddress` for random-access address calculation, `TensorStridedAddressGenerator` for sequential traversal, `TensorDmaEngine` for strided copies |
| Local storage | `TensorScratchpad` for banked tensor access, `TensorMaskedSramBank` for byte-enabled writes, `TensorAccumulatingMemoryBank` for serialized masked read-modify-write with lane-wise wrapping |
| Tile layout | `TensorTileTranspose` for static spatial wiring, `SystolicMatrixTranspose` for stepped streaming, `TensorTileTiler` and `TensorTileUntiler` for framed conversion |
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

Consult the [memory guide](memory.md) for backing initialization and latency
contracts. `TensorScratchpad` defaults to the register-file array factory and
accepts a `MemoryArrayFunctor<Logic>` with zero- or one-cycle reads, subject to
the selected bank policy and the factory's access limits. See the [ready/valid
guide](ready_valid.md) for holding data stable under backpressure. Reset of the
byte-masked SRAM bank cancels outstanding reads but does not clear stored bytes.
