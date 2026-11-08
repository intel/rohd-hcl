// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache.dart
// Blocking cache composition.
//
// 2026 November 7
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory_contract.dart';
import 'package:rohd_hcl/src/memory/associative/parallel_associative_memory.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';
import 'package:rohd_hcl/src/memory/contracts/memory_array.dart';
import 'package:rohd_hcl/src/memory/replacement/behavioral_replacement.dart';
import 'package:rohd_hcl/src/memory/replacement/replacement_policy.dart';
import 'package:rohd_hcl/src/memory/replacement/replacement_reservations.dart';
import 'package:rohd_hcl/src/memory/replacement/round_robin_replacement.dart';
import 'package:rohd_hcl/src/memory/replacement/tree_pseudo_lru_replacement.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';
import 'package:rohd_hcl/src/memory/storage/memory_array_factories.dart';
import 'package:rohd_hcl/src/memory/storage/register_file.dart';
import 'package:rohd_hcl/src/models/memory/memory_model.dart';

/// Builds the replacement policy for one cache set.
@experimental
typedef CacheReplacementBuilder = ReplacementPolicy Function({
  required Logic clk,
  required Logic reset,
  required Logic validMask,
  required Logic eligibleMask,
  required List<ReplacementAccessInterface> accesses,
  required List<ReplacementAllocationInterface> allocations,
  required int entryCount,
  required String name,
});

/// Builds a policy with ports for previously reserved allocation commits.
@experimental
typedef CacheReplacementDeferredBuilder = ReplacementPolicy Function({
  required Logic clk,
  required Logic reset,
  required Logic validMask,
  required Logic eligibleMask,
  required List<ReplacementAccessInterface> accesses,
  required List<ReplacementAllocationInterface> allocations,
  required List<ReplacementCommitInterface> commits,
  required int entryCount,
  required String name,
});

/// Factory for the replacement policy used independently in each cache set.
@experimental
class CacheReplacement {
  /// Stable, unique identity used in generated module names.
  final String identity;

  /// Builds one policy instance on the supplied ports.
  final CacheReplacementBuilder build;

  /// Optional builder supporting deferred commits by reserved way.
  final CacheReplacementDeferredBuilder? buildWithCommits;

  /// Creates a replacement-policy factory.
  const CacheReplacement({
    required this.identity,
    required this.build,
    this.buildWithCommits,
  });

  /// Rotates through the ways after allocations.
  static const roundRobin = CacheReplacement(
      identity: 'roundRobin',
      build: RoundRobinReplacement.new,
      buildWithCommits: RoundRobinReplacement.new);

  /// Approximates least-recent use with a binary tree.
  static const treePseudoLru = CacheReplacement(
      identity: 'treePseudoLru',
      build: TreePseudoLruReplacement.new,
      buildWithCommits: TreePseudoLruReplacement.new);

  /// Simulation-only policy using the standard replacement port protocol.
  factory CacheReplacement.behavioral(BehavioralReplacementKind kind) {
    ReplacementPolicy build({
      required Logic clk,
      required Logic reset,
      required Logic validMask,
      required Logic eligibleMask,
      required List<ReplacementAccessInterface> accesses,
      required List<ReplacementAllocationInterface> allocations,
      required int entryCount,
      required String name,
      List<ReplacementCommitInterface> commits = const [],
    }) =>
        BehavioralReplacementPolicy(
          clk: clk,
          reset: reset,
          validMask: validMask,
          eligibleMask: eligibleMask,
          accesses: accesses,
          allocations: allocations,
          commits: commits,
          entryCount: entryCount,
          kind: kind,
          name: name,
        );
    return CacheReplacement(
      identity: 'behavioral_${kind.name}',
      build: build,
      buildWithCommits: build,
    );
  }
}

/// Data storage used by a cache set.
@experimental
enum CacheDataStorage {
  /// Synthesizable flop-based data storage.
  registerFile,

  /// Simulation-only sparse behavioral data storage.
  behavioral,
}

MemoryArrayFunctor<T> _cacheDataMemory<T extends Logic>(
        CacheDataStorage storage) =>
    switch (storage) {
      CacheDataStorage.registerFile => registerFileArray<T>(),
      CacheDataStorage.behavioral => behavioralRegisterFileArray<T>(),
    };

/// Lookup behavior when a fill for the same block is accepted.
@experimental
enum CacheReadDuringFill {
  /// Return the state before the sampling edge.
  oldData,

  /// Return the incoming fill data on the accepting cycle.
  forward,
}

/// Arbitration for independently buffered eviction responses.
@experimental
enum CacheEvictionConcurrency {
  /// Present all pending evictions independently.
  parallel,

  /// Present the lowest-numbered pending eviction only.
  oneAtATime,
}

/// One caller-owned cache lookup interface.
@experimental
class CacheLookupPort<T extends Logic> extends PairInterface {
  /// Lookup request valid.
  Logic get valid => port('valid');

  /// Requested block address.
  Logic get address => port('address');

  /// Whether this lookup is accepted.
  Logic get ready => port('ready');

  /// Whether the accepted lookup found a matching block.
  Logic get hit => port('hit');

  /// Lookup data.
  T get data => port('data') as T;

  /// Creates a lookup port with a typed data schema.
  CacheLookupPort({required int addressWidth, required T dataSchema})
      : super(
          portsFromProvider: [
            Logic.port('valid'),
            Logic.port('address', addressWidth),
          ],
          portsFromConsumer: [
            Logic.port('ready'),
            Logic.port('hit'),
            dataSchema.cloneTyped(name: 'data'),
          ],
        );

  @override
  CacheLookupPort<T> clone() =>
      CacheLookupPort<T>(addressWidth: address.width, dataSchema: data);
}

/// One caller-owned fill port and its associated eviction response.
@experimental
class CacheFillPort<T extends Logic> extends PairInterface {
  /// Fill request valid.
  Logic get valid => port('valid');

  /// Block to fill.
  Logic get address => port('address');

  /// Data to fill.
  T get data => port('data') as T;

  /// Whether the fill is accepted.
  Logic get ready => port('ready');

  /// Whether the eviction consumer can accept a response.
  Logic get evictionReady => port('evictionReady');

  /// Whether an eviction response is available.
  Logic get evictionValid => port('evictionValid');

  /// Address of the evicted block.
  Logic get evictionAddress => port('evictionAddress');

  /// Data of the evicted block.
  T get evictionData => port('evictionData') as T;

  /// Creates a fill port with a typed data schema.
  CacheFillPort({required int addressWidth, required T dataSchema})
      : super(
          portsFromProvider: [
            Logic.port('valid'),
            Logic.port('address', addressWidth),
            dataSchema.cloneTyped(name: 'data'),
            Logic.port('evictionReady'),
          ],
          portsFromConsumer: [
            Logic.port('ready'),
            Logic.port('evictionValid'),
            Logic.port('evictionAddress', addressWidth),
            dataSchema.cloneTyped(name: 'evictionData'),
          ],
        );

  @override
  CacheFillPort<T> clone() =>
      CacheFillPort<T>(addressWidth: address.width, dataSchema: data);
}

String _cacheFillSignalName(String signal, {String index = ''}) =>
    switch (signal) {
      'evictionReady' => 'eviction_${index}ready',
      'evictionValid' => 'eviction_${index}valid',
      'evictionAddress' => 'eviction_${index}address',
      'evictionData' => 'eviction_${index}data',
      _ => 'fill_$index$signal',
    };

/// A blocking cache with caller-managed fills and evictions.
///
/// Addresses are block addresses. The low bits select a set; the complete
/// address is stored as the key. The default tag implementation uses parallel
/// flops. Data uses a [RegisterFile] or a simulation-only [MemoryModel], both
/// with combinational reads.
///
/// A fill transfers when its port's valid and ready are high on a rising edge.
/// If it replaces a valid entry,
/// the fill port presents that entry and the fill waits for eviction ready.
/// The caller must hold fill valid, address, and data stable until transfer.
/// Lookups can proceed alongside fills that do not require eviction.
/// Lookups are blocked while an eviction is offered. An enabled lookup is
/// combinational and accepted when the lookup port's ready is high.
///
/// Reset synchronously invalidates all entries and resets replacement state.
/// Reset suppresses transfers. No backing-store accesses are performed.
/// {@category Memory}
@experimental
class Cache<T extends Logic> extends Module {
  /// Number of sets.
  final int setCount;

  /// Number of entries in each set.
  final int waysPerSet;

  /// Replacement policy used in each set.
  final CacheReplacement replacement;

  /// Data implementation used independently in each set.
  ///
  /// This selects the default when no `dataMemory` factory is supplied.
  final CacheDataStorage dataStorage;

  /// Lookup behavior for simultaneous fills of the same block.
  final CacheReadDuringFill readDuringFill;

  /// Creates a cache with an explicit number of sets and ways.
  Cache({
    required Logic clk,
    required Logic reset,
    required CacheLookupPort<T> lookup,
    required CacheFillPort<T> fill,
    required this.setCount,
    required this.waysPerSet,
    this.replacement = CacheReplacement.roundRobin,
    this.dataStorage = CacheDataStorage.registerFile,
    MemoryArrayFunctor<T>? dataMemory,
    this.readDuringFill = CacheReadDuringFill.oldData,
    AssociativeMemoryFunctor tagMemory = parallelAssociativeMemoryFunctor,
    super.name = 'cache',
  }) : super(
          definitionName: 'Cache_S${setCount}_W${waysPerSet}_'
              'A${fill.address.width}_${payloadShapeIdentity(fill.data)}_'
              '${replacement.identity}_'
              '${dataMemory?.identity ?? dataStorage.name}_'
              '${readDuringFill.name}_'
              '${tagMemory.identity}',
        ) {
    if (setCount < 1 || (setCount & (setCount - 1)) != 0) {
      throw ArgumentError.value(setCount, 'setCount', 'Must be a power of 2.');
    }

    if (waysPerSet < 1) {
      throw ArgumentError.value(waysPerSet, 'waysPerSet', 'Must be positive.');
    }
    final setBits = (setCount - 1).bitLength;
    if (fill.address.width < max(1, setBits) ||
        lookup.address.width != fill.address.width) {
      throw ArgumentError(
          'Cache address widths must match and address all sets.');
    }
    if (clk.width != 1 || reset.width != 1) {
      throw ArgumentError('Clock and reset must be bits.');
    }
    if (!sameDeclaredPayloadShape(fill.data, lookup.data)) {
      throw ArgumentError('Cache port payload shapes must match.');
    }

    final fillAddress = fill.address;
    final fillData = fill.data;
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localLookup = addInterfacePorts(lookup,
        inputTags: [PairDirection.fromProvider],
        outputTags: [PairDirection.fromConsumer],
        uniquify: (signal) => 'lookup_$signal');
    final localFill = addInterfacePorts(fill,
        inputTags: [PairDirection.fromProvider],
        outputTags: [PairDirection.fromConsumer],
        uniquify: _cacheFillSignalName);
    final localLookupValid = localLookup.valid;
    final localLookupAddress = localLookup.address;
    final localFillValid = localFill.valid;
    final localFillAddress = localFill.address;
    final localFillData = localFill.data;
    final localEvictionReady = localFill.evictionReady;
    final localLookupReady = localLookup.ready;

    final fillAccepted = Logic(name: 'fill_accepted');
    final lookupHits = <Logic>[];
    final lookupDataBySet = <Logic>[];
    final readyBySet = <Logic>[];
    final evictBySet = <Logic>[];
    final evictAddressBySet = <Logic>[];
    final evictDataBySet = <Logic>[];
    final evictionDemandBySet = <Logic>[];
    final wayWidth = max(1, (waysPerSet - 1).bitLength);

    Logic selects(Logic address, int set) => setBits == 0
        ? Const(1)
        : storedIndexMatches(address.getRange(0, setBits), set);

    for (var set = 0; set < setCount; set++) {
      final lookupSelected = selects(localLookupAddress, set);
      final fillSelected = selects(localFillAddress, set);
      final update = AssociativeUpdatePortInterface(
          keyWidth: fillAddress.width, indexWidth: wayWidth);
      final lookup = AssociativeLookupPortInterface(
          keyWidth: fillAddress.width, indexWidth: wayWidth);
      final fillLookup = AssociativeLookupPortInterface(
          keyWidth: fillAddress.width, indexWidth: wayWidth);
      final sideRead = AssociativeIndexedSideReadRequest(indexWidth: wayWidth);
      final lookupAccess = ReplacementAccessInterface(waysPerSet);
      final fillAccess = ReplacementAccessInterface(waysPerSet);
      final allocation = ReplacementAllocationInterface(waysPerSet);
      final dataWrite = DataPortInterface<T>.typed(localFillData, wayWidth);
      final dataLookup = DataPortInterface<T>.typed(localFillData, wayWidth);
      final dataEviction = DataPortInterface<T>.typed(localFillData, wayWidth);

      lookup.en <= localLookupReady & localLookupValid & lookupSelected;
      lookup.key <= localLookupAddress;
      fillLookup.en <= localFillValid & ~localReset & fillSelected;
      fillLookup.key <= localFillAddress;
      allocation.en <= fillLookup.en & ~fillLookup.hit;
      allocation.commit <= fillAccepted & fillSelected & ~fillLookup.hit;
      lookupAccess.en <= lookup.hit;
      lookupAccess.index <= lookup.index;
      fillAccess.en <= fillLookup.hit;
      fillAccess.index <= fillLookup.index;
      final selectedWay =
          mux(fillLookup.hit, fillLookup.index, allocation.index);
      update.en <= fillAccepted & fillSelected;
      update.index <= selectedWay;
      update.key <= localFillAddress;
      update.entryValid <= Const(1);
      sideRead.index <= allocation.index;

      final binding = tagMemory(
        clk: localClk,
        reset: localReset,
        updatePorts: [update],
        lookupPorts: [lookup, fillLookup],
        entryCount: waysPerSet,
        sideReadRequest: sideRead,
        requiresValidityMask: true,
        lookupLatency: 0,
        duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
        matchSelection: AssociativeMatchSelection.lowestIndex,
        resultShape: AssociativeResultShape.selectedIndex,
        lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
        updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
        requiredResetBehavior: AssociativeMemoryResetBehavior.clearValidity,
        name: 'tags_$set',
      );
      final tags = binding.memory!;
      final validity = (tags as AssociativeValidityMaskProvider).validMask!;
      final sideResponse =
          (tags as AssociativeIndexedSideReadProvider).sideReadResponse!;
      final eligible =
          Const((BigInt.one << waysPerSet) - BigInt.one, width: waysPerSet);
      final policy = replacement.build(
        clk: localClk,
        reset: localReset,
        validMask: validity,
        eligibleMask: eligible,
        accesses: [lookupAccess, fillAccess],
        allocations: [allocation],
        entryCount: waysPerSet,
        name: 'replacement_$set',
      );
      if (policy.entryCount != waysPerSet) {
        throw StateError('Replacement factory ${replacement.identity} '
            'built a policy with an incompatible entry count.');
      }

      dataWrite.en <= update.en;
      dataWrite.addr <= selectedWay;
      dataWrite.data <= localFillData;
      dataLookup.en <= lookup.hit;
      dataLookup.addr <= lookup.index;
      dataEviction.en <= allocation.evict;
      dataEviction.addr <= allocation.index;
      (dataMemory ?? _cacheDataMemory<T>(dataStorage))(
        clk: localClk,
        reset: localReset,
        writePorts: [dataWrite],
        readPorts: [dataLookup, dataEviction],
        entryCount: waysPerSet,
        readLatency: 0,
        maxConcurrentReads: 2,
        maxConcurrentWrites: 1,
        name: 'data_$set',
      );

      lookupHits.add(lookup.hit);
      lookupDataBySet.add(
          mux(lookup.hit, dataLookup.data, Const(0, width: fillData.width)));
      readyBySet.add(fillSelected &
          (fillLookup.hit |
              (allocation.valid & (~allocation.evict | localEvictionReady))));
      evictBySet.add(allocation.evict);
      evictionDemandBySet.add(fillLookup.en & ~fillLookup.hit & validity.and());
      evictAddressBySet.add(mux(allocation.evict, sideResponse.key,
          Const(0, width: fillAddress.width)));
      evictDataBySet.add(mux(allocation.evict, dataEviction.data,
          Const(0, width: fillData.width)));
    }

    Logic combine(List<Logic> values) =>
        values.reduce((left, right) => left | right);
    localLookupReady <= ~localReset & ~combine(evictionDemandBySet);
    localFill.ready <= ~localReset & combine(readyBySet);
    fillAccepted <= localFillValid & localFill.ready;
    final forward = readDuringFill == CacheReadDuringFill.forward
        ? localLookupReady &
            localLookupValid &
            fillAccepted &
            storedAddressMatches(localLookupAddress, localFillAddress)
        : Const(0);
    localLookup.hit <= forward | combine(lookupHits);
    localLookup.data <=
        mux(forward, normalizeStoredLogic(localFillData),
            combine(lookupDataBySet));
    localFill.evictionValid <= combine(evictBySet);
    localFill.evictionAddress <= combine(evictAddressBySet);
    localFill.evictionData <= combine(evictDataBySet);
  }

  /// Creates a direct-mapped cache with [entryCount] sets.
  Cache.directMapped({
    required Logic clk,
    required Logic reset,
    required CacheLookupPort<T> lookup,
    required CacheFillPort<T> fill,
    required int entryCount,
    CacheDataStorage dataStorage = CacheDataStorage.registerFile,
    MemoryArrayFunctor<T>? dataMemory,
    CacheReadDuringFill readDuringFill = CacheReadDuringFill.oldData,
    AssociativeMemoryFunctor tagMemory = parallelAssociativeMemoryFunctor,
    String name = 'direct_mapped_cache',
  }) : this(
          clk: clk,
          reset: reset,
          lookup: lookup,
          fill: fill,
          setCount: entryCount,
          waysPerSet: 1,
          dataStorage: dataStorage,
          dataMemory: dataMemory,
          readDuringFill: readDuringFill,
          tagMemory: tagMemory,
          name: name,
        );

  /// Creates a set-associative cache.
  Cache.setAssociative({
    required Logic clk,
    required Logic reset,
    required CacheLookupPort<T> lookup,
    required CacheFillPort<T> fill,
    required int setCount,
    required int waysPerSet,
    CacheReplacement replacement = CacheReplacement.roundRobin,
    CacheDataStorage dataStorage = CacheDataStorage.registerFile,
    MemoryArrayFunctor<T>? dataMemory,
    CacheReadDuringFill readDuringFill = CacheReadDuringFill.oldData,
    AssociativeMemoryFunctor tagMemory = parallelAssociativeMemoryFunctor,
    String name = 'set_associative_cache',
  }) : this(
          clk: clk,
          reset: reset,
          lookup: lookup,
          fill: fill,
          setCount: setCount,
          waysPerSet: waysPerSet,
          replacement: replacement,
          dataStorage: dataStorage,
          dataMemory: dataMemory,
          readDuringFill: readDuringFill,
          tagMemory: tagMemory,
          name: name,
        );

  /// Creates a fully associative cache with [entryCount] ways.
  Cache.fullyAssociative({
    required Logic clk,
    required Logic reset,
    required CacheLookupPort<T> lookup,
    required CacheFillPort<T> fill,
    required int entryCount,
    CacheReplacement replacement = CacheReplacement.roundRobin,
    CacheDataStorage dataStorage = CacheDataStorage.registerFile,
    MemoryArrayFunctor<T>? dataMemory,
    CacheReadDuringFill readDuringFill = CacheReadDuringFill.oldData,
    AssociativeMemoryFunctor tagMemory = parallelAssociativeMemoryFunctor,
    String name = 'fully_associative_cache',
  }) : this(
          clk: clk,
          reset: reset,
          lookup: lookup,
          fill: fill,
          setCount: 1,
          waysPerSet: entryCount,
          replacement: replacement,
          dataStorage: dataStorage,
          dataMemory: dataMemory,
          readDuringFill: readDuringFill,
          tagMemory: tagMemory,
          name: name,
        );
}

/// A multi-port cache with independently buffered eviction responses.
///
/// By default each set accepts at most one fill per cycle. Set
/// [maxFillsPerSet] above one to permit fills to distinct ways in the same
/// set. Conflicting same-block fills give priority to lower-numbered ports.
/// A fill handshake transfers ownership of the request to the
/// cache; a valid victim is buffered before the entry is overwritten.
/// With one fill per set, replacement advances on acceptance. With multiple
/// fills per set, an eviction's replacement update is deferred until its
/// eviction handshake; other accepted fills update it on acceptance.
/// While any eviction is pending, new lookups and fills are blocked.
/// Reset cancels buffered fills and eviction responses.
///
/// Tags use a capability-checked associative-memory functor. Data uses
/// zero-latency register-file or behavioral storage; this implementation
/// does not yet support latency-bearing SRAM.
/// {@category Memory}
@experimental
class MultiPortCache<T extends Logic> extends Module {
  /// Number of sets.
  final int setCount;

  /// Number of ways per set.
  final int waysPerSet;

  /// Maximum fill requests selected for a set in one cycle.
  final int maxFillsPerSet;

  /// Creates a cache with multiple lookup and fill ports.
  MultiPortCache({
    required Logic clk,
    required Logic reset,
    required List<CacheLookupPort<T>> lookups,
    required List<CacheFillPort<T>> fills,
    required this.setCount,
    required this.waysPerSet,
    this.maxFillsPerSet = 1,
    CacheReplacement replacement = CacheReplacement.roundRobin,
    CacheDataStorage dataStorage = CacheDataStorage.registerFile,
    MemoryArrayFunctor<T>? dataMemory,
    CacheReadDuringFill readDuringFill = CacheReadDuringFill.oldData,
    CacheEvictionConcurrency evictionConcurrency =
        CacheEvictionConcurrency.parallel,
    AssociativeMemoryFunctor tagMemory = parallelAssociativeMemoryFunctor,
    super.name = 'multi_port_cache',
  }) : super(
          definitionName: 'MultiPortCache_S${setCount}_W${waysPerSet}_'
              'R${lookups.length}_F${fills.length}_'
              'A${fills.isEmpty ? 0 : fills.first.address.width}_'
              '${fills.isEmpty ? 'D0' : payloadShapeIdentity(fills.first.data)}'
              '_'
              '${replacement.identity}_'
              '${dataMemory?.identity ?? dataStorage.name}_'
              '${readDuringFill.name}_${evictionConcurrency.name}_'
              '${tagMemory.identity}'
              '${maxFillsPerSet == 1 ? '' : '_P$maxFillsPerSet'}',
        ) {
    if (lookups.isEmpty || fills.isEmpty) {
      throw ArgumentError('At least one lookup and fill port are required.');
    }
    if (maxFillsPerSet < 1 || maxFillsPerSet > fills.length) {
      throw ArgumentError.value(maxFillsPerSet, 'maxFillsPerSet',
          'Must be positive and no greater than the fill port count.');
    }
    if (maxFillsPerSet > 1 && replacement.buildWithCommits == null) {
      throw ArgumentError('Multi-fill sets require a replacement factory '
          'that supports deferred commits.');
    }
    if (setCount < 1 || (setCount & (setCount - 1)) != 0 || waysPerSet < 1) {
      throw ArgumentError(
          'Set count must be a power of two and ways positive.');
    }
    final addressWidth = fills.first.address.width;
    final dataWidth = fills.first.data.width;
    final setBits = (setCount - 1).bitLength;
    final wayWidth = max(1, (waysPerSet - 1).bitLength);
    if (addressWidth < max(1, setBits) ||
        clk.width != 1 ||
        reset.width != 1 ||
        lookups.any((port) =>
            port.address.width != addressWidth ||
            !sameDeclaredPayloadShape(fills.first.data, port.data)) ||
        fills.any((port) =>
            port.address.width != addressWidth ||
            !sameDeclaredPayloadShape(fills.first.data, port.data))) {
      throw ArgumentError('Cache port widths, payload shapes, or control '
          'signals do not match.');
    }
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localLookups = [
      for (var i = 0; i < lookups.length; i++)
        addInterfacePorts(lookups[i],
            inputTags: [PairDirection.fromProvider],
            outputTags: [PairDirection.fromConsumer],
            uniquify: (signal) => 'lookup_${i}_$signal')
    ];
    final localFills = [
      for (var i = 0; i < fills.length; i++)
        addInterfacePorts(fills[i],
            inputTags: [PairDirection.fromProvider],
            outputTags: [PairDirection.fromConsumer],
            uniquify: (signal) => _cacheFillSignalName(signal, index: '${i}_'))
    ];
    final lookupValid = [for (final lookup in localLookups) lookup.valid];
    final lookupAddress = [for (final lookup in localLookups) lookup.address];
    final fillValid = [for (final fill in localFills) fill.valid];
    final fillAddress = [for (final fill in localFills) fill.address];
    final fillData = [for (final fill in localFills) fill.data];
    final evictionReady = [for (final fill in localFills) fill.evictionReady];
    final pending = [
      for (var i = 0; i < fills.length; i++) Logic(name: 'pending_$i')
    ];
    final pendingAddress = [
      for (var i = 0; i < fills.length; i++)
        Logic(name: 'pending_address_$i', width: addressWidth)
    ];
    final pendingData = [
      for (var i = 0; i < fills.length; i++)
        Logic(name: 'pending_data_$i', width: dataWidth)
    ];
    final pendingWay = [
      for (var i = 0; i < fills.length; i++)
        Logic(name: 'pending_way_$i', width: wayWidth)
    ];
    final victimAddress = [
      for (var i = 0; i < fills.length; i++)
        Logic(name: 'victim_address_$i', width: addressWidth)
    ];
    final victimData = [
      for (var i = 0; i < fills.length; i++)
        Logic(name: 'victim_data_$i', width: dataWidth)
    ];
    final capture = [
      for (var i = 0; i < fills.length; i++) Logic(name: 'capture_$i')
    ];
    final capturedWay = [
      for (var i = 0; i < fills.length; i++)
        Logic(name: 'capture_way_$i', width: wayWidth)
    ];
    final capturedVictimAddress = [
      for (var i = 0; i < fills.length; i++)
        Logic(name: 'capture_victim_address_$i', width: addressWidth)
    ];
    final capturedVictimData = [
      for (var i = 0; i < fills.length; i++)
        Logic(name: 'capture_victim_data_$i', width: dataWidth)
    ];
    Logic combine(List<Logic> values) =>
        values.reduce((left, right) => left | right);
    Logic selects(Logic address, int set) => setBits == 0
        ? Const(1)
        : storedIndexMatches(address.getRange(0, setBits), set);
    final blocked = combine(pending);
    final active = ~localReset & ~blocked;
    final done = <Logic>[];
    Logic earlierPending = Const(0);
    for (var i = 0; i < fills.length; i++) {
      final offered = pending[i] &
          ~localReset &
          (evictionConcurrency == CacheEvictionConcurrency.parallel
              ? Const(1)
              : ~earlierPending);
      earlierPending = earlierPending | pending[i];
      localFills[i].evictionValid <= offered;
      localFills[i].evictionAddress <=
          mux(offered, victimAddress[i], Const(0, width: addressWidth));
      localFills[i].evictionData <=
          mux(offered, victimData[i], Const(0, width: dataWidth));
      done.add(offered & evictionReady[i]);
    }

    final readyParts = [for (var i = 0; i < fills.length; i++) <Logic>[]];
    final captureParts = [for (var i = 0; i < fills.length; i++) <Logic>[]];
    final wayParts = [for (var i = 0; i < fills.length; i++) <Logic>[]];
    final victimAddressParts = [
      for (var i = 0; i < fills.length; i++) <Logic>[]
    ];
    final victimDataParts = [for (var i = 0; i < fills.length; i++) <Logic>[]];
    final lookupHitParts = [for (var i = 0; i < lookups.length; i++) <Logic>[]];
    final lookupDataParts = [
      for (var i = 0; i < lookups.length; i++) <Logic>[]
    ];
    for (var set = 0; set < setCount; set++) {
      if (maxFillsPerSet > 1) {
        final countWidth = (fills.length + 1).bitLength;
        Logic remaining = Const(maxFillsPerSet, width: countWidth);
        final selected = <Logic>[];
        for (var i = 0; i < fills.length; i++) {
          final duplicate = i == 0
              ? Const(0)
              : combine([
                  for (var j = 0; j < i; j++)
                    fillValid[j] &
                        selects(fillAddress[j], set) &
                        storedAddressMatches(fillAddress[j], fillAddress[i])
                ]);
          final request = active &
              fillValid[i] &
              selects(fillAddress[i], set) &
              ~duplicate &
              remaining.gt(Const(0, width: countWidth));
          selected.add(request);
          remaining = remaining - request.zeroExtend(countWidth);
        }
        final probes = [
          for (var i = 0; i < lookups.length; i++)
            AssociativeLookupPortInterface(
                keyWidth: addressWidth, indexWidth: wayWidth)
        ];
        final fillProbes = [
          for (var i = 0; i < fills.length; i++)
            AssociativeLookupPortInterface(
                keyWidth: addressWidth, indexWidth: wayWidth)
        ];
        final updates = [
          for (var i = 0; i < fills.length; i++)
            AssociativeUpdatePortInterface(
                keyWidth: addressWidth, indexWidth: wayWidth)
        ];
        final sides = [
          for (var i = 0; i < fills.length; i++)
            AssociativeIndexedSideReadRequest(indexWidth: wayWidth)
        ];
        final accesses = [
          for (var i = 0; i < lookups.length + fills.length; i++)
            ReplacementAccessInterface(waysPerSet)
        ];
        final allocations = [
          for (var i = 0; i < fills.length; i++)
            ReplacementAllocationInterface(waysPerSet)
        ];
        final reserves = [
          for (var i = 0; i < fills.length; i++)
            ReplacementAccessInterface(waysPerSet)
        ];
        final releases = [
          for (var i = 0; i < fills.length; i++)
            ReplacementAccessInterface(waysPerSet)
        ];
        final commits = [
          for (var i = 0; i < fills.length; i++)
            ReplacementCommitInterface(waysPerSet)
        ];
        for (var i = 0; i < lookups.length; i++) {
          probes[i].en <=
              active & lookupValid[i] & selects(lookupAddress[i], set);
          probes[i].key <= lookupAddress[i];
          accesses[i].en <= probes[i].hit;
          accesses[i].index <= probes[i].index;
        }
        for (var i = 0; i < fills.length; i++) {
          fillProbes[i].en <= selected[i];
          fillProbes[i].key <= fillAddress[i];
          accesses[lookups.length + i].en <= fillProbes[i].hit;
          accesses[lookups.length + i].index <= fillProbes[i].index;
          allocations[i].en <= selected[i] & ~fillProbes[i].hit;
          sides[i].index <= allocations[i].index;
        }
        final binding = tagMemory(
          clk: localClk,
          reset: localReset,
          updatePorts: updates,
          lookupPorts: [...probes, ...fillProbes],
          entryCount: waysPerSet,
          sideReadRequests: sides,
          requiresValidityMask: true,
          lookupLatency: 0,
          duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
          matchSelection: AssociativeMatchSelection.lowestIndex,
          resultShape: AssociativeResultShape.selectedIndex,
          lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
          updateCollisionPolicy:
              AssociativeUpdateCollisionPolicy.highestPortWins,
          requiredResetBehavior: AssociativeMemoryResetBehavior.clearValidity,
          name: 'tags_$set',
        );
        final tags = binding.memory!;
        final validMask = (tags as AssociativeValidityMaskProvider).validMask!;
        final sideResponses =
            (tags as AssociativeMultiIndexedSideReadProvider).sideReadResponses;
        final reservationBank = ReplacementReservations(
          clk: localClk,
          reset: localReset,
          entryCount: waysPerSet,
          reserves: reserves,
          releases: releases,
          name: 'reservations_$set',
        );
        final hitWays = [
          for (var way = 0; way < waysPerSet; way++)
            combine([
              for (final probe in fillProbes)
                probe.hit & storedIndexMatches(probe.index, way)
            ])
        ].rconcat();
        final policy = replacement.buildWithCommits!(
          clk: localClk,
          reset: localReset,
          validMask: validMask,
          eligibleMask: ~reservationBank.reservedMask & ~hitWays,
          accesses: accesses,
          allocations: allocations,
          commits: commits,
          entryCount: waysPerSet,
          name: 'replacement_$set',
        );
        if (policy.entryCount != waysPerSet) {
          throw StateError('Replacement factory ${replacement.identity} '
              'built a policy with an incompatible entry count.');
        }
        final writes = [
          for (var i = 0; i < fills.length; i++)
            DataPortInterface<T>.typed(fillData.first, wayWidth)
        ];
        final reads = [
          for (var i = 0; i < lookups.length; i++)
            DataPortInterface<T>.typed(fillData.first, wayWidth)
        ];
        final victims = [
          for (var i = 0; i < fills.length; i++)
            DataPortInterface<T>.typed(fillData.first, wayWidth)
        ];
        for (var i = 0; i < lookups.length; i++) {
          reads[i].en <= probes[i].hit;
          reads[i].addr <= probes[i].index;
          lookupHitParts[i].add(probes[i].hit);
          lookupDataParts[i].add(
              mux(probes[i].hit, reads[i].data, Const(0, width: dataWidth)));
        }
        for (var i = 0; i < fills.length; i++) {
          final grant = fillProbes[i].hit | allocations[i].valid;
          final accepted = selected[i] & grant;
          final captures = accepted & allocations[i].evict;
          final completed = done[i] & selects(pendingAddress[i], set);
          final immediate = accepted & ~allocations[i].evict;
          final way =
              mux(fillProbes[i].hit, fillProbes[i].index, allocations[i].index);
          allocations[i].commit <= immediate & ~fillProbes[i].hit;
          reserves[i].en <= captures;
          reserves[i].index <= allocations[i].index;
          releases[i].en <= completed;
          releases[i].index <= pendingWay[i];
          commits[i].en <= completed;
          commits[i].index <= pendingWay[i];
          updates[i].en <= immediate | completed;
          updates[i].index <= mux(completed, pendingWay[i], way);
          updates[i].key <= mux(completed, pendingAddress[i], fillAddress[i]);
          updates[i].entryValid <= Const(1);
          writes[i].en <= updates[i].en;
          writes[i].addr <= updates[i].index;
          writes[i].data <= mux(completed, pendingData[i], fillData[i]);
          victims[i].en <= allocations[i].evict;
          victims[i].addr <= allocations[i].index;
          readyParts[i].add(accepted);
          captureParts[i].add(captures);
          wayParts[i].add(
              mux(captures, allocations[i].index, Const(0, width: wayWidth)));
          victimAddressParts[i].add(mux(
              captures, sideResponses[i].key, Const(0, width: addressWidth)));
          victimDataParts[i]
              .add(mux(captures, victims[i].data, Const(0, width: dataWidth)));
        }
        (dataMemory ?? _cacheDataMemory<T>(dataStorage))(
          clk: localClk,
          reset: localReset,
          writePorts: writes,
          readPorts: [...reads, ...victims],
          entryCount: waysPerSet,
          readLatency: 0,
          maxConcurrentReads: reads.length + victims.length,
          maxConcurrentWrites: writes.length,
          name: 'data_$set',
        );
        continue;
      }
      final selected = <Logic>[];
      Logic earlier = Const(0);
      for (var i = 0; i < fills.length; i++) {
        final requesting = fillValid[i] & selects(fillAddress[i], set);
        selected.add(active & requesting & ~earlier);
        earlier = earlier | requesting;
      }
      final selectedValid = combine(selected);
      final selectedAddress = combine([
        for (var i = 0; i < fills.length; i++)
          mux(selected[i], fillAddress[i], Const(0, width: addressWidth))
      ]);
      final selectedData = combine([
        for (var i = 0; i < fills.length; i++)
          mux(selected[i], fillData[i], Const(0, width: dataWidth))
      ]);
      final update = AssociativeUpdatePortInterface(
          keyWidth: addressWidth, indexWidth: wayWidth);
      final probes = [
        for (var i = 0; i < lookups.length; i++)
          AssociativeLookupPortInterface(
              keyWidth: addressWidth, indexWidth: wayWidth)
      ];
      final fillProbe = AssociativeLookupPortInterface(
          keyWidth: addressWidth, indexWidth: wayWidth);
      final side = AssociativeIndexedSideReadRequest(indexWidth: wayWidth);
      final accesses = [
        for (var i = 0; i < lookups.length + 1; i++)
          ReplacementAccessInterface(waysPerSet)
      ];
      final allocation = ReplacementAllocationInterface(waysPerSet);
      for (var i = 0; i < lookups.length; i++) {
        probes[i].en <=
            active & lookupValid[i] & selects(lookupAddress[i], set);
        probes[i].key <= lookupAddress[i];
        accesses[i].en <= probes[i].hit;
        accesses[i].index <= probes[i].index;
      }
      fillProbe.en <= selectedValid;
      fillProbe.key <= selectedAddress;
      accesses.last.en <= fillProbe.hit;
      accesses.last.index <= fillProbe.index;
      allocation.en <= selectedValid & ~fillProbe.hit;
      final grant = fillProbe.hit | allocation.valid;
      final accepted = selectedValid & grant;
      allocation.commit <= accepted & ~fillProbe.hit;
      side.index <= allocation.index;
      final binding = tagMemory(
        clk: localClk,
        reset: localReset,
        updatePorts: [update],
        lookupPorts: [...probes, fillProbe],
        entryCount: waysPerSet,
        sideReadRequest: side,
        requiresValidityMask: true,
        lookupLatency: 0,
        duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
        matchSelection: AssociativeMatchSelection.lowestIndex,
        resultShape: AssociativeResultShape.selectedIndex,
        lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
        updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
        requiredResetBehavior: AssociativeMemoryResetBehavior.clearValidity,
        name: 'tags_$set',
      );
      final tags = binding.memory!;
      final validMask = (tags as AssociativeValidityMaskProvider).validMask!;
      final sideResponse =
          (tags as AssociativeIndexedSideReadProvider).sideReadResponse!;
      final policy = replacement.build(
        clk: localClk,
        reset: localReset,
        validMask: validMask,
        eligibleMask:
            Const((BigInt.one << waysPerSet) - BigInt.one, width: waysPerSet),
        accesses: accesses,
        allocations: [allocation],
        entryCount: waysPerSet,
        name: 'replacement_$set',
      );
      if (policy.entryCount != waysPerSet) {
        throw StateError('Replacement factory ${replacement.identity} '
            'built a policy with an incompatible entry count.');
      }
      final pendingForSet = [
        for (var i = 0; i < fills.length; i++)
          done[i] & selects(pendingAddress[i], set)
      ];
      final pendingWrite = combine(pendingForSet);
      final pendingWriteAddress = combine([
        for (var i = 0; i < fills.length; i++)
          mux(pendingForSet[i], pendingAddress[i],
              Const(0, width: addressWidth))
      ]);
      final pendingWriteData = combine([
        for (var i = 0; i < fills.length; i++)
          mux(pendingForSet[i], pendingData[i], Const(0, width: dataWidth))
      ]);
      final pendingWriteWay = combine([
        for (var i = 0; i < fills.length; i++)
          mux(pendingForSet[i], pendingWay[i], Const(0, width: wayWidth))
      ]);
      final immediate = accepted & ~allocation.evict;
      final selectedWay = mux(fillProbe.hit, fillProbe.index, allocation.index);
      update.en <= immediate | pendingWrite;
      update.index <= mux(pendingWrite, pendingWriteWay, selectedWay);
      update.key <= mux(pendingWrite, pendingWriteAddress, selectedAddress);
      update.entryValid <= Const(1);
      final write = DataPortInterface<T>.typed(fillData.first, wayWidth);
      final reads = [
        for (var i = 0; i < lookups.length; i++)
          DataPortInterface<T>.typed(fillData.first, wayWidth)
      ];
      final victim = DataPortInterface<T>.typed(fillData.first, wayWidth);
      write.en <= update.en;
      write.addr <= update.index;
      write.data <= mux(pendingWrite, pendingWriteData, selectedData);
      for (var i = 0; i < lookups.length; i++) {
        reads[i].en <= probes[i].hit;
        reads[i].addr <= probes[i].index;
        lookupHitParts[i].add(probes[i].hit);
        lookupDataParts[i]
            .add(mux(probes[i].hit, reads[i].data, Const(0, width: dataWidth)));
      }
      victim.en <= allocation.evict;
      victim.addr <= allocation.index;
      (dataMemory ?? _cacheDataMemory<T>(dataStorage))(
        clk: localClk,
        reset: localReset,
        writePorts: [write],
        readPorts: [...reads, victim],
        entryCount: waysPerSet,
        readLatency: 0,
        maxConcurrentReads: reads.length + 1,
        maxConcurrentWrites: 1,
        name: 'data_$set',
      );
      for (var i = 0; i < fills.length; i++) {
        readyParts[i].add(selected[i] & grant);
        final captures = selected[i] & grant & allocation.evict;
        captureParts[i].add(captures);
        wayParts[i]
            .add(mux(captures, allocation.index, Const(0, width: wayWidth)));
        victimAddressParts[i].add(
            mux(captures, sideResponse.key, Const(0, width: addressWidth)));
        victimDataParts[i]
            .add(mux(captures, victim.data, Const(0, width: dataWidth)));
      }
    }

    final acceptedFills = <Logic>[];
    for (var i = 0; i < fills.length; i++) {
      final ready = localFills[i].ready..gets(combine(readyParts[i]));
      acceptedFills.add(fillValid[i] & ready);
      capture[i] <= combine(captureParts[i]);
      capturedWay[i] <= combine(wayParts[i]);
      capturedVictimAddress[i] <= combine(victimAddressParts[i]);
      capturedVictimData[i] <= combine(victimDataParts[i]);
      pending[i] <=
          flop(localClk,
              mux(capture[i], Const(1), mux(done[i], Const(0), pending[i])),
              reset: localReset);
      pendingAddress[i] <=
          flop(
              localClk,
              mux(capture[i], normalizeStoredLogic(fillAddress[i]),
                  pendingAddress[i]),
              reset: localReset);
      pendingData[i] <=
          flop(
              localClk,
              mux(capture[i], normalizeStoredLogic(fillData[i]),
                  pendingData[i]),
              reset: localReset);
      pendingWay[i] <=
          flop(localClk, mux(capture[i], capturedWay[i], pendingWay[i]),
              reset: localReset);
      victimAddress[i] <=
          flop(localClk,
              mux(capture[i], capturedVictimAddress[i], victimAddress[i]),
              reset: localReset);
      victimData[i] <=
          flop(localClk, mux(capture[i], capturedVictimData[i], victimData[i]),
              reset: localReset);
    }
    for (var i = 0; i < lookups.length; i++) {
      localLookups[i].ready <= active;
      var hit = combine(lookupHitParts[i]);
      var data = combine(lookupDataParts[i]);
      if (readDuringFill == CacheReadDuringFill.forward) {
        for (var j = fills.length - 1; j >= 0; j--) {
          final forward = active &
              lookupValid[i] &
              acceptedFills[j] &
              storedAddressMatches(lookupAddress[i], fillAddress[j]);
          hit = forward | hit;
          data = mux(forward, normalizeStoredLogic(fillData[j]), data);
        }
      }
      localLookups[i].hit <= hit;
      localLookups[i].data <= data;
    }
  }
}
