// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arbiter.dart
// Implementation of arbiters.
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>
//

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
  Arbiter(List<Logic> requests) {
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
  PriorityArbiter(super.requests) {
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

/// Arbiter Roun Robin.
class RoundRobinArbiterlogic extends Arbiter {
  ///Mask to define pending requests to be attended
  ///i.e. If bit 4 is granted in a 8 bit request, [requestMask] will be 11110000
  ///turning off the bit granted along with all previous bits
  List<Logic> requestMask = [];

  ///Result of masking [_requests] with [requestMask]
  ///Contains bits of [_requests] but as bits granted, will off
  List<Logic> grantMask = [];

  /// Initiliazing Round Robin
  RoundRobinArbiterlogic(super.requests, Logic clk, Logic reset) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    requestMask = List.generate(count, (i) => Logic(name: 'requestMask$i'));
    grantMask = List.generate(count, (i) => Logic(name: 'grantMask$i'));
    Sequential(clk, [
      If(reset, then: [
        for (var g = 0; g < count; g++) requestMask[g] < 1,
        for (var g = 0; g < count; g++) _grants[g] < 0,
        for (var g = 0; g < count; g++) grantMask[g] < _requests[g],
      ], orElse: [
        /// Added [_grants] to turn off granted bit when a reset on
        ///  [requestMask] happens to avoid grant same bit again
        for (var g = 0; g < count; g++)
          grantMask[g] < requestMask[g] & _requests[g] & ~_grants[g],
        CaseZ(grantMask.rswizzle(), [
          for (var i = 0; i < count; i++)
            CaseItem(
                Const(LogicValue.filled(count, LogicValue.z)
                    .withSet(i, LogicValue.one)),
                [
                  for (var g = 0; g < count; g++) _grants[g] < (i == g ? 1 : 0),
                  for (var g = 0; g < count; g++)
                    requestMask[g] < (g <= i ? 0 : 1),
                ])
        ], defaultItem: [
          /// In case [grantMask] turns all 0, logic will determine firs bit
          /// high to grant it
          for (var g = 0; g < count; g++)
            _grants[g] <
                ~_requests.rswizzle().getRange(0, g).or() &
                    _requests.rswizzle().or() &
                    _requests[g],

          /// Proceed to restart [requestMask] as all requests have been granted
          for (var g = 0; g < count; g++) requestMask[g] < _requests[g],
        ]),
      ])
    ]);
  }
}
