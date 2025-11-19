[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=621521356)

[![Generator Web App](https://img.shields.io/badge/Generator_Web_App-live-brightgreen)](https://intel.github.io/rohd-hcl/confapp/)
[![Tests](https://github.com/intel/rohd-hcl/actions/workflows/general.yml/badge.svg?event=push)](https://github.com/intel/rohd-hcl/actions/workflows/general.yml)
[![API Docs](https://img.shields.io/badge/API%20Docs-generated-success)](https://intel.github.io/rohd-hcl/rohd_hcl/rohd_hcl-library.html)
[![Chat](https://img.shields.io/discord/1001179329411166267?label=Chat)](https://discord.gg/jubxF84yGw)
[![License](https://img.shields.io/badge/License-BSD--3-blue)](https://github.com/intel/rohd-hcl/blob/main/LICENSE)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](https://github.com/intel/rohd-hcl/blob/main/CODE_OF_CONDUCT.md)

# ROHD Hardware Component Libary

A hardware component library developed with [ROHD](https://intel.github.io/rohd-website/). This library aims to collect a set of reusable, configurable components that can be leveraged in other designs. These components are also intended as good examples of ROHD hardware implementations.

Check out the [generator web app](https://intel.github.io/rohd-hcl/confapp/), which lets you explore some of the available components, configure them, and generate SystemVerilog.

This project is always improving and growing! In a given category, initial components are primarily focused on correctness with room for optimization from there. Please feel free to contribute or provide feedback. Check out [`CONTRIBUTING`](https://github.com/intel/rohd-hcl/blob/main/CONTRIBUTING.md) for details on how to contribute.

This project is *not* intended to be the *only* place for reusable hardware components developed in ROHD. It's not even intended to be the only *library*. Contributions are welcomed to this library, but developers are also welcome to build independent packages or libraries, even if they may overlap.

## Guidelines for Components

- All hardware components should be `Module`s so that they are convertible to SystemVerilog
- Components should be general and easily reusable
- Components should be as configurable as may be useful
- Components must be extensively tested
- Components must have excellent documentation and examples
- The first component in a category should be the simplest
- Focus on breadth of component types before depth in one type
- Add `extension`s to other classes to make component usage easier, when appropriate

## Component List

See the [component list](https://github.com/intel/rohd-hcl/blob/main/doc/README.md) for documentation on components and plans for future component development.

Some examples of component categories include:

- Encoders & Decoders
- Arbiters
- FIFOs & Queues
- Find
- Count
- Sort
- Arithmetic
- Rotate
- Counters
- Pseudorandom
- Error checking & correction
- Data flow
- Memory
- Standard interfaces
- Models

-----------------

Copyright (C) 2023-2025 Intel Corporation  
SPDX-License-Identifier: BSD-3-Clause
