// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rotate_round_robin_arbiter.dart
// Implementation of arbiters.
//
// 2023
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [RoundRobinArbiter] implemented using rotations and a [PriorityArbiter].
class RotateRoundRobinArbiter extends StatefulArbiter
    implements RoundRobinArbiter {
  /// Creates an [Arbiter] that fairly takes turns between [requests].
  RotateRoundRobinArbiter(super.requests,
      {required super.clk,
      required super.reset,
      super.name = 'rotate_round_robin_arbiter',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'RotateRoundRobinArbiter_W${requests.length}') {
    if (count == 0) {
      // Nothing to arbitrate between, and nothing to drive: `grants` is empty
      // too.  The other arbiters accept an empty request list, so this one
      // does as well rather than failing deep inside the rotation math.
      return;
    }

    // A single request needs no rotation, but `log2Ceil(1)` is 0 and a
    // 0-bit preference cannot hold the result of the increment below.
    final preference =
        Logic(name: 'preference', width: max(1, log2Ceil(count)));

    final rotatedReqs = requests
        .rswizzle()
        .rotateRight(preference, maxAmount: count - 1)
        .elements;
    final priorityArb = PriorityArbiter(rotatedReqs);
    final unRotatedGrants = priorityArb.grants
        .rswizzle()
        .rotateLeft(preference, maxAmount: count - 1);

    Sequential(clk, reset: reset, [
      If(unRotatedGrants.or(), then: [
        preference < TreeOneHotToBinary(unRotatedGrants).binary + 1,
      ]),
    ]);

    for (var i = 0; i < count; i++) {
      grants[i] <= unRotatedGrants[i];
    }
  }
}
