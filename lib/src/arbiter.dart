// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arbiter.dart
// Implementation of arbiters.
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:collection';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An abstract description of an arbiter module.
abstract class Arbiter extends Module {
  /// Each element corresponds to an arbitration grant of the correspondingly
  /// indexed request passed at construction time.
  List<Logic> get grants => UnmodifiableListView(_grants);

  final List<Logic> _grants = [];

  final List<Logic> _requests = [];

  /// The total number of requests and grants for this [Arbiter].
  int get count => _requests.length;

  /// Constructs an arbiter where each element in [requests] is a one-bit signal
  /// requesting a corresponding bit from [grants].
  Arbiter(List<Logic> requests, {super.name = 'arbiter'}) {
    for (var i = 0; i < requests.length; i++) {
      if (requests[i].width != 1) {
        throw RohdHclException('Each request must be 1 bit,'
            ' but found ${requests[i]} at index $i.');
      }

      _requests.add(addInput('request_$i', requests[i]));
      _grants.add(addOutput('grant_$i'));
    }
  }
}

/// An [Arbiter] which always picks the lowest-indexed request.
class PriorityArbiter extends Arbiter {
  /// Constructs an arbiter where the grant is given to the lowest-indexed
  /// request.
  PriorityArbiter(super.requests, {super.name = 'priority_arbiter'}) {
    Combinational([
      CaseZ(_requests.rswizzle(), conditionalType: ConditionalType.priority, [
        for (var i = 0; i < count; i++)
          CaseItem(
            Const(
              LogicValue.filled(count, LogicValue.z).withSet(i, LogicValue.one),
            ),
            [for (var g = 0; g < count; g++) _grants[g] < (i == g ? 1 : 0)],
          )
      ], defaultItem: [
        for (var g = 0; g < count; g++) _grants[g] < 0
      ]),
    ]);
  }
}

/// Round Robin Arbiter.
class RoundRobinArbiter extends Arbiter {
  /// Mask to define pending requests to be attended
  /// the main idea is to mask the requests as they are granted to ensure all
  /// requests are granted once before resetting the mask
  /// example:
  /// [clk] [_requests] [_requestMask]   [_grantMask]   [_grants]
  ///  0    00100010   &  11111111      =   00100010  ->  00000010
  ///  1    00100010   &  11111100      =   00100000  ->  00100000
  ///  2    10000001   &  11000000      =   10000000  ->  10000000
  /// On clock 0 and 1 the grants are used to generate the
  /// requestMask, therefore grantMask changes to grant the next request
  /// Clock 3 shows when a request changes, the requestMask make sure to
  /// handle the missing requests before resetting
  List<Logic> _requestMask = [];

  /// Result of masking [_requests] with [_requestMask]
  /// Contains bits of [_requests] but as bits are granted, will turn off
  List<Logic> _grantMask = [];

  /// Round Robin arbiter handles requests by granting each requestor
  /// and keeping record of requests already granted, in order to mask it until
  /// granting the turn of each request to start again
  RoundRobinArbiter(super.requests,
      {required Logic clk, required Logic reset}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
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
        Case(_grants.rswizzle(), conditionalType: ConditionalType.unique, [
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
          for (var g = 0; g < count; g++) _requestMask[g] < 1,
        ])
      ])
    ]);
    Combinational([
      for (var g = 0; g < count; g++)
        _grantMask[g] < _requestMask[g] & _requests[g],
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
                  for (var g = 0; g < count; g++) _grants[g] < (i == g ? 1 : 0),
                ]),
        ],
        // When all bits have been granted, [_grantMask] turns all to 0s because
        // of the [_requestMask], therefore logic to define next [_grants]
        // relies on [_request] least significant bit
        defaultItem: [
          for (var g = 0; g < count; g++)
            _grants[g] <
                ~_requests.rswizzle().getRange(0, g).or() & _requests[g],
        ],
      ),
    ]);
  }
}
