// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_memory_contract.dart
// Requests, capabilities, contracts, and bindings for associative memories.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory.dart';
import 'package:rohd_hcl/src/memory/state/state_transactions.dart';

/// Whether an associative memory permits more than one entry per key.
enum AssociativeDuplicateKeyPolicy {
  /// At most one valid entry may contain a key.
  disallow,

  /// Several valid entries may contain the same key.
  allow
}

/// Selection policy when several valid entries match one lookup.
enum AssociativeMatchSelection {
  /// Select the matching entry with the lowest physical index.
  lowestIndex,

  /// Select the matching entry with the highest physical index.
  highestIndex
}

/// Result information required from an associative lookup.
enum AssociativeResultShape {
  /// Return only `hit` and the selected index.
  selectedIndex,

  /// Return the complete match vector in addition to the selected index.
  matchVectorAndSelectedIndex
}

/// Key comparison semantics for an associative lookup.
enum AssociativeMatchMode {
  /// Match a stored key only when every key bit is equal.
  exact,

  /// Match only the bits selected by a request-provided mask.
  masked,

  /// Match a key together with an implementation-defined context.
  contextQualified
}

/// Visibility of an update concurrent with a lookup of the same key.
enum AssociativeLookupUpdatePolicy {
  /// Lookup observes state from before the concurrent update.
  lookupBeforeUpdate,

  /// Lookup observes state including the concurrent update.
  lookupAfterUpdate,

  /// The result of a concurrent lookup and update is unspecified.
  undefined
}

/// Resolution of simultaneous updates targeting the same entry index.
enum AssociativeUpdateCollisionPolicy {
  /// Multiple enabled updates to one index are illegal.
  disallow,

  /// The lowest-numbered enabled update port wins.
  lowestPortWins,

  /// The highest-numbered enabled update port wins.
  highestPortWins
}

/// When a bulk associative operation acknowledges completion.
enum AssociativeBulkOperationCompletion {
  /// Completion is emitted only after all selected updates are accepted.
  afterAllUpdates,

  /// Completion is emitted when the bulk request itself is accepted.
  immediate
}

/// Reset behavior provided or required by associative storage.
enum AssociativeMemoryResetBehavior {
  /// Reset does not initialize entry validity.
  none,

  /// Reset invalidates every entry.
  clearValidity
}

/// Whether reset is sampled by a clock edge or takes effect immediately.
enum AssociativeMemoryResetTiming {
  /// Reset takes effect on the active clock edge.
  synchronous,

  /// Reset takes effect independently of the clock.
  asynchronous
}

/// How an associative-memory implementation participates in generated RTL.
enum AssociativeMemoryImplementationKind {
  /// The implementation emits synthesizable storage and matching logic.
  synthesizable,

  /// The implementation is available only to software simulation.
  simulationOnly,

  /// The implementation instantiates a module supplied by the target flow.
  external
}

/// An immutable requested associative-memory shape and behavior.
class AssociativeMemoryRequest {
  /// Width of each associative key.
  final int keyWidth;

  /// Width of an entry index.
  final int indexWidth;

  /// Number of searchable entries.
  final int entryCount;

  /// Number of independent indexed update ports.
  final int updatePortCount;

  /// Number of independent lookup ports.
  final int lookupPortCount;

  /// Enabled lookup to result latency.
  final int lookupLatency;

  /// Update sampling-edge to commit latency.
  final int updateLatency;

  /// Required duplicate-key behavior.
  final AssociativeDuplicateKeyPolicy duplicateKeyPolicy;

  /// Required selection behavior for duplicate matches.
  final AssociativeMatchSelection matchSelection;

  /// Required result information.
  final AssociativeResultShape resultShape;

  /// Required key comparison semantics.
  final AssociativeMatchMode matchMode;

  /// Required visibility for simultaneous lookup and update.
  final AssociativeLookupUpdatePolicy lookupUpdatePolicy;

  /// Required precedence for simultaneous updates to one index.
  final AssociativeUpdateCollisionPolicy updateCollisionPolicy;

  /// Minimum reset behavior required by the consumer.
  final AssociativeMemoryResetBehavior requiredResetBehavior;

  /// Required reset timing.
  final AssociativeMemoryResetTiming requiredResetTiming;

  /// Whether the consumer requires an indexed key/validity side-read port.
  final bool requiresIndexedSideRead;

  /// Number of independently indexed key/validity side reads.
  final int indexedSideReadCount;

  final bool _legacySideReadRequirement;

  /// Whether the consumer requires a combinational per-entry validity mask.
  final bool requiresValidityMask;

  /// Creates an associative-memory request.
  AssociativeMemoryRequest({
    required this.keyWidth,
    required this.indexWidth,
    required this.entryCount,
    required this.updatePortCount,
    required this.lookupPortCount,
    required this.lookupLatency,
    required this.duplicateKeyPolicy,
    required this.matchSelection,
    required this.resultShape,
    required this.lookupUpdatePolicy,
    required this.updateCollisionPolicy,
    this.matchMode = AssociativeMatchMode.exact,
    this.updateLatency = 0,
    this.requiredResetBehavior = AssociativeMemoryResetBehavior.none,
    this.requiredResetTiming = AssociativeMemoryResetTiming.synchronous,
    bool requiresIndexedSideRead = false,
    int? indexedSideReadCount,
    this.requiresValidityMask = false,
  })  : indexedSideReadCount =
            indexedSideReadCount ?? (requiresIndexedSideRead ? 1 : 0),
        _legacySideReadRequirement =
            requiresIndexedSideRead && indexedSideReadCount == null,
        requiresIndexedSideRead =
            requiresIndexedSideRead || (indexedSideReadCount ?? 0) > 0 {
    if (requiresIndexedSideRead && this.indexedSideReadCount == 0) {
      throw ArgumentError('An indexed side-read request must have a port.');
    }
    validate();
  }

  /// Creates a request from concrete associative-memory ports.
  factory AssociativeMemoryRequest.fromPorts({
    required List<AssociativeUpdatePortInterface> updatePorts,
    required List<AssociativeLookupPortInterface> lookupPorts,
    required int entryCount,
    required int lookupLatency,
    required AssociativeDuplicateKeyPolicy duplicateKeyPolicy,
    required AssociativeMatchSelection matchSelection,
    required AssociativeResultShape resultShape,
    required AssociativeLookupUpdatePolicy lookupUpdatePolicy,
    required AssociativeUpdateCollisionPolicy updateCollisionPolicy,
    int updateLatency = 0,
    AssociativeMemoryResetBehavior requiredResetBehavior =
        AssociativeMemoryResetBehavior.none,
    AssociativeMemoryResetTiming requiredResetTiming =
        AssociativeMemoryResetTiming.synchronous,
    bool requiresIndexedSideRead = false,
    int? indexedSideReadCount,
    bool requiresValidityMask = false,
  }) {
    final allPorts = <AssociativePortInterface>[...updatePorts, ...lookupPorts];
    if (lookupPorts.isEmpty) {
      throw ArgumentError('At least one associative lookup port is required.');
    }
    final keyWidth = allPorts.first.keyWidth;
    final indexWidth = allPorts.first.indexWidth;
    if (allPorts.any(
        (port) => port.keyWidth != keyWidth || port.indexWidth != indexWidth)) {
      throw ArgumentError('All associative ports must have matching shapes.');
    }
    if (resultShape == AssociativeResultShape.matchVectorAndSelectedIndex &&
        lookupPorts.any((port) => port.matchEntryCount != entryCount)) {
      throw ArgumentError('Match-vector lookup ports must provide one bit per '
          'associative entry.');
    }
    final request = AssociativeMemoryRequest(
      keyWidth: keyWidth,
      indexWidth: indexWidth,
      entryCount: entryCount,
      updatePortCount: updatePorts.length,
      lookupPortCount: lookupPorts.length,
      lookupLatency: lookupLatency,
      updateLatency: updateLatency,
      duplicateKeyPolicy: duplicateKeyPolicy,
      matchSelection: matchSelection,
      resultShape: resultShape,
      lookupUpdatePolicy: lookupUpdatePolicy,
      updateCollisionPolicy: updateCollisionPolicy,
      requiredResetBehavior: requiredResetBehavior,
      requiredResetTiming: requiredResetTiming,
      requiresIndexedSideRead: requiresIndexedSideRead,
      indexedSideReadCount: indexedSideReadCount,
      requiresValidityMask: requiresValidityMask,
    );
    return request;
  }

  /// Validates that this request describes a realizable raw interface.
  void validate() {
    if (keyWidth < 1 ||
        indexWidth < 1 ||
        entryCount < 1 ||
        updatePortCount < 0 ||
        lookupPortCount < 1 ||
        lookupLatency < 0 ||
        indexedSideReadCount < 0 ||
        updateLatency < 0) {
      throw ArgumentError('Associative-memory widths, entry count, lookup '
          'ports, and latencies must be valid.');
    }
    if ((BigInt.one << indexWidth) < BigInt.from(entryCount)) {
      throw ArgumentError(
          'Index width $indexWidth cannot represent $entryCount entries.');
    }
  }

  bool _hasSameShape(AssociativeMemoryRequest other) =>
      keyWidth == other.keyWidth &&
      indexWidth == other.indexWidth &&
      entryCount == other.entryCount &&
      updatePortCount == other.updatePortCount &&
      lookupPortCount == other.lookupPortCount &&
      requiresIndexedSideRead == other.requiresIndexedSideRead &&
      indexedSideReadCount == other.indexedSideReadCount &&
      requiresValidityMask == other.requiresValidityMask;
}

/// Indexed side-read request for associative key and validity state.
class AssociativeIndexedSideReadRequest extends LogicStructure {
  /// Requested entry index.
  Logic get index => elements[0];

  /// Creates an indexed side-read request.
  AssociativeIndexedSideReadRequest({
    required int indexWidth,
    String name = 'associativeIndexedSideReadRequest',
  }) : super([Logic(name: 'index', width: indexWidth)], name: name);

  AssociativeIndexedSideReadRequest._clone(LogicStructure original,
      {String? name})
      : super(original.elements.map((element) => element.clone()).toList(),
            name: name ?? original.name);

  /// Makes a copy with the same shape.
  @override
  AssociativeIndexedSideReadRequest clone({String? name}) =>
      AssociativeIndexedSideReadRequest._clone(this, name: name);
}

/// Indexed side-read response containing key and validity state.
class AssociativeIndexedSideReadResponse extends LogicStructure {
  /// Stored key at the requested index.
  Logic get key => elements[0];

  /// Whether the requested entry is valid.
  Logic get entryValid => elements[1];

  /// Creates an indexed side-read response.
  AssociativeIndexedSideReadResponse({
    required int keyWidth,
    String name = 'associativeIndexedSideReadResponse',
  }) : super([
          Logic(name: 'key', width: keyWidth),
          Logic(name: 'entryValid'),
        ], name: name);

  AssociativeIndexedSideReadResponse._clone(LogicStructure original,
      {String? name})
      : super(original.elements.map((element) => element.clone()).toList(),
            name: name ?? original.name);

  /// Makes a copy with the same shape.
  @override
  AssociativeIndexedSideReadResponse clone({String? name}) =>
      AssociativeIndexedSideReadResponse._clone(this, name: name);
}

/// Optional combinational indexed access to stored key and validity.
abstract interface class AssociativeIndexedSideReadProvider {
  /// Response to the supplied side-read request, or null when not enabled.
  AssociativeIndexedSideReadResponse? get sideReadResponse;
}

/// Optional combinational access through multiple indexed side-read ports.
abstract interface class AssociativeMultiIndexedSideReadProvider {
  /// Responses corresponding to the indexed side-read requests, in order.
  List<AssociativeIndexedSideReadResponse> get sideReadResponses;
}

/// Optional combinational access to all stored validity bits.
abstract interface class AssociativeValidityMaskProvider {
  /// One validity bit per entry, or null when tracking was not requested.
  Logic? get validMask;
}

/// Static capabilities advertised by an associative-memory implementation.
class AssociativeMemoryCapabilities {
  /// Fewest update ports accepted by the implementation.
  final int minimumUpdatePorts;

  /// Most update ports accepted, or `null` when unbounded.
  final int? maximumUpdatePorts;

  /// Fewest lookup ports accepted by the implementation.
  final int minimumLookupPorts;

  /// Most lookup ports accepted, or `null` when unbounded.
  final int? maximumLookupPorts;

  /// Smallest supported entry count.
  final int minimumEntryCount;

  /// Largest supported entry count, or `null` when unbounded.
  final int? maximumEntryCount;

  /// Smallest supported key width.
  final int minimumKeyWidth;

  /// Largest supported key width, or `null` when unbounded.
  final int? maximumKeyWidth;

  /// Smallest supported lookup latency.
  final int minimumLookupLatency;

  /// Largest supported lookup latency, or `null` when unbounded.
  final int? maximumLookupLatency;

  /// Update sampling-edge to commit latency.
  final int updateLatency;

  /// Supported duplicate-key policies.
  final Set<AssociativeDuplicateKeyPolicy> supportedDuplicateKeyPolicies;

  /// Supported duplicate-match selectors.
  final Set<AssociativeMatchSelection> supportedMatchSelections;

  /// Supported key comparison semantics.
  final Set<AssociativeMatchMode> supportedMatchModes;

  /// Supported lookup result shapes.
  final Set<AssociativeResultShape> supportedResultShapes;

  /// Supported simultaneous lookup/update policies.
  final Set<AssociativeLookupUpdatePolicy> supportedLookupUpdatePolicies;

  /// Supported simultaneous update collision policies.
  final Set<AssociativeUpdateCollisionPolicy> supportedUpdateCollisionPolicies;

  /// Reset behavior provided by the implementation.
  final AssociativeMemoryResetBehavior resetBehavior;

  /// Reset timing provided by the implementation.
  final AssociativeMemoryResetTiming resetTiming;

  /// How the implementation participates in generated RTL.
  final AssociativeMemoryImplementationKind implementationKind;

  /// Snapshot and restore behavior provided outside associative data ports.
  final StateTransactionCapabilities stateTransactions;

  /// Whether indexed key and validity side reads are exposed.
  final bool supportsIndexedSideRead;

  /// Maximum indexed side-read ports, or null if unbounded.
  final int? maximumIndexedSideReads;

  /// Whether a combinational per-entry validity mask is exposed.
  final bool supportsValidityMask;

  /// Whether selected entries can be invalidated through a state operation.
  final bool supportsIndexedInvalidation;

  /// Whether all entries can be invalidated without enumerating them.
  final bool supportsInvalidateAll;

  /// Completion semantics for bulk operations.
  final AssociativeBulkOperationCompletion bulkOperationCompletion;

  /// Whether every lookup port accepts a request every cycle.
  final bool sustainsOneLookupPerPortPerCycle;

  /// Creates an associative-memory capability declaration.
  factory AssociativeMemoryCapabilities({
    required Set<AssociativeDuplicateKeyPolicy> supportedDuplicateKeyPolicies,
    required Set<AssociativeMatchSelection> supportedMatchSelections,
    required Set<AssociativeResultShape> supportedResultShapes,
    required Set<AssociativeLookupUpdatePolicy> supportedLookupUpdatePolicies,
    required Set<AssociativeUpdateCollisionPolicy>
        supportedUpdateCollisionPolicies,
    required AssociativeMemoryResetBehavior resetBehavior,
    required AssociativeMemoryImplementationKind implementationKind,
    required bool sustainsOneLookupPerPortPerCycle,
    AssociativeMemoryResetTiming resetTiming =
        AssociativeMemoryResetTiming.synchronous,
    Set<AssociativeMatchMode> supportedMatchModes = const {
      AssociativeMatchMode.exact
    },
    int minimumUpdatePorts = 0,
    int? maximumUpdatePorts,
    int minimumLookupPorts = 1,
    int? maximumLookupPorts,
    int minimumEntryCount = 1,
    int? maximumEntryCount,
    int minimumKeyWidth = 1,
    int? maximumKeyWidth,
    int minimumLookupLatency = 0,
    int? maximumLookupLatency,
    int updateLatency = 0,
    StateTransactionCapabilities stateTransactions =
        StateTransactionCapabilities.unsupported,
    bool supportsIndexedSideRead = false,
    int? maximumIndexedSideReads = 1,
    bool supportsValidityMask = false,
    bool supportsIndexedInvalidation = false,
    bool supportsInvalidateAll = false,
    AssociativeBulkOperationCompletion bulkOperationCompletion =
        AssociativeBulkOperationCompletion.afterAllUpdates,
  }) =>
      AssociativeMemoryCapabilities.immutable(
        minimumUpdatePorts: minimumUpdatePorts,
        maximumUpdatePorts: maximumUpdatePorts,
        minimumLookupPorts: minimumLookupPorts,
        maximumLookupPorts: maximumLookupPorts,
        minimumEntryCount: minimumEntryCount,
        maximumEntryCount: maximumEntryCount,
        minimumKeyWidth: minimumKeyWidth,
        maximumKeyWidth: maximumKeyWidth,
        minimumLookupLatency: minimumLookupLatency,
        maximumLookupLatency: maximumLookupLatency,
        updateLatency: updateLatency,
        supportedDuplicateKeyPolicies:
            Set.unmodifiable(supportedDuplicateKeyPolicies),
        supportedMatchSelections: Set.unmodifiable(supportedMatchSelections),
        supportedMatchModes: Set.unmodifiable(supportedMatchModes),
        supportedResultShapes: Set.unmodifiable(supportedResultShapes),
        supportedLookupUpdatePolicies:
            Set.unmodifiable(supportedLookupUpdatePolicies),
        supportedUpdateCollisionPolicies:
            Set.unmodifiable(supportedUpdateCollisionPolicies),
        resetBehavior: resetBehavior,
        resetTiming: resetTiming,
        implementationKind: implementationKind,
        sustainsOneLookupPerPortPerCycle: sustainsOneLookupPerPortPerCycle,
        stateTransactions: stateTransactions,
        supportsIndexedSideRead: supportsIndexedSideRead,
        maximumIndexedSideReads: maximumIndexedSideReads,
        supportsValidityMask: supportsValidityMask,
        supportsIndexedInvalidation: supportsIndexedInvalidation,
        supportsInvalidateAll: supportsInvalidateAll,
        bulkOperationCompletion: bulkOperationCompletion,
      );

  /// Creates capabilities from values already known to be immutable.
  const AssociativeMemoryCapabilities.immutable({
    required this.supportedDuplicateKeyPolicies,
    required this.supportedMatchSelections,
    required this.supportedResultShapes,
    required this.supportedLookupUpdatePolicies,
    required this.supportedUpdateCollisionPolicies,
    required this.resetBehavior,
    required this.implementationKind,
    required this.sustainsOneLookupPerPortPerCycle,
    this.resetTiming = AssociativeMemoryResetTiming.synchronous,
    this.supportedMatchModes = const {AssociativeMatchMode.exact},
    this.stateTransactions = StateTransactionCapabilities.unsupported,
    this.supportsIndexedSideRead = false,
    this.maximumIndexedSideReads = 1,
    this.supportsValidityMask = false,
    this.supportsIndexedInvalidation = false,
    this.supportsInvalidateAll = false,
    this.bulkOperationCompletion =
        AssociativeBulkOperationCompletion.afterAllUpdates,
    this.minimumUpdatePorts = 0,
    this.maximumUpdatePorts,
    this.minimumLookupPorts = 1,
    this.maximumLookupPorts,
    this.minimumEntryCount = 1,
    this.maximumEntryCount,
    this.minimumKeyWidth = 1,
    this.maximumKeyWidth,
    this.minimumLookupLatency = 0,
    this.maximumLookupLatency,
    this.updateLatency = 0,
  });

  /// Whether [request] can be implemented exactly as requested.
  bool supports(AssociativeMemoryRequest request) =>
      incompatibilityReason(request) == null;

  /// Why [request] is unsupported, or `null` when it is supported.
  String? incompatibilityReason(AssociativeMemoryRequest request) {
    request.validate();
    _validateDeclaration();
    if (!sustainsOneLookupPerPortPerCycle) {
      return 'does not sustain one lookup per port per cycle';
    }
    if (request.updatePortCount < minimumUpdatePorts ||
        maximumUpdatePorts != null &&
            request.updatePortCount > maximumUpdatePorts!) {
      return 'requires ${request.updatePortCount} update ports; supported '
          'range '
          'is $minimumUpdatePorts..${maximumUpdatePorts ?? 'unbounded'}';
    }
    if (request.lookupPortCount < minimumLookupPorts ||
        maximumLookupPorts != null &&
            request.lookupPortCount > maximumLookupPorts!) {
      return 'requires ${request.lookupPortCount} lookup ports; supported '
          'range '
          'is $minimumLookupPorts..${maximumLookupPorts ?? 'unbounded'}';
    }
    if (request.entryCount < minimumEntryCount ||
        maximumEntryCount != null && request.entryCount > maximumEntryCount!) {
      return 'requires ${request.entryCount} entries; supported range is '
          '$minimumEntryCount..${maximumEntryCount ?? 'unbounded'}';
    }
    if (request.keyWidth < minimumKeyWidth ||
        maximumKeyWidth != null && request.keyWidth > maximumKeyWidth!) {
      return 'requires key width ${request.keyWidth}; supported range is '
          '$minimumKeyWidth..${maximumKeyWidth ?? 'unbounded'}';
    }
    if (request.lookupLatency < minimumLookupLatency ||
        maximumLookupLatency != null &&
            request.lookupLatency > maximumLookupLatency!) {
      return 'requires lookup latency ${request.lookupLatency}; supported '
          'range '
          'is $minimumLookupLatency..${maximumLookupLatency ?? 'unbounded'}';
    }
    if (request.updateLatency != updateLatency) {
      return 'requires update latency ${request.updateLatency}; implementation '
          'provides $updateLatency';
    }
    if (!supportedDuplicateKeyPolicies.contains(request.duplicateKeyPolicy)) {
      return 'does not support ${request.duplicateKeyPolicy.name} duplicate '
          'keys';
    }
    if (!supportedMatchSelections.contains(request.matchSelection)) {
      return 'does not support ${request.matchSelection.name} match selection';
    }
    if (!supportedMatchModes.contains(request.matchMode)) {
      return 'does not support ${request.matchMode.name} match semantics';
    }
    if (!supportedResultShapes.contains(request.resultShape)) {
      return 'does not support ${request.resultShape.name} results';
    }
    if (!supportedLookupUpdatePolicies.contains(request.lookupUpdatePolicy)) {
      return 'does not support ${request.lookupUpdatePolicy.name} lookup/update '
          'behavior';
    }
    if (!supportedUpdateCollisionPolicies
        .contains(request.updateCollisionPolicy)) {
      return 'does not support ${request.updateCollisionPolicy.name} update '
          'collision behavior';
    }
    if (request.requiredResetBehavior ==
            AssociativeMemoryResetBehavior.clearValidity &&
        resetBehavior != AssociativeMemoryResetBehavior.clearValidity) {
      return 'does not clear entry validity on reset';
    }
    if (request.requiredResetTiming != resetTiming) {
      return 'requires ${request.requiredResetTiming.name} reset timing; '
          'implementation provides ${resetTiming.name}';
    }
    if (request.requiresIndexedSideRead && !supportsIndexedSideRead) {
      return 'does not expose an indexed side-read port';
    }
    if (maximumIndexedSideReads != null &&
        request.indexedSideReadCount > maximumIndexedSideReads!) {
      return 'requires ${request.indexedSideReadCount} indexed side reads; '
          'implementation supports at most $maximumIndexedSideReads';
    }
    if (request.requiresValidityMask && !supportsValidityMask) {
      return 'does not provide a validity mask';
    }
    return null;
  }

  void _validateDeclaration() {
    if (minimumUpdatePorts < 0 ||
        maximumUpdatePorts != null &&
            maximumUpdatePorts! < minimumUpdatePorts ||
        minimumLookupPorts < 1 ||
        maximumLookupPorts != null &&
            maximumLookupPorts! < minimumLookupPorts ||
        minimumEntryCount < 1 ||
        maximumEntryCount != null && maximumEntryCount! < minimumEntryCount ||
        minimumKeyWidth < 1 ||
        maximumKeyWidth != null && maximumKeyWidth! < minimumKeyWidth ||
        minimumLookupLatency < 0 ||
        maximumLookupLatency != null &&
            maximumLookupLatency! < minimumLookupLatency ||
        updateLatency < 0 ||
        (maximumIndexedSideReads != null && maximumIndexedSideReads! < 1) ||
        supportedDuplicateKeyPolicies.isEmpty ||
        supportedMatchSelections.isEmpty ||
        supportedMatchModes.isEmpty ||
        supportedResultShapes.isEmpty ||
        supportedLookupUpdatePolicies.isEmpty ||
        supportedUpdateCollisionPolicies.isEmpty) {
      throw StateError('Invalid associative-memory capability declaration.');
    }
  }
}

/// Timing and behavior selected for one associative-memory binding.
class AssociativeMemoryContract {
  /// Effective enabled-lookup to result latency.
  final int lookupLatency;

  /// Effective update sampling-edge to commit latency.
  final int updateLatency;

  /// Effective duplicate-key behavior.
  final AssociativeDuplicateKeyPolicy duplicateKeyPolicy;

  /// Effective duplicate-match selector.
  final AssociativeMatchSelection matchSelection;

  /// Effective result information.
  final AssociativeResultShape resultShape;

  /// Effective simultaneous lookup/update behavior.
  final AssociativeLookupUpdatePolicy lookupUpdatePolicy;

  /// Effective simultaneous update collision behavior.
  final AssociativeUpdateCollisionPolicy updateCollisionPolicy;

  /// Reset behavior provided by the selected implementation.
  final AssociativeMemoryResetBehavior resetBehavior;

  /// Reset timing provided by the selected implementation.
  final AssociativeMemoryResetTiming resetTiming;

  /// How the implementation participates in generated RTL.
  final AssociativeMemoryImplementationKind implementationKind;

  /// Creates a resolved associative-memory contract.
  const AssociativeMemoryContract({
    required this.lookupLatency,
    required this.updateLatency,
    required this.duplicateKeyPolicy,
    required this.matchSelection,
    required this.resultShape,
    required this.lookupUpdatePolicy,
    required this.updateCollisionPolicy,
    required this.resetBehavior,
    required this.implementationKind,
    this.resetTiming = AssociativeMemoryResetTiming.synchronous,
  });
}

/// Builds an associative memory for a resolved shared port contract.
typedef AssociativeMemoryBuilder = AssociativeMemory Function({
  required Logic clk,
  required Logic reset,
  required List<AssociativeUpdatePortInterface> updatePorts,
  required List<AssociativeLookupPortInterface> lookupPorts,
  required AssociativeMemoryRequest request,
  required AssociativeMemoryContract contract,
  required String name,
});

/// Builds an associative memory with one or more indexed side reads.
typedef AssociativeMultiSideReadBuilder = AssociativeMemory Function({
  required Logic clk,
  required Logic reset,
  required List<AssociativeUpdatePortInterface> updatePorts,
  required List<AssociativeLookupPortInterface> lookupPorts,
  required List<AssociativeIndexedSideReadRequest> sideReadRequests,
  required AssociativeMemoryRequest request,
  required AssociativeMemoryContract contract,
  required String name,
});

/// Selects an implementation-specific contract for a supported request.
typedef AssociativeMemoryContractResolver = AssociativeMemoryContract Function(
    AssociativeMemoryRequest request);

/// A resolved associative-memory implementation and its instantiated module.
class AssociativeMemoryBinding {
  /// Implementation that owns this binding.
  final AssociativeMemoryFunctor implementation;

  /// Request from which this binding was resolved.
  final AssociativeMemoryRequest request;

  /// Effective implementation contract.
  final AssociativeMemoryContract contract;

  /// Instantiated memory, or `null` until [instantiate] is called.
  AssociativeMemory? memory;

  AssociativeMemoryBinding._(this.implementation, this.request, this.contract);

  /// Instantiates this binding on ports matching the resolved request.
  AssociativeMemory instantiate({
    required Logic clk,
    required Logic reset,
    required List<AssociativeUpdatePortInterface> updatePorts,
    required List<AssociativeLookupPortInterface> lookupPorts,
    required String name,
    AssociativeIndexedSideReadRequest? sideReadRequest,
    List<AssociativeIndexedSideReadRequest>? sideReadRequests,
  }) {
    if (memory != null) {
      throw StateError(
          'An associative-memory binding may be instantiated once.');
    }
    if (sideReadRequest != null && sideReadRequests != null) {
      throw ArgumentError('Use either sideReadRequest or sideReadRequests.');
    }
    final sides = sideReadRequests ??
        (sideReadRequest == null
            ? <AssociativeIndexedSideReadRequest>[]
            : [sideReadRequest]);
    final legacyUnboundSideRead =
        request._legacySideReadRequirement && sides.isEmpty;
    if ((!legacyUnboundSideRead &&
            request.indexedSideReadCount != sides.length) ||
        sides.any((side) => side.index.width != request.indexWidth)) {
      throw ArgumentError(
          'Indexed side-read port does not match the resolved request.');
    }
    final actualRequest = AssociativeMemoryRequest.fromPorts(
      updatePorts: updatePorts,
      lookupPorts: lookupPorts,
      entryCount: request.entryCount,
      lookupLatency: request.lookupLatency,
      updateLatency: request.updateLatency,
      duplicateKeyPolicy: request.duplicateKeyPolicy,
      matchSelection: request.matchSelection,
      resultShape: request.resultShape,
      lookupUpdatePolicy: request.lookupUpdatePolicy,
      updateCollisionPolicy: request.updateCollisionPolicy,
      requiredResetBehavior: request.requiredResetBehavior,
      requiredResetTiming: request.requiredResetTiming,
      requiresIndexedSideRead: request.requiresIndexedSideRead,
      indexedSideReadCount: request.indexedSideReadCount,
      requiresValidityMask: request.requiresValidityMask,
    );
    if (!request._hasSameShape(actualRequest)) {
      throw ArgumentError(
          'Bound associative ports do not match the resolved request shape.');
    }
    if (sides.isNotEmpty && implementation._buildMultiple == null) {
      throw ArgumentError('Associative-memory implementation '
          '${implementation.identity} has no indexed-side-read builder.');
    }
    final built = sides.isNotEmpty
        ? implementation._buildMultiple!(
            clk: clk,
            reset: reset,
            updatePorts: updatePorts,
            lookupPorts: lookupPorts,
            sideReadRequests: sides,
            request: request,
            contract: contract,
            name: name,
          )
        : implementation._build(
            clk: clk,
            reset: reset,
            updatePorts: updatePorts,
            lookupPorts: lookupPorts,
            request: request,
            contract: contract,
            name: name,
          );
    if (built.entryCount != request.entryCount ||
        built.keyWidth != request.keyWidth ||
        built.indexWidth != request.indexWidth ||
        built.numUpdates != request.updatePortCount ||
        built.numLookups != request.lookupPortCount ||
        built.lookupLatency != contract.lookupLatency ||
        built.updateLatency != contract.updateLatency) {
      throw StateError('Associative-memory implementation '
          '${implementation.identity} built a module that does not match its '
          'resolved binding.');
    }
    if (request.requiresValidityMask) {
      if (built is! AssociativeValidityMaskProvider) {
        throw StateError('Associative-memory implementation '
            '${implementation.identity} did not provide a validity mask.');
      }
      final mask = (built as AssociativeValidityMaskProvider).validMask;
      if (mask == null || mask.width != request.entryCount) {
        throw StateError('Associative-memory implementation '
            '${implementation.identity} provided an invalid validity mask.');
      }
    }
    if (sides.length == 1) {
      if (built is! AssociativeIndexedSideReadProvider) {
        throw StateError('Associative-memory implementation '
            '${implementation.identity} did not provide its indexed '
            'side read.');
      }
      final response =
          (built as AssociativeIndexedSideReadProvider).sideReadResponse;
      if (response == null || response.key.width != request.keyWidth) {
        throw StateError('Associative-memory implementation '
            '${implementation.identity} provided an invalid side-read '
            'response.');
      }
    }
    if (sides.length > 1) {
      if (built is! AssociativeMultiIndexedSideReadProvider) {
        throw StateError('Associative-memory implementation '
            '${implementation.identity} did not provide indexed side reads.');
      }
      final responses =
          (built as AssociativeMultiIndexedSideReadProvider).sideReadResponses;
      if (responses.length != sides.length ||
          responses.any((response) => response.key.width != request.keyWidth)) {
        throw StateError('Associative-memory implementation '
            '${implementation.identity} provided invalid side-read responses.');
      }
    }
    memory = built;
    return built;
  }
}

/// A callable implementation for raw associative memory.
///
/// Calling the functor requires an exact semantic and timing match. Consumers
/// that can adapt to an implementation-selected contract should call [resolve]
/// and compose around the returned binding before invoking
/// [AssociativeMemoryBinding.instantiate].
/// {@category Memory}
class AssociativeMemoryFunctor {
  final AssociativeMemoryBuilder _build;
  final AssociativeMultiSideReadBuilder? _buildMultiple;
  final AssociativeMemoryContractResolver? _resolve;

  /// Stable SystemVerilog-safe implementation identity.
  final String identity;

  /// Static implementation capabilities.
  final AssociativeMemoryCapabilities capabilities;

  /// Creates an associative-memory implementation functor.
  ///
  /// [buildMultipleSideReads] is required when binding indexed side-read
  /// ports. The original [build] callback remains unchanged, including for
  /// legacy capability-only indexed-side-read requests.
  const AssociativeMemoryFunctor({
    required this.identity,
    required this.capabilities,
    required AssociativeMemoryBuilder build,
    AssociativeMultiSideReadBuilder? buildMultipleSideReads,
    AssociativeMemoryContractResolver? resolve,
  })  : _build = build,
        _buildMultiple = buildMultipleSideReads,
        _resolve = resolve;

  /// Resolves [request] without instantiating hardware.
  AssociativeMemoryBinding resolve(AssociativeMemoryRequest request) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(identity)) {
      throw ArgumentError.value(identity, 'identity',
          'Must be a valid SystemVerilog identifier fragment.');
    }
    final incompatibility = capabilities.incompatibilityReason(request);
    if (incompatibility != null) {
      throw ArgumentError(
          'Associative-memory implementation $identity $incompatibility.');
    }
    if (request.indexedSideReadCount > 1 && _buildMultiple == null) {
      throw ArgumentError('Associative-memory implementation $identity has no '
          'indexed-side-read builder.');
    }
    final contract = _resolve?.call(request) ??
        AssociativeMemoryContract(
          lookupLatency: request.lookupLatency,
          updateLatency: capabilities.updateLatency,
          duplicateKeyPolicy: request.duplicateKeyPolicy,
          matchSelection: request.matchSelection,
          resultShape: request.resultShape,
          lookupUpdatePolicy: request.lookupUpdatePolicy,
          updateCollisionPolicy: request.updateCollisionPolicy,
          resetBehavior: capabilities.resetBehavior,
          resetTiming: capabilities.resetTiming,
          implementationKind: capabilities.implementationKind,
        );
    if (contract.lookupLatency < capabilities.minimumLookupLatency ||
        capabilities.maximumLookupLatency != null &&
            contract.lookupLatency > capabilities.maximumLookupLatency! ||
        contract.updateLatency != capabilities.updateLatency ||
        !capabilities.supportedDuplicateKeyPolicies
            .contains(contract.duplicateKeyPolicy) ||
        !capabilities.supportedMatchSelections
            .contains(contract.matchSelection) ||
        !capabilities.supportedResultShapes.contains(contract.resultShape) ||
        !capabilities.supportedLookupUpdatePolicies
            .contains(contract.lookupUpdatePolicy) ||
        !capabilities.supportedUpdateCollisionPolicies
            .contains(contract.updateCollisionPolicy) ||
        contract.resetBehavior != capabilities.resetBehavior ||
        contract.resetTiming != capabilities.resetTiming ||
        contract.implementationKind != capabilities.implementationKind) {
      throw StateError('Associative-memory implementation $identity resolved '
          'a contract outside its advertised capabilities.');
    }
    return AssociativeMemoryBinding._(this, request, contract);
  }

  /// Resolves and instantiates an exact associative-memory request.
  AssociativeMemoryBinding call({
    required Logic clk,
    required Logic reset,
    required List<AssociativeUpdatePortInterface> updatePorts,
    required List<AssociativeLookupPortInterface> lookupPorts,
    required int entryCount,
    required int lookupLatency,
    required AssociativeDuplicateKeyPolicy duplicateKeyPolicy,
    required AssociativeMatchSelection matchSelection,
    required AssociativeResultShape resultShape,
    required AssociativeLookupUpdatePolicy lookupUpdatePolicy,
    required AssociativeUpdateCollisionPolicy updateCollisionPolicy,
    required String name,
    AssociativeIndexedSideReadRequest? sideReadRequest,
    List<AssociativeIndexedSideReadRequest>? sideReadRequests,
    bool requiresValidityMask = false,
    int updateLatency = 0,
    AssociativeMemoryResetBehavior requiredResetBehavior =
        AssociativeMemoryResetBehavior.none,
  }) {
    if (sideReadRequest != null && sideReadRequests != null) {
      throw ArgumentError('Use either sideReadRequest or sideReadRequests.');
    }
    final request = AssociativeMemoryRequest.fromPorts(
      updatePorts: updatePorts,
      lookupPorts: lookupPorts,
      entryCount: entryCount,
      lookupLatency: lookupLatency,
      updateLatency: updateLatency,
      duplicateKeyPolicy: duplicateKeyPolicy,
      matchSelection: matchSelection,
      resultShape: resultShape,
      lookupUpdatePolicy: lookupUpdatePolicy,
      updateCollisionPolicy: updateCollisionPolicy,
      requiredResetBehavior: requiredResetBehavior,
      requiresIndexedSideRead: sideReadRequest != null,
      indexedSideReadCount: sideReadRequests?.length,
      requiresValidityMask: requiresValidityMask,
    );
    final binding = resolve(request);
    if (binding.contract.lookupLatency != request.lookupLatency ||
        binding.contract.updateLatency != request.updateLatency ||
        binding.contract.duplicateKeyPolicy != request.duplicateKeyPolicy ||
        binding.contract.matchSelection != request.matchSelection ||
        binding.contract.resultShape != request.resultShape ||
        binding.contract.lookupUpdatePolicy != request.lookupUpdatePolicy ||
        binding.contract.updateCollisionPolicy !=
            request.updateCollisionPolicy) {
      throw StateError('Associative-memory implementation $identity resolved '
          'behavior different from the controller request. Resolve the binding '
          'before composing controller timing or semantics.');
    }
    binding.instantiate(
      clk: clk,
      reset: reset,
      updatePorts: updatePorts,
      lookupPorts: lookupPorts,
      sideReadRequest: sideReadRequest,
      sideReadRequests: sideReadRequests,
      name: name,
    );
    return binding;
  }
}
