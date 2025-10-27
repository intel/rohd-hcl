// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cached_request_response_channel.dart
// Cached request/response channel with address-based caching.
//
// 2025 October 26
// Author: GitHub Copilot <github-copilot@github.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A cached request/response channel that implements address-based caching
/// with Content Addressable Memory (CAM) for tracking pending requests.
///
/// On cache hit: Returns cached data immediately via response FIFO.
/// On cache miss: Stores request in CAM, forwards request downstream.
/// On downstream response: Updates cache and response FIFO with response data.
class CachedRequestResponseChannel extends RequestResponseChannelBase {
  /// Internal address/data cache for storing cached responses.
  late final Cache addressDataCache;

  /// Internal CAM (implemented as FullyAssociativeCache) for tracking pending
  /// requests. Stores ID as tag, address as data to match responses back to
  /// the correct upstream request.
  late final FullyAssociativeCache pendingRequestsCam;

  /// Internal FIFO for buffering responses before they are delivered upstream.
  late final ReadyValidFifo<ResponseStructure> responseFifo;

  /// Internal response interface for connecting downstream responses to FIFO.
  late final ReadyValidInterface<ResponseStructure> internalResponseIntf;

  /// Port interface for reading from the address/data cache.
  late final ValidDataPortInterface cacheReadPort;

  /// Port interface for filling (writing to) the address/data cache.
  late final ValidDataPortInterface cacheFillPort;

  /// Port interface for reading from the CAM (ID lookup for responses).
  late final ValidDataPortInterface camReadPort;

  /// Port interface for filling (writing to) the CAM (storing request IDs).
  late final ValidDataPortInterface camFillPort;

  /// Function to create the address/data cache instance.
  final Cache Function(
    Logic clk,
    Logic reset,
    List<ValidDataPortInterface> fills,
    List<ValidDataPortInterface> reads,
  ) cacheFactory;

  /// Function to create the replacement policy for the CAM.
  final ReplacementPolicy Function(
    Logic clk,
    Logic reset,
    List<AccessInterface> hits,
    List<AccessInterface> allocs,
    List<AccessInterface> invalidates, {
    int ways,
    String name,
  }) camReplacementPolicy;

  /// The depth of the response buffer FIFO. Should be larger than [camWays]
  /// to ensure the CAM becomes the limiting factor for backpressure control.
  final int responseBufferDepth;

  /// The number of ways (entries) in the CAM for tracking pending requests.
  /// Must be a power of 2 and at least 2. This typically becomes the system's
  /// capacity limit when [responseBufferDepth] is sufficiently large.
  final int camWays;

  /// Creates a [CachedRequestResponseChannel] with address-based caching.
  ///
  /// The [cacheFactory] function is used to create the address/data cache
  /// instance. The [camReplacementPolicy] function creates the replacement
  /// policy for the CAM. The [camWays] parameter controls the number of
  /// concurrent outstanding requests that can be tracked.
  ///
  /// The [responseBufferDepth] should typically be larger than [camWays] to
  /// ensure the CAM's full signal properly controls backpressure rather than
  /// being limited by response buffer capacity.
  CachedRequestResponseChannel({
    required super.clk,
    required super.reset,
    required super.upstreamRequestIntf,
    required super.upstreamResponseIntf,
    required super.downstreamRequestIntf,
    required super.downstreamResponseIntf,
    required this.cacheFactory,
    this.camReplacementPolicy = PseudoLRUReplacement.new,
    this.responseBufferDepth = 16,
    this.camWays = 8,
    super.name = 'cachedRequestResponseChannel',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'CachedRequestResponseChannel'
                    '_ID${upstreamRequestIntf.data.id.width}'
                    '_ADDR${upstreamRequestIntf.data.addr.width}'
                    '_DATA${upstreamResponseIntf.data.data.width}'
                    '_RSPBUF$responseBufferDepth'
                    '_CAM$camWays');

  @override
  void buildLogic() {
    final idWidth = upstreamRequest.data.id.width;
    final addrWidth = upstreamRequest.data.addr.width;
    final dataWidth = upstreamResponse.data.data.width;

    // Create cache interfaces.
    cacheReadPort = ValidDataPortInterface(dataWidth, addrWidth);
    cacheFillPort = ValidDataPortInterface(dataWidth, addrWidth);

    // Create CAM interfaces - stores ID as tag, address as data.
    // Enable readWithInvalidate for atomic read+invalidate operations.
    camReadPort =
        ValidDataPortInterface(addrWidth, idWidth, hasReadWithInvalidate: true);
    camFillPort = ValidDataPortInterface(addrWidth, idWidth);

    // Create address/data cache using the factory function.
    addressDataCache =
        cacheFactory(clk, reset, [cacheFillPort], [cacheReadPort]);

    // Create pending requests CAM - ID as tag, address as data.
    pendingRequestsCam = FullyAssociativeCache(
        clk, reset, [camFillPort], [camReadPort],
        ways: camWays,
        replacement: camReplacementPolicy,
        generateOccupancy: true,
        name: 'pendingRequestsCam');

    // Create internal response interface for FIFO input.
    internalResponseIntf = ReadyValidInterface(
        ResponseStructure(idWidth: idWidth, dataWidth: dataWidth));

    // Create response FIFO.
    responseFifo = ReadyValidFifo<ResponseStructure>(
        clk: clk,
        reset: reset,
        upstream: internalResponseIntf,
        downstream: upstreamResponse,
        depth: responseBufferDepth,
        name: 'responseFifo');

    // Build the main cache logic.
    _buildCacheLogic();
  }

  /// Builds the main cache logic for handling requests and responses.
  void _buildCacheLogic() {
    // Create internal logic signals without .named() calls to avoid
    // underscores.
    final cacheHit = Logic(name: 'cacheHit');
    final cacheMiss = Logic(name: 'cacheMiss');
    final camHit = Logic(name: 'camHit');
    final canAcceptUpstreamReq = Logic(name: 'canAcceptUpstreamReq');
    final canForwardDownstream = Logic(name: 'canForwardDownstream');
    final responseFromCache = Logic(name: 'responseFromCache');
    final responseFromDownstream = Logic(name: 'responseFromDownstream');

    // CAM occupancy signals from FullyAssociativeCache.
    final camFull = pendingRequestsCam.full!;

    // Cache lookup for incoming requests.
    cacheReadPort.en <= upstreamRequest.valid;
    cacheReadPort.addr <= upstreamRequest.data.addr;

    // CAM lookup for downstream responses with automatic invalidation.
    camReadPort.en <= downstreamResponse.valid;
    camReadPort.addr <= downstreamResponse.data.id;
    // Use readWithInvalidate to atomically read and invalidate CAM entries
    // when processing downstream responses.
    camReadPort.readWithInvalidate <= downstreamResponse.valid;

    // Hit/miss determination (combinational logic).
    cacheHit <= cacheReadPort.valid;
    cacheMiss <= ~cacheReadPort.valid;
    camHit <= camReadPort.valid;

    // Response generation conditions.
    responseFromCache <=
        (upstreamRequest.valid & cacheHit).named('responseFromCacheCondition');
    responseFromDownstream <=
        (downstreamResponse.valid & camHit)
            .named('responseFromDownstreamCondition');

    // Backpressure and flow control. Cache hits need response FIFO space AND no
    // competing downstream response. Cache misses need downstream ready AND CAM
    // space (stored in CAM for later response). Exception: Allow cache miss
    // even when CAM full if concurrent downstream response frees CAM entry.
    final camSpaceAvailable = Logic(name: 'camSpaceAvailable');
    camSpaceAvailable <=
        (~camFull |
                (downstreamResponse.valid & camHit)
                    .named('camFreeingCondition'))
            .named('camSpaceCondition');

    final canAcceptCacheHit = Logic(name: 'canAcceptCacheHit');
    canAcceptCacheHit <=
        (cacheHit & internalResponseIntf.ready & ~responseFromDownstream)
            .named('cacheHitAcceptCondition');

    final canAcceptCacheMiss = Logic(name: 'canAcceptCacheMiss');
    canAcceptCacheMiss <=
        (cacheMiss & downstreamRequest.ready & camSpaceAvailable)
            .named('cacheMissAcceptCondition');

    canAcceptUpstreamReq <=
        (canAcceptCacheHit | canAcceptCacheMiss)
            .named('upstreamAcceptCondition');
    canForwardDownstream <= downstreamRequest.ready;

    // Upstream request handling.
    upstreamRequest.ready <= canAcceptUpstreamReq;

    // Forward miss requests downstream.
    final downstreamRequestValidCondition =
        Logic(name: 'downstreamRequestValidCondition');
    downstreamRequestValidCondition <=
        (upstreamRequest.valid &
                cacheMiss &
                canForwardDownstream &
                camSpaceAvailable)
            .named('downstreamValidCondition');
    downstreamRequest.valid <= downstreamRequestValidCondition;
    downstreamRequest.data <= upstreamRequest.data;

    // CAM operations: store new entries only.
    // Invalidations are handled automatically by readWithInvalidate.
    final shouldStoreInCam = Logic(name: 'shouldStoreInCam');
    shouldStoreInCam <=
        (upstreamRequest.valid &
                cacheMiss &
                canForwardDownstream &
                camSpaceAvailable)
            .named('camStoreCondition');

    // Use fill interface only for storing new entries.
    camFillPort.en <= shouldStoreInCam;
    camFillPort.valid <= shouldStoreInCam;
    camFillPort.addr <= upstreamRequest.data.id;
    camFillPort.data <= upstreamRequest.data.addr;

    // CAM occupancy tracking is now handled automatically by
    // FullyAssociativeCache.

    // Update cache with downstream responses.
    cacheFillPort.en <= responseFromDownstream;
    cacheFillPort.valid <= responseFromDownstream;
    cacheFillPort.addr <= camReadPort.data; // Address from CAM.
    cacheFillPort.data <= downstreamResponse.data.data; // Response data.

    // Response FIFO handling - arbitrate between cache hits and downstream
    // responses. Priority: downstream responses (need to update cache) > cache
    // hits.
    final fifoWriteFromDownstream = responseFromDownstream;
    final fifoWriteFromCache = Logic(name: 'fifoWriteFromCache');
    fifoWriteFromCache <=
        (responseFromCache & ~responseFromDownstream)
            .named('fifoWriteCacheCondition');

    final internalResponseIntfValid = Logic(name: 'internalResponseIntfValid');
    internalResponseIntfValid <=
        (fifoWriteFromDownstream | fifoWriteFromCache)
            .named('internalResponseValid');
    internalResponseIntf.valid <= internalResponseIntfValid;

    final responseId =
        Logic(name: 'responseId', width: internalResponseIntf.data.id.width);
    final responseData = Logic(
        name: 'responseData', width: internalResponseIntf.data.data.width);

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

    // Downstream response ready - can accept when response FIFO has space.
    downstreamResponse.ready <= internalResponseIntf.ready;
  }
}
