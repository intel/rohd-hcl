// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// replacement_reservations.dart
// Persistent reservations for replacement candidates.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';
import 'package:rohd_hcl/src/memory/replacement/replacement_policy.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// Caller-owned persistent reservations for one set of replacement entries.
///
/// Releases are processed in port order before reserves in port order. A
/// release and a new reservation of the same entry may occur on one edge.
/// Duplicate reservations, releases of unreserved entries, and out-of-range
/// indices are reported; they do not assign ownership to a particular client.
/// The caller must release reservations on cancellation or after commit.
class ReplacementReservations extends Module {
  /// One bit per reserved entry.
  Logic get reservedMask => output('reservedMask');

  /// An enabled reserve was invalid or targeted an already-reserved entry.
  Logic get invalidReserve => output('invalidReserve');

  /// An enabled release was invalid or targeted an unreserved entry.
  Logic get invalidRelease => output('invalidRelease');

  /// Creates a reservation bank.
  ReplacementReservations({
    required Logic clk,
    required Logic reset,
    required int entryCount,
    required List<ReplacementAccessInterface> reserves,
    required List<ReplacementAccessInterface> releases,
    super.name = 'replacement_reservations',
  }) : super(
            definitionName: 'ReplacementReservations_E${entryCount}_'
                'R${reserves.length}_L${releases.length}') {
    if (entryCount < 1 ||
        clk.width != 1 ||
        reset.width != 1 ||
        reserves.any((port) => port.entryCount != entryCount) ||
        releases.any((port) => port.entryCount != entryCount)) {
      throw ArgumentError('Invalid reservation geometry or ports.');
    }
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    List<ReplacementAccessInterface> connect(
            List<ReplacementAccessInterface> ports, String prefix) =>
        [
          for (final (index, port) in ports.indexed)
            port.clone()
              ..connectIO(this, port,
                  inputTags: {DataPortGroup.control},
                  uniquify: (signal) => '${prefix}_${index}_$signal')
        ];
    final localReleases = connect(releases, 'release');
    final localReserves = connect(reserves, 'reserve');
    final current = Logic(name: 'reservations', width: entryCount);
    var next = current;
    Logic badRelease = Const(0);
    Logic badReserve = Const(0);

    Logic selected(Logic index, Logic bits) => [
          for (var entry = 0; entry < entryCount; entry++)
            storedIndexMatches(index, entry) & bits[entry]
        ].reduce((left, right) => left | right);
    Logic inRange(Logic index) => index
        .zeroExtend(index.width + 1)
        .lt(Const(entryCount, width: index.width + 1));

    for (final port in localReleases) {
      badRelease = badRelease |
          (port.en & (~inRange(port.index) | ~selected(port.index, next)));
      next = [
        for (var entry = 0; entry < entryCount; entry++)
          mux(port.en & storedIndexMatches(port.index, entry), Const(0),
              next[entry])
      ].rconcat();
    }
    for (final port in localReserves) {
      badReserve = badReserve |
          (port.en & (~inRange(port.index) | selected(port.index, next)));
      next = [
        for (var entry = 0; entry < entryCount; entry++)
          mux(port.en & storedIndexMatches(port.index, entry), Const(1),
              next[entry])
      ].rconcat();
    }
    current <= flop(localClk, next, reset: localReset);
    addOutput('reservedMask', width: entryCount) <= current;
    addOutput('invalidReserve') <= badReserve;
    addOutput('invalidRelease') <= badRelease;
  }
}
