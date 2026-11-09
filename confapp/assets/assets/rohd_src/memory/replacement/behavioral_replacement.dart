// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_replacement.dart
// Clock-stepped software replacement policies.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';
import 'package:rohd_hcl/src/memory/replacement/behavioral_replacement_systemc.dart';
import 'package:rohd_hcl/src/memory/replacement/replacement_policy.dart';
import 'package:rohd_hcl/src/memory/state/state_transactions.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

/// Built-in replacement algorithms available in the software policy.
enum BehavioralReplacementKind {
  /// Cyclic selection, advanced by committed allocations.
  roundRobin,

  /// Binary-tree pseudo-LRU, updated by accesses and allocations.
  treePseudoLru,
}

typedef _Selection = ({LogicValue valid, LogicValue index});
typedef _Allocation = ({LogicValue valid, LogicValue index, LogicValue evict});
typedef _Evaluation = ({
  LogicValue nextState,
  LogicValue invalidAccess,
  LogicValue invalidCommit,
  List<_Allocation> allocations,
});

/// Detached state for a behavioral replacement policy.
class BehavioralReplacementImage {
  final BehavioralReplacementKind _kind;
  final int _entryCount;
  final LogicValue _state;

  const BehavioralReplacementImage._(this._kind, this._entryCount, this._state);
}

/// Software replacement policy using the same ports as [ReplacementPolicy].
///
/// Allocation results are combinational. Accesses, deferred commits, and
/// committed allocations update state at the rising edge, in that order.
/// State starts unknown and is synchronously cleared by reset, as in RTL.
class BehavioralReplacementPolicy extends ReplacementPolicy
    with SystemVerilog
    implements
        BehavioralModel,
        BehavioralModelProvider,
        StateTransactionProvider<BehavioralReplacementImage>,
        StateTransactionCapabilityProvider {
  /// Selection and state-update algorithm.
  final BehavioralReplacementKind kind;

  @override
  late final BehavioralReplacementDescription description;

  @override
  BehavioralModel get behavioralModel => this;

  @override
  StateTransactionCapabilities get stateTransactionCapabilities =>
      StateTransactionCapabilities.software;

  @override
  late final StateTransactionEndpoint<BehavioralReplacementImage>
      stateTransactions =
      SoftwareStateTransactionAdapter(snapshot: snapshot, restore: restore);

  late LogicValue _state;
  late final void Function() _refresh;

  /// Creates a software implementation of the replacement port protocol.
  BehavioralReplacementPolicy({
    required super.clk,
    required super.reset,
    required super.validMask,
    required super.eligibleMask,
    required super.accesses,
    required super.allocations,
    required super.entryCount,
    required this.kind,
    super.commits,
    super.name = 'behavioral_replacement',
  }) : super(
            definitionName: 'BehavioralReplacement_${kind.name}_E${entryCount}_'
                'H${accesses.length}_A${allocations.length}_'
                'C${commits.length}') {
    if (kind == BehavioralReplacementKind.treePseudoLru &&
        (entryCount & (entryCount - 1)) != 0) {
      throw ArgumentError.value(
          entryCount, 'entryCount', 'Tree pseudo-LRU requires a power of two.');
    }
    description = BehavioralReplacementDescription(
        replacementKind: kind,
        entryCount: entryCount,
        accessCount: localAccesses.length,
        commitCount: localCommits.length,
        allocationCount: localAllocations.length);
    final stateWidth = kind == BehavioralReplacementKind.roundRobin
        ? indexWidth
        : entryCount == 1
            ? 1
            : entryCount - 1;
    _state = LogicValue.filled(stateWidth, LogicValue.x);

    LogicValue value(Logic signal, {required bool previous}) =>
        previous ? signal.previousValue! : signal.value;

    _Evaluation evaluate({required bool previous}) {
      var pending = _state;
      var invalidHit = LogicValue.zero;
      var badCommit = LogicValue.zero;
      final valid = value(validMask, previous: previous);
      final eligible = value(eligibleMask, previous: previous);
      final limit = LogicValue.ofInt(entryCount, indexWidth + 1);
      for (final access in localAccesses) {
        final index = value(access.index, previous: previous);
        final enable = value(access.en, previous: previous);
        final inRange = index.zeroExtend(indexWidth + 1) < limit;
        invalidHit |= enable & ~inRange;
        pending = selectLogicValue(
            enable & inRange, _onAccess(pending, index), pending);
      }
      for (final commit in localCommits) {
        final index = value(commit.index, previous: previous);
        final enable = value(commit.en, previous: previous);
        final inRange = index.zeroExtend(indexWidth + 1) < limit;
        badCommit |= enable & ~inRange;
        pending = selectLogicValue(
            enable & inRange, _onAllocation(pending, index), pending);
      }
      var reserved = LogicValue.filled(entryCount, LogicValue.zero);
      final results = <_Allocation>[];
      for (final allocation in localAllocations) {
        final enable = value(allocation.en, previous: previous);
        final commit = value(allocation.commit, previous: previous);
        final available = eligible & ~reserved;
        final unused = available & ~valid;
        final candidates = selectLogicValue(unused.or(), unused, available);
        final choice = _select(pending, candidates);
        final granted = enable & choice.valid;
        final committed = granted & commit;
        badCommit |= commit & ~granted;
        var selectedValid = LogicValue.zero;
        final reservationBits = <LogicValue>[];
        for (var index = 0; index < entryCount; index++) {
          final matches = storedValueIndexMatches(choice.index, index);
          selectedValid |= valid[index] & matches;
          reservationBits.add(granted & matches);
        }
        results.add((
          valid: granted,
          index: selectLogicValue(granted, choice.index,
              LogicValue.filled(indexWidth, LogicValue.zero)),
          evict: granted & selectedValid,
        ));
        reserved |= LogicValue.of(reservationBits);
        pending = selectLogicValue(
            committed, _onAllocation(pending, choice.index), pending);
      }
      return (
        nextState: pending,
        invalidAccess: invalidHit,
        invalidCommit: badCommit,
        allocations: results,
      );
    }

    void refresh() {
      final result = evaluate(previous: false);
      invalidAccess.put(result.invalidAccess);
      invalidCommit.put(result.invalidCommit);
      for (final (index, port) in localAllocations.indexed) {
        final choice = result.allocations[index];
        port.valid.put(choice.valid);
        port.index.put(choice.index);
        port.evict.put(choice.evict);
      }
    }

    _refresh = refresh;
    for (final signal in [
      validMask,
      eligibleMask,
      for (final port in localAccesses) ...[port.en, port.index],
      for (final port in localCommits) ...[port.en, port.index],
      for (final port in localAllocations) ...[port.en, port.commit],
    ]) {
      signal.glitch.listen((_) => refresh());
    }
    clk.posedge.listen((_) {
      _state = selectLogicValue(
          reset.previousValue!,
          LogicValue.filled(stateWidth, LogicValue.zero),
          evaluate(previous: true).nextState);
      refresh();
    });
    Simulator.injectAction(refresh);
  }

  LogicValue _onAccess(LogicValue state, LogicValue index) =>
      kind == BehavioralReplacementKind.roundRobin
          ? state
          : _updateTree(state, index);

  LogicValue _onAllocation(LogicValue state, LogicValue index) {
    if (kind == BehavioralReplacementKind.treePseudoLru) {
      return _updateTree(state, index);
    }
    return selectLogicValue(
        storedValueIndexMatches(index, entryCount - 1),
        LogicValue.filled(indexWidth, LogicValue.zero),
        index + LogicValue.ofInt(1, indexWidth));
  }

  LogicValue _updateTree(LogicValue state, LogicValue index) {
    if (entryCount == 1) {
      return state;
    }
    final nodes = List<({int start, int end})?>.filled(entryCount - 1, null);
    void visit(int node, int start, int end) {
      if (end - start == 1) {
        return;
      }
      nodes[node] = (start: start, end: end);
      final middle = (start + end) ~/ 2;
      visit(node * 2 + 1, start, middle);
      visit(node * 2 + 2, middle, end);
    }

    visit(0, 0, entryCount);
    final extended = index.zeroExtend(indexWidth + 1);
    LogicValue number(int value) => LogicValue.ofInt(value, indexWidth + 1);
    return LogicValue.of([
      for (var node = 0; node < nodes.length; node++)
        selectLogicValue(
            (extended >= number(nodes[node]!.start)) &
                (extended < number(nodes[node]!.end)),
            selectLogicValue(
                extended < number((nodes[node]!.start + nodes[node]!.end) ~/ 2),
                LogicValue.one,
                LogicValue.zero),
            state[node])
    ]);
  }

  _Selection _select(LogicValue state, LogicValue candidates) {
    if (kind == BehavioralReplacementKind.treePseudoLru) {
      _Selection visit(int node, int start, int end) {
        if (end - start == 1) {
          return (
            valid: candidates[start],
            index: LogicValue.ofInt(start, indexWidth)
          );
        }
        final middle = (start + end) ~/ 2;
        final left = visit(node * 2 + 1, start, middle);
        final right = visit(node * 2 + 2, middle, end);
        final chooseRight = selectLogicValue(
            state[node], right.valid, ~left.valid & right.valid);
        return (
          valid: left.valid | right.valid,
          index: selectLogicValue(chooseRight, right.index, left.index)
        );
      }

      return visit(0, 0, entryCount);
    }
    final width = entryCount.bitLength;
    final pointer = state.zeroExtend(width);
    var found = LogicValue.zero;
    var selected = LogicValue.filled(indexWidth, LogicValue.zero);
    var selectedValue = LogicValue.filled(width, LogicValue.zero);
    for (var index = 0; index < entryCount; index++) {
      final current = LogicValue.ofInt(index, width);
      final rank = selectLogicValue(current >= pointer, current - pointer,
          LogicValue.ofInt(entryCount, width) - pointer + current);
      final choose = candidates[index] & (~found | (rank < selectedValue));
      selected = selectLogicValue(
          choose, LogicValue.ofInt(index, indexWidth), selected);
      selectedValue = selectLogicValue(choose, rank, selectedValue);
      found |= candidates[index];
    }
    return (valid: found, index: selected);
  }

  /// Captures the detached internal policy state, including X/Z bits.
  BehavioralReplacementImage snapshot() =>
      BehavioralReplacementImage._(kind, entryCount, _state);

  /// Restores an image from the same algorithm and geometry.
  void restore(BehavioralReplacementImage image) {
    if (image._kind != kind || image._entryCount != entryCount) {
      throw ArgumentError.value(image, 'image', 'Invalid replacement state.');
    }
    _state = image._state;
    _refresh();
  }

  @override
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) =>
      description.generateSystemC(className: className, options: options);

  @override
  DefinitionGenerationType get generatedDefinitionType =>
      DefinitionGenerationType.custom;

  @override
  String? definitionVerilog(String definitionType) => throw UnsupportedError(
      'Behavioral replacement policies cannot be exported as RTL.');
}
