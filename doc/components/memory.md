# Memory

ROHD-HCL provides a generic `abstract` [`Memory`](https://intel.github.io/rohd-hcl/rohd_hcl/Memory-class.html) class which accepts a dynamic number of `writePorts` and `readPorts`, where each port is of type [`DataPortInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/DataPortInterface-class.html).  A `DataPortInterface` is a simple interface with `en` and `addr` as `control` signals and `data` signal(s).  In a write interface, all signals are in the same direction.  In a read interface, the `control` signals are in the opposite direction of the `data` signal(s).

## Masks

A subclass of `DataPortInterface` is the[`MaskedDataPortInterface`](https://intel.github.io/rohd-hcl/rohd_hcl/MaskedDataPortInterface-class.html), which adds `mask` to the `data` group of signals.  The `mask` signal is a byte-enable signal, where each bit of `mask` controls one byte of `data`.

## Register Files

A subclass of `Memory` is the [`RegisterFile`](https://intel.github.io/rohd-hcl/rohd_hcl/RegisterFile-class.html), which inherits the same flexible interface from `Memory`.  It has a configurable number of entries via `numEntries`.

The `RegisterFile` accepts masks on writes, but not on reads.

Currently, `RegisterFile` only generates flop-based memory (no latches).

The read path is combinational, so data is provided immediately according to the control signals.

The `RegisterFile` can be initialized with data on reset using `resetValue` following the conventions of `ResettableEntries`.

[RegisterFile Schematic](https://intel.github.io/rohd-hcl/RegisterFile.html)

## First-In First-Out (FIFO) Buffers

Please see [`Fifo`](./fifo.md)

## Memory Models

The `MemoryModel` has the same interface as a `Memory`, but is non-synthesizable and uses a software-based `SparseMemoryStorage` as a backing for data storage. This is a useful tool for testing systems that have relatively large memories.

The `MemoryStorage` class also provides utilities for reading (`loadMemString`) and writing (`dumpMemString`) Verilog-compliant memory files (e.g. for `readmemh`).

## Cam

A content-addressable memory or `Cam` is provided which allows for associative lookup of an index to help with building specialized forms of caches where the data is stored in a separate register file. In this case the `tag` is matched during a read and the position in memory is returned. For the fill ports, the user can simply write a new tag at a given index location. This means the `Cam` is a fine-grained component for use in building associative look of positions of objects in another memory.

Another form of `Cam` or `CamInvalidate` provides a read interface with a read-with-invalidate feature if the invalidate port is set on the interface.

An example use is:

```dart
const tagWidth = 8;
      const numEntries = 4;
      const idWidth = 2;

      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final writePort = DataPortInterface(tagWidth, idWidth);
      final lookupPort = TagInvalidateInterface(idWidth, tagWidth);

      final cam = CamInvalidate(
        clk,
        reset,
        [writePort],
        [lookupPort],
        numEntries: numEntries,
      );
      // Write tag 0x99 to entry 1
      writePort.addr.inject(1);
      writePort.data.inject(0x99);
      await clk.nextPosedge;

      // Lookup tag 0x42 without invalidate
      lookupPort.tag.inject(0x99);
      await clk.nextPosedge;
      expect(lookupPort.idx.value.toInt(), equals(1),
          reason: 'Should return index 0');
```

## Caches

ROHD-HCL provides cache implementations for different architectural needs, from simple direct-mapped caches to sophisticated multi-ported set-associative designs.  The base `Cache` interface provides a set of fill ports, read ports, and eviction ports.

Cache ports are all `ValidDataPortInterface`s, where a `valid` signal is used on the read side to indicate a `hit`, and it is used on the fill side (set to false) to invalidate a cache entry. This port type also can be created with `readWithInvalidate` so that a read request can invalidate the entry after the read.

 The eviction ports provide address and data for evicted cache elements, where eviction happens on a fill that needs to find space in the cache. Note that means the number of eviction ports, if supplied, must match the number of fill ports.

### Fill + Eviction composite interface

The fill side of `Cache` groups two `ValidDataPortInterface`s, one for filling together with an optional one for eviction forming `FillEvictInterface` type. If any `FillEvictInterface` provides an eviction interface, then all entries must provide an eviction (all-or-none).

Example (manual construction):

```dart
final f1 = ValidDataPortInterface(dataWidth: 32, addrWidth: 8);
final e1 = ValidDataPortInterface(dataWidth: 32, addrWidth: 8);

final fills = [FillEvictInterface(f1, e1)];

final cache = FullyAssociativeCache(clk, reset, fills, [readPort], ways: 8);
```

For convenience, there is a `CachePorts` helper class which can optionally attach eviction ports to each fill entry. Use `CachePorts.fresh(..., attachEvictionsToFills: true)` when the test needs eviction outputs. When `attachEvictionsToFills` is false (the default) the fill entries will not carry eviction sub-interfaces.

### Read-with-Invalidate Feature

The `Cache` supports an advanced read-with-invalidate operation that allows atomic read and invalidation of cache entries.

The read-with-invalidate functionality is enabled automatically when using `ValidDataPortInterface` with the `readWithInvalidate` option enabled:

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

Another `ReplacementPolicy` is `AvailableInvalidate` which only works if the cache is using invalidation and is never full.  This is useful with the `FullyAssociativeCache` with occupancy turned on so that the user can avoid filling when the cache is full and wait for an invalidate to free up space.  If the cache becomes full, `AvailableInvalidate` does not fall back on another replacement policy, it currently returns way 0 for every fill request while full.

### Direct-Mapped Cache

The [`DirectMappedCache`] provides a direct-mapped cache with multiple read and fill ports.

### Fully Associative Cache

ROHD-HCL provides fully-associative cache implementations that enable lookup by content rather than address. This is useful for building efficient caches, translation look-aside buffers (TLBs), and request tracking systems.

The [`FullyAssociativeCache`] implements eviction if the eviction ports (parallel to the fill ports) are provided. Note that there is only 1 line in a fully-associative cache as every way stores a unique tag.

```dart
final cache = FullyAssociativeCache(
  clk, reset,
  [fillPort1, fillPort2],     // Fill ports for cache line writes
  [readPort1, readPort2],     // Read ports for cache lookups
  ways: 4,                    // 4-way set associative
);
```

## Example: Request/Response Matching

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

### Occupancy Tracking

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

This is particularly useful for flow control and back-pressure management in systems that need to track cache utilization.

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
