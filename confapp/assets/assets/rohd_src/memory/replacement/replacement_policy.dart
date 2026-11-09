// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// replacement_policy.dart
// Composable replacement-policy ports and shared allocation logic.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// An access to an existing entry.
class ReplacementAccessInterface extends Interface<DataPortGroup> {
  /// Number of entries managed by the policy.
  final int entryCount;

  /// Enables the access.
  Logic get en => port('en');

  /// Index of the accessed entry.
  Logic get index => port('index');

  /// Creates an access port.
  ReplacementAccessInterface(this.entryCount) {
    if (entryCount < 1) {
      throw ArgumentError.value(entryCount, 'entryCount', 'Must be positive.');
    }
    setPorts([
      Logic.port('en'),
      Logic.port('index', max(1, (entryCount - 1).bitLength)),
    ], [
      DataPortGroup.control
    ]);
  }

  @override
  ReplacementAccessInterface clone() => ReplacementAccessInterface(entryCount);
}

/// A previously reserved entry whose allocation now commits.
class ReplacementCommitInterface extends Interface<DataPortGroup> {
  /// Number of entries managed by the policy.
  final int entryCount;

  /// Enables the deferred commit.
  Logic get en => port('en');

  /// Index of the entry that was reserved.
  Logic get index => port('index');

  /// Creates a deferred-commit port.
  ReplacementCommitInterface(this.entryCount) {
    if (entryCount < 1) {
      throw ArgumentError.value(entryCount, 'entryCount', 'Must be positive.');
    }
    setPorts([
      Logic.port('en'),
      Logic.port('index', max(1, (entryCount - 1).bitLength)),
    ], [
      DataPortGroup.control
    ]);
  }

  @override
  ReplacementCommitInterface clone() => ReplacementCommitInterface(entryCount);
}

/// A request for an allocation and its combinational response.
class ReplacementAllocationInterface extends Interface<DataPortGroup> {
  /// Number of entries managed by the policy.
  final int entryCount;

  /// Requests an allocation.
  Logic get en => port('en');

  /// Commits the selected entry on the clock edge.
  Logic get commit => port('commit');

  /// Indicates that an eligible entry was selected.
  Logic get valid => port('valid');

  /// Selected entry; zero when no allocation is granted.
  Logic get index => port('index');

  /// Indicates that the selected entry already contains valid data.
  Logic get evict => port('evict');

  /// Creates an allocation port.
  ReplacementAllocationInterface(this.entryCount) {
    if (entryCount < 1) {
      throw ArgumentError.value(entryCount, 'entryCount', 'Must be positive.');
    }
    setPorts([Logic.port('en'), Logic.port('commit')], [DataPortGroup.control]);
    setPorts([
      Logic.port('valid'),
      Logic.port('index', max(1, (entryCount - 1).bitLength)),
      Logic.port('evict'),
    ], [
      DataPortGroup.data
    ]);
  }

  @override
  ReplacementAllocationInterface clone() =>
      ReplacementAllocationInterface(entryCount);
}

/// Result of selecting a candidate from a mask.
typedef ReplacementSelection = ({Logic valid, Logic index});

/// Common interface for independently selectable replacement policies.
///
/// Validity and eligibility are caller-owned, one bit per entry. Accesses are
/// processed in port order, followed by deferred commits and allocations in
/// port order. An earlier
/// granted allocation reserves its entry from later ports in the same cycle,
/// even if it is not committed. Invalid entries are selected before valid
/// entries. Committed allocations update state at the clock edge; allocation
/// responses are combinational.
abstract class ReplacementPolicy extends Module {
  /// Number of entries managed by the policy.
  final int entryCount;

  /// Width of an entry index, including for a single-entry policy.
  final int indexWidth;

  /// Asserted for an enabled access whose index is outside the entry range.
  Logic get invalidAccess => output('invalidAccess');

  /// Asserted for an invalid allocation or out-of-range deferred commit.
  Logic get invalidCommit => output('invalidCommit');

  /// Internally connected access ports.
  @protected
  final List<ReplacementAccessInterface> localAccesses = [];

  /// Internally connected allocation ports.
  @protected
  final List<ReplacementAllocationInterface> localAllocations = [];

  /// Internally connected deferred-commit ports.
  @protected
  final List<ReplacementCommitInterface> localCommits = [];

  /// Clock used by policy state.
  @protected
  Logic get clk => input('clk');

  /// Synchronous policy reset.
  @protected
  Logic get reset => input('reset');

  /// Validity bits owned by the caller.
  @protected
  Logic get validMask => input('validMask');

  /// Entries allowed to be allocated.
  @protected
  Logic get eligibleMask => input('eligibleMask');

  /// Connects policy ports.
  ReplacementPolicy({
    required Logic clk,
    required Logic reset,
    required Logic validMask,
    required Logic eligibleMask,
    required List<ReplacementAccessInterface> accesses,
    required List<ReplacementAllocationInterface> allocations,
    required this.entryCount,
    required super.name,
    required super.definitionName,
    List<ReplacementCommitInterface> commits = const [],
  }) : indexWidth = max(1, (entryCount - 1).bitLength) {
    if (entryCount < 1) {
      throw ArgumentError.value(entryCount, 'entryCount', 'Must be positive.');
    }
    if (validMask.width != entryCount || eligibleMask.width != entryCount) {
      throw ArgumentError(
          'Validity and eligibility must have one bit per entry.');
    }
    if (allocations.isEmpty ||
        accesses.any((port) => port.entryCount != entryCount) ||
        commits.any((port) => port.entryCount != entryCount) ||
        allocations.any((port) => port.entryCount != entryCount)) {
      throw ArgumentError('Allocation ports are required and all ports must '
          'match the policy entry count.');
    }
    addInput('clk', clk);
    addInput('reset', reset);
    addInput('validMask', validMask, width: entryCount);
    addInput('eligibleMask', eligibleMask, width: entryCount);
    addOutput('invalidAccess');
    addOutput('invalidCommit');

    for (final (index, port) in accesses.indexed) {
      localAccesses.add(port.clone()
        ..connectIO(this, port,
            inputTags: {DataPortGroup.control},
            uniquify: (signal) => 'access_${index}_$signal'));
    }
    for (final (index, port) in commits.indexed) {
      localCommits.add(port.clone()
        ..connectIO(this, port,
            inputTags: {DataPortGroup.control},
            uniquify: (signal) => 'commit_${index}_$signal'));
    }
    for (final (index, port) in allocations.indexed) {
      localAllocations.add(port.clone()
        ..connectIO(this, port,
            inputTags: {DataPortGroup.control},
            outputTags: {DataPortGroup.data},
            uniquify: (signal) => 'allocation_${index}_$signal'));
    }
  }

  /// Builds ordered access and allocation processing around a policy state.
  @protected
  void buildPolicy({
    required int stateWidth,
    required Logic Function(Logic state, Logic index) onAccess,
    required ReplacementSelection Function(Logic state, Logic candidates)
        select,
    required Logic Function(Logic state, Logic index) onAllocation,
  }) {
    final state = Logic(name: 'replacementState', width: stateWidth);
    final nextState = Logic(name: 'replacementNextState', width: stateWidth);
    state <= flop(clk, mux(reset, Const(0, width: stateWidth), nextState));
    var pending = state;
    Logic invalid = Const(0);
    for (final access in localAccesses) {
      final inRange = access.index
          .zeroExtend(indexWidth + 1)
          .lt(Const(entryCount, width: indexWidth + 1));
      invalid = invalid | (access.en & ~inRange);
      pending =
          mux(access.en & inRange, onAccess(pending, access.index), pending);
    }
    invalidAccess <= invalid;

    Logic badCommit = Const(0);
    for (final commit in localCommits) {
      final inRange = commit.index
          .zeroExtend(indexWidth + 1)
          .lt(Const(entryCount, width: indexWidth + 1));
      badCommit = badCommit | (commit.en & ~inRange);
      pending = mux(
          commit.en & inRange, onAllocation(pending, commit.index), pending);
    }
    Logic reserved = Const(0, width: entryCount);
    for (final allocation in localAllocations) {
      final available = eligibleMask & ~reserved;
      final unused = available & ~validMask;
      final candidates = mux(unused.or(), unused, available);
      final choice = select(pending, candidates);
      final granted = allocation.en & choice.valid;
      final committed = granted & allocation.commit;
      badCommit = badCommit | (allocation.commit & ~granted);
      allocation.valid <= granted;
      allocation.index <=
          mux(granted, choice.index, Const(0, width: indexWidth));
      final selectedValid = [
        for (var index = 0; index < entryCount; index++)
          validMask[index] & storedIndexMatches(choice.index, index)
      ].reduce((left, right) => left | right);
      allocation.evict <= granted & selectedValid;
      reserved = reserved |
          [
            for (var index = 0; index < entryCount; index++)
              granted & storedIndexMatches(choice.index, index)
          ].rconcat();
      pending = mux(committed, onAllocation(pending, choice.index), pending);
    }
    invalidCommit <= badCommit;
    nextState <= pending;
  }
}
