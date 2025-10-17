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

## Cache

The `Cache` is an abstract class that implements a configurable set-associative cache for caching data. It provides a flexible framework for implementing caches with different replacement policies and associativities.

### Key Operations

1. **Reading**: Returns cached data with a valid bit indicating hit/miss status. Updates replacement policy on hits.
2. **Filling**: Writes data into the cache, potentially allocating a new line if not present. Can also invalidate entries when valid bit is *not* set.
3. **Eviction**: Optional eviction ports provide the address and data being evicted during cache line allocation.

### Cache Interface

The cache uses `ValidDataPortInterface` for both read and fill ports, which
extends
[DataPortInterface](https://pub.dev/documentation/rohd_hcl/latest/rohd_hcl/DataPortInterface-class.html)
with:

- `valid`: Indicates whether the data is valid.
- Standard `en`, `addr`, and `data` signals from `DataPortInterface`.

## Multi-Ported Read Cache

The `MultiPortedReadCache` is a configurable set-associative cache that supports multiple read and fill ports. It implements a read-cache (not tracking dirty data for write-back) and supports write-around policy.

### Multi-Ported Cache Features

- Configurable associativity (number of ways)
- Configurable depth (number of lines)
- Multiple read and fill ports
- Pluggable replacement policies (default: Pseudo-LRU)
- Optional eviction ports for cache line replacement

### Usage Example

```dart
// Create Cache interfaces.
final fillPort = ValidDataPortInterface(dataWidth: 32, addrWidth: 16);
final readPort = ValidDataPortInterface(dataWidth: 32, addrWidth: 16);

// Instantiate cache with 4-way associativity, 64 lines.
final cache = MultiPortedReadCache(
  clk, reset, 
  [fillPort],   // Fill ports.
  [readPort],   // Read ports.
  ways: 4,
  lines: 64,
);
```

### Replacement Policy

A set-associative cache manages line replacement using a `ReplacementPolicy`.
Currently available is a Pseudo-LRU replacement policy `PseudoLRUReplacement` but other replacement policies can be passed in using a function parameter as follows:

```dart
 ReplacementPolicy Function(
      Logic clk,
      Logic reset,
      List<AccessInterface> hits,
      List<AccessInterface> misses,
      List<AccessInterface> invalidates,
      {int ways,
      String name})
```

Here the `AccessInterface` has the following ports:

- `access`: Indicates whether the way is being accessed (like an enable).
- `way`:  which way of the cache is being hit, missed, or invalidated.

## Direct-Mapped Cache

The `DirectMappedCache` is a simplified cache implementation where each memory address maps to exactly one cache line (1-way set-associative). This eliminates the need for replacement policies and way selection logic, making it more efficient but potentially having more conflict misses.

### Direct-Mapped Cache Features

- Single way (direct mapping)
- Configurable number of lines
- Simplified logic compared to multi-way caches
- Higher potential for conflict misses
- Multiple read and fill ports supported

### Direct-Mapped Cache Usage Example

```dart
// Create interfaces for direct-mapped cache.
final fillPort = ValidDataPortInterface(dataWidth: 32, addrWidth: 8);
final readPort = ValidDataPortInterface(dataWidth: 32, addrWidth: 8);

// Instantiate direct-mapped cache with 16 lines.
final cache = DirectMappedCache(
  clk, reset,
  [fillPort],   // Fill ports.
  [readPort],   // Read ports.
  lines: 16,    // Number of cache lines.
);
```

## Cached Request/Response

The `CachedRequestResponse` module implements a cache with ready/valid request/response interfaces. It acts as a caching layer between upstream and downstream components, handling cache hits internally and forwarding misses to downstream.

### Request/Response Cache Features

- Ready/valid interfaces for requests and responses
- Configurable cache implementation via `cacheBuilder` parameter
- Internal FIFO for response queuing
- ID-based request/response matching using CAM
- Automatic cache line allocation on misses

### Request/Response Cache Usage Example

```dart
// Create request/response cache with default DirectMappedCache.
final cachedRR = CachedRequestResponse(
  clk: clk,
  reset: reset,
  upstreamRequest: upstreamReqInterface,
  upstreamResponse: upstreamRespInterface,
  downstreamRequest: downstreamReqInterface,
  downstreamResponse: downstreamRespInterface,
  idWidth: 4,
  addrWidth: 16,
  dataWidth: 32,
  cacheDepth: 64,
);

// Custom cache implementation example.
final customCachedRR = CachedRequestResponse(
  // ... interface connections ...
  cacheBuilder: (clk, reset, fills, reads) =>
    MultiPortedReadCache(clk, reset, fills, reads,
      ways: 4, lines: 16, replacement: PseudoLRUReplacement.new),
);
```

## Content Addressable Memory (CAM)

The `Cam` implements a Content Addressable Memory that allows associative lookup operations. Unlike traditional memory that is accessed by address, a CAM is accessed by content - you provide a tag and get back the data associated with that tag.

### CAM Interface

The CAM uses `TagInterface` for lookups:

- `tag`: Input tag to search for in the CAM.
- `idx`: Output index where the tag was found.
- `hit`: Output indicating whether the tag was found.
- `en`: Enable signal for the lookup operation.

Write operations use standard [DataPortInterface](https://intel.github.io/rohd-hcl/rohd_hcl/DataPortInterface-class.html) with direct address access.

### CAM Usage Example

```dart
// Create Cam interfaces.
final writePort = DataPortInterface(dataWidth: 32, addrWidth: 3);
final lookupPort = TagInterface(idWidth: 3, tagWidth: 32);

// Instantiate 8-entry CAM.
final cam = Cam(
  clk, reset,
  [writePort],    // Write ports (direct address)
  [lookupPort],   // Lookup ports (associative)
  numEntries: 8,
);

// Write data to specific address.
writePort.en.inject(1);
writePort.addr.inject(5);           // Write to entry 5.
writePort.data.inject(0x42);        // Store this tag.
await clk.waitCyles(1);

// Look up by tag.
lookupPort.en.inject(1);
lookupPort.tag.inject(0x42);  // Search for this value.
// Results: lookupPort.hit will be 1, lookupPort.idx will be 5.
```
