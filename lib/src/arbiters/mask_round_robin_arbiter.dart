// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// mask_round_robin_arbiter.dart
// Implementation of a masked round-robin arbiter.
//
// 2023

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [RoundRobinArbiter] implemented using request and grant masks.
class MaskRoundRobinArbiter extends StatefulArbiter
    implements RoundRobinArbiter {
  /// Mask to define pending requests to be attended
  /// the main idea is to mask the requests as they are granted to ensure all
  /// requests are granted once before resetting the mask
  /// example:
  /// [clk] [_requests] [_requestMask]   [_grantMask]   [grants]
  ///  0    00100010   &  11111111      =   00100010  ->  00000010
  ///  1    00100010   &  11111100      =   00100000  ->  00100000
  ///  2    10000001   &  11000000      =   10000000  ->  10000000
  /// On clock 0 and 1 the grants are used to generate the
  /// requestMask, therefore grantMask changes to grant the next request
  /// Clock 3 shows when a request changes, the requestMask make sure to
  /// handle the missing requests before resetting
  List<Logic> _requestMask = [];

  /// Result of masking [requests] with [_requestMask]
  /// Contains bits of [requests] but as bits are granted, will turn off
  List<Logic> _grantMask = [];

  /// Round Robin arbiter handles requests by granting each requestor
  /// and keeping record of requests already granted, in order to mask it until
  /// granting the turn of each request to start again
  MaskRoundRobinArbiter(super.requests,
      {required super.clk,
      required super.reset,
      super.name = 'mask_round_robin_arbiter',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'MaskRoundRobinArbiter_W${requests.length}') {
    _requestMask = List.generate(count, (i) => Logic(name: 'requestMask$i'));
    _grantMask = List.generate(count, (i) => Logic(name: 'grantMask$i'));
    Sequential(clk, [
      If(reset, then: [
        for (var g = 0; g < count; g++) _requestMask[g] < 1,
      ], orElse: [
        // Use [_grants] to turn the bit granted to 0 along with all bits
        // to the right to avoid, in case if  [_requests] changes, granting a
        // previous request
        // Example:
        // [_grants] [requestMask]
        // 00001000   11110000
        Case(grants.rswizzle(), conditionalType: ConditionalType.unique, [
          for (var i = 0; i < count; i++)
            CaseItem(
                Const(LogicValue.filled(count, LogicValue.zero)
                    .withSet(i, LogicValue.one)),
                [
                  for (var g = 0; g < count; g++)
                    _requestMask[g] < (i < g ? 1 : 0),
                ])
          // In case [_grants] are all 0s, requestMask gets a reset
        ], defaultItem: [
          // leave request mask as-is if there was no grant
        ])
      ])
    ]);
    Combinational([
      for (var g = 0; g < count; g++)
        _grantMask[g] < _requestMask[g] & requests[g],
      // CaseZ uses [_grantMask] to set the [_grants] based on the
      // least significant bit
      CaseZ(
        _grantMask.rswizzle(), conditionalType: ConditionalType.priority,
        [
          for (var i = 0; i < count; i++)
            CaseItem(
                Const(LogicValue.filled(count, LogicValue.z)
                    .withSet(i, LogicValue.one)),
                [
                  for (var g = 0; g < count; g++) grants[g] < (i == g ? 1 : 0),
                ]),
        ],
        // When all bits have been granted, [_grantMask] turns all to 0s because
        // of the [_requestMask], therefore logic to define next [_grants]
        // relies on [_request] least significant bit
        defaultItem: [
          for (var g = 0; g < count; g++)
            grants[g] <
                (g == 0
                    ? requests[g]
                    : ~requests
                            .rswizzle()
                            .named('requestsComplement')
                            .getRange(0, g)
                            .or() &
                        requests[g]),
        ],
      ),
    ]);
  }
}
