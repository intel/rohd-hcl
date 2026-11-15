## Description & Motivation

Expand reusable compute primitives and their documentation:

- Add unsigned accumulation, numeric narrowing, divider core and ready/valid wrapper, a valid-only carry-save multiplier wrapper, and fixes for divider nontermination at certain operand widths and signed inputs.
- Add a protocol-neutral fixed-latency tracker and a generic ready/valid wrapper with initiation-interval scheduling, reserved result buffering, and optional IDs for in-order, continuously advancing cores.
- Add opt-in 4:2 compression trees, configurable per-input/output delay estimates for multipliers, multiply-accumulates, and dot products, and fix pipelined compression-tree MAC control ports.
- Add GF(2) algebra and finite fields, linear transforms, LFSRs including a zero-based tap-list API, signatures, and seed-aligned PRBS generation and checking.
- Add floating-point classification and comparison, opt-in explicit-J alignment, configurable prefix scans including Gray-code conversion, first-match selection, boolean scatter, thermometer conversion, and a clock-enable divider.
- Add one-hot/binary extensions, strict-majority hardware reused by compressor carries, and opt-in aligned serializer timing. Extend Confapp and source views for compute and binary-math components, custom compression delays, and serializer alignment; the generic fixed-latency entry is a delay-core example.
- Fix AXI4 handshake sampling and queued writes. Add an opt-in ACE4 signal layout and signal-level BFM support, and typed resettable-entry controls.
- Move durable component-selection and contributor guidance into the README-linked documentation.

## Related Issue(s)

- Fix #8: Implement serial and parallel LFSRs, including the requested simple tap-list API.
- Fix #19: Add one-hot/binary extensions for `Logic` and `LogicValue`.
- Fix #86: Add reusable strict-majority hardware and use its three-input form for compressor carries; retain the existing boolean `LogicValue.majority()` API.
- Fix #149: Add opt-in aligned serializer output timing while preserving existing defaults.
- Fix #120: Add a 4:2 compressor and delay-driven selection in compression trees, incorporating the applicable work from #142.
- Related to #46: Recurrence and signature primitives are groundwork, not a complete CRC.
- Fix #146: Add a general fixed-latency ready/valid wrapper with optional ID propagation for in-order cores that advance through bubbles.
- Related to #139: Exhaustive 1- through 4-bit tests and divider fixes address part of the issue; the typed FSM is already in main. Leave the issue open for the remaining work proposed by #287, which remains open and needs rebasing and validation.

## Testing

- The existing PR reports a local `dart test` run.
- Focused AXI4, ACE4, resettable-entry, and static/runtime control tests: 73 passed.
- Typed storage and control regression tests: 72 passed, including generated RTL and SystemC cases.
- Serializer regression tests: 36 passed.
- One-hot and configurator regression tests: 144 passed.
- Divider and wrapper tests: 11 passed, including exhaustive 1- through 4-bit signed and unsigned operands and directed ROHD, Icarus, and Verilator checks.
- Binary recurrence tests: 10 passed, including tap-list sequences, controls, validation, and generated RTL.
- Compression-tree, multiplier, MAC, dot-product, and configurator tests: 216 passed, including 4:2 selection, all compressor inputs, mixed configurations, and pipeline controls.
- Configurable compression-delay and column-compressor tests: 18 passed, including asymmetric pin paths, mixed configurations, irregular rows, and generated RTL. Additional multiplier, MAC, and dot-product regressions: 351 passed.
- Majority, population-count, and compressor regressions: 37 passed, including exhaustive small-width X/Z inputs, wider vectors, shared three-input carry logic, and generated RTL.
- Confapp configurator regressions: 165 passed, including default generation, non-default round trips, custom delays, and aligned serializer timing. Focused Confapp widget and source-mapping tests passed; mapped source files exist. The generated asset bundle was not rebuilt in this environment.
- Fixed-latency tracker and wrapper tests: 14 passed, including ROHD simulation, generated Icarus RTL, multi-cycle cores, backpressure, reset, throughput, and typed payloads. Queue and handshake contract regressions: 50 passed.
- Targeted Dart analysis, Markdown lint, and whitespace checks passed.
- Broader pre-merge validation: **to be completed**.

## Backwards-compatibility

No intentional breaking API changes. Existing serializer and ACE4 layouts remain the defaults; aligned timing and the ACE4 signal layout are opt-in. Explicit-J alignment and Gray prefix topology are also opt-in. AXI4 monitor sampling is corrected to capture values at the handshake edge. Divider cases that previously failed to complete now produce results; the public divider interface and `logDataWidth` value are unchanged.

The existing case-based one-hot decoder can produce different X/Z results in ROHD simulation and generated RTL; the value extension follows ROHD simulation. The ACE4 checker covers signal-level behavior, not full coherency compliance.

## Documentation

Updated the component index and topic guides, contributor guidance, and `CHANGELOG.md`. The compute-family development page is retired in favor of permanent component documentation.

This draft includes uncommitted changes; update it and complete validation before submitting the PR.
