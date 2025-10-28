# CachedRequestResponseChannel

The `CachedRequestResponseChannel` is an advanced component that implements address-based caching with a Content Addressable Memory (CAM) for tracking pending requests. It provides high-performance request/response processing by caching frequently accessed data while maintaining correctness through sophisticated flow control.

## Overview

The `CachedRequestResponseChannel` extends the `RequestResponseChannelBase` to add caching capabilities:

- **Cache Hit**: Returns cached data immediately via response FIFO.
- **Cache Miss**: Stores request in CAM, forwards request downstream.
- **Downstream Response**: Updates cache and response FIFO with response data.

## Architecture

```text
Upstream Request → [Cache Lookup] → Cache Hit? → [Response FIFO] → Upstream Response
                       ↓ Miss
                  [CAM Storage] → [Downstream Request] → [Downstream Response] → [Cache Update]
```

### Key Components

1. **Address/Data Cache**: Configurable cache implementation for storing frequently accessed data
2. **Pending Requests CAM**: Fully associative cache for tracking outstanding requests by ID
3. **Response FIFO**: Buffer for responses back to upstream
4. **Flow Control Logic**: Sophisticated backpressure handling

### Features

- **Configurable Cache**: Uses function parameters to allow different cache implementations
- **Configurable Replacement Policy**: Customizable CAM replacement strategy
- **Occupancy Tracking**: Automatic CAM occupancy monitoring with full/empty signals
- **Concurrent Operations**: Handles simultaneous cache hits and downstream responses
- **Backpressure Handling**: Intelligent flow control prevents deadlocks

## Interface

### Constructor Parameters

```dart
CachedRequestResponseChannel({
  required Logic clk,
  required Logic reset,
  required ReadyValidInterface<RequestStructure> upstreamRequestIntf,
  required ReadyValidInterface<ResponseStructure> upstreamResponseIntf,
  required ReadyValidInterface<RequestStructure> downstreamRequestIntf,
  required ReadyValidInterface<ResponseStructure> downstreamResponseIntf,
  required Cache Function(Logic, Logic, List<ValidDataPortInterface>, List<ValidDataPortInterface>) cacheFactory,
  ReplacementPolicy Function(...) camReplacementPolicy = PseudoLRUReplacement.new,
  int responseBufferDepth = 8,
  String name = 'cached_request_response_channel',
  // ... other Module parameters
})
```

### Key Parameters

- **`cacheFactory`**: Function that creates the address/data cache instance
- **`camReplacementPolicy`**: Function that creates the CAM replacement policy
- **`responseBufferDepth`**: Depth of the response buffer FIFO

## Usage Examples

### Basic Usage

```dart
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

// Create request/response interfaces
final upstreamReq = ReadyValidInterface(RequestStructure(idWidth: 4, addrWidth: 8));
final upstreamResp = ReadyValidInterface(ResponseStructure(idWidth: 4, dataWidth: 32));
final downstreamReq = ReadyValidInterface(RequestStructure(idWidth: 4, addrWidth: 8));
final downstreamResp = ReadyValidInterface(ResponseStructure(idWidth: 4, dataWidth: 32));

// Create cache with default fully associative cache
final cachedChannel = CachedRequestResponseChannel(
  clk: clk,
  reset: reset,
  upstreamRequestIntf: upstreamReq,
  upstreamResponseIntf: upstreamResp,
  downstreamRequestIntf: downstreamReq,
  downstreamResponseIntf: downstreamResp,
  cacheFactory: (clk, reset, fills, reads) => FullyAssociativeCache(
    clk,
    reset,
    fills,
    reads,
    ways: 16, // 16-way associative cache
  ),
);
```

### Custom Cache Configuration

```dart
// Use a custom cache factory function
Cache createCustomCache(Logic clk, Logic reset, 
                       List<ValidDataPortInterface> fills,
                       List<ValidDataPortInterface> reads) {
  return FullyAssociativeCache(
    clk,
    reset,
    fills,
    reads,
    ways: 32,
    replacement: FIFOReplacement.new, // FIFO replacement policy
  );
}

final cachedChannel = CachedRequestResponseChannel(
  clk: clk,
  reset: reset,
  upstreamRequestIntf: upstreamReq,
  upstreamResponseIntf: upstreamResp,
  downstreamRequestIntf: downstreamReq,
  downstreamResponseIntf: downstreamResp,
  cacheFactory: createCustomCache,
  camReplacementPolicy: LRUReplacement.new, // LRU for CAM
  responseBufferDepth: 16, // Larger response buffer
);
```

### High-Performance Configuration

```dart
// High-performance configuration with large cache and deep buffers
final performanceChannel = CachedRequestResponseChannel(
  clk: clk,
  reset: reset,
  upstreamRequestIntf: upstreamReq,
  upstreamResponseIntf: upstreamResp,
  downstreamRequestIntf: downstreamReq,
  downstreamResponseIntf: downstreamResp,
  cacheFactory: (clk, reset, fills, reads) => FullyAssociativeCache(
    clk,
    reset,
    fills,
    reads,
    ways: 64, // Large 64-way cache
    replacement: PseudoLRUReplacement.new,
  ),
  camReplacementPolicy: PseudoLRUReplacement.new,
  responseBufferDepth: 32, // Deep response buffer
);
```

## Operation Flow

### Cache Hit Flow

1. Upstream request arrives
2. Cache lookup performs tag comparison
3. On hit: Data retrieved from cache
4. Response sent to response FIFO
5. Response forwarded to upstream

### Cache Miss Flow

1. Upstream request arrives
2. Cache lookup results in miss
3. Request ID and address stored in CAM
4. Request forwarded downstream
5. Downstream response arrives
6. CAM lookup matches response ID to original request
7. Cache updated with new data
8. Response sent to response FIFO
9. CAM entry invalidated

### Concurrent Operations

The component supports concurrent operations:

- Cache hit response while processing downstream response
- Multiple outstanding requests (limited by CAM capacity)
- Intelligent arbitration between cache and downstream responses

## Flow Control and Backpressure

### Upstream Backpressure

- Cache hits: Requires response FIFO space AND no competing downstream response
- Cache misses: Requires downstream ready AND CAM space available
- Exception: Cache miss allowed when CAM full if concurrent downstream response frees entry

### Downstream Backpressure

- Downstream responses accepted when response FIFO has space
- CAM invalidation on response processing

## Performance Characteristics

### Latency

- **Cache Hit**: 1 cycle (data immediately available)
- **Cache Miss**: End-to-end downstream latency + 1 cycle cache update

### Throughput

- **Peak**: 1 transaction per cycle (cache hits)
- **Sustained**: Limited by downstream throughput and cache hit rate

### Capacity

- **Cache**: Configurable via cache factory function
- **Outstanding Requests**: 8 entries (default CAM size)
- **Response Buffer**: 8 entries (configurable)

## Design Considerations

### Cache Sizing

- Larger caches improve hit rates but increase area and potentially access time
- Consider workload access patterns when sizing

### CAM Sizing

- Must accommodate maximum expected outstanding requests
- Size based on downstream latency and request rate

### Response Buffer Sizing

- Should accommodate burst responses from downstream
- Prevents backpressure from upstream processing delays

### Replacement Policies

- **Cache**: Choose based on access patterns (LRU for temporal locality, Random for uniform access)
- **CAM**: LRU typically works well for request tracking

## Testing Considerations

When testing `CachedRequestResponseChannel`:

1. **Basic Functionality**: Test cache hits, misses, and correct data flow
2. **Concurrency**: Verify simultaneous cache hits and downstream responses
3. **Backpressure**: Test flow control under various load conditions
4. **Corner Cases**: CAM full conditions, FIFO full conditions
5. **Replacement**: Verify correct eviction behavior

## Related Components

- [`RequestResponseChannelBase`](request_response_channel.md): Base class
- [`FullyAssociativeCache`](fully_associative_cache.md): Default cache implementation
- [`ReadyValidFifo`](../interfaces/ready_valid.md): Response buffering
- [`ReplacementPolicy`](../memory/replacement_policies.md): Cache and CAM replacement strategies

## Examples Repository

See the `example/` directory for complete working examples:

- `cached_channel_basic.dart`: Basic usage example
- `cached_channel_custom.dart`: Custom cache configuration
- `cached_channel_performance.dart`: High-performance setup
