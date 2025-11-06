# Request/Response Channel Components

The ROHD-HCL library provides a comprehensive set of request/response channel components for building robust communication protocols between modules. These components are located in `lib/src/memory/` and exported through the main memory package.

## Overview

Request/response channels implement a channel with upstream request and response interfaces as well as downstream request and response interfaces.

- Request interfaces are comprised of `id` and `address`.
- Response interfaces are comprised of `id` and `data` corresponding to the `address`.

These interfaces are `ReadyValidInterfaces` with `RequestStructure` and `ResponseStructure` data payloads.

## Components

Four related types are provided:

- `RequestResponseChannelBase` (abstract): common base class that wires the
  upstream and downstream `ReadyValidInterface` pairs and exposes clock and
  reset signals for subclasses to implement behavior.
- `RequestResponseChannel`: a minimal implementation that directly forwards
  request and response signals (zero latency pass-through).
- `BufferedRequestResponseChannel`: a variant that inserts FIFOs on both the
  request and response paths to decouple upstream and downstream timing.
- `CachedRequestResponseChannel`: an advanced caching implementation with address-based caching and Content Addressable Memory (CAM) for tracking pending requests.

### RequestResponseChannel

Simple pass-through implementation. Behavior:

- Forwards `data` and `valid` from `upstreamRequest` to `downstreamRequest`.
- Connects `ready` back from `downstreamRequest` to `upstreamRequest`.
- For responses, forwards `data` and `valid` from `downstreamResponse` to
  `upstreamResponse` and connects `ready` signals accordingly.

Constructor parameters: same as `RequestResponseChannelBase`.

### BufferedRequestResponseChannel

Adds FIFOs on both request and response paths.

Additional constructor parameters (named):

- `int requestBufferDepth` — FIFO depth for requests (default 4).
- `int responseBufferDepth` — FIFO depth for responses (default 4).

Behavior summary:

- Requests: writes incoming `upstreamRequest.data` into an internal
  `ReadyValidFifo<RequestStructure>` when `upstreamRequest.valid` is asserted and FIFO is
  not full. Downstream sees `requestFifo.readData` on `downstreamRequest.data`
  and `downstreamRequest.valid` is asserted while the FIFO is not empty.
- Responses: symmetric behavior with an internal `responseFifo` buffering
  `downstreamResponse.data` and exposing it to `upstreamResponse`.

Protected members:

- `requestFifo` — instance of `ReadyValidFifo<RequestStructure>` used for request
  buffering.
- `responseFifo` — instance of `ReadyValidFifo<ResponseStructure>` used for response
  buffering.

### CachedRequestResponseChannel

Advanced caching implementation with address-based caching and Content Addressable Memory (CAM) for tracking pending requests.

Additional constructor parameters (named):

- `Cache Function(...) cacheFactory` — function to create the address/data cache instance.
- `ReplacementPolicy Function(...) camReplacementPolicy` — function to create the replacement policy for the CAM (default: PseudoLRU).
- `int responseBufferDepth` — FIFO depth for responses (default 8).

Behavior summary:

- **Cache Hit**: Returns cached data immediately via response FIFO.
- **Cache Miss**: Stores request in CAM, forwards request downstream.
- **Downstream Response**: Updates cache and response FIFO with response data, invalidates CAM entry.

Architecture:

- **Address/Data Cache**: Stores responses for fast hit serving (configurable via `cacheFactory`).
- **CAM (Content Addressable Memory)**: Tracks pending requests by ID using `FullyAssociativeCache`.
- **Response FIFO**: Buffers responses back to upstream.
- **Occupancy Tracking**: Prevents CAM overflow with automatic backpressure.

Protected members:

- `addressDataCache` — Cache instance for storing address/data pairs.
- `pendingRequestsCam` — FullyAssociativeCache used as CAM for request tracking.
- `responseFifo` — ReadyValidFifo for response buffering.
- `cacheReadPort`, `cacheFillPort` — Cache interface ports.
- `camReadPort`, `camFillPort` — CAM interface ports.

## Usage Examples

The following snippets show typical usage patterns. These assume you have
already created `Logic` signals for `clk` and `reset`, and `ReadyValidInterface`
instances for the upstream and downstream sides.

### 1) Simple forwarding channel

```dart
final channel = RequestResponseChannel(
  clk: clk,
  reset: reset,
  upstreamRequestIntf: upstreamReqIntf,
  upstreamResponseIntf: upstreamRspIntf,
  downstreamRequestIntf: downstreamReqIntf,
  downstreamResponseIntf: downstreamRspIntf,
);

// The channel is a pass-through: requests and responses flow with zero
// additional buffering or transformation.
```

### 2) Buffered channel with 8-deep FIFOs

```dart
final buffered = BufferedRequestResponseChannel(
  clk: clk,
  reset: reset,
  upstreamRequestIntf: upstreamReqIntf,
  upstreamResponseIntf: upstreamRspIntf,
  downstreamRequestIntf: downstreamReqIntf,
  downstreamResponseIntf: downstreamRspIntf,
  requestBufferDepth: 8,
  responseBufferDepth: 8,
);

// This decouples timing between upstream and downstream by up to 8
// transactions on both directions.
```

### 3) Cached channel with custom cache

```dart
// Cache factory function
Cache cacheFactory(Logic clk, Logic reset, 
                  List<ValidDataPortInterface> fills, 
                  List<ValidDataPortInterface> reads) {
  return FullyAssociativeCache(clk, reset, fills, reads, ways: 4);
}

final cached = CachedRequestResponseChannel(
  clk: clk,
  reset: reset,
  upstreamRequestIntf: upstreamReqIntf,
  upstreamResponseIntf: upstreamRspIntf,
  downstreamRequestIntf: downstreamReqIntf,
  downstreamResponseIntf: downstreamRspIntf,
  cacheFactory: cacheFactory,
  camReplacementPolicy: PseudoLRUReplacement.new,
  responseBufferDepth: 16,
);

// Provides caching for repeated address accesses with configurable 
// cache implementation and replacement policy.
```

## Performance Characteristics

### CachedRequestResponseChannel Again

- **Hit Latency**: 1-2 cycles (cache lookup + response FIFO)
- **Miss Latency**: Full downstream latency + cache update
- **Throughput**: Limited by cache hit rate and response FIFO depth
- **Resource Usage**: Configurable cache ways and CAM depth

### Optimization Guidelines

- **Cache Ways**: More ways increase hit rate but consume more area
- **Response Buffer**: Larger buffers improve throughput under variable latency
- **Replacement Policy**: LRU provides good hit rates, Pseudo-LRU saves area

## Implementation Details

- The base class clones the provided `ReadyValidInterface` objects and
  connects them to the module's IO using `pairConnectIO`. Original interfaces
  remain usable elsewhere.
- `BufferedRequestResponseChannel` exposes internal FIFOs as protected
  members for extension by subclasses.
- `CachedRequestResponseChannel` uses occupancy tracking to prevent CAM
  overflow and handles concurrent hit/miss scenarios.
- The generated `definitionName` encodes ID/address/data widths and buffer
  sizes for convenience; custom names may be provided.
- SystemVerilog output optimized to minimize ugly underscore signal names.

## Testing and Verification

Comprehensive test suites are provided covering:

- Basic functionality (hits, misses, forwarding)
- Backpressure scenarios (FIFO full, CAM full)
- Resource limits and recovery
- Concurrent operations and corner cases
- Performance characterization

See `test/request_response_channel_test.dart` for detailed examples.

## See Also

- Source: `lib/src/memory/` (request_response_channel*.dart)
- Cache components: `FullyAssociativeCache`, `Cache`
- Ready/valid interfaces: `ReadyValidInterface`, `ReadyValidFifo`
- Request/Response structures: `RequestStructure`, `ResponseStructure`
