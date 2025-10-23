// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_channel.dart
//  A memory component that forwards requests and responses between upstream and
// downstream.
//
// 2025 October 19
// Author: Assistant

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Abstract base class for request-response channel components.
///
/// This provides the common interface structure and connection pattern
/// for components that process requests and responses between upstream
/// and downstream interfaces using ReadyValidInterface pairs.
abstract class RequestResponseChannelBase extends Module {
  /// The upstream request interface (input from requester).
  late final ReadyValidInterface<RequestStructure> upstreamRequest;

  /// The upstream response interface (output to requester).
  late final ReadyValidInterface<ResponseStructure> upstreamResponse;

  /// The downstream request interface (output to memory/completer).
  late final ReadyValidInterface<RequestStructure> downstreamRequest;

  /// The downstream response interface (input from memory/completer).
  late final ReadyValidInterface<ResponseStructure> downstreamResponse;

  /// Clock signal for synchronous logic (available for subclasses).
  @protected
  late final Logic clk;

  /// Reset signal for synchronous logic (available for subclasses).
  @protected
  late final Logic reset;

  /// Creates a [RequestResponseChannelBase] with the given interfaces.
  ///
  /// The [clk] and [reset] signals are required for future subcomponents.
  // / Subclasses should implement [buildLogic] to define their specific
  //behavior.
  RequestResponseChannelBase({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<RequestStructure> upstreamRequestIntf,
    required ReadyValidInterface<ResponseStructure> upstreamResponseIntf,
    required ReadyValidInterface<RequestStructure> downstreamRequestIntf,
    required ReadyValidInterface<ResponseStructure> downstreamResponseIntf,
    required super.name,
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              '${name}_'
                  'ID${upstreamRequestIntf.data.id.width}_'
                  'ADDR${upstreamRequestIntf.data.address.width}_'
                  'DATA${upstreamResponseIntf.data.data.width}',
        ) {
    // Add clock and reset inputs
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);

    //  Clone and connect upstream request interface (consumer role - receives
    // requests)
    upstreamRequest = upstreamRequestIntf.clone()
      ..pairConnectIO(this, upstreamRequestIntf, PairRole.consumer,
          uniquify: (original) => 'upstream_req_$original');

    //  Clone and connect upstream response interface (provider role - sends
    // responses)
    upstreamResponse = upstreamResponseIntf.clone()
      ..pairConnectIO(this, upstreamResponseIntf, PairRole.provider,
          uniquify: (original) => 'upstream_rsp_$original');

    //  Clone and connect downstream request interface (provider role - sends
    // requests)
    downstreamRequest = downstreamRequestIntf.clone()
      ..pairConnectIO(this, downstreamRequestIntf, PairRole.provider,
          uniquify: (original) => 'downstream_req_$original');

    //  Clone and connect downstream response interface (consumer role -
    // receives responses)
    downstreamResponse = downstreamResponseIntf.clone()
      ..pairConnectIO(this, downstreamResponseIntf, PairRole.consumer,
          uniquify: (original) => 'downstream_rsp_$original');

    // Call the abstract method for subclass-specific logic
    buildLogic();
  }

  /// Abstract method for subclasses to implement their specific logic.
  ///
  /// This method is called after all interfaces are connected and should
  /// contain the logic that defines how requests and responses are processed.
  void buildLogic();
}

/// A simple forwarding implementation of [RequestResponseChannelBase].
///
/// This component forwards requests from upstream to downstream and
/// responses from downstream back to upstream without any processing.
class RequestResponseChannel extends RequestResponseChannelBase {
  /// Creates a [RequestResponseChannel] that forwards requests and responses.
  ///
  /// The [clk] and [reset] signals are required for future subcomponents.
  RequestResponseChannel({
    required super.clk,
    required super.reset,
    required super.upstreamRequestIntf,
    required super.upstreamResponseIntf,
    required super.downstreamRequestIntf,
    required super.downstreamResponseIntf,
    super.reserveName,
    super.reserveDefinitionName,
    super.definitionName,
  }) : super(
          name: 'request_response_channel',
        );

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
