
# ROHD-HCL Component List

This index groups the library's components by category and links to their
documentation. Some APIs are experimental, simulation-only, or retained for
compatibility; the linked documentation describes their status and limitations.
Ideas for further development are listed separately below.

Some in-development items will have opened issues, as well. Feel free to create
a pull request or file issues to add more ideas to this list. If you plan to
develop and contribute a component, please be sure to open an issue so that
there are not multiple people working on the same thing. Make sure to check if
someone else has an open issue for a certain component before starting.

Applications should import the package barrel rather than `lib/src` paths:

```dart
import 'package:rohd_hcl/rohd_hcl.dart';
```

- [Static or Runtime Parameters](./static_or_runtime_parameters.md)
- [Utilities and Building Blocks](./utilities.md)

## Source Layout

Sources under `lib/src` are organized by the component's primary function. Each
category has a barrel file that exports its components directly or through
subcategory barrels. The package barrel exports every category barrel.

| Category | Barrel | Subcategories |
| --- | --- | --- |
| [Arithmetic](#arithmetic) | [`arithmetic.dart`](../lib/src/arithmetic/arithmetic.dart) | `accumulation`, `addition`, `conversion`, `division_and_roots`, `floating_point`, `multiplication`, `multiply_accumulate`, `normalization`, `prefix_networks`, `signals`, `values` |
| [Bit operations](#bit-operations) | [`bit_operations.dart`](../lib/src/bit_operations/bit_operations.dart) | `population_count`, `search`, `selection`, `shifting` |
| [Clocking](#clocking) | [`clocking.dart`](../lib/src/clocking/clocking.dart) | `cdc`, `event_detection`, `gating`, `generation` |
| [Dataflow](#dataflow) | [`dataflow.dart`](../lib/src/dataflow/dataflow.dart) | `ordering`, `reduction`, `selection`, `serialization` |
| [Encodings](#encodings) | [`encodings.dart`](../lib/src/encodings/encodings.dart) | `gray`, `one_hot`, `priority`, `thermometer` |
| [Error control](#error-control) | [`error_control.dart`](../lib/src/error_control/error_control.dart) | `protection` |
| [Flow control](#flow-control) | [`flow_control.dart`](../lib/src/flow_control/flow_control.dart) | `arbitration`, `attachments`, `control`, `ready_valid`, `storage` |
| [Interfaces](#interfaces) | [`interfaces.dart`](../lib/src/interfaces/interfaces.dart) | `amba` (`amba4`, `amba5`, `endpoints`), `spi` (`endpoints`) |
| [Memory](#memory) | [`memories.dart`](../lib/src/memory/memories.dart) | `associative`, `behavioral`, `cache`, `contracts`, `csr`, `replacement`, `sequential`, `state`, `storage` |
| [Models](#models) | [`models.dart`](../lib/src/models/models.dart) | `amba`, `memory`, `ready_valid_bfm`, `spi_bfm` |

The configurator tags each configurable component with the same category and
subcategory, and the confapp sidebar groups components accordingly.

## Components

### Arithmetic

- **Accumulation:** [sums](./components/summation.md#sum),
  [counters](./components/summation.md#counter), and
  [gated counters](./components/summation.md#gated-counter).
- **Addition and subtraction:**
  - [Ripple carry adder](./components/adder.md#ripple-carry-adder).
  - [Parallel prefix adder](./components/adder.md#parallel-prefix-adder).
  - [Compound adder](./components/adder.md#compound-adder) and
    [carry-select ones' complement compound adder](./components/adder.md#carry-select-ones-complement-compound-adder).
  - [Native adder](./components/adder.md#native-adder).
  - [Ones' complement adder/subtractor](./components/adder.md#ones-complement-adder-subtractor)
    and [sign-magnitude adder](./components/adder.md#sign-magnitude-adder).
- **Multiplication and accumulation:**
  - [Carry-save multiplier](./components/multiplier.md#carry-save-multiplier).
  - [Compression-tree multiplier](./components/multiplier.md#compression-tree-multiplier).
  - [Compression-tree multiply-accumulate](./components/multiplier.md#compression-tree-multiply-accumulate)
    and [generic multiply-accumulate](./components/multiplier.md#generic-multiply-accumulate).
  - [Dot product](./components/multiplier.md#dot-product).
  - [Booth encoding and compression building blocks](./components/multiplier_components.md).
- **Division and roots:** [integer divider](./components/divider.md),
  [ceil division and logarithm](./components/arithmetic_primitives.md#division-and-logarithms),
  [fixed-point square root](./components/fixed_point.md#fixedpointsqrt), and
  [floating-point square root](./components/floating_point.md#floatingpointsqrt).
- **Normalization:** [absolute value](./components/arithmetic_primitives.md#absolute-value)
  and [leading digit and zero anticipation](./components/leading_digit_anticipate.md).
- **Prefix networks:** [prefix operations and typed networks](./components/parallel_prefix_operations.md)
  for operations such as priority finding, bitwise scans, incrementing, and
  decrementing.
- **Floating point:** [values and formats](./components/floating_point.md#floatingpointvalue),
  [adders](./components/floating_point.md#floatingpointadder),
  [multiplier](./components/floating_point.md#floatingpointmultiplier),
  [converter](./components/floating_point.md#floatingpointconverter), and
  [classification and comparison](./components/floating_point.md#floating-point-classification-and-comparison),
  [status](./components/floating_point.md#floating-point-status).
- **Fixed point:** [values, signals and arithmetic](./components/fixed_point.md),
  [fixed-to-float](./components/fixed_point.md#fixedtofloat), and
  [float-to-fixed](./components/fixed_point.md#floattofixed).
- **Other primitives:** [unsigned arithmetic with overflow](./components/arithmetic_primitives.md#arithmetic-with-overflow)
  and [circular pointer](./components/arithmetic_primitives.md#circular-pointer).

### Bit operations

- **Population count:** [count zeros or ones](./components/count.md) and
  [bitwise population count](./components/bit_operations.md#bitwise-population-count).
- **Search:** [find bits](./components/find.md),
  [find patterns](./components/find_pattern.md), and
  [leading and trailing zeros](./components/bit_operations.md#leading-and-trailing-zeros).
- **Selection:** [one-hot, priority, and bitwise multiplexers](./components/bit_operations.md#multiplexers)
  and sparse-to-dense boolean scatter, illustrated with
  [reduction trees](./components/reduction_tree.md).
- **Shifting and bit manipulation:** [rotate](./components/rotate.md),
  [signed shifter](./components/shifter.md), and
  [padding and bit replacement](./components/bit_operations.md#padding-and-bit-replacement).

### Clocking

- [Clock gating](./components/clock_gating.md) and [toggle gating](./components/toggle_gate.md).
- [Edge detection](./components/edge_detector.md).
- [Clock-domain synchronizer](./components/async_fifo.md#synchronizer-module).
- [Divided-rate clock enable](./components/clock_gating.md#clock-enable-divider).

### Dataflow

- [Bitonic sort](./components/sort.md#bitonic-sort).
- [Reduction trees](./components/reduction_tree.md).
- [Extrema selection](./components/extrema.md).
- [Serialization and deserialization](./components/serialization.md) convert
  between wider arrays and narrower streams.

### Encodings

- [One-hot codecs](./components/onehot.md).
- [Binary/Gray conversion](./components/binary_gray.md).
- [Thermometer conversion](./components/binary_gray.md#thermometer-conversion).
- [Parallel-prefix and recursive priority encoders](./components/priority_encoder.md).

### Error control

- [Error-correcting codes](./components/ecc.md).
- [Parity transmitter and receiver](./components/parity.md).

### Flow control

- **Arbitration:** [priority and round-robin arbiters](./components/arbiter.md).
- **FIFO storage:** [synchronous FIFO](./components/fifo.md) and
  [asynchronous FIFO](./components/async_fifo.md).
- **Ready/valid:** [interfaces and handshaking](./components/ready_valid.md#interfaces-and-handshaking),
  [elastic buffers and pipelines](./components/ready_valid.md#elastic-buffers),
  [queue](./components/ready_valid.md#readyvalidqueue), and
  [legacy FIFO](./components/ready_valid.md#legacy-readyvalidfifo).
- **Composition:** [protocol-neutral FIFO cores and directional attachments](./components/protocol_composition.md).
- **Credit-related building blocks:** [up/down counters](./components/summation.md#counter)
  support credit accounting, and the [LTI BFM](./components/amba/lti.md#validation)
  models credit-based traffic.

### Interfaces

- **AMBA:** [AXI, AXI-Lite, ACE, and AXI-S](./components/amba/axi.md),
  [LTI](./components/amba/lti.md), and [APB](./components/amba/apb.md).
- **SPI:** [interface](./components/standard_interfaces.md#spi) and
  [main and subordinate endpoints](./components/spi_gaskets.md).
- [Interface registration helpers](./components/standard_interfaces.md#module-registration-helpers).

### Memory

- **Storage:** [register files and masked ports](./components/memory.md),
  [array factories and inferred SRAM](./components/memory.md#shared-array-factories-and-sram),
  and [shift registers](./components/shift_register.md).
- **Associative:** [parallel associative memory and legacy CAM](./components/associative_memory.md),
  including [matching and selection](./components/associative_memory.md#matching-and-selection-without-storage)
  and [legacy CAM migration](./components/associative_memory.md#migrating-from-legacy-cam).
- **Cache:** [cache organization and RTL components](./components/associative_memory.md#cache-organization-examples),
  [transaction contracts, scheduling, and adapters](./components/associative_memory.md#transactional-cache-composition-contracts),
  and the [concurrent behavioral cache](./components/associative_memory.md#concurrent-behavioral-cache).
  Cache-specific APIs are experimental.
- **Replacement:** [round-robin and tree pseudo-LRU policies](./components/associative_memory.md#replacement-policies).
- **Control/status registers:** [CSR definitions, blocks, and tops](./components/csr.md),
  including the [whole-top software implementation](./components/csr.md#whole-top-software-implementation).

### Models

- **Memory and behavioral models:** [memory models](./components/memory.md#memory-models),
  [behavioral model capability and SystemC](./components/behavioral_models.md), and
  [associative software reference](./components/associative_memory.md#clock-stepped-software-reference).
- **Bus functional models:** [AXI](./components/amba/axi.md#validation),
  [LTI](./components/amba/lti.md#validation), [APB](./components/amba/apb.md#apb-bfm),
  [ready/valid](./components/ready_valid_bfm.md), and [SPI](./components/spi_bfm.md).

## Ideas for Future Development

These are possible additions rather than a complete roadmap. Existing building
blocks may already support parts of these use cases:

- Arithmetic: a dedicated Gray-coded counter, inverse square root, logarithms
  beyond the existing `Log2Ceil`, and binary-coded decimal (BCD).
- Bit operations: a component exposing the total number of pattern occurrences.
  [FindPattern](./components/find_pattern.md) already finds the first or nth
  occurrence, but does not expose its internal count.
- Encodings: programmable logic arrays (PLAs).
- Error control: CRC, interleaving, and pseudorandom generators such as LFSRs.
- Flow control: general-purpose credit-based hardware attachments.
- Interconnect: coherent and non-coherent networks on chip.
- Interfaces: AHB, SFI, PCIe, UCIe, JTAG, UART, DDR, and HBM.
- Models: CXL.

## Adding a New Component

Please refer to [Component](./Component.md) for the best practices for creating
new components.

----------------

Copyright (C) 2023-2026 Intel Corporation SPDX-License-Identifier: BSD-3-Clause
