// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_cache.dart
// Concurrent simulation-only transactional cache and backing store.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/behavioral/memory_state_access.dart';
import 'package:rohd_hcl/src/memory/cache/cache_transaction_contract.dart';
import 'package:rohd_hcl/src/memory/state/state_transactions.dart';
import 'package:rohd_hcl/src/memory/state/stored_value.dart';
import 'package:rohd_hcl/src/models/sparse_memory_storage.dart';

/// Additional operations implemented by [BehavioralCache].
@experimental
enum BehavioralCacheOperation {
  /// Look up a block, fetching and installing it on a miss.
  readThrough(4),

  /// Update a block, fetching and installing it on a miss.
  writeAllocate(5);

  /// Wire encoding negotiated through the core's capabilities.
  final int code;

  const BehavioralCacheOperation(this.code);
}

/// A block and its opaque metadata in a behavioral backing store.
@experimental
typedef BehavioralCacheBlock = ({LogicValue data, LogicValue metadata});

/// Detached sparse backing-store state, including opaque line metadata.
@experimental
class BehavioralCacheBackingStoreImage {
  /// Width of a block address.
  final int addressWidth;

  /// Width of block data.
  final int dataWidth;

  /// Width of line metadata.
  final int metadataWidth;

  /// Explicitly stored blocks.
  final Map<BigInt, BehavioralCacheBlock> entries;

  /// Creates an immutable image.
  BehavioralCacheBackingStoreImage({
    required this.addressWidth,
    required this.dataWidth,
    required this.metadataWidth,
    required Map<BigInt, BehavioralCacheBlock> entries,
  }) : entries = Map.unmodifiable(entries);
}

/// Sparse, persistent backing storage for [BehavioralCache].
///
/// Unwritten blocks contain unknown data and metadata. Resetting a cache does
/// not reset this object; callers may share it or initialize it explicitly.
@experimental
class BehavioralCacheBackingStore
    implements MemoryStateAccess<BehavioralCacheBackingStoreImage> {
  /// Width of a block address.
  final int addressWidth;

  /// Width of block data.
  final int dataWidth;

  /// Width of opaque line metadata.
  final int metadataWidth;

  late final SparseMemoryStorage _storage;

  /// Creates an empty backing store.
  BehavioralCacheBackingStore({
    required this.addressWidth,
    required this.dataWidth,
    required this.metadataWidth,
  }) {
    if (addressWidth < 1 || dataWidth < 1 || metadataWidth < 1) {
      throw ArgumentError('Backing-store widths must be positive.');
    }
    _storage = SparseMemoryStorage(
        addrWidth: addressWidth, dataWidth: dataWidth + metadataWidth);
  }

  void _validateAddress(BigInt address) {
    if (address.isNegative || address >= (BigInt.one << addressWidth)) {
      throw RangeError('Backing-store address does not fit its width.');
    }
  }

  LogicValue _address(BigInt address) {
    _validateAddress(address);
    return LogicValue.ofBigInt(address, addressWidth);
  }

  BehavioralCacheBlock _unpack(LogicValue value) => (
        data: value.getRange(0, dataWidth),
        metadata: value.getRange(dataWidth, dataWidth + metadataWidth),
      );

  LogicValue _pack(BehavioralCacheBlock block) =>
      LogicValue.of([block.data, block.metadata]);

  /// Reads a block, returning unknown values for an uninitialized address.
  BehavioralCacheBlock read(BigInt address) {
    final value = _storage.getData(_address(address));
    return value == null
        ? (
            data: LogicValue.filled(dataWidth, LogicValue.x),
            metadata: LogicValue.filled(metadataWidth, LogicValue.x),
          )
        : _unpack(value);
  }

  /// Writes a complete block and its metadata.
  void write(BigInt address,
      {required LogicValue data, required LogicValue metadata}) {
    final target = _address(address);
    if (data.width != dataWidth || metadata.width != metadataWidth) {
      throw ArgumentError('Backing-store block widths do not match.');
    }
    _storage.setData(target, _pack((data: data, metadata: metadata)));
  }

  /// Reads raw data, or null when the block has not been initialized.
  @override
  LogicValue? peek(int address) => peekBigInt(BigInt.from(address));

  @override
  LogicValue? peekBigInt(BigInt address) {
    final value = _storage.getData(_address(address));
    return value == null ? null : _unpack(value).data;
  }

  /// Writes raw data, preserving existing metadata or initializing it to X.
  @override
  void poke(int address, LogicValue value) =>
      pokeBigInt(BigInt.from(address), value);

  @override
  void pokeBigInt(BigInt address, LogicValue value) {
    final stored = _storage.getData(_address(address));
    write(address,
        data: value,
        metadata: (stored == null ? null : _unpack(stored).metadata) ??
            LogicValue.filled(metadataWidth, LogicValue.x));
  }

  /// Captures a detached image of every initialized block and its metadata.
  @override
  BehavioralCacheBackingStoreImage snapshot() =>
      BehavioralCacheBackingStoreImage(
        addressWidth: addressWidth,
        dataWidth: dataWidth,
        metadataWidth: metadataWidth,
        entries: {
          for (final address in _storage.addresses)
            address.toBigInt(): _unpack(_storage.getData(address)!)
        },
      );

  void _validateImage(BehavioralCacheBackingStoreImage image) {
    if (image.addressWidth != addressWidth ||
        image.dataWidth != dataWidth ||
        image.metadataWidth != metadataWidth) {
      throw ArgumentError('Backing-store image geometry does not match.');
    }
    for (final entry in image.entries.entries) {
      _validateAddress(entry.key);
      if (entry.value.data.width != dataWidth ||
          entry.value.metadata.width != metadataWidth) {
        throw ArgumentError('Backing-store image block widths do not match.');
      }
    }
  }

  /// Validates and atomically overlays or replaces the sparse backing state.
  @override
  void load(BehavioralCacheBackingStoreImage image, {bool replace = false}) {
    _validateImage(image);
    _storage.loadSymbolicState({
      for (final entry in image.entries.entries)
        _address(entry.key): _pack(entry.value)
    }, const [], replace: replace);
  }
}

/// Software replacement state used by a [BehavioralCache].
///
/// [select] must not mutate policy state. Accesses and allocations are
/// reported only when their cache operation takes effect.
@experimental
abstract interface class BehavioralCacheReplacement {
  /// Selects a way in [set] given the current validity of its ways.
  int select(int set, List<bool> valid);

  /// Records a successful access to an existing way.
  void access(int set, int way);

  /// Records allocation of a way for a previously absent block.
  void allocate(int set, int way);

  /// Resets all replacement state.
  void reset();
}

/// Optional snapshot support for a behavioral replacement policy.
///
/// Images must be detached and immutable. After [validateSnapshot] succeeds,
/// [restoreSnapshot] must not fail or partially apply the image.
@experimental
abstract interface class SnapshotableBehavioralCacheReplacement {
  /// Captures the complete replacement state.
  Object snapshotReplacement();

  /// Rejects an image that cannot be restored by this policy.
  void validateSnapshot(Object image);

  /// Replaces the state with an already validated image.
  void restoreSnapshot(Object image);
}

/// Round-robin replacement which prefers invalid ways.
@experimental
class BehavioralCacheRoundRobin
    implements
        BehavioralCacheReplacement,
        SnapshotableBehavioralCacheReplacement {
  final List<int> _next;
  final int _ways;

  /// Creates independent round-robin state for each set.
  BehavioralCacheRoundRobin({required int setCount, required int waysPerSet})
      : _next = List.filled(setCount, 0),
        _ways = waysPerSet {
    if (setCount < 1 || waysPerSet < 1) {
      throw ArgumentError('Replacement geometry must be positive.');
    }
  }

  @override
  int select(int set, List<bool> valid) {
    if (set < 0 || set >= _next.length || valid.length != _ways) {
      throw ArgumentError('Replacement geometry does not match the cache.');
    }
    for (var offset = 0; offset < _ways; offset++) {
      final candidate = (_next[set] + offset) % _ways;
      if (!valid[candidate]) {
        return candidate;
      }
    }
    return _next[set];
  }

  @override
  void access(int set, int way) {}

  @override
  void allocate(int set, int way) => _next[set] = (way + 1) % _ways;

  @override
  void reset() => _next.fillRange(0, _next.length, 0);

  @override
  Object snapshotReplacement() => List<int>.unmodifiable(_next);

  @override
  void validateSnapshot(Object image) {
    if (image is! List<int> ||
        image.length != _next.length ||
        image.any((way) => way < 0 || way >= _ways)) {
      throw ArgumentError('Invalid round-robin replacement image.');
    }
  }

  @override
  void restoreSnapshot(Object image) {
    validateSnapshot(image);
    _next.setAll(0, image as List<int>);
  }
}

class _Line {
  final BigInt address;
  final LogicValue data;
  final LogicValue metadata;

  _Line(this.address, this.data, this.metadata);
}

class _CacheWays extends ListBase<_Line?> {
  final SparseMemoryStorage storage;
  final int start;
  final int count;
  final int addressWidth;
  final int dataWidth;
  final int metadataWidth;

  _CacheWays(this.storage, this.start, this.count, this.addressWidth,
      this.dataWidth, this.metadataWidth);

  @override
  int get length => count;

  @override
  set length(int value) => throw UnsupportedError('Cache way count is fixed.');

  LogicValue _address(int index) {
    if (index < 0 || index >= count) {
      throw RangeError.range(index, 0, count - 1, 'index');
    }
    return LogicValue.ofInt(start + index, storage.addrWidth);
  }

  @override
  _Line? operator [](int index) {
    final value = storage.getData(_address(index));
    if (value == null || value[value.width - 1] == LogicValue.zero) {
      return null;
    }
    if (value[value.width - 1] != LogicValue.one) {
      throw StateError('Stored cache line validity is unknown.');
    }
    return _Line(
        value.getRange(0, addressWidth).toBigInt(),
        value.getRange(addressWidth, addressWidth + dataWidth),
        value.getRange(addressWidth + dataWidth,
            addressWidth + dataWidth + metadataWidth));
  }

  @override
  void operator []=(int index, _Line? line) {
    final address = _address(index);
    if (line == null) {
      storage.setData(
          address, LogicValue.filled(storage.dataWidth, LogicValue.zero));
      return;
    }
    storage.setData(
        address,
        LogicValue.of([
          LogicValue.ofBigInt(line.address, addressWidth),
          line.data,
          line.metadata,
          LogicValue.one,
        ]));
  }
}

class _Transaction {
  final int port;
  final int operation;
  final BigInt address;
  final LogicValue token;
  final LogicValue data;
  final LogicValue mask;
  final LogicValue metadata;
  final LogicValue context;
  final int eligibleCycle;
  _Line? eviction;
  int? evictionCause;
  _PendingCommit? pending;
  int? status;
  LogicValue? responseData;
  LogicValue? responseMetadata;

  _Transaction({
    required this.port,
    required this.operation,
    required this.address,
    required this.token,
    required this.data,
    required this.mask,
    required this.metadata,
    required this.context,
    required this.eligibleCycle,
  });

  bool get complete => status != null;

  _Transaction copy() => _Transaction(
        port: port,
        operation: operation,
        address: address,
        token: token,
        data: data,
        mask: mask,
        metadata: metadata,
        context: context,
        eligibleCycle: eligibleCycle,
      )
        ..eviction = eviction
        ..evictionCause = evictionCause
        ..pending = pending
        ..status = status
        ..responseData = responseData
        ..responseMetadata = responseMetadata;
}

class _PendingCommit {
  final int way;
  final bool hit;
  final LogicValue? beforeData;
  final LogicValue? beforeMetadata;

  const _PendingCommit(
      {required this.way,
      required this.hit,
      required this.beforeData,
      required this.beforeMetadata});
}

/// Detached full behavioral-cache state, including in-flight transactions.
@experimental
class BehavioralCacheImage {
  final String _configuration;
  final Type _replacementType;
  final Object _replacementState;
  final List<List<_Line?>> _lines;
  final List<_Transaction> _transactions;
  final List<List<int>> _evictionOffers;
  final int _cycle;

  /// Backing state at the same model boundary.
  final BehavioralCacheBackingStoreImage backing;

  /// Number of accepted requests captured in this image.
  int get outstandingCount => _transactions.length;

  BehavioralCacheImage._({
    required String configuration,
    required Type replacementType,
    required Object replacementState,
    required List<List<_Line?>> lines,
    required List<_Transaction> transactions,
    required List<List<int>> evictionOffers,
    required int cycle,
    required this.backing,
  })  : _configuration = configuration,
        _replacementType = replacementType,
        _replacementState = replacementState,
        _lines = List.unmodifiable(lines.map(List<_Line?>.unmodifiable)),
        _transactions =
            List.unmodifiable(transactions.map((txn) => txn.copy())),
        _evictionOffers =
            List.unmodifiable(evictionOffers.map(List<int>.unmodifiable)),
        _cycle = cycle;
}

String _portShape<T extends Logic, M extends Logic, C extends Logic,
    R extends Logic>(List<CacheTransactionPort<T, M, C, R>> ports) {
  if (ports.isEmpty) {
    return 'NoPorts';
  }
  return '${payloadShapeIdentity(ports.first.requests.data)}_'
      '${payloadShapeIdentity(ports.first.responses.data)}_'
      '${payloadShapeIdentity(ports.first.evictions.data)}';
}

/// Simulation-only transactional cache with concurrent outstanding requests.
///
/// Requests to the same set take effect in acceptance order. Requests to
/// different sets can proceed independently, even while an eviction stalls.
/// Responses remain ordered on each port. For simultaneous requests, lower
/// port numbers are accepted first. This model does not generate RTL.
/// {@category Memory}
@experimental
class BehavioralCache<T extends Logic, M extends Logic, C extends Logic,
        R extends Logic> extends Module
    implements
        CacheTransactionCore<T, M, C, R>,
        StateTransactionProvider<BehavioralCacheImage>,
        StateTransactionCapabilityProvider {
  @override
  final List<CacheTransactionPort<T, M, C, R>> ports;

  @override
  final CacheTransactionCapabilities capabilities;

  /// Backing store, retained across cache reset.
  final BehavioralCacheBackingStore backingStore;

  /// Number of sets.
  final int setCount;

  /// Number of entries in each set.
  final int waysPerSet;

  /// Maximum operations that may begin in one cycle.
  final int operationsPerCycle;

  /// Minimum cycles from request acceptance to beginning an operation.
  final int operationLatency;

  /// Caller-supplied policy, or independent round-robin state by default.
  final BehavioralCacheReplacement replacement;

  @override
  late final StateTransactionEndpoint<BehavioralCacheImage> stateTransactions =
      SoftwareStateTransactionAdapter(
          snapshot: snapshot,
          restore: restore,
          capabilities: () => stateTransactionCapabilities);

  @override
  StateTransactionCapabilities get stateTransactionCapabilities =>
      replacement is SnapshotableBehavioralCacheReplacement &&
              backingStore.runtimeType == BehavioralCacheBackingStore
          ? StateTransactionCapabilities.software
          : StateTransactionCapabilities.unsupported;

  late final String _configuration;
  late final List<List<_Line?>> _lines;
  late final List<_Transaction> _transactions;
  late final List<List<_Transaction>> _evictionOffers;
  late final void Function() _refresh;
  int _cycle = 0;

  /// Creates the model. The port operation width must encode the extensions.
  BehavioralCache({
    required Logic clk,
    required Logic reset,
    required List<CacheTransactionPort<T, M, C, R>> ports,
    required this.setCount,
    required this.waysPerSet,
    required int maxOutstanding,
    required this.backingStore,
    this.operationsPerCycle = 1,
    this.operationLatency = 1,
    BehavioralCacheReplacement? replacement,
    super.name = 'behavioral_cache',
  })  : ports = List.unmodifiable(ports),
        replacement = replacement ??
            BehavioralCacheRoundRobin(
                setCount: setCount, waysPerSet: waysPerSet),
        capabilities = CacheTransactionCapabilities(
          operations: CacheTransactionOperation.values.toSet(),
          extensionOperations:
              BehavioralCacheOperation.values.map((op) => op.code).toSet(),
          maxOutstanding: maxOutstanding,
          responseOrdering: CacheTransactionOrdering.inOrder,
          sameBlockOrdering: CacheSameBlockOrdering.acceptanceOrder,
          sameCycleOrdering: CacheSameCycleOrdering.lowerPortFirst,
          supportsMaskedUpdates: true,
          reportsInvalidations: true,
        ),
        super(
            definitionName: 'BehavioralCache_S${setCount}_W${waysPerSet}_'
                'P${ports.length}_N${maxOutstanding}_'
                'I${operationsPerCycle}_L${operationLatency}_'
                '${_portShape(ports)}') {
    if (ports.isEmpty ||
        clk.width != 1 ||
        reset.width != 1 ||
        setCount < 1 ||
        (setCount & (setCount - 1)) != 0 ||
        waysPerSet < 1 ||
        operationsPerCycle < 1 ||
        operationLatency < 1) {
      throw ArgumentError('Invalid behavioral-cache geometry or timing.');
    }
    final request = ports.first.requests.data;
    final response = ports.first.responses.data;
    final eviction = ports.first.evictions.data;
    if (BigInt.from(setCount) > (BigInt.one << request.address.width) ||
        backingStore.addressWidth != request.address.width ||
        backingStore.dataWidth != request.data.width ||
        backingStore.metadataWidth != request.lineMetadata.width ||
        ports.any((port) =>
            !sameDeclaredPayloadShape(request, port.requests.data) ||
            !sameDeclaredPayloadShape(response, port.responses.data) ||
            !sameDeclaredPayloadShape(eviction, port.evictions.data))) {
      throw ArgumentError('Cache ports and backing store must have matching '
          'geometry and payload shapes.');
    }
    ports.forEach(capabilities.validatePort);
    _configuration = '$setCount:$waysPerSet:$maxOutstanding:'
        '$operationsPerCycle:$operationLatency:${ports.length}:'
        '${_portShape(ports)}';

    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localPorts = [
      for (final (index, port) in ports.indexed)
        addInterfacePorts(port,
            inputTags: [PairDirection.fromProvider],
            outputTags: [PairDirection.fromConsumer],
            uniquify: (signal) => 'port_${index}_$signal'),
    ];
    final entryAddressWidth = (setCount * waysPerSet - 1).bitLength;
    final lineStorage = SparseMemoryStorage(
        addrWidth: entryAddressWidth == 0 ? 1 : entryAddressWidth,
        dataWidth: request.address.width +
            request.data.width +
            request.lineMetadata.width +
            1);
    final lines = _lines = [
      for (var set = 0; set < setCount; set++)
        _CacheWays(
            lineStorage,
            set * waysPerSet,
            waysPerSet,
            request.address.width,
            request.data.width,
            request.lineMetadata.width),
    ];
    final transactions = _transactions = <_Transaction>[];
    final evictionOffers = _evictionOffers = [
      for (var index = 0; index < ports.length; index++) <_Transaction>[],
    ];
    int setOf(BigInt address) => (address % BigInt.from(setCount)).toInt();
    LogicValue zero(int width) => LogicValue.filled(width, LogicValue.zero);
    LogicValue bits(Logic signal, {bool previous = false}) {
      LogicValue read(Logic leaf) =>
          previous ? leaf.previousValue! : leaf.value;
      return signal is LogicStructure
          ? signal.leafElements.map(read).toList().rconcat()
          : read(signal);
    }

    void drive(Logic signal, LogicValue value) {
      if (signal is LogicStructure) {
        var offset = 0;
        for (final leaf in signal.leafElements) {
          leaf.put(value.getRange(offset, offset + leaf.width));
          offset += leaf.width;
        }
      } else {
        signal.put(value);
      }
    }

    LogicValue merged(LogicValue oldData, LogicValue newData, LogicValue mask) {
      final unitWidth = oldData.width ~/ mask.width;
      return [
        for (var bit = 0; bit < oldData.width; bit++)
          if (mask[bit ~/ unitWidth] == LogicValue.zero)
            oldData[bit]
          else if (mask[bit ~/ unitWidth] == LogicValue.one)
            newData[bit]
          else if (oldData[bit] == newData[bit] && oldData[bit].isValid)
            oldData[bit]
          else
            LogicValue.x,
      ].rconcat();
    }

    void refresh() {
      final resetValue = localReset.value;
      var available = maxOutstanding - transactions.length;
      var uncertainGrant = false;
      for (final (index, port) in localPorts.indexed) {
        final valid = port.requests.valid.value;
        final token = bits(port.requests.data.token);
        final conflict = valid == LogicValue.one &&
            token.isValid &&
            transactions.any((txn) => txn.port == index && txn.token == token);
        final tokenUnknown = valid == LogicValue.one && !token.isValid;
        final unknown = !resetValue.isValid ||
            (resetValue == LogicValue.zero &&
                (uncertainGrant || !valid.isValid || tokenUnknown));
        port.tokenConflict.put(resetValue == LogicValue.one
            ? LogicValue.zero
            : tokenUnknown || !valid.isValid || !resetValue.isValid
                ? LogicValue.x
                : conflict
                    ? LogicValue.one
                    : LogicValue.zero);
        final ready = resetValue == LogicValue.one
            ? LogicValue.zero
            : unknown
                ? LogicValue.x
                : available > 0 && !conflict
                    ? LogicValue.one
                    : LogicValue.zero;
        port.requests.ready.put(ready);
        if (ready == LogicValue.one && valid == LogicValue.one) {
          available--;
        } else if (ready == LogicValue.x && available > 0) {
          uncertainGrant = true;
        }

        final own = transactions.where((txn) => txn.port == index).toList();
        final responseTxn =
            own.isNotEmpty && own.first.complete ? own.first : null;
        final evictionTxn = evictionOffers[index].firstOrNull;
        port.responses.valid.put(resetValue == LogicValue.one
            ? LogicValue.zero
            : !resetValue.isValid
                ? LogicValue.x
                : responseTxn == null
                    ? LogicValue.zero
                    : LogicValue.one);
        port.evictions.valid.put(resetValue == LogicValue.one
            ? LogicValue.zero
            : !resetValue.isValid
                ? LogicValue.x
                : evictionTxn == null
                    ? LogicValue.zero
                    : LogicValue.one);
        if (responseTxn != null) {
          final out = port.responses.data;
          drive(out.token, responseTxn.token);
          drive(out.status, LogicValue.ofInt(responseTxn.status!, 2));
          drive(out.data, responseTxn.responseData!);
          drive(out.lineMetadata, responseTxn.responseMetadata!);
          drive(out.context, responseTxn.context);
          drive(out.result, zero(out.result.width));
        }
        if (evictionTxn != null) {
          final out = port.evictions.data;
          final victim = evictionTxn.eviction!;
          drive(out.token, evictionTxn.token);
          drive(out.cause,
              LogicValue.ofInt(evictionTxn.evictionCause!, out.cause.width));
          drive(out.address,
              LogicValue.ofBigInt(victim.address, out.address.width));
          drive(out.data, victim.data);
          drive(out.lineMetadata, victim.metadata);
          drive(out.context, evictionTxn.context);
        }
      }
    }

    void finish(_Transaction txn, int status,
        [LogicValue? data, LogicValue? metadata]) {
      txn
        ..status = status
        ..responseData = data ?? zero(request.data.width)
        ..responseMetadata = metadata ?? zero(request.lineMetadata.width);
    }

    void commit(_Transaction txn) {
      final pending = txn.pending!;
      final set = setOf(txn.address);
      final ways = lines[set];
      final isInvalidate =
          txn.operation == CacheTransactionOperation.invalidate.code;
      final isFill = txn.operation == CacheTransactionOperation.fill.code;
      final isUpdate = txn.operation == CacheTransactionOperation.update.code;
      final readThrough =
          txn.operation == BehavioralCacheOperation.readThrough.code;
      final writeAllocate =
          txn.operation == BehavioralCacheOperation.writeAllocate.code;
      if (pending.hit) {
        this.replacement.access(set, pending.way);
      }
      if (isInvalidate) {
        ways[pending.way] = null;
      } else {
        final updated = isUpdate || writeAllocate;
        final data = updated
            ? merged(pending.beforeData!, txn.data, txn.mask)
            : readThrough
                ? pending.beforeData!
                : txn.data;
        final metadata = readThrough ? pending.beforeMetadata! : txn.metadata;
        ways[pending.way] = _Line(txn.address, normalizeStoredValue(data),
            normalizeStoredValue(metadata));
        if (!pending.hit) {
          this.replacement.allocate(set, pending.way);
        }
      }
      if (isFill) {
        finish(txn, CacheTransactionStatus.completed.code);
      } else {
        finish(
            txn,
            pending.hit
                ? CacheTransactionStatus.hit.code
                : CacheTransactionStatus.miss.code,
            pending.beforeData,
            pending.beforeMetadata);
      }
      txn.pending = null;
    }

    void begin(_Transaction txn) {
      final set = setOf(txn.address);
      final ways = lines[set];
      final hitWay = ways.indexWhere((line) => line?.address == txn.address);
      final hit = hitWay >= 0;
      final old = hit ? ways[hitWay] : null;
      final readThrough =
          txn.operation == BehavioralCacheOperation.readThrough.code;
      final writeAllocate =
          txn.operation == BehavioralCacheOperation.writeAllocate.code;
      final isFill = txn.operation == CacheTransactionOperation.fill.code;
      final isUpdate = txn.operation == CacheTransactionOperation.update.code;
      final isLookup = txn.operation == CacheTransactionOperation.lookup.code;
      final isInvalidate =
          txn.operation == CacheTransactionOperation.invalidate.code;
      if (!isFill &&
          !isUpdate &&
          !isLookup &&
          !isInvalidate &&
          !readThrough &&
          !writeAllocate) {
        finish(txn, CacheTransactionStatus.error.code);
        return;
      }
      if (!hit && !isFill && !readThrough && !writeAllocate) {
        finish(txn, CacheTransactionStatus.miss.code);
        return;
      }
      if (hit && (isLookup || readThrough)) {
        this.replacement.access(set, hitWay);
        finish(txn, CacheTransactionStatus.hit.code, old!.data, old.metadata);
        return;
      }
      final fetched = !hit && (readThrough || writeAllocate)
          ? backingStore.read(txn.address)
          : null;
      final beforeData = old?.data ?? fetched?.data;
      final beforeMetadata = old?.metadata ?? fetched?.metadata;
      var way = hitWay;
      if (!hit) {
        way = this
            .replacement
            .select(set, List.unmodifiable(ways.map((line) => line != null)));
        if (way < 0 || way >= waysPerSet) {
          throw StateError('Replacement policy selected an invalid way.');
        }
      }
      final victim = isInvalidate
          ? old
          : !hit
              ? ways[way]
              : null;
      txn.pending = _PendingCommit(
          way: way,
          hit: hit,
          beforeData: beforeData,
          beforeMetadata: beforeMetadata);
      if (victim == null) {
        commit(txn);
      } else {
        txn
          ..eviction = victim
          ..evictionCause = isInvalidate
              ? CacheTransactionEvictionCause.invalidation.code
              : CacheTransactionEvictionCause.replacement.code;
        evictionOffers[txn.port].add(txn);
      }
    }

    localClk.posedge.listen((_) {
      final resetValue = localReset.previousValue!;
      if (!resetValue.isValid) {
        throw StateError('Behavioral cache sampled an unknown reset.');
      }
      if (resetValue == LogicValue.one) {
        transactions.clear();
        for (final offers in evictionOffers) {
          offers.clear();
        }
        for (final ways in lines) {
          ways.fillRange(0, ways.length, null);
        }
        this.replacement.reset();
        _cycle = 0;
        refresh();
        return;
      }
      _cycle++;
      for (final (index, port) in localPorts.indexed) {
        final responseValid = port.responses.valid.previousValue!;
        final responseReady = port.responses.ready.previousValue!;
        if (responseValid == LogicValue.one && !responseReady.isValid) {
          throw StateError('Behavioral cache sampled unknown response ready.');
        }
        if (responseValid == LogicValue.one &&
            responseReady == LogicValue.one) {
          final txn = transactions.firstWhere((txn) => txn.port == index);
          transactions.remove(txn);
        }
        final evictionValid = port.evictions.valid.previousValue!;
        final evictionReady = port.evictions.ready.previousValue!;
        if (evictionValid == LogicValue.one && !evictionReady.isValid) {
          throw StateError('Behavioral cache sampled unknown eviction ready.');
        }
        if (evictionValid == LogicValue.one &&
            evictionReady == LogicValue.one) {
          final txn = evictionOffers[index].removeAt(0);
          final victim = txn.eviction!;
          backingStore.write(victim.address,
              data: victim.data, metadata: victim.metadata);
          txn.eviction = null;
          commit(txn);
        }
      }
      for (final (index, port) in localPorts.indexed) {
        final valid = port.requests.valid.previousValue!;
        final ready = port.requests.ready.previousValue!;
        if (!valid.isValid || (valid == LogicValue.one && !ready.isValid)) {
          throw StateError('Behavioral cache sampled unknown request control.');
        }
        if (valid != LogicValue.one || ready != LogicValue.one) {
          continue;
        }
        final input = port.requests.data;
        final operation = bits(input.operation, previous: true);
        final address = bits(input.address, previous: true);
        final token = bits(input.token, previous: true);
        if (!operation.isValid || !address.isValid || !token.isValid) {
          throw StateError('Behavioral cache requires known operation, address '
              'and token at request acceptance.');
        }
        transactions.add(_Transaction(
          port: index,
          operation:
              operation.toBigInt() <= BigInt.from(5) ? operation.toInt() : -1,
          address: address.toBigInt(),
          token: token,
          data: bits(input.data, previous: true),
          mask: bits(input.writeMask, previous: true),
          metadata: bits(input.lineMetadata, previous: true),
          context: bits(input.context, previous: true),
          eligibleCycle: _cycle + operationLatency,
        ));
      }
      var begun = 0;
      final blockedSets = <int>{};
      for (final txn in transactions) {
        if (txn.complete) {
          continue;
        }
        final set = setOf(txn.address);
        if (blockedSets.contains(set)) {
          continue;
        }
        if (txn.eviction != null ||
            txn.eligibleCycle > _cycle ||
            begun == operationsPerCycle) {
          blockedSets.add(set);
          continue;
        }
        begin(txn);
        begun++;
        if (!txn.complete) {
          blockedSets.add(set);
        }
      }
      refresh();
    });
    for (final port in localPorts) {
      port.requests.valid.glitch.listen((_) => refresh());
      port.requests.data.token.glitch.listen((_) => refresh());
    }
    localReset.glitch.listen((_) => refresh());
    _refresh = refresh;
    Simulator.injectAction(refresh);
  }

  /// Inspects a resident block without changing replacement state.
  BehavioralCacheBlock? peek(BigInt address) {
    backingStore._validateAddress(address);
    final set = (address % BigInt.from(setCount)).toInt();
    final line =
        _lines[set].where((line) => line?.address == address).firstOrNull;
    return line == null ? null : (data: line.data, metadata: line.metadata);
  }

  /// Replaces or inserts raw resident state without issuing an eviction.
  ///
  /// The cache must have no outstanding transactions. Inserting a new block
  /// into a full set is rejected rather than silently discarding a line.
  void poke(BigInt address,
      {required LogicValue data, required LogicValue metadata}) {
    backingStore._validateAddress(address);
    if (_transactions.isNotEmpty) {
      throw StateError('Raw cache writes require no outstanding transactions.');
    }
    if (data.width != backingStore.dataWidth ||
        metadata.width != backingStore.metadataWidth) {
      throw ArgumentError('Cache block widths do not match.');
    }
    final set = (address % BigInt.from(setCount)).toInt();
    final ways = _lines[set];
    var way = ways.indexWhere((line) => line?.address == address);
    if (way < 0) {
      way = ways.indexOf(null);
      if (way < 0) {
        throw StateError('Raw cache insertion requires an invalid way.');
      }
    }
    ways[way] = _Line(
        address, normalizeStoredValue(data), normalizeStoredValue(metadata));
  }

  /// Captures the cache, backing store, replacement and in-flight transactions.
  ///
  /// External channel peers and already transferred events are not rolled
  /// back. Custom replacement policies must implement
  /// [SnapshotableBehavioralCacheReplacement].
  BehavioralCacheImage snapshot() {
    final policy = replacement;
    if (policy is! SnapshotableBehavioralCacheReplacement) {
      throw UnsupportedError('Replacement policy does not support snapshots.');
    }
    if (backingStore.runtimeType != BehavioralCacheBackingStore) {
      throw UnsupportedError('Custom backing stores cannot be snapshotted.');
    }
    final indices = {
      for (final (index, txn) in _transactions.indexed) txn: index,
    };
    return BehavioralCacheImage._(
      configuration: _configuration,
      replacementType: policy.runtimeType,
      replacementState: (policy as SnapshotableBehavioralCacheReplacement)
          .snapshotReplacement(),
      lines: _lines,
      transactions: _transactions,
      evictionOffers: [
        for (final offers in _evictionOffers)
          [for (final txn in offers) indices[txn]!],
      ],
      cycle: _cycle,
      backing: backingStore.snapshot(),
    );
  }

  /// Atomically restores a compatible full image.
  ///
  /// Callers must also restore or coordinate external channel peers.
  void restore(BehavioralCacheImage image) {
    final policy = replacement;
    if (policy is! SnapshotableBehavioralCacheReplacement) {
      throw UnsupportedError('Replacement policy does not support snapshots.');
    }
    if (backingStore.runtimeType != BehavioralCacheBackingStore) {
      throw UnsupportedError('Custom backing stores cannot be restored.');
    }
    if (image._configuration != _configuration ||
        image._replacementType != policy.runtimeType) {
      throw ArgumentError('Cache image configuration does not match.');
    }
    backingStore._validateImage(image.backing);
    final snapshotPolicy = policy as SnapshotableBehavioralCacheReplacement;
    final restored = [for (final txn in image._transactions) txn.copy()];
    snapshotPolicy
      ..validateSnapshot(image._replacementState)
      ..restoreSnapshot(image._replacementState);
    backingStore.load(image.backing, replace: true);
    for (final (index, ways) in image._lines.indexed) {
      _lines[index].setAll(0, ways);
    }
    _transactions
      ..clear()
      ..addAll(restored);
    for (final (index, offers) in image._evictionOffers.indexed) {
      _evictionOffers[index]
        ..clear()
        ..addAll(offers.map((txn) => restored[txn]));
    }
    _cycle = image._cycle;
    _refresh();
  }
}
