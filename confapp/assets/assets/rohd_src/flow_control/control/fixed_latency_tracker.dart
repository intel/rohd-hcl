// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_latency_tracker.dart
// Direct scheduling for fixed-latency operations.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';

/// Tracks admission, fixed-latency completion, and result retirement.
///
/// [accepted] pulses when `request` is asserted and [canAccept] is high.
/// Each accepted request produces one [completed] pulse after [latency]
/// cycles. The caller must retire each result exactly once and retain completed
/// results until retirement. [error] indicates a retirement without a
/// completed result.
/// {@category Flow Control}
class FixedLatencyTracker extends Module {
  /// Cycles from admission to completion.
  final int latency;

  /// Minimum cycles between admissions.
  final int initiationInterval;

  /// Maximum admitted but unretired requests.
  final int capacity;

  /// High when another request can be admitted.
  Logic get canAccept => output('can_accept');

  /// A request is admitted in this cycle.
  Logic get accepted => output('accepted');

  /// An admitted operation completes in this cycle.
  Logic get completed => output('completed');

  /// Number of admitted but unretired requests.
  Logic get outstanding => output('outstanding');

  /// A retirement was requested without a completed result.
  Logic get error => output('error');

  /// Creates direct fixed-latency scheduling logic.
  FixedLatencyTracker({
    required Logic clk,
    required Logic reset,
    required Logic request,
    required Logic retire,
    required this.latency,
    required this.initiationInterval,
    required this.capacity,
    super.name = 'fixed_latency_tracker',
  }) : super(
          definitionName: 'FixedLatencyTracker_L${latency}_'
              'I${initiationInterval}_C$capacity',
        ) {
    if (latency < 0 || initiationInterval < 1 || capacity < 1) {
      throw ArgumentError(
          'Latency must be nonnegative; initiation interval and capacity '
          'must be positive.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    request = addInput('request', request);
    retire = addInput('retire', retire);

    final countWidth = max(1, (capacity + 1).log2Ceil);
    addOutput('outstanding', width: countWidth);
    addOutput('can_accept');
    addOutput('accepted');
    addOutput('completed');
    addOutput('error');

    final completedPending =
        Logic(name: 'completed_pending', width: countWidth);
    final retireStored = retire & completedPending.or() & ~reset;
    final Logic intervalReady;
    Logic? cooldown;
    if (initiationInterval == 1) {
      intervalReady = Const(1);
    } else {
      cooldown =
          Logic(name: 'cooldown', width: max(1, initiationInterval.log2Ceil));
      intervalReady = ~cooldown.or();
    }
    canAccept <=
        ~reset &
            intervalReady &
            (outstanding.lt(Const(capacity, width: countWidth)) | retireStored);
    accepted <= request & canAccept;

    var valid = accepted;
    for (var stage = 0; stage < latency; stage++) {
      valid = flop(clk, valid, reset: reset);
    }
    completed <= valid & ~reset;
    final actualRetire = retire & (completedPending.or() | completed) & ~reset;
    error <= retire & ~(completedPending.or() | completed) & ~reset;

    Sequential(clk, reset: reset, resetValues: {
      outstanding: 0,
      completedPending: 0,
      if (cooldown != null) cooldown: 0,
    }, [
      If(accepted & ~actualRetire,
          then: [outstanding < outstanding + Const(1, width: countWidth)]),
      If(actualRetire & ~accepted,
          then: [outstanding < outstanding - Const(1, width: countWidth)]),
      If(completed & ~actualRetire, then: [
        completedPending < completedPending + Const(1, width: countWidth)
      ]),
      If(actualRetire & ~completed, then: [
        completedPending < completedPending - Const(1, width: countWidth)
      ]),
      if (cooldown != null)
        If(accepted, then: [
          cooldown < initiationInterval - 1
        ], orElse: [
          If(cooldown.or(), then: [cooldown < cooldown - 1])
        ]),
    ]);
  }
}
