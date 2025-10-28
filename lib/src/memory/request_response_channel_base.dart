// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_channel_base.dart
// Base class for request/response channel components.
//
// 2025 October 26
// Author: GitHub Copilot <github-copilot@github.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

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
  late final ReadyValidInterface<RequestStructure> upstreamReq;

  /// The upstream response interface (provider role inside the module).
  @protected
  late final ReadyValidInterface<ResponseStructure> upstreamResponse;

  /// The downstream request interface (provider role inside the module).
  @protected
  late final ReadyValidInterface<RequestStructure> downstreamReq;

  /// The downstream response interface (consumer role inside the module).
  @protected
  late final ReadyValidInterface<ResponseStructure> downstreamResp;

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
    super.name = 'requestResponseChannelBase',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'RequestResponseChannelBase'
                    '_ID${upstreamRequestIntf.data.id.width}'
                    '_ADDR${upstreamRequestIntf.data.addr.width}'
                    '_DATA${upstreamResponseIntf.data.data.width}') {
    // Add clock and reset as inputs.
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);

    // Clone and connect upstream request interface (consumer role).
    upstreamReq = upstreamRequestIntf.clone()
      ..pairConnectIO(this, upstreamRequestIntf, PairRole.consumer,
          uniquify: (original) => 'upstream_req_$original');

    // Clone and connect upstream response interface (provider role).
    upstreamResponse = upstreamResponseIntf.clone()
      ..pairConnectIO(this, upstreamResponseIntf, PairRole.provider,
          uniquify: (original) => 'upstream_resp_$original');

    // Clone and connect downstream request interface (provider role).
    downstreamReq = downstreamRequestIntf.clone()
      ..pairConnectIO(this, downstreamRequestIntf, PairRole.provider,
          uniquify: (original) => 'downstream_req_$original');

    // Clone and connect downstream response interface (consumer role).
    downstreamResp = downstreamResponseIntf.clone()
      ..pairConnectIO(this, downstreamResponseIntf, PairRole.consumer,
          uniquify: (original) => 'downstream_resp_$original');

    // Call subclass-defined logic.
    buildLogic();
  }

  /// Builds the internal logic for the request/response channel.
  ///
  /// Subclasses must implement this method to define how requests and
  /// responses are processed between upstream and downstream interfaces.
  @protected
  void buildLogic();
}
