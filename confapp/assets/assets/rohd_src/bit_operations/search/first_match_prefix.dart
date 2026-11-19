// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// first_match_prefix.dart
// Implementation of first match prefix.
//
// 2026 October 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/utils.dart';

/// Selects the eligible prefix through its first matching lane.
///
/// Lane zero is the lowest-priority-indexed bit and is selected first.
/// [keepMask] contains every eligible lane before the first eligible matching
/// lane and that matching lane itself. [selectedMask] contains only the first
/// eligible matching lane. When no lane matches, [keepMask] contains every
/// eligible lane.
/// {@category Bit Operations}
class FirstMatchPrefix extends Module {
  /// Eligible lanes preserved through the selected prefix.
  Logic get keepMask => output('keepMask');

  /// One-hot first eligible matching lane.
  Logic get selectedMask => output('selectedMask');

  /// Number of lanes in [keepMask].
  Logic get keptCount => output('keptCount');

  /// High when an eligible lane matches.
  Logic get anyMatch => output('anyMatch');

  /// Creates an eligible first-match prefix selector.
  FirstMatchPrefix({
    required Logic eligibleMask,
    required Logic matchMask,
    super.name = 'first_match_prefix',
  }) : super(definitionName: 'FirstMatchPrefix_L${eligibleMask.width}') {
    if (eligibleMask.width < 1 || eligibleMask.width != matchMask.width) {
      throw ArgumentError(
          'eligibleMask and matchMask must have equal positive widths.');
    }
    eligibleMask =
        addInput('eligibleMask', eligibleMask, width: eligibleMask.width);
    matchMask = addInput('matchMask', matchMask, width: matchMask.width);
    final keepMask = addOutput('keepMask', width: eligibleMask.width);
    final selectedMask = addOutput('selectedMask', width: eligibleMask.width);
    final keptCount =
        addOutput('keptCount', width: widthFor((eligibleMask.width) + 1));
    final anyMatch = addOutput('anyMatch');

    Logic earlierMatch = Const(0);
    Logic keep = Const(0, width: eligibleMask.width);
    Logic selected = Const(0, width: eligibleMask.width);
    Logic count = Const(0, width: keptCount.width);
    for (var lane = 0; lane < eligibleMask.width; lane++) {
      final match = eligibleMask[lane] & matchMask[lane];
      final keepLane = eligibleMask[lane] & ~earlierMatch;
      final selectLane = match & ~earlierMatch;
      keep = keep | (keepLane.zeroExtend(eligibleMask.width) << lane);
      selected = selected | (selectLane.zeroExtend(eligibleMask.width) << lane);
      count = count + keepLane.zeroExtend(keptCount.width);
      earlierMatch = earlierMatch | match;
    }
    keepMask <= keep;
    selectedMask <= selected;
    keptCount <= count;
    anyMatch <= earlierMatch;
  }
}
