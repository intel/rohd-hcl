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

## First-In First-Out (FIFO) Buffers

Please see [`Fifo`](./fifo.md)

## Memory Models

The `MemoryModel` has the same interface as a `Memory`, but is non-synthesizable and uses a software-based `SparseMemoryStorage` as a backing for data storage. This is a useful tool for testing systems that have relatively large memories.

The `MemoryStorage` class also provides utilities for reading (`loadMemString`) and writing (`dumpMemString`) verilog-compliant memory files (e.g. for `readmemh`).

## Caches

ROHD-HCL provides cache implementations for different architectural needs, from simple direct-mapped caches to sophisticated multi-ported set-associative designs.  The base `Cache` interface provides a set of fill ports, read ports, and eviction ports.

Fill and read ports are `ValidDataPortInterface`s, where a `valid` signal is used on the read side to indicate a `hit`, and it is used on the fill side (set to false) to invalidate a cache entry.

 The eviction ports provide address and data for evicted cache elements, where eviction happens on a fill that needs to find space in the cache (not on an invalidate) This capability is not yet implemented in all following `Cache` implementations.

### Replacement Policy

For supporting set-associative caching, the `Cache` interface provides a way to provide a replacement policy via a `Function` parameter:

```dart
  final ReplacementPolicy Function(
      Logic clk,
      Logic reset,
      List<AccessInterface> hits,
      List<AccessInterface> misses,
      List<AccessInterface> invalidates,
      {int ways,
      String name}) replacement;
```

Here, the `AccessInterface` simply carries the `access` flag and the `way` that is being read or written.

A pseudo-LRU `ReplacementPolicy` called `PseudoLRUReplacement` is provided as default for use in set-associative caches.

### DirectMappedCache

The [`DirectMappedCache`] provides a direct-mapped cache with multiple read and fill ports.

### Fully Associative Cache (e.g., Contents Addressable Memory (CAM))

ROHD-HCL provides fully-associative cache implementations that enable lookup by content rather than address. This is useful for building efficient caches, translation lookaside buffers (TLBs), and request tracking systems.

The [`FullyAssociativeCache`] implements eviction if the eviction ports (parallel to the fill ports) are provided. Note that there is only 1 line in a fully-associative cache as every way stores a unique tag.

```dart
final cache = FullyAssociativeCache(
  clk, reset,
  [fillPort1, fillPort2],     // Fill ports for cache line writes
  [readPort1, readPort2],     // Read ports for cache lookups
  ways: 4,                    // 4-way set associative
);
```

#### Read-with-Invalidate Feature

The `FullyAssociativeCache` supports an advanced read-with-invalidate operation that allows atomic read and invalidation of cache entries. This feature is particularly useful for implementing request/response tracking systems where you need to read data and immediately mark the entry as invalid.

The read-with-invalidate functionality is enabled automatically when using `ValidDataPortInterface` with the `readWithInvalidate` extension:

```dart
// Create read port with read-with-invalidate capability
final readPort = ValidDataPortInterface(dataWidth: 32, addrWidth: 8)
  ..readWithInvalidate = Logic(name: 'readWithInvalidate');

final cache = FullyAssociativeCache(
  clk, reset,
  [fillPort],
  [readPort],  // This port now supports read-with-invalidate
  ways: 8,
);

// To perform a read-with-invalidate operation:
// 1. Set the address and enable the read
readPort.addr <= targetAddress;
readPort.en <= Const(1);
// 2. Assert readWithInvalidate to invalidate on hit
readPort.readWithInvalidate <= shouldInvalidate;

// The cache will:
// - Return valid data if hit occurs (readPort.valid will be high)
// - Automatically invalidate the entry on the next clock cycle if readWithInvalidate was asserted
```

**Key Properties of Read-with-Invalidate:**

- **Atomic Operation**: The read and invalidate happen as a single atomic operation
- **Conditional**: Invalidation only occurs on cache hits, not misses
- **Pipelined**: The invalidation is registered and occurs on the clock cycle following the hit detection
- **Compatible**: Works seamlessly with existing fill operations and replacement policies

**Use Cases:**

1. **Request Tracking**: Read request data and immediately mark as completed
2. **Cache Coherency**: Implement invalidation protocols
3. **Resource Management**: Atomically consume cached resources

**Example: Request/Response Matching**

```dart
// CAM for tracking pending requests - stores request ID as tag, address as data
final pendingRequests = FullyAssociativeCache(
  clk, reset,
  [fillPort],     // Add new pending requests
  [lookupPort],   // Look up and remove completed requests
  ways: 16,
);

// When a response arrives, look up the request and invalidate the entry
lookupPort.addr <= responseId;        // Use response ID as lookup key
lookupPort.en <= responseValid;       // Enable lookup when response is valid
lookupPort.readWithInvalidate <= Const(1); // Always invalidate on hit

// If hit occurs:
// - lookupPort.valid will be high
// - lookupPort.data contains the original request address
// - Entry is automatically invalidated for future requests
```

#### Occupancy Tracking

The `FullyAssociativeCache` can optionally provide occupancy tracking signals by setting `generateOccupancy: true`:

```dart
final cache = FullyAssociativeCache(
  clk, reset,
  [fillPort],
  [readPort],
  ways: 8,
  generateOccupancy: true,  // Enable occupancy tracking
);

// Access occupancy signals
final currentOccupancy = cache.occupancy!;  // Number of valid entries (0 to ways)
final isFull = cache.full!;                 // High when all ways are occupied
final isEmpty = cache.empty!;               // High when no entries are valid
```

This is particularly useful for flow control and backpressure management in systems that need to track cache utilization.

### Set Associative Cache

The [`SetAssociativeCache`] provides a set-associative cache with multiple read and fill ports and a replacement policy parameter to specify what type of way replacement the cache should use.

```dart
final cache = SetAssociativeCache(
  clk, reset,
  [fillPort1, fillPort2],     // Fill ports for cache line writes
  [readPort1, readPort2],     // Read ports for cache lookups
  ways: 4,                    // 4-way set associative
  lines: 256,                 // 256 cache lines
);
```

The [`SetAssociativeCache`] implements DOES NOT support emitting eviction data on eviction ports yet.
