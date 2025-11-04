// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// request_response_channel.dart (unified)
// Unified request/response channel primitives: request & response structures,
// base channel, and simple pass-through channel.
//
// This file consolidates the prior separate files:
//  - request_structure.dart
//  - response_structure.dart
//  - request_response_channel_base.dart
//  - request_response_channel.dart
// and relocates them under interfaces/ for broader reuse.
//
// 2025 November 4
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

  /// Creates a [RequestStructure] with the specified widths.
  RequestStructure({required int idWidth, required int addrWidth})
      : super([
          Logic(width: idWidth, name: 'id', naming: Naming.mergeable),
          Logic(width: addrWidth, name: 'addr', naming: Naming.mergeable),
        ], name: 'requestStructure');

  RequestStructure._from(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  RequestStructure clone({String? name}) =>
      RequestStructure._from(this, name: name);
}

/// A [LogicStructure] representing a response with id, data, and nonCacheable
/// fields.
class ResponseStructure extends LogicStructure {
  /// The transaction ID field.
  Logic get id => elements[0];

  /// The data field.
  Logic get data => elements[1];

  /// The nonCacheable bit. When set, prevents response data from updating
  /// address/data caches (still forwarded upstream and CAM processed).
  Logic get nonCacheable => elements[2];

  /// Creates a [ResponseStructure] with the specified widths.
  ResponseStructure({required int idWidth, required int dataWidth})
      : super([
          Logic(width: idWidth, name: 'id', naming: Naming.mergeable),
          Logic(width: dataWidth, name: 'data', naming: Naming.mergeable),
          Logic(name: 'nonCacheable', naming: Naming.mergeable),
        ], name: 'responseStructure');

  ResponseStructure._from(LogicStructure original, {String? name})
      : super(original.elements.map((e) => e.clone()).toList(),
            name: name ?? original.name);

  @override
  ResponseStructure clone({String? name}) =>
      ResponseStructure._from(this, name: name);
}

/// Base class for request/response channel components.
abstract class RequestResponseChannelBase extends Module {
  /// Upstream request interface.
  @protected
  late final ReadyValidInterface<RequestStructure> upstreamReq;

  /// Upstream response interface.
  @protected
  late final ReadyValidInterface<ResponseStructure> upstreamResponse;

  /// Downstream request interface.
  @protected
  late final ReadyValidInterface<RequestStructure> downstreamReq;

  /// Downstream response interface.
  @protected
  late final ReadyValidInterface<ResponseStructure> downstreamResp;

  /// Constructs a [RequestResponseChannelBase] from pairs of upstream and
  /// downstream request/response interfaces.
  RequestResponseChannelBase({
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
    upstreamReq = upstreamRequestIntf.clone()
      ..pairConnectIO(this, upstreamRequestIntf, PairRole.consumer,
          uniquify: (o) => 'upstream_req_$o');
    upstreamResponse = upstreamResponseIntf.clone()
      ..pairConnectIO(this, upstreamResponseIntf, PairRole.provider,
          uniquify: (o) => 'upstream_resp_$o');
    downstreamReq = downstreamRequestIntf.clone()
      ..pairConnectIO(this, downstreamRequestIntf, PairRole.provider,
          uniquify: (o) => 'downstream_req_$o');
    downstreamResp = downstreamResponseIntf.clone()
      ..pairConnectIO(this, downstreamResponseIntf, PairRole.consumer,
          uniquify: (o) => 'downstream_resp_$o');

    // Subclasses will invoke buildLogic() after adding any required inputs
    // (e.g., clk/reset) locally.
  }

  /// Build the internal logic of the request/response channel.
  @protected
  void buildLogic();
}

/// Simple pass-through request/response channel.
class RequestResponseChannel extends RequestResponseChannelBase {
  /// Construct a [RequestResponseChannel] from pairs of upstream and downstream
  /// request/response interfaces.
  RequestResponseChannel({
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
    downstreamReq.data <= upstreamReq.data;
    downstreamReq.valid <= upstreamReq.valid;
    upstreamReq.ready <= downstreamReq.ready;

    upstreamResponse.data <= downstreamResp.data;
    upstreamResponse.valid <= downstreamResp.valid;
    downstreamResp.ready <= upstreamResponse.ready;
  }
}
