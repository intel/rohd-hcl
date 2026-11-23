// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// grant_retainer.dart
// Protocol-neutral arbitration ownership retention.
//
// 2026 October 6
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Retains an arbitration owner independently of the selection policy.
///
/// [selection] is the retained owner while locked and the current candidate
/// otherwise. [grant] additionally requires the selected owner's request to
/// be active, so a retained owner may pause without creating a false transfer.
/// Capture and release are policy-neutral state-transition controls.
class GrantRetainer {
  /// Registered owner captured when retention begins.
  late final Logic retainedOwner;

  /// Current owner selection, retained while [locked] is high.
  late final Logic selection;

  /// Active one-hot grant, equal to [selection] masked by live requests.
  late final Logic grant;

  /// High while an owner is retained.
  late final Logic locked;

  /// Creates ownership-retention hardware in the containing module.
  GrantRetainer({
    required Logic clk,
    required Logic reset,
    required Logic candidate,
    required Logic requests,
    required Logic capture,
    required Logic release,
    String name = 'grant_retainer',
  }) {
    if (candidate.width < 1 || candidate.width != requests.width) {
      throw ArgumentError(
        'Candidate and request vectors must have the same positive width.',
      );
    }
    if (clk.width != 1 ||
        reset.width != 1 ||
        capture.width != 1 ||
        release.width != 1) {
      throw ArgumentError('Grant-retainer control signals must be one bit.');
    }

    retainedOwner =
        Logic(name: '${name}_retained_owner', width: candidate.width);
    locked = Logic(name: '${name}_locked');
    selection = Logic(name: '${name}_selection', width: candidate.width)
      ..gets(mux(locked, retainedOwner, candidate));
    grant = Logic(name: '${name}_grant', width: candidate.width)
      ..gets(selection & requests);

    Sequential(
      clk,
      reset: reset,
      resetValues: {
        locked: 0,
        retainedOwner: 0,
      },
      [
        If(locked & release, then: [
          locked < 0,
        ], orElse: [
          If(~locked & capture & candidate.or(), then: [
            locked < 1,
            retainedOwner < candidate,
          ]),
        ]),
      ],
    );
  }
}
