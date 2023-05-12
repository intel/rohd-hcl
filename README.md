[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=621521356)

[![Tests](https://github.com/intel/rohd-hcl/actions/workflows/general.yml/badge.svg?event=push)](https://github.com/intel/rohd-hcl/actions/workflows/general.yml)
[![API Docs](https://img.shields.io/badge/API%20Docs-generated-success)](https://intel.github.io/rohd-hcl/rohd_hcl/rohd_hcl-library.html)
[![Chat](https://img.shields.io/discord/1001179329411166267?label=Chat)](https://discord.gg/jubxF84yGw)
[![License](https://img.shields.io/badge/License-BSD--3-blue)](https://github.com/intel/rohd-hcl/blob/main/LICENSE)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](https://github.com/intel/rohd-hcl/blob/main/CODE_OF_CONDUCT.md)

# ROHD Hardware Component Libary

A hardware component library developed with [ROHD](https://github.com/intel/rohd).  This library aims to collect a set of reusable, configurable components that can be leveraged in other designs.  These components are also intended as good examples of ROHD hardware implementations.

This project is a work in progress!  Initial components are primarily focused on correctness, and there is room for optimization from there.  Please feel free to contribute or provide feedback.  Check out [`CONTRIBUTING`](https://github.com/intel/rohd-hcl/blob/main/CONTRIBUTING.md) for details on how to contribute.

This project is *not* intended to be the *only* place for reusable hardware components developed in ROHD.  It's not even intended to be the only *library*.  Contributions are welcomed to this library, but developers are also welcome to build independent packages or libraries, even if they may overlap.

## Guidelines for Components

- All components should be `Module`s so that they are convertible to SystemVerilog
- Components should be general and easily reusable
- Components should be as configurable as may be useful
- Components must be extensively tested
- Components must have excellent documentation and examples
- The first component in a category should be the simplest
- Focus on breadth of component types before depth in one type
- Add `extension`s to other classes to make component usage easier, when appropriate

## Component List

Below is a list of components either already or planning to be implemented.

| Marking         | Status                                 |
|-----------------|----------------------------------------|
| No link         | Idea phase / included in parent link   |
| Link **(OPEN)** | An issue is opened for discussion      |
| Link **(WIP)**  | An issue is actively being developed   |
| Link to API     | Implemented with API documentation     |

- Encoders
  - 1-hot to Binary
  - Binary to 1-hot
  - Gray to Binary
  - Binary to Gray
  - Priority
  - PLAs
- Arbiters
  - Priority
  - [Round-robin **(WIP)**](https://github.com/intel/rohd-hcl/issues/11)
- [FIFO](./doc/fifo.md)
  - Synchronous
  - Asynchronous
  - Bubble Generating
  - Shift register
- Find
  - Find N'th bit=X /           LZD/LOD
  - Find N'th bit=X from end    TZD/TOD
  - Min
  - Max
  - Find pattern
- Count
  - Count bit=X
  - Count pattern
- [Sort **(WIP)**](https://github.com/intel/rohd-hcl/issues/9)
- Arithmetic
  - [Prefix Trees **(WIP)**](https://github.com/intel/rohd-hcl/issues/12)
  - Adders
  - Subtractors
  - Multipliers
    - [Pipelined Integer Multiplier **(WIP)**](https://github.com/intel/rohd-hcl/issues/10)
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
    - Dot product
- [Rotate](./doc/rotate.md)
  - Dynamic and fixed amounts
  - Left and right
  - Includes `extension`s on `Logic` and `LogicValue`
- Counters
  - Binary counter
  - Gray counter
- [LFSR **(WIP)**](https://github.com/intel/rohd-hcl/issues/8)
- Error checking
  - ECC
  - CRC
  - Parity
- Data flow
  - Ready/Valid
  - Connect/Disconnect (e.g. SFI)
  - Widening
  - Narrowing
  - Crediting
  - NoC's
    - Coherent
    - Non-Coherent
- [Memory](./doc/memory.md)
  - [Masks](./doc/memory.md#masks)
  - [Register Files](./doc/memory.md#register-files)
    - Flop-based
    - Latch-based
  - Replacement Policies
    - LRU
- Standard interfaces
  - AXI
  - APB
  - AHB
  - SFI
  - PCIe
  - UCIe
  - JTAG
  - SPI
  - UART
  - DDR
  - HBM

----------------
2023 March 30  
Author: Max Korbel <<max.korbel@intel.com>>

Copyright (C) 2023 Intel Corporation  
SPDX-License-Identifier: BSD-3-Clause
