
# ROHD-HCL Component List

Below is a list of components grouped by category. Ones with links are documented and completed, while others are still in planning or development stages.

Some in-development items will have opened issues, as well. Feel free to create a pull request or file issues to add more ideas to this list. If you plan to develop and contribute a component, please be sure to open an issue so that there are not multiple people working on the same thing. Make sure to check if someone else has an open issue for a certain component before starting.

Applications should import the package barrel rather than `lib/src` paths:

```dart
import 'package:rohd_hcl/rohd_hcl.dart';
```

- [Static or Runtime Parameters](./static_or_runtime_parameters.md)

## Source Layout

Sources under `lib/src` are organized by the component's primary function.
Each category has a barrel file that exports its components directly or
through subcategory barrels. The package barrel exports every category barrel.

| Category | Barrel | Subcategories |
| --- | --- | --- |
| Arithmetic | [`arithmetic.dart`](../lib/src/arithmetic/arithmetic.dart) | `accumulation`, `addition`, `conversion`, `division_and_roots`, `floating_point`, `multiplication`, `multiply_accumulate`, `normalization`, `prefix_networks`, `signals`, `values` |
| Bit operations | [`bit_operations.dart`](../lib/src/bit_operations/bit_operations.dart) | `population_count`, `search`, `shifting` |
| Clocking | [`clocking.dart`](../lib/src/clocking/clocking.dart) | `cdc`, `event_detection`, `gating` |
| Dataflow | [`dataflow.dart`](../lib/src/dataflow/dataflow.dart) | `ordering`, `reduction`, `selection`, `serialization` |
| Encodings | [`encodings.dart`](../lib/src/encodings/encodings.dart) | `gray`, `one_hot`, `priority` |
| Error control | [`error_control.dart`](../lib/src/error_control/error_control.dart) | `protection` |
| Flow control | [`flow_control.dart`](../lib/src/flow_control/flow_control.dart) | `arbitration`, `ready_valid`, `storage` |
| Interfaces | [`interfaces.dart`](../lib/src/interfaces/interfaces.dart) | `amba` (`amba4`, `amba5`, `endpoints`), `spi` (`endpoints`) |
| Memory | [`memories.dart`](../lib/src/memory/memories.dart) | `associative`, `contracts`, `csr`, `sequential`, `state`, `storage` |
| Models | [`models.dart`](../lib/src/models/models.dart) | `amba`, `memory`, `ready_valid_bfm`, `spi_bfm` |

The configurator tags each configurable component with the same category and
subcategory, and the confapp sidebar groups components accordingly.

## Components

- Arithmetic
  - [Prefix Trees](./components/parallel_prefix_operations.md) Several efficient components that leverage a variety of parallel prefix trees such as Ripple, Kogge-Stone, Sklansky, and Brent-Kung tree types.
    - [Priority Encoder](./components/parallel_prefix_operations.md)
    - [Or-scan](./components/parallel_prefix_operations.md)
    - [Incrementer](./components/parallel_prefix_operations.md)
    - [Decrementer](./components/parallel_prefix_operations.md)
  - [Adders](./components/adder.md)
    - [Ripple Carry Adder](./components/adder.md#ripple-carry-adder)
    - [Parallel Prefix Adder](./components/parallel_prefix_operations.md)
    - [Compound Adder](./components/adder.md#compound-adder)
    - [Native Adder](./components/adder.md#native-adder)
  - Subtractors
    - [Ones' Complement Adder Subtractor](./components/adder.md#ones-complement-adder-subtractor)
    - [Sign Magnitude Adder](./components/adder.md#sign-magnitude-adder)
  - Accumulation
    - [Summation](./components/summation.md#sum)
    - [Binary counter](./components/summation.md#counter)
    - [Gated counter](./components/summation.md#gated-counter)
    - Gray counter
  - Multipliers
    - [Pipelined Integer Multiplier](./components/multiplier.md#carry-save-multiplier)
    - [Compression Tree Multiplier](./components/multiplier.md#compression-tree-multiplier)
    - [Compression Tree Multiply-Accumulate](./components/multiplier.md#compression-tree-multiply-accumulate)
    - [Generic Multiply-Accumulate](./components/multiplier.md#generic-multiply-accumulate)
    - [Dot Product](./components/multiplier.md#dot-product)
    - [Booth Encoding and Compression Components](./components/multiplier_components.md)
  - Division and roots
    - [Multi Cycle Integer Divider](./components/divider.md)
    - [Fixed-Point Square Root](./components/fixed_point.md#fixedpointsqrt)
    - [Floating-Point Square Root](./components/floating_point.md#floatingpointsqrt)
    - Inverse square root
    - Log
  - Normalization
    - [Leading Digit Anticipate](./components/leading_digit_anticipate.md)
  - Floating point
    - [Floating-Point Value Types](./components/floating_point.md#floatingpointvalue)
      - Double (64-bit)
      - Float (32-bit)
      - BFloat16 (16-bit)
      - TensorFloat32 (19-bit)
      - 8-bit E4/M3 and E5/M2
    - [Single Path Floating-Point Adder](./components/floating_point.md#floatingpointadder)
    - [Dual Path Floating-Point Adder](./components/floating_point.md#floatingpointadder)
    - [Simple Floating-Point Multiplier](./components/floating_point.md#floatingpointmultiplier)
    - [Floating-Point Converter](./components/floating_point.md#floatingpointconverter)
  - [Fixed point](./components/fixed_point.md)
    - [FloatToFixed](./components/fixed_point.md#floattofixed)
    - [FixedToFloat](./components/fixed_point.md#fixedtofloat)
  - Binary-Coded Decimal (BCD)
- Bit operations
  - Search
    - [Find](./components/find.md)
      - [Find N'th bit (0 or 1) from the start/end](./components/find.md#find-nth)
    - [Find Pattern](./components/find_pattern.md)
      - [Find Pattern from Start/End](./components/find_pattern.md#find-pattern-from-startend)
      - [Find N'th Pattern from Start/End](./components/find_pattern.md#find-nth-pattern-from-startend)
  - Population count
    - [Count bit occurrence](./components/count.md)
    - Count pattern occurrence
  - Shifting
    - [Rotate](./components/rotate.md)
    - [SignedShifter](./components/shifter.md)
- Clocking
  - Gating
    - [Clock gating](./components/clock_gating.md)
    - [Toggle gating](./components/toggle_gate.md)
  - Event detection
    - [Edge detection](./components/edge_detector.md)
  - Clock-domain crossing
    - Synchronizer
- Dataflow
  - Selection
    - [Extrema](./components/extrema.md)
  - Ordering
    - [Bitonic sort](./components/sort.md#bitonic-sort)
  - Reduction
    - [Reduction Tree](./components/reduction_tree.md)
  - [Serialization](./components/serialization.md)
  - Widening
  - Narrowing
- Encodings
  - [1-hot to Binary](./components/onehot.md)
  - [Binary to 1-hot](./components/onehot.md)
  - [Binary to Gray](./components/binary_gray.md#binary-to-gray)
  - [Gray to Binary](./components/binary_gray.md#gray-to-binary)
  - Priority Encoders
    - [Prefix-tree based Priority Encoder](./components/priority_encoder.md#parallel-prefix-priority-encoder)
    - [Recursive Priority Encoder](./components/priority_encoder.md#recursive-priority-encoder)
  - PLAs
- Error control
  - [ECC](./components/ecc.md)
  - CRC
  - [Parity](./components/parity.md)
  - Interleaving
  - Pseudorandom
    - LFSR
- Flow control
  - Arbitration
    - [Priority Arbiter](./components/arbiter.md#priority-arbiter)
    - [Round-robin Arbiter](./components/arbiter.md#round-robin-arbiter)
  - Storage
    - [Synchronous FIFO](./components/fifo.md)
    - [Asynchronous / clock-crossing FIFO](./components/async_fifo.md)
  - Ready/Valid
    - [Ready/valid interfaces and FIFO](./components/ready_valid.md)
  - Connect/Disconnect
  - Crediting
- Interconnect
  - NoC's
    - Coherent
    - Non-Coherent
- Memory
  - [Register File](./components/memory.md#register-files)
  - [Masking](./components/memory.md#masks)
  - [CAMs](./components/memory.md#cam)
  - [Shift register](./components/shift_register.md)
  - [Control/Status Registers (CSRs)](./components/csr.md)
  - [Behavioral models](./components/behavioral_models.md)
- Interfaces
  - [AXI](./components/amba/axi.md)
  - [LTI](./components/amba/lti.md)
  - [APB interface](./components/standard_interfaces.md#apb)
  - [APB completers and BFM](./components/amba/apb.md)
  - AHB
  - SFI
  - PCIe
  - UCIe
  - JTAG
  - [SPI](./components/standard_interfaces.md#spi)
  - UART
  - DDR
  - HBM
  - Endpoints
    - [SPI](./components/spi_gaskets.md)
- Models
  - [AXI](./components/amba/axi.md)
  - [LTI](./components/amba/lti.md)
  - [APB](./components/amba/apb.md)
  - [Ready/Valid](./components/ready_valid_bfm.md)
  - [SPI](./components/spi_bfm.md)
  - [Memory Model](./components/memory.md#memory-models)
  - [Behavioral models (RTL vs. software vs. SystemC)](./components/behavioral_models.md)
  - CXL

## Adding a New Component

Please refer to [Component](./Component.md) for the best practices for creating new components.

----------------

Copyright (C) 2023-2026 Intel Corporation
SPDX-License-Identifier: BSD-3-Clause
