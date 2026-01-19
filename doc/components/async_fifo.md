# Asynchronous FIFO

ROHD-HCL provides an asynchronous FIFO for safely passing data between two independent clock domains.

## Overview

The `AsyncFifo` module enables data transfer between two completely independent clock domains (different frequencies, phases, or sources). This is essential for designs that need to communicate across clock domain boundaries while maintaining data integrity and preventing metastability issues.

## Key Features

- **Independent Clock Domains**: Separate write and read clocks operating at any frequency
- **Gray Code Pointers**: Uses Gray code encoding for pointer synchronization (only 1 bit changes at a time)
- **Metastability Protection**: Multi-stage synchronizers prevent metastability propagation
- **Safe Full/Empty Flags**: Properly synchronized flags in respective clock domains
- **Configurable Depth**: FIFO depth must be a power of 2 (2, 4, 8, 16, 32, etc.)
- **Configurable Synchronizer Stages**: Default 2-stage synchronizers (configurable for different requirements)

## Architecture

The async FIFO uses the following techniques for safe clock domain crossing:

1. **Dual-Port Memory**: Independent read and write addresses
2. **Gray-Coded Pointers**: Write and read pointers use Gray code to minimize multi-bit transition errors
3. **Pointer Synchronization**: Gray pointers are synchronized across clock domains using multi-flop synchronizers
4. **Domain-Specific Flags**:
   - `full` flag generated in write clock domain
   - `empty` flag generated in read clock domain

## Usage

### Basic Example

```dart
final asyncFifo = AsyncFifo(
  writeClk: wrClk,
  readClk: rdClk,
  writeReset: wrRst,
  readReset: rdRst,
  writeEnable: wrEn,
  writeData: wrData,
  readEnable: rdEn,
  depth: 16,  // Must be power of 2
);
```

### Write Domain

In the write clock domain:

- Assert `writeEnable` to write `writeData` into the FIFO
- Monitor `full` flag - do not write when full
- Data is written on the rising edge of `writeClk`

### Read Domain

In the read clock domain:

- Monitor `empty` flag - do not read when empty
- Current data available on `readData` output (combinational read)
- Assert `readEnable` to advance to next entry
- Read pointer updates on rising edge of `readClk`

## Important Considerations

### Depth Requirements

The FIFO depth **must be a power of 2** (2, 4, 8, 16, 32, 64, etc.). This requirement ensures proper Gray code pointer wrapping.

```dart
// Valid depths
depth: 4
depth: 16
depth: 32

// Invalid depths
depth: 10  (not a power of 2)
depth: 20  (not a power of 2)
```

### Synchronization Latency

- Full/empty flags have synchronization latency (typically 2-3 clock cycles)
- After reset, the FIFO may appear empty for several cycles while synchronizers settle
- Design your system to account for this latency

### Clock Domain Crossing

**The async FIFO is specifically designed for clock domain crossing.** For single-clock designs, use the standard `Fifo` module instead, which is more efficient.

## Synchronizer Module

The `Synchronizer` module is a reusable component for safely crossing single-bit or multi-bit control signals between clock domains.

```dart
final sync = Synchronizer(
  destClk,
  dataIn: sourceSignal,
  reset: destReset,
  stages: 2,  // Number of flip-flop stages (default: 2)
);
```

**Warning**: Synchronizers are only suitable for control signals, not data buses. For data transfer, always use an async FIFO.

## Example: Producer-Consumer System

See the complete example in [async_fifo_example.dart](../../example/async_fifo_example.dart) which demonstrates:

- Two independent clock domains (fast write, slow read)
- Continuous data streaming
- Full/empty flag handling
- SystemVerilog generation

## Performance

### Throughput

- Write throughput: Up to 1 entry per write clock cycle (when not full)
- Read throughput: Up to 1 entry per read clock cycle (when not empty)
- Actual throughput depends on clock frequency ratio

### Latency

- Read latency: Combinational read (0 cycles to see data)
- Flag latency: 2-3 cycles for synchronization across domains

## Design Trade-offs

| Aspect           | Synchronous FIFO  | Asynchronous FIFO         |
| ---------------- | ----------------- | ------------------------- |
| Clock Domains    | Single            | Independent (2 clocks)    |
| Depth Constraint | Any value         | Must be power of 2        |
| Synchronization  | None needed       | Gray code + synchronizers |
| Area             | Smaller           | Larger (synchronizers)    |
| Latency          | Lower             | Higher (sync overhead)    |
| Use Case         | Same clock domain | Clock domain crossing     |

## Common Use Cases

1. **Different Clock Frequencies**: Transferring data between fast and slow domains
2. **Asynchronous Interfaces**: Connecting to external devices with independent clocks
3. **Clock Domain Isolation**: Isolating timing paths in multi-clock SoC designs
4. **Rate Adaptation**: Buffering data when production and consumption rates vary

## Additional Resources

- For single-clock FIFOs, see [FIFO documentation](./fifo.md)
- For Gray code converters, see [Binary-Gray documentation](./binary_gray.md)
- For general CDC principles, refer to industry standards on clock domain crossing

---

Copyright (C) 2026 Intel Corporation  
SPDX-License-Identifier: BSD-3-Clause
