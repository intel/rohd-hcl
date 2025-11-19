// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// buffered_request_response_channel.dart
// Buffered request/response channel with FIFOs.
//
// 2025 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A buffered request/response channel that uses FIFOs to buffer both
/// request and response paths.
class BufferedRequestResponseChannel extends RequestResponseChannelBase {
  /// Clock signal.
  @protected
  late final Logic clk;

  /// Reset signal.
  @protected
  late final Logic reset;

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
    required Logic clk,
    required Logic reset,
    required super.upstreamRequestIntf,
    required super.upstreamResponseIntf,
    required super.downstreamRequestIntf,
    required super.downstreamResponseIntf,
    this.requestBufferDepth = 4,
    this.responseBufferDepth = 4,
    super.name = 'bufferedRequestResponseChannel',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'BufferedRequestResponseChannel'
                    '_ID${upstreamRequestIntf.data.id.width}'
                    '_ADDR${upstreamRequestIntf.data.addr.width}'
                    '_DATA${upstreamResponseIntf.data.data.width}'
                    '_REQBUF$requestBufferDepth'
                    '_RSPBUF$responseBufferDepth') {
    // Add clock and reset locally (base no longer manages them)
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    // Now that clk/reset exist, build logic.
    buildLogic();
  }
  @override
  void buildLogic() {
    // Create request FIFO between upstream and downstream request interfaces
    requestFifo = ReadyValidFifo<RequestStructure>(
      clk: clk,
      reset: reset,
      upstream: upstreamReq,
      downstream: downstreamReq,
      depth: requestBufferDepth,
      name: 'requestFifo',
    );

    // Create response FIFO between downstream and upstream response interfaces
    responseFifo = ReadyValidFifo<ResponseStructure>(
      clk: clk,
      reset: reset,
      upstream: downstreamResp,
      downstream: upstreamResponse,
      depth: responseBufferDepth,
      name: 'responseFifo',
    );
  }
}
