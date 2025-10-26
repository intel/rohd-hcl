// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_channel.dart
// Implementation of request/response channel components.
//
// 2025 October 24
// Author: GitHub Copilot <github-copilot@github.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [LogicStructure] representing a request with id and address fields.
class RequestStructure extends LogicStructure {
  /// The transaction ID field.
  Logic get id => elements[0];

  /// The address field.
  Logic get addr => elements[1];

  /// Creates a [RequestStructure] with the specified [idWidth] and [addrWidth].
  RequestStructure({required int idWidth, required int addrWidth})
      : super([
          Logic(width: idWidth, name: 'id', naming: Naming.mergeable),
          Logic(width: addrWidth, name: 'addr', naming: Naming.mergeable),
        ], name: 'request_structure');

  /// Private constructor for cloning.
  RequestStructure._fromStructure(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  RequestStructure clone({String? name}) =>
      RequestStructure._fromStructure(this, name: name);
}

/// A [LogicStructure] representing a response with id and data fields.
class ResponseStructure extends LogicStructure {
  /// The transaction ID field.
  Logic get id => elements[0];

  /// The data field.
  Logic get data => elements[1];

  /// Creates a [ResponseStructure] with the specified [idWidth] and
  /// [dataWidth].
  ResponseStructure({required int idWidth, required int dataWidth})
      : super([
          Logic(width: idWidth, name: 'id', naming: Naming.mergeable),
          Logic(width: dataWidth, name: 'data', naming: Naming.mergeable),
        ], name: 'response_structure');

  /// Private constructor for cloning.
  ResponseStructure._fromStructure(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  ResponseStructure clone({String? name}) =>
      ResponseStructure._fromStructure(this, name: name);
}

/// A base class for request/response channel components that forwards requests
/// from upstream to downstream and responses from downstream to upstream.
abstract class RequestResponseChannelBase extends Module {
  /// Clock signal used by the component and any subcomponents.
  @protected
  late final Logic clk;

  /// Reset signal used by the component and any subcomponents.
  @protected
  late final Logic reset;

  /// The upstream request interface (consumer role inside the module).
  @protected
  late final ReadyValidInterface<RequestStructure> upstreamRequest;

  /// The upstream response interface (provider role inside the module).
  @protected
  late final ReadyValidInterface<ResponseStructure> upstreamResponse;

  /// The downstream request interface (provider role inside the module).
  @protected
  late final ReadyValidInterface<RequestStructure> downstreamRequest;

  /// The downstream response interface (consumer role inside the module).
  @protected
  late final ReadyValidInterface<ResponseStructure> downstreamResponse;

  /// Creates a [RequestResponseChannelBase] with the specified interfaces.
  ///
  /// The component will forward upstream requests to downstream and downstream
  /// responses to upstream. Subclasses must implement [buildLogic] to define
  /// the internal behavior.
  RequestResponseChannelBase({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<RequestStructure> upstreamRequestIntf,
    required ReadyValidInterface<ResponseStructure> upstreamResponseIntf,
    required ReadyValidInterface<RequestStructure> downstreamRequestIntf,
    required ReadyValidInterface<ResponseStructure> downstreamResponseIntf,
    super.name = 'request_response_channel_base',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'RequestResponseChannelBase_'
                    'ID${upstreamRequestIntf.data.id.width}_'
                    'ADDR${upstreamRequestIntf.data.addr.width}_'
                    'DATA${upstreamResponseIntf.data.data.width}') {
    // Add clock and reset as inputs
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);

    // Clone and connect upstream request interface (consumer role)
    upstreamRequest = upstreamRequestIntf.clone()
      ..pairConnectIO(this, upstreamRequestIntf, PairRole.consumer,
          uniquify: (original) => 'upstream_req_$original');

    // Clone and connect upstream response interface (provider role)
    upstreamResponse = upstreamResponseIntf.clone()
      ..pairConnectIO(this, upstreamResponseIntf, PairRole.provider,
          uniquify: (original) => 'upstream_resp_$original');

    // Clone and connect downstream request interface (provider role)
    downstreamRequest = downstreamRequestIntf.clone()
      ..pairConnectIO(this, downstreamRequestIntf, PairRole.provider,
          uniquify: (original) => 'downstream_req_$original');

    // Clone and connect downstream response interface (consumer role)
    downstreamResponse = downstreamResponseIntf.clone()
      ..pairConnectIO(this, downstreamResponseIntf, PairRole.consumer,
          uniquify: (original) => 'downstream_resp_$original');

    // Call subclass-defined logic
    buildLogic();
  }

  /// Builds the internal logic for the request/response channel.
  ///
  /// Subclasses must implement this method to define how requests and
  /// responses are processed between upstream and downstream interfaces.
  @protected
  void buildLogic();
}

/// A simple pass-through request/response channel that directly forwards
/// requests and responses without buffering or modification.
class RequestResponseChannel extends RequestResponseChannelBase {
  /// Creates a [RequestResponseChannel] that directly forwards requests
  /// and responses.
  RequestResponseChannel({
    required super.clk,
    required super.reset,
    required super.upstreamRequestIntf,
    required super.upstreamResponseIntf,
    required super.downstreamRequestIntf,
    required super.downstreamResponseIntf,
    super.name = 'request_response_channel',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'RequestResponseChannel_'
                    'ID${upstreamRequestIntf.data.id.width}_'
                    'ADDR${upstreamRequestIntf.data.addr.width}_'
                    'DATA${upstreamResponseIntf.data.data.width}');

  @override
  void buildLogic() {
    // Forward upstream request to downstream request
    downstreamRequest.data <= upstreamRequest.data;
    downstreamRequest.valid <= upstreamRequest.valid;
    upstreamRequest.ready <= downstreamRequest.ready;

    // Forward downstream response to upstream response
    upstreamResponse.data <= downstreamResponse.data;
    upstreamResponse.valid <= downstreamResponse.valid;
    downstreamResponse.ready <= upstreamResponse.ready;
  }
}

/// A buffered request/response channel that uses FIFOs to buffer both
/// request and response paths.
class BufferedRequestResponseChannel extends RequestResponseChannelBase {
  /// Internal request FIFO module.
  late final ReadyValidFifo<RequestStructure> requestFifo;

  /// Internal response FIFO module.
  late final ReadyValidFifo<ResponseStructure> responseFifo;

  /// The depth of the request buffer FIFO.
  final int requestBufferDepth;

  /// The depth of the response buffer FIFO.
  final int responseBufferDepth;

  /// Creates a [BufferedRequestResponseChannel] with FIFOs for request and
  /// response buffering.
  BufferedRequestResponseChannel({
    required super.clk,
    required super.reset,
    required super.upstreamRequestIntf,
    required super.upstreamResponseIntf,
    required super.downstreamRequestIntf,
    required super.downstreamResponseIntf,
    this.requestBufferDepth = 4,
    this.responseBufferDepth = 4,
    super.name = 'buffered_request_response_channel',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'BufferedRequestResponseChannel_'
                    'ID${upstreamRequestIntf.data.id.width}_'
                    'ADDR${upstreamRequestIntf.data.addr.width}_'
                    'DATA${upstreamResponseIntf.data.data.width}_'
                    'REQBUF${requestBufferDepth}_'
                    'RSPBUF$responseBufferDepth');

  @override
  void buildLogic() {
    // Create request FIFO between upstream and downstream request interfaces
    requestFifo = ReadyValidFifo<RequestStructure>(
      clk: clk,
      reset: reset,
      upstream: upstreamRequest,
      downstream: downstreamRequest,
      depth: requestBufferDepth,
      name: 'request_fifo',
    );

    // Create response FIFO between downstream and upstream response interfaces
    responseFifo = ReadyValidFifo<ResponseStructure>(
      clk: clk,
      reset: reset,
      upstream: downstreamResponse,
      downstream: upstreamResponse,
      depth: responseBufferDepth,
      name: 'response_fifo',
    );
  }
}

/// A cached request/response channel that implements address-based caching
/// with Content Addressable Memory (CAM) for tracking pending requests.
///
/// On cache hit: Returns cached data immediately via response FIFO
/// On cache miss: Stores request in CAM, forwards request downstream
/// On downstream response: Updates cache and response FIFO with response data
class CachedRequestResponseChannel extends RequestResponseChannelBase {
  /// Internal address/data cache for storing cached responses.
  late final FullyAssociativeCache addressDataCache;

  /// Internal CAM (implemented as FullyAssociativeCache) for tracking pending
  /// requests. Stores ID as tag, address as data to match responses back to
  /// original requests.
  late final FullyAssociativeCache pendingRequestsCam;

  /// Internal response FIFO for buffering responses back to upstream.
  late final ReadyValidFifo<ResponseStructure> responseFifo;

  /// Internal response interface for connecting to FIFO.
  late final ReadyValidInterface<ResponseStructure> internalResponseIntf;

  /// Cache interfaces for address/data cache operations.
  late final ValidDataPortInterface cacheReadPort;
  late final ValidDataPortInterface cacheFillPort;

  /// CAM interfaces for pending request tracking.
  late final ValidDataPortInterface camReadPort;
  late final ValidDataPortInterface camFillPort;

  /// The number of cache ways (associativity).
  final int cacheWays;

  /// The number of CAM ways (associativity).
  final int camWays;

  /// The depth of the response buffer FIFO.
  final int responseBufferDepth;

  /// Creates a [CachedRequestResponseChannel] with address-based caching.
  CachedRequestResponseChannel({
    required super.clk,
    required super.reset,
    required super.upstreamRequestIntf,
    required super.upstreamResponseIntf,
    required super.downstreamRequestIntf,
    required super.downstreamResponseIntf,
    this.cacheWays = 8,
    this.camWays = 8,
    this.responseBufferDepth = 8,
    super.name = 'cached_request_response_channel',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'CachedRequestResponseChannel_'
                    'ID${upstreamRequestIntf.data.id.width}_'
                    'ADDR${upstreamRequestIntf.data.addr.width}_'
                    'DATA${upstreamResponseIntf.data.data.width}_'
                    'CWAYS${cacheWays}_'
                    'CAMWAYS${camWays}_'
                    'RSPBUF$responseBufferDepth');

  @override
  void buildLogic() {
    final idWidth = upstreamRequest.data.id.width;
    final addrWidth = upstreamRequest.data.addr.width;
    final dataWidth = upstreamResponse.data.data.width;

    // Create cache interfaces
    cacheReadPort = ValidDataPortInterface(dataWidth, addrWidth);
    cacheFillPort = ValidDataPortInterface(dataWidth, addrWidth);

    // Create CAM interfaces - stores ID as tag, address as data
    camReadPort = ValidDataPortInterface(addrWidth, idWidth);
    camFillPort = ValidDataPortInterface(addrWidth, idWidth);

    // Create address/data cache - address as tag, data as data
    addressDataCache = FullyAssociativeCache(
      clk,
      reset,
      [cacheFillPort],
      [cacheReadPort],
      ways: cacheWays,
      name: 'address_data_cache',
    );

    // Create pending requests CAM - ID as tag, address as data
    pendingRequestsCam = FullyAssociativeCache(
      clk,
      reset,
      [camFillPort],
      [camReadPort],
      ways: camWays,
      name: 'pending_requests_cam',
    );

    // Create internal response interface for FIFO input
    internalResponseIntf = ReadyValidInterface(ResponseStructure(
      idWidth: idWidth,
      dataWidth: dataWidth,
    ));

    // Create response FIFO
    responseFifo = ReadyValidFifo<ResponseStructure>(
      clk: clk,
      reset: reset,
      upstream: internalResponseIntf,
      downstream: upstreamResponse,
      depth: responseBufferDepth,
      name: 'response_fifo',
    );

    // Build the main cache logic
    _buildCacheLogic();
  }

  /// Builds the main cache logic for handling requests and responses.
  void _buildCacheLogic() {
    // Create internal logic signals
    final cacheHit = Logic(name: 'cache_hit');
    final cacheMiss = Logic(name: 'cache_miss');
    final camHit = Logic(name: 'cam_hit');
    final canAcceptUpstreamReq = Logic(name: 'can_accept_upstream_req');
    final canForwardDownstream = Logic(name: 'can_forward_downstream');
    final responseFromCache = Logic(name: 'response_from_cache');
    final responseFromDownstream = Logic(name: 'response_from_downstream');

    // Simple CAM occupancy tracking for capacity management
    final camOccupancyWidth = log2Ceil(camWays + 1);
    final camOccupancy = Logic(name: 'cam_occupancy', width: camOccupancyWidth);
    final camFull = Logic(name: 'cam_full');

    // Cache lookup for incoming requests
    cacheReadPort.en <= upstreamRequest.valid;
    cacheReadPort.addr <= upstreamRequest.data.addr;

    // CAM lookup for downstream responses
    camReadPort.en <= downstreamResponse.valid;
    camReadPort.addr <= downstreamResponse.data.id;

    // Hit/miss determination (combinational logic)
    cacheHit <= cacheReadPort.valid;
    cacheMiss <= ~cacheReadPort.valid;
    camHit <= camReadPort.valid;

    // Response generation conditions
    responseFromCache <= upstreamRequest.valid & cacheHit;
    responseFromDownstream <= downstreamResponse.valid & camHit;

    // Backpressure and flow control
    // Cache hits need response FIFO space AND no competing downstream response
    // Cache misses need downstream ready AND CAM space (stored in CAM for later response)
    canAcceptUpstreamReq <=
        (cacheHit & internalResponseIntf.ready & ~responseFromDownstream) |
            (cacheMiss & downstreamRequest.ready & ~camFull);
    canForwardDownstream <= downstreamRequest.ready;

    // Upstream request handling
    upstreamRequest.ready <= canAcceptUpstreamReq;

    // Forward miss requests downstream
    downstreamRequest.valid <=
        upstreamRequest.valid & cacheMiss & canForwardDownstream & ~camFull;
    downstreamRequest.data <= upstreamRequest.data;

    // CAM operations: store new entries and invalidate completed ones
    final shouldStoreInCam =
        upstreamRequest.valid & cacheMiss & canForwardDownstream & ~camFull;
    final shouldInvalidateCam = downstreamResponse.valid & camHit;

    // Use fill interface for both storage and invalidation
    camFillPort.en <= shouldStoreInCam | shouldInvalidateCam;

    // For new entries: set valid=1, use upstream ID and address
    // For invalidations: set valid=0, use response ID and CAM address
    camFillPort.valid <= shouldStoreInCam & ~shouldInvalidateCam;
    camFillPort.addr <=
        mux(shouldInvalidateCam, downstreamResponse.data.id,
            upstreamRequest.data.id);
    camFillPort.data <=
        mux(shouldInvalidateCam, camReadPort.data, upstreamRequest.data.addr);

    // Simple CAM occupancy tracking
    final nextCamOccupancy = Logic(name: 'next_cam_occupancy', width: camOccupancyWidth);
    Combinational([
      If.block([
        // Both store and invalidate: net zero change
        Iff(shouldStoreInCam & shouldInvalidateCam, [
          nextCamOccupancy < camOccupancy,
        ]),
        // Only store: increment (with saturation)
        ElseIf(shouldStoreInCam & ~shouldInvalidateCam, [
          nextCamOccupancy < mux(
            camOccupancy.gte(Const(camWays, width: camOccupancyWidth)),
            camOccupancy,
            camOccupancy + Const(1, width: camOccupancyWidth)
          ),
        ]),
        // Only invalidate: decrement (with underflow protection)
        ElseIf(~shouldStoreInCam & shouldInvalidateCam, [
          nextCamOccupancy < mux(
            camOccupancy.eq(Const(0, width: camOccupancyWidth)),
            camOccupancy,
            camOccupancy - Const(1, width: camOccupancyWidth)
          ),
        ]),
        // Neither: no change
        Else([
          nextCamOccupancy < camOccupancy,
        ]),
      ])
    ]);

    camOccupancy <= flop(clk, nextCamOccupancy, reset: reset, resetValue: 0);
    camFull <= camOccupancy.gte(Const(camWays, width: camOccupancyWidth));

    // Update cache with downstream responses
    cacheFillPort.en <= responseFromDownstream;
    cacheFillPort.valid <= responseFromDownstream;
    cacheFillPort.addr <= camReadPort.data; // Address from CAM
    cacheFillPort.data <= downstreamResponse.data.data; // Response data

    // Response FIFO handling - arbitrate between cache hits and downstream
    // responses Priority: downstream responses (need to update cache) > cache
    // hits
    final fifoWriteFromDownstream = responseFromDownstream;
    final fifoWriteFromCache = responseFromCache & ~responseFromDownstream;

    internalResponseIntf.valid <= fifoWriteFromDownstream | fifoWriteFromCache;

    final responseId =
        Logic(name: 'response_id', width: internalResponseIntf.data.id.width);
    final responseData = Logic(
        name: 'response_data', width: internalResponseIntf.data.data.width);

    Combinational([
      If.block([
        Iff(fifoWriteFromDownstream, [
          responseId < downstreamResponse.data.id,
          responseData < downstreamResponse.data.data,
        ]),
        ElseIf(fifoWriteFromCache, [
          responseId < upstreamRequest.data.id,
          responseData < cacheReadPort.data,
        ])
      ])
    ]);

    internalResponseIntf.data.id <= responseId;
    internalResponseIntf.data.data <= responseData;

    // Downstream response ready - can accept when response FIFO has space
    downstreamResponse.ready <= internalResponseIntf.ready;
  }
}
