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
  late final ReadyValidInterface<ResponseStructure> internalRespIntf;

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
      List<ValidDataPortInterface> reads) cacheFactory;

  /// Function to create the replacement policy for the CAM.
  final ReplacementPolicy Function(
      Logic clk,
      Logic reset,
      List<AccessInterface> hits,
      List<AccessInterface> allocs,
      List<AccessInterface> invalidates,
      {int ways,
      String name}) camReplacementPolicy;

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
    final idWidth = upstreamReq.data.id.width;
    final addrWidth = upstreamReq.data.addr.width;
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
    internalRespIntf = ReadyValidInterface(
        ResponseStructure(idWidth: idWidth, dataWidth: dataWidth));

    // Create response FIFO.
    responseFifo = ReadyValidFifo<ResponseStructure>(
        clk: clk,
        reset: reset,
        upstream: internalRespIntf,
        downstream: upstreamResponse,
        depth: responseBufferDepth,
        name: 'responseFifo');

    // Build the main cache logic.
    _buildCacheLogic();
  }

  /// Builds the main cache logic for handling requests and responses.
  void _buildCacheLogic() {
    final cacheHit = Logic(name: 'cacheHit');
    final camHit = Logic(name: 'camHit');

    cacheReadPort.en <= upstreamReq.valid;
    cacheReadPort.addr <= upstreamReq.data.addr;
    cacheHit <= cacheReadPort.valid;

    camReadPort.en <= downstreamResp.valid;
    camReadPort.addr <= downstreamResp.data.id;
    camReadPort.readWithInvalidate <= downstreamResp.valid;
    camHit <= camReadPort.valid;

    final respFromCache = upstreamReq.valid & cacheHit;
    final respFromDownstream = downstreamResp.valid & camHit;

    final camSpaceAvailable = ~pendingRequestsCam.full! | respFromDownstream;

    upstreamReq.ready <=
        (cacheHit & internalRespIntf.ready & ~respFromDownstream) |
            (~cacheHit & downstreamReq.ready & camSpaceAvailable);

    final forwardMissDownstream =
        upstreamReq.valid & ~cacheHit & downstreamReq.ready & camSpaceAvailable;

    downstreamReq.valid <= forwardMissDownstream;
    downstreamReq.data <= upstreamReq.data;

    camFillPort.en <= forwardMissDownstream;
    camFillPort.valid <= forwardMissDownstream;
    camFillPort.addr <= upstreamReq.data.id;
    camFillPort.data <= upstreamReq.data.addr;

    cacheFillPort.en <= respFromDownstream;
    cacheFillPort.valid <= respFromDownstream;
    cacheFillPort.addr <= camReadPort.data; // Address from CAM.
    cacheFillPort.data <= downstreamResp.data.data; // Response data.

    internalRespIntf.valid <=
        respFromDownstream | (respFromCache & ~respFromDownstream);

    final responseId = Logic(width: internalRespIntf.data.id.width);
    final responseData = Logic(width: internalRespIntf.data.data.width);

    Combinational([
      If.block([
        Iff(respFromDownstream, [
          responseId < downstreamResp.data.id,
          responseData < downstreamResp.data.data,
        ]),
        Else([
          responseId < upstreamReq.data.id, // Cache hit case
          responseData < cacheReadPort.data,
        ])
      ])
    ]);

    internalRespIntf.data.id <= responseId;
    internalRespIntf.data.data <= responseData;
    downstreamResp.ready <= internalRespIntf.ready;
  }
}
