// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cached_request_response_channel.dart
// Cached request/response channel with address-based caching.
//
// 2025 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A cached request/response channel that implements address-based caching
/// with Content Addressable Memory (CAM) for tracking pending requests.
///
/// On cache hit: Returns cached data immediately via response FIFO.
/// On cache miss: Stores request in CAM, forwards request downstream.
/// On downstream response: Updates cache and response FIFO with response data.
/// External cache write: Writes to or invalidates cache entries, taking
/// priority over downstream responses.
class CachedRequestResponseChannel extends RequestResponseChannelBase {
  /// Clock signal.
  @protected
  late final Logic clk;

  /// Reset signal.
  @protected
  late final Logic reset;

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

  /// External cache write interface for writing to or invalidating cache
  /// entries. This interface takes priority over downstream responses.
  late final ReadyValidInterface<CacheWriteStructure> cacheWriteIntf;

  /// External cache reset signal (non-blocking). When high, the address/data
  /// cache is locally reset and all hits are suppressed. Does not affect CAM
  /// or response FIFO.
  late final Logic resetCache;

  /// Optional externally provided reset cache signal.
  final Logic? _externalResetCache;

  /// Optional external cache write interface provided via constructor.
  final ReadyValidInterface<CacheWriteStructure>? _externalCacheWriteIntf;

  /// Port interface for reading from the address/data cache.
  late final ValidDataPortInterface cacheReadPort;

  /// Port interface for filling (writing to) the address/data cache.
  late final ValidDataPortInterface cacheFillPort;

  /// Port interface for reading from the CAM (ID lookup for responses).
  late final ValidDataPortInterface camReadPort;

  /// Port interface for filling (writing to) the CAM (storing request IDs).
  late final ValidDataPortInterface camFillPort;

  /// Function to create the address/data cache instance.
  /// Now expects a list of composite fill interfaces where each entry
  /// contains the fill port and an optional eviction sub-interface.
  final Cache Function(Logic clk, Logic reset, List<FillEvictInterface> fills,
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
  ///
  /// The optional [cacheWriteIntf] provides an external interface for writing
  /// to or invalidating cache entries. When provided, this interface takes
  /// priority over downstream responses for cache updates.
  CachedRequestResponseChannel({
    required Logic clk,
    required Logic reset,
    required super.upstreamRequestIntf,
    required super.upstreamResponseIntf,
    required super.downstreamRequestIntf,
    required super.downstreamResponseIntf,
    // Local parameters
    required this.cacheFactory,
    ReadyValidInterface<CacheWriteStructure>? cacheWriteIntf,
    Logic? resetCache,
    this.camReplacementPolicy = PseudoLRUReplacement.new,
    this.responseBufferDepth = 16,
    this.camWays = 8,
    super.name = 'cachedRequestResponseChannel',
    super.reserveName = true,
    super.reserveDefinitionName = false,
    String? definitionName,
  })  : _externalCacheWriteIntf = cacheWriteIntf,
        _externalResetCache = resetCache,
        super(
            definitionName: definitionName ??
                'CachedRequestResponseChannel'
                    '_ID${upstreamRequestIntf.data.id.width}'
                    '_ADDR${upstreamRequestIntf.data.addr.width}'
                    '_DATA${upstreamResponseIntf.data.data.width}'
                    '_RSPBUF$responseBufferDepth'
                    '_CAM$camWays') {
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    buildLogic();
  }

  @override
  void buildLogic() {
    final idWidth = upstreamReq.data.id.width;
    final addrWidth = upstreamReq.data.addr.width;
    final dataWidth = upstreamResponse.data.data.width;

    // Initialize cache write interface
    if (_externalCacheWriteIntf != null) {
      cacheWriteIntf = _externalCacheWriteIntf!;
    } else {
      // Create internal interface with valid hardwired to 0 (inactive)
      cacheWriteIntf = ReadyValidInterface(
          CacheWriteStructure(addrWidth: addrWidth, dataWidth: dataWidth));
      cacheWriteIntf.valid <= Const(0);
      cacheWriteIntf.data.addr <= Const(0, width: addrWidth);
      cacheWriteIntf.data.data <= Const(0, width: dataWidth);
      cacheWriteIntf.data.invalidate <= Const(0);
    }

    // Initialize reset cache signal (optional external, else inactive low)
    resetCache = addInput('resetCache', _externalResetCache ?? Const(0));

    // Create cache interfaces.
    cacheReadPort = ValidDataPortInterface(dataWidth, addrWidth);
    cacheFillPort = ValidDataPortInterface(dataWidth, addrWidth);

    // Create CAM interfaces - stores ID as tag, address as data.
    // Enable readWithInvalidate for atomic read+invalidate operations.
    camReadPort =
        ValidDataPortInterface(addrWidth, idWidth, hasReadWithInvalidate: true);
    camFillPort = ValidDataPortInterface(addrWidth, idWidth);

    // Local reset only for the address/data cache (do not reset CAM or FIFO)
    final cacheLocalReset = reset | resetCache;

    // Create address/data cache using the factory function with local reset.
    // Wrap the single fill port into the composite FillEvictInterface.
    addressDataCache = cacheFactory(clk, cacheLocalReset,
        [FillEvictInterface(cacheFillPort)], [cacheReadPort]);

    // Create pending requests CAM - ID as tag, address as data.
    // FullyAssociativeCache now expects composite fill interfaces as well.
    pendingRequestsCam = FullyAssociativeCache(
        clk, reset, [FillEvictInterface(camFillPort)], [camReadPort],
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

    cacheReadPort.en <= Const(1);
    cacheReadPort.addr <= upstreamReq.data.addr;
    // Suppress hits while cache reset is active.
    cacheHit <= cacheReadPort.valid & upstreamReq.valid & ~resetCache;

    camReadPort.en <= downstreamResp.valid;
    camReadPort.addr <= downstreamResp.data.id;
    camReadPort.readWithInvalidate <= downstreamResp.valid;
    camHit <= camReadPort.valid;

    final respFromCache = upstreamReq.valid & cacheHit;
    final respFromDownstream = downstreamResp.valid & camHit;

    // Cache write interface takes priority over downstream responses
    final cacheWriteActive = cacheWriteIntf.valid;
    final respFromDownstreamGated = respFromDownstream & ~cacheWriteActive;

    // Check if the CAM supports simultaneous fill and RWI when full.
    // If not supported, only allow fills when CAM is not full.
    final camCanBypass = pendingRequestsCam.canBypassFillWithRWI;

    final camSpaceAvailable = camCanBypass
        ? (~pendingRequestsCam.full! | respFromDownstreamGated)
        : ~pendingRequestsCam.full!;

    upstreamReq.ready <=
        (cacheHit &
                internalRespIntf.ready &
                ~respFromDownstreamGated &
                ~cacheWriteActive) |
            (~cacheHit &
                downstreamReq.ready &
                camSpaceAvailable &
                ~cacheWriteActive);

    final forwardMissDownstream = upstreamReq.valid &
        (~cacheHit | resetCache) &
        camSpaceAvailable &
        ~cacheWriteActive;

    downstreamReq.valid <= forwardMissDownstream;
    downstreamReq.data <= upstreamReq.data;

    camFillPort.en <= forwardMissDownstream;
    camFillPort.valid <= forwardMissDownstream;
    camFillPort.addr <= upstreamReq.data.id;
    camFillPort.data <= upstreamReq.data.addr;

    // Cache fill priority: cache write > downstream response
    // Cache write interface: write data or invalidate (invalidate bit)
    // Downstream responses with nonCacheable=1 bypass cache update
    final cacheFillAddr = Logic(width: cacheFillPort.addrWidth);
    final cacheFillData = Logic(width: cacheFillPort.dataWidth);
    final cacheFillValid = Logic(name: 'cacheFillValid');

    Combinational([
      If.block([
        Iff(cacheWriteActive, [
          cacheFillPort.en < Const(1),
          cacheFillValid < ~cacheWriteIntf.data.invalidate,
          cacheFillAddr < cacheWriteIntf.data.addr,
          cacheFillData < cacheWriteIntf.data.data,
        ]),
        ElseIf(respFromDownstream, [
          cacheFillPort.en < Const(1),
          // Only mark as valid if nonCacheable bit is NOT set
          // Also suppress fills during cache reset
          cacheFillValid < (~downstreamResp.data.nonCacheable & ~resetCache),
          cacheFillAddr < camReadPort.data, // Address from CAM
          cacheFillData < downstreamResp.data.data, // Response data
        ]),
        Else([
          cacheFillPort.en < Const(0),
          cacheFillValid < Const(0),
          cacheFillAddr < Const(0, width: cacheFillPort.addrWidth),
          cacheFillData < Const(0, width: cacheFillPort.dataWidth),
        ])
      ])
    ]);

    cacheFillPort.valid <= cacheFillValid;
    cacheFillPort.addr <= cacheFillAddr;
    cacheFillPort.data <= cacheFillData;

    // Cache write interface is always ready (no backpressure on writes)
    cacheWriteIntf.ready <= Const(1);

    internalRespIntf.valid <=
        respFromDownstreamGated | (respFromCache & ~respFromDownstreamGated);

    final responseId = Logic(width: internalRespIntf.data.id.width);
    final responseData = Logic(width: internalRespIntf.data.data.width);
    final responseNonCacheable = Logic(name: 'responseNonCacheable');

    Combinational([
      If.block([
        Iff(respFromDownstreamGated, [
          responseId < downstreamResp.data.id,
          responseData < downstreamResp.data.data,
          responseNonCacheable < downstreamResp.data.nonCacheable,
        ]),
        Else([
          responseId < upstreamReq.data.id, // Cache hit case
          responseData < cacheReadPort.data,
          responseNonCacheable < Const(0), // Cache hits are always cacheable
        ])
      ])
    ]);

    internalRespIntf.data.id <= responseId;
    internalRespIntf.data.data <= responseData;
    internalRespIntf.data.nonCacheable <= responseNonCacheable;
    downstreamResp.ready <= internalRespIntf.ready & ~cacheWriteActive;

    // No handshake for resetCache (plain Logic input) so nothing to drive.
  }
}
