// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// associative_software_model.dart
// Clock-stepped associative memory reference model.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory_contract.dart';
import 'package:rohd_hcl/src/memory/associative/associative_software_systemc.dart';
import 'package:rohd_hcl/src/memory/associative/behavioral_parallel_systemc.dart';
import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';
import 'package:rohd_hcl/src/memory/behavioral/memory_state_access.dart';
import 'package:rohd_hcl/src/memory/state/state_transactions.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';
import 'package:rohd_hcl/src/models/sparse_memory_storage.dart';

/// One indexed associative entry. Validity may be 0, 1, or unknown.
typedef AssociativeSoftwareEntry = ({LogicValue key, LogicValue valid});

/// A sampled update. A null update means its port is disabled.
class AssociativeSoftwareUpdate {
  /// Entry to update.
  final int index;

  /// Key to store.
  final LogicValue key;

  /// Validity to store.
  final LogicValue valid;

  /// Creates an update request.
  const AssociativeSoftwareUpdate(
      {required this.index, required this.key, required this.valid});
}

/// A sampled lookup. A null lookup means its port is disabled.
class AssociativeSoftwareLookup {
  /// Query key.
  final LogicValue key;

  /// Query mask, required only for masked matching.
  final LogicValue? mask;

  /// Context passed to a context-qualified matcher.
  final LogicValue? context;

  /// Creates a lookup request.
  const AssociativeSoftwareLookup({required this.key, this.mask, this.context});
}

/// Result of a sampled lookup, including its entire match vector.
typedef AssociativeSoftwareResult = ({
  LogicValue hit,
  LogicValue index,
  LogicValue matchVector,
});

/// A pure, stateless implementation-defined comparison.
///
/// The returned value must be one bit wide. A provider with external mutable
/// state cannot be replayed by this model's snapshots.
typedef AssociativeSoftwareMatcher = LogicValue Function(
    {required AssociativeSoftwareLookup lookup,
    required LogicValue storedKey,
    required int index});

/// Detached raw associative state. Entries omitted during load are unchanged,
/// or reset when `replace` is requested.
class AssociativeSoftwareState {
  /// Key width.
  final int keyWidth;

  /// Number of entries.
  final int entryCount;

  /// Indexed entries.
  final Map<int, AssociativeSoftwareEntry> entries;

  /// Creates an immutable raw-state image.
  AssociativeSoftwareState(
      {required this.keyWidth,
      required this.entryCount,
      required Map<int, AssociativeSoftwareEntry> entries})
      : entries = Map.unmodifiable(entries);
}

class _PendingUpdate {
  final int due;
  final int port;
  final AssociativeSoftwareUpdate request;
  const _PendingUpdate(this.due, this.port, this.request);
}

class _PendingLookup {
  final int due;
  final int port;
  final AssociativeSoftwareResult result;
  const _PendingLookup(this.due, this.port, this.result);
}

/// Detached execution state, including in-flight updates and lookups.
class AssociativeSoftwareExecutionImage {
  final AssociativeMemoryRequest _configuration;
  final AssociativeSoftwareMatcher? _matcher;
  final AssociativeSoftwareState _state;
  final int _cycle;
  final List<_PendingUpdate> _updates;
  final List<_PendingLookup> _lookups;

  AssociativeSoftwareExecutionImage._(AssociativeSoftwareModel model)
      : _configuration = model.configuration,
        _matcher = model.matcher,
        _state = model.snapshot(),
        _cycle = model._cycle,
        _updates = List.unmodifiable(model._updates),
        _lookups = List.unmodifiable(model._lookups);
}

/// Clock-stepped software model for indexed CAM updates and associative lookup.
///
/// Each call to [step] samples one request per port. An update with latency
/// zero commits on that step; a lookup with latency zero completes on that
/// step. Longer latencies are measured in subsequent calls to [step]. Lookup
/// visibility is relative to updates committing on the same step.
///
/// This API uses null for a disabled request, rather than modeling uncertain
/// enables or indices. Keys, masks, and stored validity retain four-state
/// values. Raw access and snapshots do not capture external callers.
class AssociativeSoftwareModel
    implements
        MemoryStateAccess<AssociativeSoftwareState>,
        BehavioralModel,
        BehavioralModelProvider,
        StateTransactionProvider<AssociativeSoftwareExecutionImage>,
        StateTransactionCapabilityProvider {
  /// Requested geometry and behavior.
  final AssociativeMemoryRequest configuration;

  /// Required pure implementation for context-qualified matching.
  final AssociativeSoftwareMatcher? matcher;

  late final SparseMemoryStorage _storage;
  int _cycle = 0;
  final List<_PendingUpdate> _updates = [];
  final List<_PendingLookup> _lookups = [];

  /// Creates an initially invalid associative memory.
  AssociativeSoftwareModel(this.configuration, {this.matcher}) {
    configuration.validate();
    if (configuration.lookupUpdatePolicy ==
        AssociativeLookupUpdatePolicy.undefined) {
      throw UnsupportedError('An undefined lookup/update policy cannot be '
          'used as a deterministic software model.');
    }

    if ((configuration.matchMode == AssociativeMatchMode.contextQualified) !=
        (matcher != null)) {
      throw ArgumentError('Context-qualified matching requires exactly one '
          'explicit matcher.');
    }
    _storage = SparseMemoryStorage(
        addrWidth: configuration.indexWidth,
        dataWidth: configuration.keyWidth + 1);
  }

  AssociativeSoftwareEntry _emptyEntry() => (
        key: LogicValue.filled(configuration.keyWidth, LogicValue.zero),
        valid: LogicValue.zero,
      );

  LogicValue _address(int index) =>
      LogicValue.ofInt(index, configuration.indexWidth);

  AssociativeSoftwareEntry _readEntry(int index) {
    final value = _storage.getData(_address(index));
    return value == null
        ? _emptyEntry()
        : (
            key: value.getRange(0, configuration.keyWidth),
            valid: value[configuration.keyWidth],
          );
  }

  List<AssociativeSoftwareEntry> get _entries =>
      List.generate(configuration.entryCount, _readEntry, growable: false);

  set _entries(List<AssociativeSoftwareEntry> entries) {
    _storage.loadSymbolicState({
      for (var index = 0; index < entries.length; index++)
        _address(index):
            LogicValue.of([entries[index].key, entries[index].valid])
    }, const [], replace: true);
  }

  /// Number of calls to [step] since creation or the last restored snapshot.
  int get cycle => _cycle;

  @override
  late final AssociativeSoftwareDescription description =
      AssociativeSoftwareDescription(configuration);

  @override
  BehavioralModel get behavioralModel => this;

  @override
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) =>
      description.generateSystemC(className: className, options: options);

  @override
  StateTransactionCapabilities get stateTransactionCapabilities =>
      StateTransactionCapabilities.software;

  @override
  late final StateTransactionEndpoint<AssociativeSoftwareExecutionImage>
      stateTransactions = SoftwareStateTransactionAdapter(
          snapshot: snapshotExecution, restore: restoreExecution);

  void _validateEntry(int index, AssociativeSoftwareEntry entry) {
    if (index < 0 || index >= configuration.entryCount) {
      throw RangeError.range(index, 0, configuration.entryCount - 1, 'index');
    }
    if (entry.key.width != configuration.keyWidth || entry.valid.width != 1) {
      throw ArgumentError('Associative entry widths do not match.');
    }
  }

  void _validateDuplicates(List<AssociativeSoftwareEntry> entries) {
    if (configuration.duplicateKeyPolicy ==
        AssociativeDuplicateKeyPolicy.allow) {
      return;
    }
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        final possibleDuplicate = entries[i].valid &
            entries[j].valid &
            storedValuesEqual(entries[i].key, entries[j].key);
        if (possibleDuplicate != LogicValue.zero) {
          throw StateError('Entries $i and $j may contain duplicate keys.');
        }
      }
    }
  }

  /// Reads key and validity without applying lookup semantics.
  AssociativeSoftwareEntry entry(int index) {
    if (index < 0 || index >= configuration.entryCount) {
      throw RangeError.range(index, 0, configuration.entryCount - 1, 'index');
    }
    return _readEntry(index);
  }

  /// Reads a key, or null when the entry is definitely invalid.
  @override
  LogicValue? peek(int address) {
    final value = entry(address);
    return value.valid == LogicValue.zero ? null : value.key;
  }

  @override
  LogicValue? peekBigInt(BigInt address) {
    if (address.isNegative ||
        address >= BigInt.from(configuration.entryCount)) {
      throw RangeError('Address $address is outside associative storage.');
    }
    return peek(address.toInt());
  }

  /// Writes a valid key without architectural update timing.
  @override
  void poke(int address, LogicValue value) =>
      writeEntry(address, key: value, valid: LogicValue.one);

  @override
  void pokeBigInt(BigInt address, LogicValue value) {
    if (address.isNegative ||
        address >= BigInt.from(configuration.entryCount)) {
      throw RangeError('Address $address is outside associative storage.');
    }
    poke(address.toInt(), value);
  }

  /// Writes raw key and validity, atomically validating duplicate policy.
  void writeEntry(int index,
      {required LogicValue key, required LogicValue valid}) {
    if (_updates.isNotEmpty) {
      throw StateError('Raw writes require pending updates to be drained.');
    }
    final value =
        (key: normalizeStoredValue(key), valid: normalizeStoredValue(valid));
    _validateEntry(index, value);
    final next = List<AssociativeSoftwareEntry>.of(_entries)..[index] = value;
    _validateDuplicates(next);
    _entries = next;
  }

  @override
  AssociativeSoftwareState snapshot() {
    final entries = _entries;
    return AssociativeSoftwareState(
      keyWidth: configuration.keyWidth,
      entryCount: configuration.entryCount,
      entries: {for (var i = 0; i < entries.length; i++) i: entries[i]},
    );
  }

  @override
  void load(AssociativeSoftwareState image, {bool replace = false}) {
    if (_updates.isNotEmpty) {
      throw StateError('Raw loads require pending updates to be drained.');
    }
    _load(image, replace: replace);
  }

  void _load(AssociativeSoftwareState image, {required bool replace}) {
    if (image.keyWidth != configuration.keyWidth ||
        image.entryCount != configuration.entryCount) {
      throw ArgumentError('Associative image geometry does not match.');
    }
    final next = replace
        ? List.generate(configuration.entryCount, (_) => _emptyEntry())
        : List<AssociativeSoftwareEntry>.of(_entries);
    for (final item in image.entries.entries) {
      _validateEntry(item.key, item.value);
      next[item.key] = (
        key: normalizeStoredValue(item.value.key),
        valid: normalizeStoredValue(item.value.valid),
      );
    }
    _validateDuplicates(next);
    _entries = next;
  }

  /// Invalidates all entries and cancels in-flight work.
  void reset() {
    if (configuration.requiredResetBehavior ==
        AssociativeMemoryResetBehavior.none) {
      throw UnsupportedError(
          'This configuration does not specify reset behavior.');
    }
    _storage.reset();
    _updates.clear();
    _lookups.clear();
  }

  void _validateLookup(AssociativeSoftwareLookup request) {
    if (request.key.width != configuration.keyWidth) {
      throw ArgumentError('Lookup key width does not match.');
    }
    switch (configuration.matchMode) {
      case AssociativeMatchMode.exact:
        if (request.mask != null || request.context != null) {
          throw ArgumentError(
              'Exact lookup does not accept a mask or context.');
        }
      case AssociativeMatchMode.masked:
        if (request.mask?.width != configuration.keyWidth ||
            request.context != null) {
          throw ArgumentError('Masked lookup requires a key-width mask.');
        }
      case AssociativeMatchMode.contextQualified:
        if (request.context == null || request.mask != null) {
          throw ArgumentError('Context-qualified lookup requires context.');
        }
    }
  }

  LogicValue _mux(LogicValue select, LogicValue yes, LogicValue no) =>
      selectLogicValue(select, yes, no);

  List<AssociativeSoftwareEntry> _applyUpdates(
      List<AssociativeSoftwareEntry> entries,
      Iterable<_PendingUpdate> updates) {
    final byIndex = <int, _PendingUpdate>{};
    for (final update in updates) {
      final existing = byIndex[update.request.index];
      if (existing != null) {
        switch (configuration.updateCollisionPolicy) {
          case AssociativeUpdateCollisionPolicy.disallow:
            throw StateError(
                'Multiple updates target entry ${update.request.index}.');
          case AssociativeUpdateCollisionPolicy.lowestPortWins:
            if (existing.port < update.port) {
              continue;
            }
          case AssociativeUpdateCollisionPolicy.highestPortWins:
            if (existing.port > update.port) {
              continue;
            }
        }
      }
      byIndex[update.request.index] = update;
    }
    final next = List<AssociativeSoftwareEntry>.of(entries);
    for (final update in byIndex.values) {
      next[update.request.index] =
          (key: update.request.key, valid: update.request.valid);
    }
    _validateDuplicates(next);
    return next;
  }

  AssociativeSoftwareResult _lookup(AssociativeSoftwareLookup lookup,
      List<AssociativeSoftwareEntry> entries) {
    final matches = <LogicValue>[];
    for (var index = 0; index < entries.length; index++) {
      final stored = entries[index];
      final equal = switch (configuration.matchMode) {
        AssociativeMatchMode.exact => storedValuesEqual(lookup.key, stored.key),
        AssociativeMatchMode.masked => storedValuesEqual(
            lookup.key & lookup.mask!, stored.key & lookup.mask!),
        AssociativeMatchMode.contextQualified =>
          matcher!(lookup: lookup, storedKey: stored.key, index: index),
      };
      if (equal.width != 1) {
        throw StateError('Associative matcher must return one bit.');
      }
      matches.add(stored.valid & equal);
    }
    final vector = LogicValue.of(matches);
    final indexWidth = max(1, (configuration.entryCount - 1).bitLength);
    var found = LogicValue.zero;
    var selected = LogicValue.filled(indexWidth, LogicValue.zero);
    for (var i = 0; i < matches.length; i++) {
      final candidate = LogicValue.ofInt(i, indexWidth);
      final preferred =
          configuration.matchSelection == AssociativeMatchSelection.lowestIndex
              ? candidate < selected
              : candidate > selected;
      final choose = matches[i] & (~found | preferred);
      selected = _mux(choose, candidate, selected);
      found |= matches[i];
    }
    final extended = LogicValue.of([
      selected,
      if (configuration.indexWidth > indexWidth)
        LogicValue.filled(
            configuration.indexWidth - indexWidth, LogicValue.zero),
    ]);
    return (
      hit: vector.or(),
      index: _mux(vector.or(), extended,
          LogicValue.filled(configuration.indexWidth, LogicValue.zero)),
      matchVector: vector,
    );
  }

  /// Samples requests and returns completions due on this step, by port.
  ///
  /// Validation and matching complete before any state is changed.
  List<AssociativeSoftwareResult?> step({
    required List<AssociativeSoftwareLookup?> lookups,
    required List<AssociativeSoftwareUpdate?> updates,
  }) {
    if (lookups.length != configuration.lookupPortCount ||
        updates.length != configuration.updatePortCount) {
      throw ArgumentError('Request counts do not match configured ports.');
    }
    lookups.nonNulls.forEach(_validateLookup);
    final newUpdates = <_PendingUpdate>[];
    for (var port = 0; port < updates.length; port++) {
      final update = updates[port];
      if (update == null) {
        continue;
      }
      _validateEntry(update.index, (key: update.key, valid: update.valid));
      newUpdates.add(_PendingUpdate(
          _cycle + configuration.updateLatency,
          port,
          AssociativeSoftwareUpdate(
              index: update.index,
              key: normalizeStoredValue(update.key),
              valid: normalizeStoredValue(update.valid))));
    }
    final allUpdates = [..._updates, ...newUpdates];
    final current = _entries;
    final dueUpdates =
        allUpdates.where((update) => update.due == _cycle).toList();
    final next = _applyUpdates(current, dueUpdates);
    var projected = next;
    final futureCycles = allUpdates
        .where((update) => update.due > _cycle)
        .map((update) => update.due)
        .toSet()
        .toList()
      ..sort();
    for (final due in futureCycles) {
      projected = _applyUpdates(
          projected, allUpdates.where((update) => update.due == due));
    }
    final lookupState = configuration.lookupUpdatePolicy ==
            AssociativeLookupUpdatePolicy.lookupBeforeUpdate
        ? current
        : next;
    final newLookups = <_PendingLookup>[];
    for (var port = 0; port < lookups.length; port++) {
      final lookup = lookups[port];
      if (lookup != null) {
        newLookups.add(_PendingLookup(_cycle + configuration.lookupLatency,
            port, _lookup(lookup, lookupState)));
      }
    }
    final dueLookups =
        [..._lookups, ...newLookups].where((lookup) => lookup.due == _cycle);
    final completed = List<AssociativeSoftwareResult?>.filled(
        configuration.lookupPortCount, null);
    for (final lookup in dueLookups) {
      completed[lookup.port] = lookup.result;
    }
    if (dueUpdates.isNotEmpty) {
      _entries = next;
    }
    _updates
      ..removeWhere((update) => update.due == _cycle)
      ..addAll(newUpdates.where((update) => update.due != _cycle));
    _lookups
      ..removeWhere((lookup) => lookup.due == _cycle)
      ..addAll(newLookups.where((lookup) => lookup.due != _cycle));
    _cycle++;
    return List.unmodifiable(completed);
  }

  /// Captures raw state and all in-flight operations.
  // ignore: use_to_and_as_if_applicable
  AssociativeSoftwareExecutionImage snapshotExecution() =>
      AssociativeSoftwareExecutionImage._(this);

  /// Atomically restores an execution image from a compatible configuration.
  void restoreExecution(AssociativeSoftwareExecutionImage image) {
    final other = image._configuration;
    final current = configuration;
    if (other.keyWidth != current.keyWidth ||
        other.indexWidth != current.indexWidth ||
        other.entryCount != current.entryCount ||
        other.updatePortCount != current.updatePortCount ||
        other.lookupPortCount != current.lookupPortCount ||
        other.lookupLatency != current.lookupLatency ||
        other.updateLatency != current.updateLatency ||
        other.duplicateKeyPolicy != current.duplicateKeyPolicy ||
        other.matchSelection != current.matchSelection ||
        other.matchMode != current.matchMode ||
        other.resultShape != current.resultShape ||
        other.lookupUpdatePolicy != current.lookupUpdatePolicy ||
        other.updateCollisionPolicy != current.updateCollisionPolicy ||
        other.requiredResetBehavior != current.requiredResetBehavior ||
        other.requiredResetTiming != current.requiredResetTiming ||
        !identical(image._matcher, matcher)) {
      throw ArgumentError('Associative execution image configuration differs.');
    }
    _load(image._state, replace: true);
    _cycle = image._cycle;
    _updates
      ..clear()
      ..addAll(image._updates);
    _lookups
      ..clear()
      ..addAll(image._lookups);
  }
}

/// Software equivalent of the combinational-lookup parallel-flop memory.
///
/// Lookup, validity and indexed side-read outputs react combinationally.
/// Updates and synchronous reset are sampled on the rising edge.
class BehavioralParallelAssociativeMemory extends AssociativeMemory
    with SystemVerilog
    implements
        AssociativeIndexedSideReadProvider,
        AssociativeMultiIndexedSideReadProvider,
        AssociativeValidityMaskProvider,
        BehavioralModel,
        BehavioralModelProvider,
        StateTransactionProvider<AssociativeSoftwareExecutionImage>,
        StateTransactionCapabilityProvider {
  /// Whether validity tracking outputs are present.
  final bool enableValidTracking;
  final List<AssociativeIndexedSideReadRequest> _sideReads;
  final List<Logic> _sideIndices = [];
  late final AssociativeSoftwareModel _model;
  late final void Function() _refresh;

  @override
  late final BehavioralParallelAssociativeDescription description;

  @override
  BehavioralModel get behavioralModel => this;

  @override
  String generateSystemC({
    required String className,
    SystemCModelOptions options = const SystemCModelOptions(),
  }) =>
      description.generateSystemC(className: className, options: options);

  @override
  final List<AssociativeIndexedSideReadResponse> sideReadResponses;

  @override
  AssociativeIndexedSideReadResponse? get sideReadResponse =>
      sideReadResponses.isEmpty ? null : sideReadResponses.first;

  @override
  Logic? get validMask => enableValidTracking ? output('valid_mask') : null;

  /// The number of valid entries, if validity tracking is enabled.
  Logic? get validCount => enableValidTracking ? output('valid_count') : null;

  /// Whether all entries are valid, if validity tracking is enabled.
  Logic? get full => enableValidTracking ? output('full') : null;

  /// Whether all entries are invalid, if validity tracking is enabled.
  Logic? get empty => enableValidTracking ? output('empty') : null;

  @override
  StateTransactionCapabilities get stateTransactionCapabilities =>
      StateTransactionCapabilities.software;

  @override
  late final StateTransactionEndpoint<AssociativeSoftwareExecutionImage>
      stateTransactions =
      SoftwareStateTransactionAdapter(snapshot: snapshot, restore: restore);

  /// Creates a simulation-only implementation of the parallel RTL contract.
  BehavioralParallelAssociativeMemory({
    required super.clk,
    required super.reset,
    required super.updates,
    required super.lookups,
    required super.entryCount,
    required super.contract,
    this.enableValidTracking = false,
    List<AssociativeIndexedSideReadRequest> sideReadRequests = const [],
    super.name = 'behavioral_parallel_associative_memory',
  })  : _sideReads = List.unmodifiable(sideReadRequests),
        sideReadResponses = List.unmodifiable([
          for (final _ in sideReadRequests)
            AssociativeIndexedSideReadResponse(keyWidth: lookups.first.keyWidth)
        ]),
        super(definitionName: 'BehavioralParallelAssociativeMemory') {
    if (contract.implementationKind !=
            AssociativeMemoryImplementationKind.simulationOnly ||
        contract.lookupLatency != 0 ||
        contract.updateLatency != 0 ||
        contract.duplicateKeyPolicy != AssociativeDuplicateKeyPolicy.allow ||
        contract.lookupUpdatePolicy !=
            AssociativeLookupUpdatePolicy.lookupAfterUpdate ||
        contract.updateCollisionPolicy ==
            AssociativeUpdateCollisionPolicy.disallow ||
        contract.resetBehavior !=
            AssociativeMemoryResetBehavior.clearValidity ||
        contract.resetTiming != AssociativeMemoryResetTiming.synchronous ||
        _sideReads.any((request) => request.index.width != indexWidth)) {
      throw ArgumentError('The behavioral parallel associative memory requires '
          'the parallel RTL contract.');
    }
    _model = AssociativeSoftwareModel(AssociativeMemoryRequest(
      keyWidth: keyWidth,
      indexWidth: indexWidth,
      entryCount: entryCount,
      updatePortCount: numUpdates,
      lookupPortCount: numLookups,
      lookupLatency: 0,
      duplicateKeyPolicy: contract.duplicateKeyPolicy,
      matchSelection: contract.matchSelection,
      resultShape: contract.resultShape,
      lookupUpdatePolicy: contract.lookupUpdatePolicy,
      updateCollisionPolicy: contract.updateCollisionPolicy,
      requiredResetBehavior: contract.resetBehavior,
    ));
    description = BehavioralParallelAssociativeDescription(
      entryCount: entryCount,
      keyWidth: keyWidth,
      indexWidth: indexWidth,
      updateCount: numUpdates,
      matchVectors: [
        for (final lookup in localLookups) lookup.matchVector != null
      ],
      sideReadCount: _sideReads.length,
      trackValidity: enableValidTracking,
      selection: contract.matchSelection,
      collision: contract.updateCollisionPolicy,
    );
    _model._entries = List.generate(
        entryCount,
        (_) => (
              key: LogicValue.filled(keyWidth, LogicValue.x),
              valid: LogicValue.x
            ));

    if (enableValidTracking) {
      addOutput('valid_count', width: (entryCount + 1).log2Ceil);
      addOutput('full');
      addOutput('empty');
      addOutput('valid_mask', width: entryCount);
    }
    for (final (port, request) in _sideReads.indexed) {
      final suffix = port == 0 ? '' : '_$port';
      _sideIndices.add(
          addInput('side_read_index$suffix', request.index, width: indexWidth));
      final key = addOutput('side_read_key$suffix', width: keyWidth);
      final valid = addOutput('side_read_valid$suffix');
      sideReadResponses[port].key <= key;
      sideReadResponses[port].entryValid <= valid;
    }

    void refreshLookup(AssociativeLookupPortInterface lookup) {
      final entries = _model._entries;
      final result = _model._lookup(
          AssociativeSoftwareLookup(key: lookup.key.value), entries);
      final enabledHit = lookup.en.value & result.hit;
      lookup.hit.put(enabledHit);
      lookup.index.put(selectLogicValue(enabledHit, result.index,
          LogicValue.filled(indexWidth, LogicValue.zero)));
      lookup.matchVector?.put(selectLogicValue(lookup.en.value,
          result.matchVector, LogicValue.filled(entryCount, LogicValue.zero)));
    }

    void refreshSide(int port) {
      final value = _sideIndices[port].value;
      final AssociativeSoftwareEntry entry;
      if (!value.isValid) {
        entry = (
          key: LogicValue.filled(keyWidth, LogicValue.x),
          valid: LogicValue.x
        );
      } else if (value.toBigInt() >= BigInt.from(entryCount)) {
        entry = _model._emptyEntry();
      } else {
        entry = _model._readEntry(value.toInt());
      }
      final suffix = port == 0 ? '' : '_$port';
      output('side_read_key$suffix').put(entry.key);
      output('side_read_valid$suffix').put(entry.valid);
    }

    void refresh() {
      final entries = _model._entries;
      if (enableValidTracking) {
        final mask = LogicValue.of([for (final entry in entries) entry.valid]);
        final width = (entryCount + 1).log2Ceil;
        var count = LogicValue.filled(width, LogicValue.zero);
        for (final entry in entries) {
          count += entry.valid.zeroExtend(width);
        }
        validCount!.put(count);
        full!.put(mask.and());
        empty!.put(~mask.or());
        validMask!.put(mask);
      }
      localLookups.forEach(refreshLookup);
      for (var port = 0; port < _sideIndices.length; port++) {
        refreshSide(port);
      }
    }

    _refresh = refresh;
    for (final lookup in localLookups) {
      lookup.en.glitch.listen((_) => refreshLookup(lookup));
      lookup.key.glitch.listen((_) => refreshLookup(lookup));
    }
    for (final (port, index) in _sideIndices.indexed) {
      index.glitch.listen((_) => refreshSide(port));
    }
    clk.changed.listen((event) {
      if (!event.previousValue.isValid || !event.newValue.isValid) {
        _model._entries = List.generate(
            entryCount,
            (_) => (
                  key: LogicValue.filled(keyWidth, LogicValue.x),
                  valid: LogicValue.x
                ));
        refresh();
        return;
      }
      if (event.previousValue != LogicValue.zero ||
          event.newValue != LogicValue.one) {
        return;
      }
      final resetValue = reset.previousValue!;
      final entries = _model._entries;
      if (resetValue == LogicValue.one) {
        _model._entries =
            List.generate(entryCount, (_) => _model._emptyEntry());
      } else if (resetValue != LogicValue.zero) {
        _model._entries = List.generate(
            entryCount,
            (_) => (
                  key: LogicValue.filled(keyWidth, LogicValue.x),
                  valid: LogicValue.x
                ));
      } else {
        final ordered = contract.updateCollisionPolicy ==
                AssociativeUpdateCollisionPolicy.lowestPortWins
            ? localUpdates.reversed
            : localUpdates;
        for (var index = 0; index < entryCount; index++) {
          for (final update in ordered) {
            final select = update.en.previousValue! &
                storedValueIndexMatches(update.index.previousValue!, index);
            if (select == LogicValue.one) {
              entries[index] = (
                key: normalizeStoredValue(update.key.previousValue!),
                valid: normalizeStoredValue(update.entryValid.previousValue!)
              );
            } else if (select != LogicValue.zero) {
              entries[index] = (
                key: LogicValue.filled(keyWidth, LogicValue.x),
                valid: LogicValue.x
              );
            }
          }
        }
        _model._entries = entries;
      }
      refresh();
    });
    Simulator.injectAction(refresh);
  }

  /// Captures the resident entries for replay.
  AssociativeSoftwareExecutionImage snapshot() => _model.snapshotExecution();

  /// Restores a compatible image and refreshes combinational outputs.
  void restore(AssociativeSoftwareExecutionImage image) {
    _model.restoreExecution(image);
    _refresh();
  }

  @override
  DefinitionGenerationType get generatedDefinitionType =>
      DefinitionGenerationType.custom;

  @override
  String? definitionVerilog(String definitionType) => throw UnsupportedError(
      'Behavioral parallel associative memory cannot be exported as RTL.');
}

/// Simulation-only parallel associative storage for cache tag factories.
const behavioralParallelAssociativeMemoryFunctor = AssociativeMemoryFunctor(
  identity: 'behavioralParallel',
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
    implementationKind: AssociativeMemoryImplementationKind.simulationOnly,
    sustainsOneLookupPerPortPerCycle: true,
    supportsIndexedSideRead: true,
    maximumIndexedSideReads: null,
    supportsValidityMask: true,
    stateTransactions: StateTransactionCapabilities.software,
  ),
  build: _buildBehavioralParallel,
  buildMultipleSideReads: _buildBehavioralParallelWithSideReads,
);

AssociativeMemory _buildBehavioralParallel({
  required Logic clk,
  required Logic reset,
  required List<AssociativeUpdatePortInterface> updatePorts,
  required List<AssociativeLookupPortInterface> lookupPorts,
  required AssociativeMemoryRequest request,
  required AssociativeMemoryContract contract,
  required String name,
}) =>
    BehavioralParallelAssociativeMemory(
      clk: clk,
      reset: reset,
      updates: updatePorts,
      lookups: lookupPorts,
      entryCount: request.entryCount,
      contract: contract,
      enableValidTracking: request.requiresValidityMask,
      name: name,
    );

AssociativeMemory _buildBehavioralParallelWithSideReads({
  required Logic clk,
  required Logic reset,
  required List<AssociativeUpdatePortInterface> updatePorts,
  required List<AssociativeLookupPortInterface> lookupPorts,
  required List<AssociativeIndexedSideReadRequest> sideReadRequests,
  required AssociativeMemoryRequest request,
  required AssociativeMemoryContract contract,
  required String name,
}) =>
    BehavioralParallelAssociativeMemory(
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
