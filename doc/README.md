
# ROHD-HCL Component List

Below is a list of components grouped by category. Ones with links are documented and completed, while others are still in planning or development stages.

Some in-development items will have opened issues, as well. Feel free to create a pull request or file issues to add more ideas to this list. If you plan to develop and contribute a component, please be sure to open an issue so that there's not multiple people working on the same thing. Make sure to check if someone else has an open issue for a certain component before starting.

- Encoders & Decoders
  - [1-hot to Binary](./components/onehot.md)
  - [Binary to 1-hot](./components/onehot.md)
  - Gray to Binary
  - Binary to Gray
  - Priority
  - PLAs
- Arbiters
  - [Priority Arbiter](./components/arbiter.md#priority-arbiter)
  - Round-robin Arbiter
- FIFOs & Queues
  - [Synchronous FIFO](./components/fifo.md)
  - Asynchronous / clock-crossing FIFO
  - [Shift register](./shift_register.md)
- Find
  - Find N'th bit (0 or 1) from the start/end
  - Find minimum
  - Find maximum
  - Find N'th pattern from the start/end
- Count
  - Count bit occurence
  - Count pattern occurence
- Sort
  - [Bitonic sort](./components/sort.md#bitonic-sort)
- Arithmetic
  - Prefix Trees
  - Adders
  - Subtractors
  - Multipliers
    - [Pipelined Integer Multiplier](./components/multiplier.md#carry-save-multiplier)
  - Dividers
  - Log
  - Square root
  - Inverse square root
  - Floating point
    - Double (64-bit)
    - Float (32-bit)
    - BFloat16 (16-bit)
    - BFloat8 (8-bit)
    - BFloat4 (4-bit)
- [Rotate](./components/rotate.md)
- Counters
  - Binary counter
  - Gray counter
- Pseudorandom
  - LFSR
- Error checking & correction
  - ECC
  - CRC
  - Parity
- Data flow
  - Ready/Valid
  - Connect/Disconnect
  - Widening
  - Narrowing
  - Crediting
  - NoC's
    - Coherent
    - Non-Coherent
- Memory
  - [Register File](./components/memory.md#register-files)
  - [Masking](./components/memory.md#masks)
  - Replacement Policies
    - LRU
  - [Memory Model](./components/memory.md#memory-models)
- Standard interfaces
  - AXI
  - [APB](./components/standard_interfaces.md#apb)
  - AHB
  - SFI
  - PCIe
  - UCIe
  - JTAG
  - SPI
  - UART
  - DDR
  - HBM
- Models
  - [APB](./components/apb_bfm.md)

----------------

Copyright (C) 2023 Intel Corporation  
SPDX-License-Identifier: BSD-3-Clause
