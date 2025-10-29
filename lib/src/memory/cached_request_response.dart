// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cached_request_response.dart
// A cache component that handles request/response transactions with
// ready/valid protocol.
//
// 2025 October 14
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [LogicStructure] representing a request with an ID and address.
class RequestData extends LogicStructure {
  /// The unique identifier for this request.
  final int idWidth;

  /// The address width for this request.
  final int addrWidth;

  /// Constructs a [RequestData] with the specified [idWidth] and [addrWidth].
  RequestData({required this.idWidth, required this.addrWidth, super.name})
      : super([
          Logic(name: 'id', width: idWidth),
          Logic(name: 'addr', width: addrWidth),
        ]);

  /// The request ID.
  Logic get id => elements[0];

  /// The request address.
  Logic get addr => elements[1];

  /// Creates a copy of this [RequestData] with the same configuration.
  @override
  RequestData clone({String? name}) =>
      RequestData(idWidth: idWidth, addrWidth: addrWidth, name: name);
}

/// A [LogicStructure] representing a response with an ID and data.
class ResponseData extends LogicStructure {
  /// The unique identifier width for this response.
  final int idWidth;

  /// The data width for this response.
  final int dataWidth;

  /// Constructs a [ResponseData] with the specified [idWidth] and [dataWidth].
  ResponseData({required this.idWidth, required this.dataWidth, super.name})
      : super([
          Logic(name: 'id', width: idWidth),
          Logic(name: 'data', width: dataWidth),
        ]);

  /// The response ID.
  Logic get id => elements[0];

  /// The response data.
  Logic get data => elements[1];

  /// Creates a copy of this [ResponseData] with the same configuration.
  @override
  ResponseData clone({String? name}) =>
      ResponseData(idWidth: idWidth, dataWidth: dataWidth, name: name);
}

/// A module implementing a cache with request/response ready/valid interfaces.
///
/// This cache component:
/// - Receives upstream requests with ID and address
/// - Checks if address is in cache (hit) or not (miss)
/// - On hit: queues response (ID+data) to response FIFO
/// - On miss: forwards request to downstream, stores ID in CAM
/// - Receives downstream responses, matches ID in CAM, updates cache
/// - Drains response FIFO to upstream response interface
/// - Downstream has priority over upstream for response FIFO access
///
/// The cache implementation can be customized using the [cacheBuilder]
/// parameter.
///
/// Example with different cache types:
/// ```dart
/// // Direct-mapped cache (default)
/// final cached1 = CachedRequestResponse(
///   cacheBuilder: (clk, reset, fills, reads) =>
///     DirectMappedCache(clk, reset, fills, reads, lines: 16),
///   ...
/// );
///
/// // Multi-ported cache with custom configuration
/// final cached2 = CachedRequestResponse(
///   cacheBuilder: (clk, reset, fills, reads) =>
///     SetAssociativeCache(clk, reset, fills, reads,
///       ways: 4, lines: 16, replacement: PseudoLRUReplacement.new),
///   ...
/// );
/// ```

class CachedRequestResponse extends Module {
  /// The width of request/response IDs.
  final int idWidth;

  /// The width of addresses.
  final int addrWidth;

  /// The width of data.
  final int dataWidth;

  /// The depth of the cache (number of lines).
  final int cacheDepth;

  /// The number of ways in the cache (associativity).
  /// Note: This parameter is only used with the default cache builder.
  final int cacheWays;

  /// The depth of the response FIFO.
  final int responseFifoDepth;

  /// Function to build the cache instance.
  /// Takes clock, reset, fill ports, and read ports as parameters.
  final Cache Function(
    Logic clk,
    Logic reset,
    List<ValidDataPortInterface> fills,
    List<ValidDataPortInterface> reads,
  ) cacheBuilder;

  /// Upstream request ready/valid interface.
  late final ReadyValidInterface<RequestData> upstreamRequest;

  /// Upstream response ready/valid interface.
  late final ReadyValidInterface<ResponseData> upstreamResponse;

  /// Downstream request ready/valid interface.
  late final ReadyValidInterface<RequestData> downstreamRequest;

  /// Downstream response ready/valid interface.
  late final ReadyValidInterface<ResponseData> downstreamResponse;

  /// Clock signal.
  Logic get clk => input('clk');

  /// Reset signal.
  Logic get reset => input('reset');

  /// Constructs a [CachedRequestResponse] with the specified parameters.
  ///
  /// The [cacheBuilder] parameter allows customization of the cache
  /// implementation. If not provided, defaults to a [DirectMappedCache]
  /// with the specified [cacheDepth].
  ///
  /// The [idWidth], [addrWidth], and [dataWidth] are inferred from the
  /// provided interfaces unless explicitly specified.
  CachedRequestResponse({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<RequestData> upstreamRequest,
    required ReadyValidInterface<ResponseData> upstreamResponse,
    required ReadyValidInterface<RequestData> downstreamRequest,
    required ReadyValidInterface<ResponseData> downstreamResponse,
    int? idWidth,
    int? addrWidth,
    int? dataWidth,
    this.cacheDepth = 16,
    this.cacheWays = 2,
    this.responseFifoDepth = 8,
    Cache Function(
      Logic clk,
      Logic reset,
      List<ValidDataPortInterface> fills,
      List<ValidDataPortInterface> reads,
    )? cacheBuilder,
    super.name = 'cached_request_response',
  })  : idWidth = idWidth ?? upstreamRequest.data.idWidth,
        addrWidth = addrWidth ?? upstreamRequest.data.addrWidth,
        dataWidth = dataWidth ?? upstreamResponse.data.dataWidth,
        cacheBuilder = cacheBuilder ??
            ((clk, reset, fills, reads) => DirectMappedCache(
                  clk,
                  reset,
                  fills,
                  reads,
                  lines: cacheDepth,
                )) {
    // Add clock and reset
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    // Connect upstream request (consumer role - receives requests)
    this.upstreamRequest = ReadyValidInterface<RequestData>(
      RequestData(idWidth: this.idWidth, addrWidth: this.addrWidth),
    )..pairConnectIO(this, upstreamRequest, PairRole.consumer,
        uniquify: (name) => 'upstream_req_$name');

    // Connect upstream response (provider role - sends responses)
    this.upstreamResponse = ReadyValidInterface<ResponseData>(
      ResponseData(idWidth: this.idWidth, dataWidth: this.dataWidth),
    )..pairConnectIO(this, upstreamResponse, PairRole.provider,
        uniquify: (name) => 'upstream_resp_$name');

    // Connect downstream request (provider role - sends requests)
    this.downstreamRequest = ReadyValidInterface<RequestData>(
      RequestData(idWidth: this.idWidth, addrWidth: this.addrWidth),
    )..pairConnectIO(this, downstreamRequest, PairRole.provider,
        uniquify: (name) => 'downstream_req_$name');

    // Connect downstream response (consumer role - receives responses)
    this.downstreamResponse = ReadyValidInterface<ResponseData>(
      ResponseData(idWidth: this.idWidth, dataWidth: this.dataWidth),
    )..pairConnectIO(this, downstreamResponse, PairRole.consumer,
        uniquify: (name) => 'downstream_resp_$name');

    _buildLogic();
  }

  void _buildLogic() {
    // Internal signals for cache, CAM, and FIFO

    // Create response FIFO for queuing responses to upstream
    final responseFifoWriteEnable = Logic(name: 'response_fifo_write_enable');
    final responseFifoWriteData = ResponseData(
      idWidth: idWidth,
      dataWidth: dataWidth,
      name: 'response_fifo_write_data',
    );
    final responseFifoReadEnable = Logic(name: 'response_fifo_read_enable');

    final responseFifo = Fifo<ResponseData>(
      clk,
      reset,
      writeEnable: responseFifoWriteEnable,
      writeData: responseFifoWriteData,
      readEnable: responseFifoReadEnable,
      depth: responseFifoDepth,
      generateBypass: true,
      name: 'response_fifo',
    );

    // Create CAM for tracking outstanding downstream requests
    // CAM stores request IDs and returns the entry index when found
    final camWritePort = DataPortInterface(idWidth, log2Ceil(cacheDepth));
    final camLookupPort = TagInterface(log2Ceil(cacheDepth), idWidth);

    Cam(
      clk,
      reset,
      [camWritePort],
      [camLookupPort],
      numEntries: cacheDepth,
    );

    // Create a register file to store addresses indexed by CAM entry
    final addrRfWritePort = DataPortInterface(addrWidth, log2Ceil(cacheDepth));
    final addrRfReadPort = DataPortInterface(addrWidth, log2Ceil(cacheDepth));

    RegisterFile(
      clk,
      reset,
      [addrRfWritePort],
      [addrRfReadPort],
      numEntries: cacheDepth,
      name: 'address_register_file',
    );

    // Create cache using the provided builder function
    final cacheFillPort = ValidDataPortInterface(dataWidth, addrWidth);
    final cacheReadPort = ValidDataPortInterface(dataWidth, addrWidth);

    cacheBuilder(
      clk,
      reset,
      [cacheFillPort], // fill ports
      [cacheReadPort], // read ports
    );

    // Upstream request handling
    final upstreamReqAccepted = upstreamRequest.accepted;
    final reqAddr = upstreamRequest.data.addr;
    final reqId = upstreamRequest.data.id;

    // Cache read request
    cacheReadPort.en <= upstreamRequest.valid;
    cacheReadPort.addr <= reqAddr;

    // Cache hit is indicated by the valid signal from the cache
    final cacheHit = cacheReadPort.valid;

    // Downstream request handling
    final downstreamReqFire = Logic(name: 'downstream_req_fire');
    downstreamReqFire <= ~cacheHit & upstreamRequest.valid & ~responseFifo.full;

    downstreamRequest.valid <= downstreamReqFire;
    downstreamRequest.data.id <= reqId;
    downstreamRequest.data.addr <= reqAddr;

    // CAM write when sending downstream request
    // Use a simple allocation strategy: use ID as the CAM entry index
    final camEntryIndex = reqId.zeroExtend(log2Ceil(cacheDepth));
    final downstreamReqAccepted = downstreamReqFire & downstreamRequest.ready;

    camWritePort.en <= downstreamReqAccepted;
    camWritePort.data <= reqId; // Store request ID as data in CAM
    camWritePort.addr <= camEntryIndex;

    // Also store the address in the address register file at the same index
    addrRfWritePort.en <= downstreamReqAccepted;
    addrRfWritePort.data <= reqAddr;
    addrRfWritePort.addr <= camEntryIndex;

    // Upstream ready signal
    upstreamRequest.ready <=
        (cacheHit & ~responseFifo.full) |
            (downstreamRequest.ready & ~responseFifo.full);

    // Response FIFO write logic
    final cacheHitResponse = Logic(name: 'cache_hit_response');
    final downstreamRespAccepted = downstreamResponse.accepted;

    cacheHitResponse <= cacheHit & upstreamReqAccepted;

    // Downstream response has priority
    responseFifoWriteEnable <=
        downstreamRespAccepted | (cacheHitResponse & ~downstreamRespAccepted);

    // Mux between downstream response and cache hit response
    responseFifoWriteData.id <=
        mux(downstreamRespAccepted, downstreamResponse.data.id, reqId);
    responseFifoWriteData.data <=
        mux(downstreamRespAccepted, downstreamResponse.data.data,
            cacheReadPort.data);

    // Downstream response handling
    // Lookup the request ID in the CAM to find the CAM entry index
    camLookupPort.tag <= downstreamResponse.data.id;

    // Read the stored address from the address RF using the CAM index
    addrRfReadPort.en <= downstreamResponse.valid;
    addrRfReadPort.addr <= camLookupPort.idx;

    downstreamResponse.ready <= ~responseFifo.full;

    // Update cache when downstream response arrives using fill port
    // Use the address from the address RF
    cacheFillPort.en <= downstreamRespAccepted & camLookupPort.hit;
    cacheFillPort.addr <= addrRfReadPort.data;
    cacheFillPort.data <= downstreamResponse.data.data;
    cacheFillPort.valid <= Const(1); // Mark as valid on fill

    // Upstream response from FIFO
    upstreamResponse.valid <= ~responseFifo.empty;
    upstreamResponse.data.id <= responseFifo.readData.id;
    upstreamResponse.data.data <= responseFifo.readData.data;

    responseFifoReadEnable <= upstreamResponse.accepted;
  }
}
