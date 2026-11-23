# P02: Inference Foundation

Development plan; use the [component guide](../README.md) for lasting usage
documentation and [contribution guidance](../../CONTRIBUTING.md) for workflow.

- **Branch:** `hcl-inference`
- **Requires:** `main`, including merged P00 and P01.

Use this family for fixed-point attention, tensor movement, scratchpads,
tiling, multicast, layout transforms, and vector reductions. Inference cores
select backing functors from the merged main foundation (P00) or expose
protocol-neutral actions; P03 memory extensions and P04 transport shells
remain outside this branch. P01 supplies the additional compute primitives;
P00 is no longer a separate branch prerequisite.

## Delivery boundaries

- Build on main's memory-array factories and register-file APIs. Do not pull
  in the P03 banked synchronous-memory implementation.
- Keep the general buffered transpose and multicast transport shells for
  P04. The grouped-query distributor uses the P02 multicast core.
- Include reusable pooling traversal, runtime narrowing, strided address
  calculation, tensor banks, and systolic transpose from the accelerator
  experiments. Leave accelerator assemblies, AXI bridging, KV-cache control,
  and OOO-specific follow-ups out of this delivery.

## Start here

- [Inference component guide](../components/inference.md)
- [Inference source](../../lib/src/inference/)
- [Ready/Valid guide](../components/ready_valid.md)
- [Memory guide](../components/memory.md)
- [Serialization guide](../components/serialization.md)

## Component catalog

This table lists the delivery scope, including reused baseline modules.

| Source subfamily | Module types |
| --- | --- |
| `arithmetic/conversion` | `DynamicNumericNarrowing` |
| `dataflow/layout` | `SystolicMatrixTranspose`, `TypedStaticPermutation` |
| `dataflow/selection` | `Extrema` |
| `dataflow/serialization` | `ReadyValidDepacketizer`, `ReadyValidPacketizer`, `ScheduledDeserializerEngine`, `ScheduledSerializerEngine` |
| `flow_control/arbitration` | `Arbiter`, `PolicyArbiter`, `PriorityArbiter`, `StatefulArbiter` |
| `flow_control/control` | `PolicyMuxCore`, `SelectiveForkCore` |
| `inference/` | `Exp2Approximation`, `FixedPointApproximation`, `FixedPointAttention`, `FixedPointAttentionRowEngine`, `GroupScaleApply`, `GroupedQueryAttentionTileDistributor`, `MixedPrecisionDotProduct`, `OnlineSoftmaxMerge`, `OnlineSoftmaxNormalize`, `OnlineSoftmaxUpdate`, `OnlineSoftmaxWeightedMerge`, `OnlineSoftmaxWeightedUpdate`, `PoolingWindowSequencer`, `ReciprocalApproximation`, `ReciprocalSqrtApproximation`, `RmsNorm`, `ScratchpadFixedPointAttention`, `TensorAccumulatingMemoryBank`, `TensorDmaEngine`, `TensorMaskedSramBank`, `TensorScratchpad`, `TensorStridedAddress`, `TensorStridedAddressGenerator`, `TensorTileIterator`, `TensorTileMulticastCore`, `TensorTileTiler`, `TensorTileTranspose`, `TensorTileUntiler`, `VectorReduce` |

## Updating This Plan

Follow the [contribution checklist](../../CONTRIBUTING.md#adding-a-new-component).
While this plan is active, keep its assignments and dependency inventory current.
Maintain usage and examples in the permanent topic docs linked by
[doc/README.md](../README.md), not solely in this plan.
