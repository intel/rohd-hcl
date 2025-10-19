# Memory

ROHD-HCL provides a generic `abstract` [`Memory`](https://intel.github.io/rohd-hcl/rohd_hcl/Memory-class.html) class which accepts a dynamic number of `writePorts` and `readPorts`, where each port is of type [`DataPortInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/DataPortInterface-class.html).  A `DataPortInterface` is a simple interface with `en` and `addr` as `control` signals and `data` signal(s).  In a write interface, all signals are in the same direction.  In a read interface, the `control` signals are in the opposite direction of the `data` signal(s).

## Masks

A sub-class of `DataPortInterface` is the[`MaskedDataPortInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/MaskedDataPortInterface-class.html), which adds `mask` to the `data` group of signals.  The `mask` signal is a byte-enable signal, where each bit of `mask` controls one byte of `data`.

## Register Files

A sub-class of `Memory` is the [`RegisterFile`](https://intel.github.io/rohd-hcl/rohd_hcl/RegisterFile-class.html), which inherits the same flexible interface from `Memory`.  It has a configurable number of entries via `numEntries`.

The `RegisterFile` accepts masks on writes, but not on reads.

Currently, `RegisterFile` only generates flop-based memory (no latches).

The read path is combinational, so data is provided immediately according to the control signals.

The `RegisterFile` can be initialized with data on reset using `resetValue` following the conventions of `ResettableEntries`.

[RegisterFile Schematic](https://intel.github.io/rohd-hcl/RegisterFile.html)

## Memory Models

The `MemoryModel` has the same interface as a `Memory`, but is non-synthesizable and uses a software-based `SparseMemoryStorage` as a backing for data storage. This is a useful tool for testing systems that have relatively large memories.

The `MemoryStorage` class also provides utilities for reading (`loadMemString`) and writing (`dumpMemString`) verilog-compliant memory files (e.g. for `readmemh`).

## Content Addressable Memory (CAM)

ROHD-HCL provides Content Addressable Memory (CAM) implementations that enable lookup by content rather than address. CAMs are essential for building associative caches, translation lookaside buffers (TLBs), and request tracking systems.

### Basic CAM

The [`Cam`] class provides a basic CAM implementation with write ports based on `DatasPortInteface` and lookup ports based on a `TagInterface`. Optionally, it provides valid entry tracking to tell how full the `Cam` currently is.

The `TagInterface` provides:

- `tag` input for the search key
- `idx` output indicating which entry matched
- `hit` output indicating if a match was found.

When `enableValidTracking` is enabled, the CAM provides:

- `full` signal indicating all entries are valid
- `empty` signal indicating no entries are valid  
- `validCount` signal with count of valid entries

Here is an example instantiation:

```dart
final cam = Cam(
  clk, reset,
  [writePort], [lookupPort],
  numEntries: 16,
  enableValidTracking: true,
);
// Use cam.full, cam.empty, and cam.validCount signals
```

### CAM with Invalidation

The [`CamInvalidate`] extends the basic `Cam` with entry invalidation operations:

- Uses [`TagInvalidateInterface`] for lookups; this interface provides
  `invalidate` signal to clear the entry upon successful lookup.
- Ideal for request/response tracking where entries should be freed right after processing.

```dart
final camInvalidate = CamInvalidate(
  clk, reset,
  [writePort], [lookupInvalidatePort],
  numEntries: 8,
  enableValidTracking: true,
);
```

## Caches

ROHD-HCL provides cache implementations for different architectural needs, from simple direct-mapped caches to sophisticated multi-ported set-associative designs.  The base `Cache` interface provides a set of write ports, read ports, and invalidate ports.  The invalidate ports provide address and data for evicted cache elements. This capability is not yet implemented in the following `Cache` implementations.

### DirectMappedCache

The [`DirectMappedCache`] provides a direct-mapped cache with multiple read and fill ports.

### Multi-Ported Read Cache

The [`MultiPortedReadCache`] provides a set-associative cache with multiple read and fill ports and a replacement policy parameter to specify what type of way replacement the cache should use. It's interface is comprised of fill and read `ValidDataPortInterface`s, where a `valid` signal is used on the read side to indicate a `hit`, and it is used on the fill side (set to false) to invalidate a cache entry.

```dart
final cache = MultiPortedReadCache(
  clk, reset,
  [fillPort1, fillPort2],     // Fill ports for cache line writes
  [readPort1, readPort2],     // Read ports for cache lookups
  ways: 4,                    // 4-way set associative
  lines: 256,                 // 256 cache lines
);
```
