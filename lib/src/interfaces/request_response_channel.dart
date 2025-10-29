// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_channel.dart
// Simple pass-through request/response channel.
//
// 2025 October 26
// Authors: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//          GitHub Copilot <github-copilot@github.com>

import 'package:rohd_hcl/rohd_hcl.dart';

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
    super.name = 'requestResponseChannel',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
            definitionName: definitionName ??
                'RequestResponseChannel'
                    '_ID${upstreamRequestIntf.data.id.width}'
                    '_ADDR${upstreamRequestIntf.data.addr.width}'
                    '_DATA${upstreamResponseIntf.data.data.width}');

  @override
  void buildLogic() {
    // Forward upstream request to downstream request.
    downstreamReq.data <= upstreamReq.data;
    downstreamReq.valid <= upstreamReq.valid;
    upstreamReq.ready <= downstreamReq.ready;

    // Forward downstream response to upstream response.
    upstreamResponse.data <= downstreamResp.data;
    upstreamResponse.valid <= downstreamResp.valid;
    downstreamResp.ready <= upstreamResponse.ready;
  }
}
