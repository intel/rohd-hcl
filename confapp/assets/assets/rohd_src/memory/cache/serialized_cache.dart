// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serialized_cache.dart
// Transactional cache using a fixed-latency data array.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory.dart';
import 'package:rohd_hcl/src/memory/associative/associative_memory_contract.dart';
import 'package:rohd_hcl/src/memory/associative/parallel_associative_memory.dart';
import 'package:rohd_hcl/src/memory/cache/cache.dart';
import 'package:rohd_hcl/src/memory/cache/cache_transaction_contract.dart';
import 'package:rohd_hcl/src/memory/contracts/memory.dart';
import 'package:rohd_hcl/src/memory/contracts/memory_array.dart';
import 'package:rohd_hcl/src/memory/replacement/replacement_policy.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';
import 'package:rohd_hcl/src/memory/storage/memory_array_factories.dart';

enum _CacheState { idle, probe, waitData, evict, write, respond }

String _portShape<T extends Logic, M extends Logic, C extends Logic,
    R extends Logic>(List<CacheTransactionPort<T, M, C, R>> ports) {
  if (ports.isEmpty) {
    return 'empty';
  }
  final request = payloadShapeIdentity(ports.first.requests.data);
  final response = payloadShapeIdentity(ports.first.responses.data);
  final eviction = payloadShapeIdentity(ports.first.evictions.data);
  return '${request}_${response}_$eviction';
}

/// A serialized transactional cache using a fixed-latency data array.
///
/// One operation is outstanding globally. Concurrent request ports arbitrate
/// in ascending order. Tags and line metadata use independently selected
/// flop-based storage by default; data is supplied by the data-memory factory.
/// A custom metadata factory must provide combinational reads.
/// {@category Memory}
@experimental
class SerializedCache<T extends Logic, M extends Logic, C extends Logic,
        R extends Logic> extends Module
    implements CacheTransactionCore<T, M, C, R> {
  @override
  final List<CacheTransactionPort<T, M, C, R>> ports;

  @override
  final CacheTransactionCapabilities capabilities;

  /// Number of sets.
  final int setCount;

  /// Number of ways in each set.
  final int waysPerSet;

  /// Creates a cache with one outstanding operation and synchronous data reads.
  SerializedCache({
    required Logic clk,
    required Logic reset,
    required List<CacheTransactionPort<T, M, C, R>> ports,
    required this.setCount,
    required this.waysPerSet,
    required MemoryArrayFunctor<T> dataMemory,
    MemoryArrayFunctor<M>? metadataMemory,
    CacheReplacement replacement = CacheReplacement.roundRobin,
    AssociativeMemoryFunctor tagMemory = parallelAssociativeMemoryFunctor,
    super.name = 'serialized_cache',
  })  : ports = List.unmodifiable(ports),
        capabilities = CacheTransactionCapabilities(
          operations: CacheTransactionOperation.values.toSet(),
          maxOutstanding: 1,
          responseOrdering: CacheTransactionOrdering.inOrder,
          sameBlockOrdering: CacheSameBlockOrdering.acceptanceOrder,
          sameCycleOrdering: CacheSameCycleOrdering.lowerPortFirst,
          supportsMaskedUpdates: true,
          reportsInvalidations: true,
        ),
        super(
          definitionName: 'SerializedCache_S${setCount}_W${waysPerSet}_'
              'P${ports.length}_${dataMemory.identity}_${replacement.identity}_'
              '${tagMemory.identity}_L${dataMemory.capabilities.readLatency}_'
              '${_portShape(ports)}'
              '${metadataMemory == null ? '' : '_M${metadataMemory.identity}'}',
        ) {
    if (ports.isEmpty ||
        clk.width != 1 ||
        reset.width != 1 ||
        setCount < 1 ||
        (setCount & (setCount - 1)) != 0 ||
        waysPerSet < 1 ||
        dataMemory.capabilities.readLatency < 1 ||
        (metadataMemory != null &&
            metadataMemory.capabilities.readLatency != 0) ||
        replacement.buildWithCommits == null) {
      throw ArgumentError('Invalid serialized cache geometry, data latency, '
          'or replacement factory.');
    }
    final requestSchema = ports.first.requests.data;
    final responseSchema = ports.first.responses.data;
    final evictionSchema = ports.first.evictions.data;
    final addressWidth = requestSchema.address.width;
    final setBits = (setCount - 1).bitLength;
    if (addressWidth < max(1, setBits) ||
        ports.any((port) =>
            !sameDeclaredPayloadShape(requestSchema, port.requests.data) ||
            !sameDeclaredPayloadShape(responseSchema, port.responses.data) ||
            !sameDeclaredPayloadShape(evictionSchema, port.evictions.data))) {
      throw ArgumentError('Cache transaction ports must have matching shapes '
          'and addresses must represent every set.');
    }
    ports.forEach(capabilities.validatePort);
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localPorts = [
      for (final (i, port) in ports.indexed)
        addInterfacePorts(port,
            inputTags: [PairDirection.fromProvider],
            outputTags: [PairDirection.fromConsumer],
            uniquify: (signal) => 'port_${i}_$signal')
    ];
    final requests = [for (final port in localPorts) port.requests];
    final responses = [for (final port in localPorts) port.responses];
    final evictions = [for (final port in localPorts) port.evictions];

    Logic combine(List<Logic> values) =>
        values.reduce((left, right) => left | right);
    final stateWidth = max(1, (_CacheState.values.length - 1).bitLength);
    Logic stateValue(_CacheState value) =>
        Const(value.index, width: stateWidth);
    final state = Logic(name: 'state', width: stateWidth);
    Logic inState(_CacheState value) => state.eq(stateValue(value));
    final idle = inState(_CacheState.idle);
    final probe = inState(_CacheState.probe);
    final waitData = inState(_CacheState.waitData);
    final evict = inState(_CacheState.evict);
    final write = inState(_CacheState.write);
    final respond = inState(_CacheState.respond);
    final ownerWidth = max(1, (ports.length - 1).bitLength);
    final owner = Logic(name: 'owner', width: ownerWidth);
    final requestBits = Logic(name: 'request_bits', width: requestSchema.width);
    final savedRequest = requestSchema.clone()..gets(requestBits);
    final accepted = <Logic>[];
    Logic earlierValid = Const(0);
    for (var i = 0; i < ports.length; i++) {
      requests[i].ready <= ~localReset & idle & ~earlierValid;
      accepted.add(requests[i].valid & requests[i].ready);
      earlierValid = earlierValid | requests[i].valid;
      final conflict = ~localReset &
          ~idle &
          owner.eq(i) &
          requests[i].valid &
          requests[i].data.token.eq(savedRequest.token);
      localPorts[i].tokenConflict <= conflict;
    }
    final accept = combine(accepted);
    Logic incoming = Const(0, width: requestSchema.width);
    Logic incomingOwner = Const(0, width: ownerWidth);
    for (var i = ports.length - 1; i >= 0; i--) {
      incoming = mux(accepted[i], requests[i].data, incoming);
      incomingOwner =
          mux(accepted[i], Const(i, width: ownerWidth), incomingOwner);
    }
    requestBits <=
        flop(localClk, mux(accept, incoming, requestBits), reset: localReset);
    owner <=
        flop(localClk, mux(accept, incomingOwner, owner), reset: localReset);

    final isLookup =
        savedRequest.operation.eq(CacheTransactionOperation.lookup.code);
    final isFill =
        savedRequest.operation.eq(CacheTransactionOperation.fill.code);
    final isUpdate =
        savedRequest.operation.eq(CacheTransactionOperation.update.code);
    final isInvalidate =
        savedRequest.operation.eq(CacheTransactionOperation.invalidate.code);
    final supported = isLookup | isFill | isUpdate | isInvalidate;
    final wayWidth = max(1, (waysPerSet - 1).bitLength);
    final savedWay = Logic(name: 'saved_way', width: wayWidth);
    final savedVictimAddress = Logic(name: 'saved_victim', width: addressWidth);
    final oldData = Logic(name: 'old_data', width: requestSchema.data.width);
    final oldMetadata =
        Logic(name: 'old_metadata', width: requestSchema.lineMetadata.width);
    final status = Logic(name: 'status', width: 2);
    final fillMiss = Logic(name: 'fill_miss');

    Logic selects(int set) => setBits == 0
        ? Const(1)
        : storedIndexMatches(savedRequest.address.getRange(0, setBits), set);
    final hits = <Logic>[];
    final allocationValid = <Logic>[];
    final allocationEvict = <Logic>[];
    final chosenWays = <Logic>[];
    final victimAddresses = <Logic>[];
    final readData = <Logic>[];
    final readMetadata = <Logic>[];
    final writeUnitWidth =
        requestSchema.data.width ~/ requestSchema.writeMask.width;
    final updatedData = [
      for (var unit = 0; unit < requestSchema.writeMask.width; unit++)
        mux(
          savedRequest.writeMask[unit],
          savedRequest.data
              .getRange(unit * writeUnitWidth, (unit + 1) * writeUnitWidth),
          oldData.getRange(unit * writeUnitWidth, (unit + 1) * writeUnitWidth),
        )
    ].rconcat();
    final writeData =
        normalizeStoredLogic(mux(isUpdate, updatedData, savedRequest.data));

    for (var set = 0; set < setCount; set++) {
      final selected = selects(set);
      final tagUpdate = AssociativeUpdatePortInterface(
          keyWidth: addressWidth, indexWidth: wayWidth);
      final tagLookup = AssociativeLookupPortInterface(
          keyWidth: addressWidth, indexWidth: wayWidth);
      final side = AssociativeIndexedSideReadRequest(indexWidth: wayWidth);
      final access = ReplacementAccessInterface(waysPerSet);
      final allocation = ReplacementAllocationInterface(waysPerSet);
      final commit = ReplacementCommitInterface(waysPerSet);
      tagLookup.en <= ~localReset & probe & selected & supported;
      tagLookup.key <= savedRequest.address;
      allocation.en <= tagLookup.en & isFill & ~tagLookup.hit;
      allocation.commit <= Const(0);
      side.index <= allocation.index;
      access.en <= tagLookup.hit;
      access.index <= tagLookup.index;
      commit.en <= ~localReset & write & selected & isFill & fillMiss;
      commit.index <= savedWay;
      tagUpdate.en <= ~localReset & write & selected & (isFill | isInvalidate);
      tagUpdate.index <= savedWay;
      tagUpdate.key <= savedRequest.address;
      tagUpdate.entryValid <= ~isInvalidate;
      final binding = tagMemory(
        clk: localClk,
        reset: localReset,
        updatePorts: [tagUpdate],
        lookupPorts: [tagLookup],
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
      final mask = (tags as AssociativeValidityMaskProvider).validMask!;
      final sideResponse =
          (tags as AssociativeIndexedSideReadProvider).sideReadResponse!;
      final policy = replacement.buildWithCommits!(
        clk: localClk,
        reset: localReset,
        validMask: mask,
        eligibleMask:
            Const((BigInt.one << waysPerSet) - BigInt.one, width: waysPerSet),
        accesses: [access],
        allocations: [allocation],
        commits: [commit],
        entryCount: waysPerSet,
        name: 'replacement_$set',
      );
      if (policy.entryCount != waysPerSet) {
        throw StateError('Replacement factory returned incompatible geometry.');
      }

      final way = mux(tagLookup.hit, tagLookup.index, allocation.index);
      final needsRead = ((isLookup | isUpdate | isInvalidate) & tagLookup.hit) |
          (isFill & ~tagLookup.hit & allocation.valid & allocation.evict);
      final dataRead = DataPortInterface<T>.typed(requestSchema.data, wayWidth);
      final dataWrite =
          DataPortInterface<T>.typed(requestSchema.data, wayWidth);
      dataRead.en <= ~localReset & probe & selected & needsRead;
      dataRead.addr <= way;
      dataWrite.en <= ~localReset & write & selected & (isFill | isUpdate);
      dataWrite.addr <= savedWay;
      dataWrite.data <= writeData;
      dataMemory(
        clk: localClk,
        reset: localReset,
        writePorts: [dataWrite],
        readPorts: [dataRead],
        entryCount: waysPerSet,
        readLatency: dataMemory.capabilities.readLatency,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 1,
        maxConcurrentAccesses: 1,
        name: 'data_$set',
      );
      final metaRead =
          DataPortInterface<M>.typed(requestSchema.lineMetadata, wayWidth);
      final metaWrite =
          DataPortInterface<M>.typed(requestSchema.lineMetadata, wayWidth);
      metaRead.en <= ~localReset & probe & selected & needsRead;
      metaRead.addr <= way;
      metaWrite.en <= dataWrite.en;
      metaWrite.addr <= savedWay;
      metaWrite.data <= normalizeStoredLogic(savedRequest.lineMetadata);
      (metadataMemory ?? registerFileArray<M>())(
        clk: localClk,
        reset: localReset,
        writePorts: [metaWrite],
        readPorts: [metaRead],
        entryCount: waysPerSet,
        readLatency: 0,
        maxConcurrentReads: 1,
        maxConcurrentWrites: 1,
        maxConcurrentAccesses: 1,
        requiredReadCollision: MemoryArrayReadCollision.combinational,
        name: 'metadata_$set',
      );
      hits.add(selected & tagLookup.hit);
      allocationValid.add(selected & allocation.valid);
      allocationEvict.add(selected & allocation.evict);
      chosenWays.add(mux(selected, way, Const(0, width: wayWidth)));
      victimAddresses
          .add(mux(selected, sideResponse.key, Const(0, width: addressWidth)));
      readData.add(mux(
          selected, dataRead.data, Const(0, width: requestSchema.data.width)));
      readMetadata.add(mux(selected, metaRead.data,
          Const(0, width: requestSchema.lineMetadata.width)));
    }
    final hit = combine(hits);
    final allocationOk = combine(allocationValid);
    final victim = combine(allocationEvict);
    final needsRead = ((isLookup | isUpdate | isInvalidate) & hit) |
        (isFill & ~hit & allocationOk & victim);
    final canFill = isFill & (hit | allocationOk);
    savedWay <=
        flop(localClk, mux(probe, combine(chosenWays), savedWay),
            reset: localReset);
    savedVictimAddress <=
        flop(localClk, mux(probe, combine(victimAddresses), savedVictimAddress),
            reset: localReset);
    oldMetadata <=
        flop(localClk,
            mux(probe & needsRead, combine(readMetadata), oldMetadata),
            reset: localReset);
    fillMiss <=
        flop(localClk, mux(probe, isFill & ~hit, fillMiss), reset: localReset);

    final latency = dataMemory.capabilities.readLatency;
    final countWidth = max(1, (latency - 1).bitLength);
    final count = Logic(name: 'read_count', width: countWidth);
    final readComplete = waitData & count.eq(0);
    count <=
        flop(
            localClk,
            mux(
                probe & needsRead,
                Const(latency - 1, width: countWidth),
                mux(waitData & ~count.eq(0),
                    count - Const(1, width: countWidth), count)),
            reset: localReset);
    oldData <=
        flop(localClk, mux(readComplete, combine(readData), oldData),
            reset: localReset);

    Logic statusValue(CacheTransactionStatus value) =>
        Const(value.code, width: 2);
    final noReadStatus = mux(
        canFill,
        statusValue(CacheTransactionStatus.completed),
        mux(supported & ~isFill, statusValue(CacheTransactionStatus.miss),
            statusValue(CacheTransactionStatus.error)));
    status <=
        flop(
            localClk,
            mux(
              probe & ~needsRead,
              noReadStatus,
              mux(
                  readComplete,
                  mux(isFill, statusValue(CacheTransactionStatus.completed),
                      statusValue(CacheTransactionStatus.hit)),
                  status),
            ),
            reset: localReset);

    final responseDone = <Logic>[];
    final evictionDone = <Logic>[];
    for (var i = 0; i < ports.length; i++) {
      final owned = owner.eq(i);
      responses[i].valid <= ~localReset & respond & owned;
      responses[i].data.token <= savedRequest.token;
      responses[i].data.status <= status;
      responses[i].data.data <=
          mux(status.eq(CacheTransactionStatus.hit.code), oldData,
              Const(0, width: oldData.width));
      responses[i].data.lineMetadata <=
          mux(status.eq(CacheTransactionStatus.hit.code), oldMetadata,
              Const(0, width: oldMetadata.width));
      responses[i].data.context <= savedRequest.context;
      responses[i].data.result <=
          Const(0, width: responses[i].data.result.width);
      evictions[i].valid <= ~localReset & evict & owned;
      evictions[i].data.token <= savedRequest.token;
      evictions[i].data.cause <=
          mux(
              isInvalidate,
              Const(CacheTransactionEvictionCause.invalidation.code,
                  width: evictions[i].data.cause.width),
              Const(CacheTransactionEvictionCause.replacement.code,
                  width: evictions[i].data.cause.width));
      evictions[i].data.address <=
          mux(isInvalidate, savedRequest.address, savedVictimAddress);
      evictions[i].data.data <= oldData;
      evictions[i].data.lineMetadata <= oldMetadata;
      evictions[i].data.context <= savedRequest.context;
      responseDone.add(responses[i].valid & responses[i].ready);
      evictionDone.add(evictions[i].valid & evictions[i].ready);
    }
    var nextState = state;
    nextState = mux(accept, stateValue(_CacheState.probe), nextState);
    nextState =
        mux(probe & needsRead, stateValue(_CacheState.waitData), nextState);
    nextState = mux(
        probe & ~needsRead,
        mux(canFill, stateValue(_CacheState.write),
            stateValue(_CacheState.respond)),
        nextState);
    nextState = mux(
        readComplete,
        mux(
            isLookup,
            stateValue(_CacheState.respond),
            mux(isUpdate, stateValue(_CacheState.write),
                stateValue(_CacheState.evict))),
        nextState);
    nextState =
        mux(combine(evictionDone), stateValue(_CacheState.write), nextState);
    nextState = mux(write, stateValue(_CacheState.respond), nextState);
    nextState =
        mux(combine(responseDone), stateValue(_CacheState.idle), nextState);
    state <= flop(localClk, nextState, reset: localReset);
  }
}
