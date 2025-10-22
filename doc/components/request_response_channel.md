# Request / Response Channel

This document describes the Request/Response channel components provided in
`lib/src/request_response_channel.dart`.

These components provide a standard ready/valid style pair of interfaces for
forwarding request structures from an upstream requester to a downstream
completer, and returning response structures back to the requester.

## Overview

Three related types are provided:

- `RequestResponseChannelBase` (abstract): common base class that wires the
  upstream and downstream `ReadyValidInterface` pairs and exposes clock and
  reset signals for subclasses to implement behavior.
- `RequestResponseChannel`: a minimal implementation that directly forwards
  request and response signals (zero latency pass-through).
- `BufferedRequestResponseChannel`: a variant that inserts FIFOs on both the
  request and response paths to decouple upstream and downstream timing.

Both concrete components expect the request and response interfaces to carry
typed payloads. The repository defines `RequestStructure` and
`ResponseStructure` types used by the interfaces; the channel preserves and
forwards those data fields.

## API summary

Source: `lib/src/request_response_channel.dart`

### RequestResponseChannelBase

Constructor parameters (named):

- `Logic clk` — clock signal used by the component and any subcomponents.
- `Logic reset` — reset signal used by the component and any subcomponents.
- `ReadyValidInterface<RequestStructure> upstreamRequestIntf` — the
  upstream request interface (consumer role inside the module).
- `ReadyValidInterface<ResponseStructure> upstreamResponseIntf` — the
  upstream response interface (provider role inside the module).
- `ReadyValidInterface<RequestStructure> downstreamRequestIntf` — the
  downstream request interface (provider role inside the module).
- `ReadyValidInterface<ResponseStructure> downstreamResponseIntf` — the
  downstream response interface (consumer role inside the module).
- `String? definitionName` — optional override for the generated definition
  name (defaults to a generated name that encodes widths and buffer sizes).

Members exposed to subclasses:

- `upstreamRequest` / `upstreamResponse` / `downstreamRequest` /
  `downstreamResponse` — cloned `ReadyValidInterface` instances connected to
  the module IO (use these inside `buildLogic`).
- `clk`, `reset` — the clock and reset `Logic` signals (marked `@protected`).

Subclass contract:

- Subclasses must implement `void buildLogic()` which is called in the base
  constructor after inputs/outputs are cloned and connected. Implementations
  should use the cloned interfaces to define internal behavior.

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
  `Fifo<RequestStructure>` when `upstreamRequest.valid` is asserted and FIFO is
  not full. Downstream sees `requestFifo.readData` on `downstreamRequest.data`
  and `downstreamRequest.valid` is asserted while the FIFO is not empty.
- Responses: symmetric behavior with an internal `responseFifo` buffering
  `downstreamResponse.data` and exposing it to `upstreamResponse`.

Protected members:

- `requestFifo` — instance of `Fifo<RequestStructure>` used for request
  buffering.
- `responseFifo` — instance of `Fifo<ResponseStructure>` used for response
  buffering.

## Usage examples

The following snippets show typical usage patterns. These assume you have
already created `Logic` signals for `clk` and `reset`, and `ReadyValidInterface`
instances for the upstream and downstream sides.

1) Simple forwarding channel

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

1) Buffered channel with 8-deep FIFOs

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

## Notes and implementation details

- The base class clones the provided `ReadyValidInterface` objects and
  connects them to the module's IO using `pairConnectIO`. That means the
  original interfaces passed in remain usable elsewhere (for example, when
  wiring multiple components together) and the channel operates on its cloned
  ports.
- `BufferedRequestResponseChannel` exposes the internal FIFOs as protected
  members which can be inspected or extended by subclasses if needed.
- The generated `definitionName` encodes ID/address/data widths and buffer
  sizes for convenience; a custom `definitionName` may be provided.

## See also

- Source: `lib/src/request_response_channel.dart`
- Ready/valid interface: look for `ReadyValidInterface` and the
  `RequestStructure`/`ResponseStructure` definitions used in this package.
