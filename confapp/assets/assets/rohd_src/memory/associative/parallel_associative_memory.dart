// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// parallel_associative_memory.dart
// Synthesizable parallel-flop associative memory.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/associative/associative_match_selector.dart';
import 'package:rohd_hcl/src/memory/associative/associative_matcher.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory_contract.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';

int _sideReadCount(AssociativeIndexedSideReadRequest? single,
        List<AssociativeIndexedSideReadRequest>? multiple) =>
    multiple?.length ?? (single == null ? 0 : 1);

/// Signals for one shared parallel associative-memory update path.
@internal
typedef ParallelAssociativeUpdateSignals = ({
  Logic en,
  Logic index,
  Logic key,
  Logic entryValid,
});

/// Signals for one shared parallel associative-memory lookup path.
@internal
typedef ParallelAssociativeLookupSignals = ({
  Logic en,
  Logic key,
  Logic hit,
  Logic index,
  Logic? matchVector,
});

/// Builds the shared parallel-flop storage and lookup implementation.
@internal
({
  Logic validCount,
  Logic full,
  Logic empty,
  List<Logic> storedKeys,
  List<Logic> entryValid,
}) buildParallelAssociativeMemoryLogic({
  required Logic clk,
  required Logic reset,
  required List<ParallelAssociativeUpdateSignals> updates,
  required List<ParallelAssociativeLookupSignals> lookups,
  required int entryCount,
  required int keyWidth,
  required int indexWidth,
  required AssociativeMemoryContract contract,
  required String name,
  bool unknownValidityIsInvalid = false,
}) {
  final storedKeys = [
    for (var index = 0; index < entryCount; index++)
      Logic(name: '${name}_storedKey_$index', width: keyWidth)
  ];
  final entryValid = [
    for (var index = 0; index < entryCount; index++)
      Logic(name: '${name}_entryValid_$index')
  ];
  final orderedUpdates = switch (contract.updateCollisionPolicy) {
    AssociativeUpdateCollisionPolicy.lowestPortWins =>
      updates.reversed.toList(),
    AssociativeUpdateCollisionPolicy.highestPortWins => updates,
    AssociativeUpdateCollisionPolicy.disallow =>
      throw StateError('Disallow policy was rejected during construction.'),
  };
  Sequential(clk, [
    Case(
        reset,
        [
          CaseItem(Const(1), [
            for (final key in storedKeys) key < Const(0, width: keyWidth),
            for (final valid in entryValid) valid < Const(0),
          ]),
          CaseItem(Const(0), [
            for (var index = 0; index < entryCount; index++)
              for (final update in orderedUpdates)
                Case(
                    update.en & storedIndexMatches(update.index, index),
                    [
                      CaseItem(Const(0), []),
                      CaseItem(Const(1), [
                        storedKeys[index] < normalizeStoredLogic(update.key),
                        entryValid[index] <
                            normalizeStoredLogic(update.entryValid),
                      ]),
                    ],
                    exactMatch: true,
                    defaultItem: [
                      storedKeys[index] <
                          Const(LogicValue.filled(keyWidth, LogicValue.x)),
                      entryValid[index] < Const(LogicValue.x),
                    ]),
          ]),
        ],
        exactMatch: true,
        defaultItem: [
          for (final key in storedKeys)
            key < Const(LogicValue.filled(keyWidth, LogicValue.x)),
          for (final valid in entryValid) valid < Const(LogicValue.x),
        ]),
  ]);
  final matchingValidity = unknownValidityIsInvalid
      ? [
          for (var index = 0; index < entryCount; index++)
            Logic(name: '${name}_matchingValid_$index')
        ]
      : entryValid;
  if (unknownValidityIsInvalid) {
    for (var index = 0; index < entryCount; index++) {
      Combinational([
        Case(entryValid[index], [
          CaseItem(Const(1), [matchingValidity[index] < Const(1)]),
        ], defaultItem: [
          matchingValidity[index] < Const(0),
        ]),
      ]);
    }
  }
  final validMask = matchingValidity.rconcat().named('${name}_validMask');
  final storedValidMask = entryValid.rconcat().named('${name}_storedValidMask');
  for (var lookupIndex = 0; lookupIndex < lookups.length; lookupIndex++) {
    final lookup = lookups[lookupIndex];
    final matcher = AssociativeMatcher(
      query: lookup.key,
      storedKeys: storedKeys,
      validMask: validMask,
      name: '${name}_matcher_$lookupIndex',
    );
    final selector = AssociativeMatchSelector(
      matchVector: matcher.matchVector,
      preference:
          contract.matchSelection == AssociativeMatchSelection.lowestIndex
              ? lowerAssociativeSelectionValue
              : higherAssociativeSelectionValue,
      selectionName: contract.matchSelection.name,
      name: '${name}_selector_$lookupIndex',
    );
    final enabledHit = lookup.en & matcher.hit;
    lookup.hit <= enabledHit;
    lookup.index <=
        mux(
          enabledHit,
          selector.selectedIndex.zeroExtend(indexWidth),
          Const(0, width: indexWidth),
        );
    lookup.matchVector?.gets(mux(
      lookup.en,
      matcher.matchVector,
      Const(0, width: entryCount),
    ));
  }
  final countWidth = (entryCount + 1).log2Ceil;
  return (
    validCount: entryValid
        .map((valid) => valid.zeroExtend(countWidth))
        .reduce((left, right) => left + right),
    full: storedValidMask.and(),
    empty: ~storedValidMask.or(),
    storedKeys: storedKeys,
    entryValid: entryValid,
  );
}

/// A synthesizable associative memory using parallel flop storage and matching.
///
/// Every lookup compares all valid entries in parallel. Updates commit on the
/// sampling edge and combinational lookups immediately observe the new state.
/// This architecture is intended for small, highly ported structures.
/// {@category Memory}
class ParallelAssociativeMemory extends AssociativeMemory
    implements
        AssociativeIndexedSideReadProvider,
        AssociativeMultiIndexedSideReadProvider,
        AssociativeValidityMaskProvider {
  /// Whether validity count, full, and empty outputs are generated.
  final bool enableValidTracking;

  /// Number of currently valid entries, when [enableValidTracking] is true.
  Logic? get validCount => enableValidTracking ? output('valid_count') : null;

  /// Whether every entry is valid, when [enableValidTracking] is true.
  Logic? get full => enableValidTracking ? output('full') : null;

  /// Whether no entries are valid, when [enableValidTracking] is true.
  Logic? get empty => enableValidTracking ? output('empty') : null;

  /// Stored entry validity, one bit per entry, when tracking is enabled.
  @override
  Logic? get validMask => enableValidTracking ? output('valid_mask') : null;

  @override
  AssociativeIndexedSideReadResponse? get sideReadResponse =>
      sideReadResponses.isEmpty ? null : sideReadResponses.first;

  @override
  final List<AssociativeIndexedSideReadResponse> sideReadResponses;
  final List<AssociativeIndexedSideReadRequest> _sideReadRequests;

  /// Creates a parallel-flop associative memory.
  ParallelAssociativeMemory({
    required super.clk,
    required super.reset,
    required super.updates,
    required super.lookups,
    required super.entryCount,
    required super.contract,
    this.enableValidTracking = false,
    AssociativeIndexedSideReadRequest? sideReadRequest,
    List<AssociativeIndexedSideReadRequest>? sideReadRequests,
    super.name = 'parallel_associative_memory',
  })  : _sideReadRequests = sideReadRequests ??
            (sideReadRequest == null ? [] : [sideReadRequest]),
        sideReadResponses = [
          for (var i = 0;
              i < _sideReadCount(sideReadRequest, sideReadRequests);
              i++)
            AssociativeIndexedSideReadResponse(keyWidth: lookups.first.keyWidth)
        ],
        super(
          definitionName: 'ParallelAssociativeMemory_'
              'U${updates.length}_Q${lookups.length}_E${entryCount}_'
              'K${lookups.isEmpty ? 0 : lookups.first.keyWidth}_'
              '${contract.matchSelection.name}_'
              '${contract.updateCollisionPolicy.name}_'
              '${contract.resultShape.name}_'
              'T${enableValidTracking ? 1 : 0}_'
              'S${_sideReadCount(sideReadRequest, sideReadRequests)}',
        ) {
    if (sideReadRequest != null && sideReadRequests != null) {
      throw ArgumentError('Use either sideReadRequest or sideReadRequests.');
    }
    if (contract.implementationKind !=
        AssociativeMemoryImplementationKind.synthesizable) {
      throw ArgumentError(
          'ParallelAssociativeMemory requires a synthesizable contract.');
    }
    if (lookupLatency != 0 || updateLatency != 0) {
      throw ArgumentError(
          'ParallelAssociativeMemory has zero lookup and update latency.');
    }
    if (contract.duplicateKeyPolicy != AssociativeDuplicateKeyPolicy.allow) {
      throw ArgumentError(
          'ParallelAssociativeMemory does not enforce unique keys.');
    }
    if (contract.lookupUpdatePolicy !=
        AssociativeLookupUpdatePolicy.lookupAfterUpdate) {
      throw ArgumentError(
          'ParallelAssociativeMemory provides lookup-after-update behavior.');
    }
    if (contract.updateCollisionPolicy ==
        AssociativeUpdateCollisionPolicy.disallow) {
      throw ArgumentError('ParallelAssociativeMemory requires deterministic '
          'update-port precedence.');
    }
    if (contract.resetBehavior !=
        AssociativeMemoryResetBehavior.clearValidity) {
      throw ArgumentError(
          'ParallelAssociativeMemory clears entry validity on reset.');
    }
    if (contract.resetTiming != AssociativeMemoryResetTiming.synchronous) {
      throw ArgumentError(
          'ParallelAssociativeMemory requires synchronous reset timing.');
    }
    if (_sideReadRequests.any((request) => request.index.width != indexWidth)) {
      throw ArgumentError('Indexed side-read index width must be $indexWidth.');
    }

    _buildLogic();
  }

  void _buildLogic() {
    final state = buildParallelAssociativeMemoryLogic(
      clk: clk,
      reset: reset,
      updates: [
        for (final update in localUpdates)
          (
            en: update.en,
            index: update.index,
            key: update.key,
            entryValid: update.entryValid,
          )
      ],
      lookups: [
        for (final lookup in localLookups)
          (
            en: lookup.en,
            key: lookup.key,
            hit: lookup.hit,
            index: lookup.index,
            matchVector: lookup.matchVector,
          )
      ],
      entryCount: entryCount,
      keyWidth: keyWidth,
      indexWidth: indexWidth,
      contract: contract,
      name: name,
    );
    if (enableValidTracking) {
      addOutput('valid_count', width: (entryCount + 1).log2Ceil) <=
          state.validCount;
      addOutput('full') <= state.full;
      addOutput('empty') <= state.empty;
      addOutput('valid_mask', width: entryCount) <= state.entryValid.rconcat();
    }
    for (final (port, request) in _sideReadRequests.indexed) {
      final suffix = port == 0 ? '' : '_$port';
      final index =
          addInput('side_read_index$suffix', request.index, width: indexWidth);
      final key = Logic(name: 'side_read_key_value$suffix', width: keyWidth);
      final valid = Logic(name: 'side_read_valid_value$suffix');
      Combinational([
        Case(
            index
                .zeroExtend(indexWidth + 1)
                .lt(Const(entryCount, width: indexWidth + 1)),
            [
              CaseItem(Const(0), [
                key < Const(0, width: keyWidth),
                valid < Const(0),
              ]),
              CaseItem(Const(1), [
                Case(
                    index,
                    [
                      for (var i = 0; i < entryCount; i++)
                        CaseItem(Const(i, width: indexWidth), [
                          key < state.storedKeys[i],
                          valid < state.entryValid[i],
                        ]),
                    ],
                    exactMatch: true,
                    defaultItem: [
                      key < Const(LogicValue.filled(keyWidth, LogicValue.x)),
                      valid < Const(LogicValue.x),
                    ]),
              ]),
            ],
            exactMatch: true,
            defaultItem: [
              key < Const(LogicValue.filled(keyWidth, LogicValue.x)),
              valid < Const(LogicValue.x),
            ]),
      ]);
      addOutput('side_read_key$suffix', width: keyWidth) <= key;
      addOutput('side_read_valid$suffix') <= valid;
      sideReadResponses[port].key <= output('side_read_key$suffix');
      sideReadResponses[port].entryValid <= output('side_read_valid$suffix');
    }
  }
}

/// Builds parallel-flop associative memory with multiple indexed reads.
AssociativeMemory parallelMultiSideReadBuilder({
  required Logic clk,
  required Logic reset,
  required List<AssociativeUpdatePortInterface> updatePorts,
  required List<AssociativeLookupPortInterface> lookupPorts,
  required List<AssociativeIndexedSideReadRequest> sideReadRequests,
  required AssociativeMemoryRequest request,
  required AssociativeMemoryContract contract,
  required String name,
}) =>
    ParallelAssociativeMemory(
      clk: clk,
      reset: reset,
      updates: updatePorts,
      lookups: lookupPorts,
      entryCount: request.entryCount,
      contract: contract,
      sideReadRequests: sideReadRequests,
      enableValidTracking: request.requiresValidityMask,
      name: name,
    );

/// Builds a [ParallelAssociativeMemory] for a resolved contract.
AssociativeMemory parallelAssociativeMemoryBuilder({
  required Logic clk,
  required Logic reset,
  required List<AssociativeUpdatePortInterface> updatePorts,
  required List<AssociativeLookupPortInterface> lookupPorts,
  required AssociativeMemoryRequest request,
  required AssociativeMemoryContract contract,
  required String name,
}) =>
    ParallelAssociativeMemory(
      clk: clk,
      reset: reset,
      updates: updatePorts,
      lookups: lookupPorts,
      entryCount: request.entryCount,
      contract: contract,
      enableValidTracking: request.requiresValidityMask,
      name: name,
    );

/// Synthesizable parallel-flop associative-memory functor.
const parallelAssociativeMemoryFunctor = AssociativeMemoryFunctor(
  identity: 'parallelFlops',
  capabilities: AssociativeMemoryCapabilities.immutable(
    maximumLookupLatency: 0,
    supportedDuplicateKeyPolicies: {AssociativeDuplicateKeyPolicy.allow},
    supportedMatchSelections: {
      AssociativeMatchSelection.lowestIndex,
      AssociativeMatchSelection.highestIndex
    },
    supportedResultShapes: {
      AssociativeResultShape.selectedIndex,
      AssociativeResultShape.matchVectorAndSelectedIndex
    },
    supportedLookupUpdatePolicies: {
      AssociativeLookupUpdatePolicy.lookupAfterUpdate
    },
    supportedUpdateCollisionPolicies: {
      AssociativeUpdateCollisionPolicy.lowestPortWins,
      AssociativeUpdateCollisionPolicy.highestPortWins
    },
    resetBehavior: AssociativeMemoryResetBehavior.clearValidity,
    implementationKind: AssociativeMemoryImplementationKind.synthesizable,
    sustainsOneLookupPerPortPerCycle: true,
    supportsIndexedSideRead: true,
    maximumIndexedSideReads: null,
    supportsValidityMask: true,
  ),
  build: parallelAssociativeMemoryBuilder,
  buildMultipleSideReads: parallelMultiSideReadBuilder,
);
