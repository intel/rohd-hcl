# Fully Associative Cache

The `FullyAssociativeCache` is a high-performance cache implementation where any memory location can be stored in any cache "way". This eliminates conflict misses at the cost of more complex tag comparison logic and replacement policies. In a fully associative cache, the entire address becomes the tag, and all ways must be searched on each access.

## Overview

Unlike direct-mapped or set-associative caches, a fully associative cache has no line indexing - every entry can hold any address. This provides maximum flexibility for cache placement policies but requires parallel tag comparison across all ways.

## Key Features

- **Flexible Associativity**: Configurable number of ways (must be > 1)
- **Multiple Ports**: Support for multiple concurrent read and fill operations
- **Read-with-Invalidate**: Atomic read and invalidation operations
- **Occupancy Tracking**: Optional signals for cache utilization monitoring
- **Configurable Replacement**: Pluggable replacement policies (default: Pseudo-LRU)
- **Eviction Support**: Optional eviction ports for writeback operations

## Interface

### Constructor

```dart
FullyAssociativeCache(
  Logic clk,
  Logic reset,
  List<ValidDataPortInterface> fills,
  List<ValidDataPortInterface> reads, {
  List<ValidDataPortInterface>? evictions,
  int ways = 4,
  ReplacementPolicy Function(...) replacement = PseudoLRUReplacement.new,
  bool generateOccupancy = false,
  String name = 'FullyAssociativeCache',
  // ... other Module parameters
})
```

### Key Parameters

- **`fills`**: List of fill ports for writing data to cache
- **`reads`**: List of read ports for looking up data
- **`evictions`**: Optional eviction ports for writeback data
- **`ways`**: Number of cache ways (associativity level)
- **`replacement`**: Function to create replacement policy instance
- **`generateOccupancy`**: Enable occupancy tracking outputs

### Occupancy Outputs

When `generateOccupancy` is `true`, the following outputs are available:

- **`occupancy`**: Current number of valid entries (0 to ways)
- **`full`**: High when all ways contain valid data
- **`empty`**: High when no entries are valid

## Usage Examples

### Basic Cache

```dart
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

// Create cache interfaces
final fillPort = ValidDataPortInterface(dataWidth: 32, addrWidth: 16);
final readPort = ValidDataPortInterface(dataWidth: 32, addrWidth: 16);

// Create 8-way fully associative cache
final cache = FullyAssociativeCache(
  clk,
  reset,
  [fillPort],   // Single fill port
  [readPort],   // Single read port
  ways: 8,      // 8-way associative
);

// Cache operations
fillPort.addr <= addressToFill;
fillPort.data <= dataToStore;
fillPort.valid <= Const(1);  // Valid fill operation
fillPort.en <= fillEnable;

readPort.addr <= addressToRead;
readPort.en <= readEnable;
// readPort.valid indicates hit/miss
// readPort.data contains retrieved data on hit
```

### Multi-Port Cache with Eviction

```dart
// Create multiple interfaces
final fillPorts = List.generate(2, (_) => 
    ValidDataPortInterface(dataWidth: 64, addrWidth: 20));
final readPorts = List.generate(4, (_) => 
    ValidDataPortInterface(dataWidth: 64, addrWidth: 20));
final evictPorts = List.generate(2, (_) => 
    ValidDataPortInterface(dataWidth: 64, addrWidth: 20));

// Multi-port cache with eviction support
final cache = FullyAssociativeCache(
  clk,
  reset,
  fillPorts,
  readPorts,
  evictions: evictPorts,
  ways: 16,
  replacement: LRUReplacement.new,  // Use LRU replacement
);
```

### Cache with Occupancy Tracking

```dart
final cache = FullyAssociativeCache(
  clk,
  reset,
  [fillPort],
  [readPort],
  ways: 32,
  generateOccupancy: true,  // Enable occupancy outputs
);

// Monitor cache utilization
final utilizationPercent = cache.occupancy! * Const(100) ~/ Const(32);
final needsGarbageCollection = cache.occupancy! > Const(28); // 87.5% full
final canAcceptNewEntry = ~cache.full!;
```

## Read-with-Invalidate Operations

The cache supports atomic read-and-invalidate operations, useful for request tracking and resource management:

### Basic Read-with-Invalidate

```dart
// Create read port with invalidate capability
final readPort = ValidDataPortInterface(dataWidth: 32, addrWidth: 8);

// Enable read-with-invalidate by adding the signal
readPort.readWithInvalidate = Logic(name: 'readWithInvalidate');

final cache = FullyAssociativeCache(
  clk, reset, [fillPort], [readPort], ways: 8
);

// Perform read-with-invalidate
readPort.addr <= targetAddress;
readPort.en <= Const(1);
readPort.readWithInvalidate <= shouldInvalidate;

// On hit:
// - readPort.valid goes high immediately
// - readPort.data contains the cached data
// - Entry is invalidated on next clock cycle
```

### Request/Response Tracking Example

```dart
class RequestTracker extends Module {
  late final FullyAssociativeCache pendingRequests;
  
  RequestTracker(Logic clk, Logic reset, 
                 ReadyValidInterface requestIntf,
                 ReadyValidInterface responseIntf) {
    
    // Create CAM for request tracking
    final addRequest = ValidDataPortInterface(dataWidth: 32, addrWidth: 8);
    final lookupRequest = ValidDataPortInterface(dataWidth: 32, addrWidth: 8)
      ..readWithInvalidate = Logic(name: 'completeRequest');

    pendingRequests = FullyAssociativeCache(
      clk, reset,
      [addRequest],      // Add new requests
      [lookupRequest],   // Look up and complete requests
      ways: 16,
      generateOccupancy: true,  // Track how many requests pending
    );

    // Add new requests to CAM
    addRequest.addr <= requestIntf.data.id;      // Use request ID as tag
    addRequest.data <= requestIntf.data.addr;    // Store request address as data
    addRequest.valid <= Const(1);               // Valid entry
    addRequest.en <= requestIntf.valid & requestIntf.ready;

    // Look up and complete requests when responses arrive
    lookupRequest.addr <= responseIntf.data.id;  // Match response ID
    lookupRequest.en <= responseIntf.valid;
    lookupRequest.readWithInvalidate <= Const(1); // Always invalidate on hit

    // Flow control
    final camNotFull = ~pendingRequests.full!;
    requestIntf.ready <= camNotFull;

    // Validate response matches pending request
    final validResponse = responseIntf.valid & lookupRequest.valid;
  }
}
```

### Conditional Invalidation

```dart
// Invalidate only under certain conditions
final shouldEvict = cacheIsFull & newRequestPriority;
readPort.readWithInvalidate <= shouldEvict;

// Multiple read ports with different invalidation logic
readPort1.readWithInvalidate <= condition1;
readPort2.readWithInvalidate <= condition2;
```

## Operation Details

### Cache Hit Flow

1. **Address Lookup**: Read request address compared against all ways in parallel
2. **Hit Detection**: Valid bit AND tag match determines hit/miss per way
3. **Way Selection**: Priority encoder selects hitting way
4. **Data Retrieval**: Data from hitting way provided on read port
5. **Policy Update**: Replacement policy updated with access information
6. **Optional Invalidation**: If `readWithInvalidate` asserted, entry marked invalid next cycle

### Cache Miss Flow

1. **Address Lookup**: No ways match the requested address
2. **Miss Signal**: Read port `valid` signal remains low
3. **No Data**: Read port `data` contents undefined
4. **No Policy Update**: Replacement policy not updated for misses

### Fill Operation Flow

1. **Hit Check**: Fill address compared against existing entries
2. **Hit Update**: If hit, existing entry data updated, policy notified
3. **Miss Allocation**: If miss, replacement policy selects victim way
4. **Eviction**: If eviction port present and victim valid, eviction data provided
5. **Entry Update**: New tag and data written to selected way, valid bit set
6. **Invalid Fill**: If `valid` is low, matching entry invalidated instead

## Performance Characteristics

### Latency

- **Cache Hit**: 1 cycle (combinational lookup + registered output)
- **Cache Miss**: 1 cycle (immediate miss detection)
- **Fill Operation**: 1 cycle (immediate write)
- **Read-with-Invalidate**: Hit detected in 1 cycle, invalidation takes effect next cycle

### Throughput

- **Multiple Ports**: Each port can operate independently each cycle
- **Concurrent Operations**: Reads and fills can proceed simultaneously
- **Resource Conflicts**: Multiple fills to same way resolved by priority

### Resource Utilization

- **Tag Storage**: One register file with ways × ports read ports
- **Data Storage**: One register file with ways entries
- **Valid Bits**: Individual flip-flops per way (for efficient updates)
- **Replacement Policy**: Depends on selected policy (Pseudo-LRU is area-efficient)

## Design Considerations

### Way Selection

Choose the number of ways based on:

- **Working Set Size**: More ways reduce conflict misses
- **Access Latency**: More ways increase tag comparison complexity
- **Area Budget**: Linear scaling with way count

### Replacement Policy

Available policies:

- **Pseudo-LRU**: Good performance, moderate area (default)
- **True LRU**: Best performance, high area cost
- **FIFO**: Simple implementation, predictable behavior
- **Random**: Minimal area, good average performance

### Port Configuration

Consider port requirements:

- **Read Ports**: Based on concurrent lookup needs
- **Fill Ports**: Based on miss handling and external update rate
- **Eviction Ports**: Required if implementing writeback cache

### Occupancy Tracking

Enable when you need:

- **Flow Control**: Prevent overflow by monitoring fullness
- **Performance Monitoring**: Track cache utilization
- **Garbage Collection**: Trigger cleanup based on occupancy

## Advanced Examples

### TLB Implementation

```dart
class TranslationLookasideBuffer extends Module {
  late final FullyAssociativeCache tlb;
  
  TranslationLookasideBuffer(Logic clk, Logic reset,
                           Logic virtualAddr, Logic physicalAddr) {
    
    final lookup = ValidDataPortInterface(dataWidth: 20, addrWidth: 20);
    final update = ValidDataPortInterface(dataWidth: 20, addrWidth: 20);
    
    // Small, fast TLB
    tlb = FullyAssociativeCache(
      clk, reset,
      [update],   // OS updates translations
      [lookup],   // MMU lookups
      ways: 64,   // 64 translation entries
      replacement: LRUReplacement.new,  // LRU for good locality
    );
    
    // Lookup virtual-to-physical translation
    lookup.addr <= virtualAddr;
    lookup.en <= Const(1);
    
    // Provide physical address if hit
    physicalAddr <= lookup.valid ? lookup.data : virtualAddr;
  }
}
```

### Cache Coherency Controller

```dart
class CoherencyController extends Module {
  late final FullyAssociativeCache directory;
  
  CoherencyController(Logic clk, Logic reset,
                     List<ReadyValidInterface> cpuRequests,
                     ReadyValidInterface memoryIntf) {
    
    final lookup = ValidDataPortInterface(dataWidth: 8, addrWidth: 32)
      ..readWithInvalidate = Logic(name: 'invalidateOnEvict');
    final update = ValidDataPortInterface(dataWidth: 8, addrWidth: 32);
    
    // Directory tracks which CPUs have cached each address
    directory = FullyAssociativeCache(
      clk, reset,
      [update],
      [lookup],
      ways: 256,  // Track 256 cached lines
      generateOccupancy: true,  // Monitor directory pressure
    );
    
    // On CPU request, check directory and manage coherency
    final requestAddr = cpuRequests[0].data.addr;
    lookup.addr <= requestAddr;
    lookup.en <= cpuRequests[0].valid;
    
    // Invalidate directory entry when line evicted
    lookup.readWithInvalidate <= evictionDetected;
  }
}
```

## Testing Guidelines

When testing `FullyAssociativeCache`:

1. **Basic Operations**: Verify hits, misses, fills, and data integrity
2. **Multi-Port**: Test concurrent operations and port priority
3. **Read-with-Invalidate**: Verify atomic read-invalidate behavior
4. **Occupancy**: Test occupancy signals and edge cases (full/empty)
5. **Replacement**: Verify correct victim selection under different policies
6. **Corner Cases**: Test simultaneous read-invalidate and fill to same address

## Related Components

- [`Cache`](cache.md): Base cache interface
- [`SetAssociativeCache`](set_associative_cache.md): Alternative cache architecture
- [`ValidDataPortInterface`](../interfaces/valid_data_port.md): Cache port interface
- [`ReplacementPolicy`](replacement_policies.md): Cache replacement strategies
- [`CachedRequestResponseChannel`](cached_request_response_channel.md): Higher-level caching component
