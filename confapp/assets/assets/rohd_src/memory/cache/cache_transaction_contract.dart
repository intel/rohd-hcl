// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_transaction_contract.dart
// Protocol-neutral transactional cache interfaces.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';

/// Operation encoded in a [CacheTransactionRequest].
///
/// The wire encoding is [code]; values above the built-ins may be negotiated
/// by an implementation as extensions.
@experimental
enum CacheTransactionOperation {
  /// Read a block without modifying it.
  lookup(0),

  /// Install a complete block, replacing an existing entry if needed.
  fill(1),

  /// Update selected data units of an existing block; do not allocate on miss.
  update(2),

  /// Invalidate a matching block.
  invalidate(3);

  /// Wire encoding for this protocol.
  final int code;

  const CacheTransactionOperation(this.code);
}

/// Completion encoded in a [CacheTransactionResponse].
///
/// The wire encoding is [code].
@experimental
enum CacheTransactionStatus {
  /// The operation found a matching block.
  hit(0),

  /// The operation did not find a matching block.
  miss(1),

  /// The operation completed without a hit/miss result.
  completed(2),

  /// The operation failed; implementation-specific details are in the result.
  error(3);

  /// Wire encoding for this protocol.
  final int code;

  const CacheTransactionStatus(this.code);
}

/// Why an existing block is reported on the eviction channel.
@experimental
enum CacheTransactionEvictionCause {
  /// A fill replaces an entry containing a different block.
  replacement(0),

  /// An invalidation removes an entry.
  invalidation(1);

  /// Wire encoding for this protocol.
  final int code;

  const CacheTransactionEvictionCause(this.code);
}

/// Ordering of responses on one transaction port.
@experimental
enum CacheTransactionOrdering {
  /// Responses are returned in request acceptance order.
  inOrder,

  /// Responses may be returned in any order.
  outOfOrder,
}

/// Ordering of operations to the same block accepted on different edges.
@experimental
enum CacheSameBlockOrdering {
  /// Operations take effect in their request acceptance order.
  acceptanceOrder,

  /// The implementation specifies another ordering rule.
  implementationDefined,
}

/// Tie-breaking for same-block requests accepted on the same edge.
@experimental
enum CacheSameCycleOrdering {
  /// Lower-numbered transaction ports take effect first.
  lowerPortFirst,

  /// The implementation specifies another ordering rule.
  implementationDefined,
}

/// Static promises of a transactional cache implementation.
@experimental
class CacheTransactionCapabilities {
  /// Operations accepted by this implementation.
  final Set<CacheTransactionOperation> operations;

  /// Additional operation encodings, agreed by the core and its adapter.
  final Set<int> extensionOperations;

  /// Maximum accepted requests outstanding across all transaction ports.
  final int maxOutstanding;

  /// Ordering of responses on each individual transaction port.
  final CacheTransactionOrdering responseOrdering;

  /// Ordering of same-block operations accepted on different edges.
  final CacheSameBlockOrdering sameBlockOrdering;

  /// Ordering of same-block operations accepted on one edge.
  final CacheSameCycleOrdering sameCycleOrdering;

  /// Whether updates support masks other than all ones.
  final bool supportsMaskedUpdates;

  /// Whether successful invalidations emit an eviction event.
  final bool reportsInvalidations;

  /// Creates a capability declaration.
  factory CacheTransactionCapabilities({
    required Set<CacheTransactionOperation> operations,
    required int maxOutstanding,
    required CacheTransactionOrdering responseOrdering,
    required CacheSameBlockOrdering sameBlockOrdering,
    required CacheSameCycleOrdering sameCycleOrdering,
    Set<int> extensionOperations = const {},
    bool supportsMaskedUpdates = false,
    bool reportsInvalidations = false,
  }) {
    if ((operations.isEmpty && extensionOperations.isEmpty) ||
        extensionOperations.any((code) => code < 4) ||
        maxOutstanding < 1 ||
        (supportsMaskedUpdates &&
            !operations.contains(CacheTransactionOperation.update)) ||
        (reportsInvalidations &&
            !operations.contains(CacheTransactionOperation.invalidate))) {
      throw ArgumentError('Invalid transactional cache capabilities.');
    }
    return CacheTransactionCapabilities._(
      Set.unmodifiable(operations),
      Set.unmodifiable(extensionOperations),
      maxOutstanding,
      responseOrdering,
      sameBlockOrdering,
      sameCycleOrdering,
      supportsMaskedUpdates,
      reportsInvalidations,
    );
  }

  const CacheTransactionCapabilities._(
    this.operations,
    this.extensionOperations,
    this.maxOutstanding,
    this.responseOrdering,
    this.sameBlockOrdering,
    this.sameCycleOrdering,
    this.supportsMaskedUpdates,
    this.reportsInvalidations,
  );

  /// Checks that [width] can encode every advertised operation.
  bool supportsOperationWidth(int width) =>
      width >= 2 &&
      extensionOperations
          .every((code) => BigInt.from(code) < (BigInt.one << width));

  /// Rejects a port that cannot encode all advertised operations.
  void validatePort<T extends Logic, M extends Logic, C extends Logic,
      R extends Logic>(CacheTransactionPort<T, M, C, R> port) {
    if (!supportsOperationWidth(port.requests.data.operation.width)) {
      throw ArgumentError('The transaction port cannot encode all advertised '
          'cache operations.');
    }
  }
}

/// A request carrying separately typed block data, stored metadata and context.
@experimental
class CacheTransactionRequest<T extends Logic, M extends Logic, C extends Logic>
    extends LogicStructure {
  /// [CacheTransactionOperation.code] or an agreed extension code.
  Logic get operation => elements[0];

  /// Block address.
  Logic get address => elements[1];

  /// Caller-owned identifier, unique among outstanding requests on this port.
  Logic get token => elements[2];

  /// Block data used by fills and updates.
  T get data => elements[3] as T;

  /// Equal-sized data-unit enables for updates; not used by other operations.
  Logic get writeMask => elements[4];

  /// Metadata to store with a filled or updated block.
  M get lineMetadata => elements[5] as M;

  /// Caller context returned unchanged with responses and eviction events.
  /// Agreed extension operations may also interpret its contents.
  C get context => elements[6] as C;

  /// Creates a request schema.
  CacheTransactionRequest({
    required int addressWidth,
    required int tokenWidth,
    required T dataSchema,
    required int writeMaskWidth,
    required M lineMetadataSchema,
    required C contextSchema,
    int operationWidth = 2,
    String name = 'cache_request',
  }) : super([
          Logic(name: 'operation', width: operationWidth),
          Logic(name: 'address', width: addressWidth),
          Logic(name: 'token', width: tokenWidth),
          dataSchema.cloneTyped(name: 'data'),
          Logic(name: 'writeMask', width: writeMaskWidth),
          lineMetadataSchema.cloneTyped(name: 'lineMetadata'),
          contextSchema.cloneTyped(name: 'requestContext'),
        ], name: name) {
    if (operationWidth < 2 ||
        addressWidth < 1 ||
        tokenWidth < 1 ||
        writeMaskWidth < 1 ||
        dataSchema.width % writeMaskWidth != 0) {
      throw ArgumentError('Invalid cache transaction request geometry.');
    }
  }

  @override
  CacheTransactionRequest<T, M, C> clone({String? name}) =>
      CacheTransactionRequest<T, M, C>(
        addressWidth: address.width,
        tokenWidth: token.width,
        operationWidth: operation.width,
        dataSchema: data,
        writeMaskWidth: writeMask.width,
        lineMetadataSchema: lineMetadata,
        contextSchema: context,
        name: name ?? this.name,
      );
}

/// Completion carrying the request token and context.
@experimental
class CacheTransactionResponse<T extends Logic, M extends Logic,
    C extends Logic, R extends Logic> extends LogicStructure {
  /// Identifier from the accepted request.
  Logic get token => elements[0];

  /// [CacheTransactionStatus.code].
  Logic get status => elements[1];

  /// Block data when defined by the operation and status.
  T get data => elements[2] as T;

  /// Stored block metadata when defined by the operation and status.
  M get lineMetadata => elements[3] as M;

  /// Context from the accepted request.
  C get context => elements[4] as C;

  /// Implementation-specific result or error details.
  R get result => elements[5] as R;

  /// Creates a response schema.
  CacheTransactionResponse({
    required int tokenWidth,
    required T dataSchema,
    required M lineMetadataSchema,
    required C contextSchema,
    required R resultSchema,
    String name = 'cache_response',
  }) : super([
          Logic(name: 'token', width: tokenWidth),
          Logic(name: 'status', width: 2),
          dataSchema.cloneTyped(name: 'data'),
          lineMetadataSchema.cloneTyped(name: 'lineMetadata'),
          contextSchema.cloneTyped(name: 'requestContext'),
          resultSchema.cloneTyped(name: 'result'),
        ], name: name) {
    if (tokenWidth < 1) {
      throw ArgumentError.value(tokenWidth, 'tokenWidth', 'Must be positive.');
    }
  }

  @override
  CacheTransactionResponse<T, M, C, R> clone({String? name}) =>
      CacheTransactionResponse<T, M, C, R>(
        tokenWidth: token.width,
        dataSchema: data,
        lineMetadataSchema: lineMetadata,
        contextSchema: context,
        resultSchema: result,
        name: name ?? this.name,
      );
}

/// An existing block reported before replacement or invalidation.
@experimental
class CacheTransactionEviction<T extends Logic, M extends Logic,
    C extends Logic> extends LogicStructure {
  /// Identifier of the request causing this event.
  Logic get token => elements[0];

  /// [CacheTransactionEvictionCause.code] or an agreed extension cause.
  Logic get cause => elements[1];

  /// Address of the removed block.
  Logic get address => elements[2];

  /// Data of the removed block.
  T get data => elements[3] as T;

  /// Stored metadata of the removed block.
  M get lineMetadata => elements[4] as M;

  /// Context of the request causing this event.
  C get context => elements[5] as C;

  /// Creates an eviction schema.
  CacheTransactionEviction({
    required int addressWidth,
    required int tokenWidth,
    required T dataSchema,
    required M lineMetadataSchema,
    required C contextSchema,
    int causeWidth = 1,
    String name = 'cache_eviction',
  }) : super([
          Logic(name: 'token', width: tokenWidth),
          Logic(name: 'cause', width: causeWidth),
          Logic(name: 'address', width: addressWidth),
          dataSchema.cloneTyped(name: 'data'),
          lineMetadataSchema.cloneTyped(name: 'lineMetadata'),
          contextSchema.cloneTyped(name: 'requestContext'),
        ], name: name) {
    if (addressWidth < 1 || tokenWidth < 1 || causeWidth < 1) {
      throw ArgumentError('Invalid cache eviction geometry.');
    }
  }

  @override
  CacheTransactionEviction<T, M, C> clone({String? name}) =>
      CacheTransactionEviction<T, M, C>(
        addressWidth: address.width,
        tokenWidth: token.width,
        causeWidth: cause.width,
        dataSchema: data,
        lineMetadataSchema: lineMetadata,
        contextSchema: context,
        name: name ?? this.name,
      );
}

/// Request, response, and eviction channels for a transactional cache port.
///
/// The caller provides requests and consumes responses and evictions. All
/// three channels require stable offers until transfer. Reset is controlled by
/// the enclosing implementation, not by this port.
@experimental
class CacheTransactionPort<T extends Logic, M extends Logic, C extends Logic,
    R extends Logic> extends PairInterface {
  /// Operations submitted to the cache.
  final IrrevocableReadyValidInterface<CacheTransactionRequest<T, M, C>>
      requests;

  /// One completion per accepted request, unless reset cancels it.
  final IrrevocableReadyValidInterface<CacheTransactionResponse<T, M, C, R>>
      responses;

  /// Existing blocks reported before they are removed.
  final IrrevocableReadyValidInterface<CacheTransactionEviction<T, M, C>>
      evictions;

  /// The offered request's token is still owned by an earlier request.
  ///
  /// The core must not accept a conflicting request. A token remains owned
  /// through the edge on which its previous response transfers.
  Logic get tokenConflict => port('tokenConflict');

  /// Creates matching channel schemas.
  CacheTransactionPort({
    required int addressWidth,
    required int tokenWidth,
    required T dataSchema,
    required int writeMaskWidth,
    required M lineMetadataSchema,
    required C contextSchema,
    required R resultSchema,
    int operationWidth = 2,
    int evictionCauseWidth = 1,
  })  : requests = IrrevocableReadyValidInterface(
          CacheTransactionRequest<T, M, C>(
            addressWidth: addressWidth,
            tokenWidth: tokenWidth,
            operationWidth: operationWidth,
            dataSchema: dataSchema,
            writeMaskWidth: writeMaskWidth,
            lineMetadataSchema: lineMetadataSchema,
            contextSchema: contextSchema,
          ),
        ),
        responses = IrrevocableReadyValidInterface(
          CacheTransactionResponse<T, M, C, R>(
            tokenWidth: tokenWidth,
            dataSchema: dataSchema,
            lineMetadataSchema: lineMetadataSchema,
            contextSchema: contextSchema,
            resultSchema: resultSchema,
          ),
        ),
        evictions = IrrevocableReadyValidInterface(
          CacheTransactionEviction<T, M, C>(
            addressWidth: addressWidth,
            tokenWidth: tokenWidth,
            causeWidth: evictionCauseWidth,
            dataSchema: dataSchema,
            lineMetadataSchema: lineMetadataSchema,
            contextSchema: contextSchema,
          ),
        ),
        super(portsFromConsumer: [Logic.port('tokenConflict')]) {
    addSubInterface('request', requests,
        uniquify: (signal) => 'request_$signal');
    addSubInterface('response', responses,
        reverse: true, uniquify: (signal) => 'response_$signal');
    addSubInterface('eviction', evictions,
        reverse: true, uniquify: (signal) => 'eviction_$signal');
  }

  @override
  CacheTransactionPort<T, M, C, R> clone() => CacheTransactionPort<T, M, C, R>(
        addressWidth: requests.data.address.width,
        tokenWidth: requests.data.token.width,
        operationWidth: requests.data.operation.width,
        dataSchema: requests.data.data,
        writeMaskWidth: requests.data.writeMask.width,
        lineMetadataSchema: requests.data.lineMetadata,
        contextSchema: requests.data.context,
        resultSchema: responses.data.result,
        evictionCauseWidth: evictions.data.cause.width,
      );
}

/// Boundary implemented by a transactional cache core.
///
/// The core consumes each port's requests and produces its responses and
/// evictions. [capabilities] applies across the complete list of ports.
@experimental
abstract interface class CacheTransactionCore<T extends Logic, M extends Logic,
    C extends Logic, R extends Logic> {
  /// Independently handshaken transaction ports.
  List<CacheTransactionPort<T, M, C, R>> get ports;

  /// Operations, ordering, and outstanding capacity provided by the core.
  CacheTransactionCapabilities get capabilities;
}

/// Builds a transactional core on caller-owned ports.
///
/// [O] is an implementation-specific configuration, allowing a core to
/// select its own tag, data, metadata, scheduling, and pipeline resources.
/// The returned [Module] participates in RTL; the core describes the same
/// composition and its capabilities.
@experimental
typedef CacheTransactionCoreBuilder<O, T extends Logic, M extends Logic,
        C extends Logic, R extends Logic>
    = ({
  Module module,
  CacheTransactionCore<T, M, C, R> core,
})
        Function({
  required Logic clk,
  required Logic reset,
  required List<CacheTransactionPort<T, M, C, R>> ports,
  required O options,
  required String name,
});

/// Boundary implemented by an adapter for an external request/response protocol.
///
/// The adapter consumes [requests], supplies [responses], and acts as the
/// caller of [cache]. External payloads and ordering are adapter-specific.
@experimental
abstract interface class CacheProtocolAdapter<Q extends Logic, S extends Logic,
    T extends Logic, M extends Logic, C extends Logic, R extends Logic> {
  /// External requests consumed by the adapter.
  ReadyValidInterface<Q> get requests;

  /// External responses produced by the adapter.
  ReadyValidInterface<S> get responses;

  /// Transactional cache port driven and consumed by the adapter.
  CacheTransactionPort<T, M, C, R> get cache;
}

/// Builds a protocol adapter on caller-owned external and cache channels.
///
/// [O] carries implementation-specific protocol and tracking configuration.
@experimental
typedef CacheProtocolAdapterBuilder<O, Q extends Logic, S extends Logic,
        T extends Logic, M extends Logic, C extends Logic, R extends Logic>
    = ({
  Module module,
  CacheProtocolAdapter<Q, S, T, M, C, R> adapter,
})
        Function({
  required Logic clk,
  required Logic reset,
  required ReadyValidInterface<Q> requests,
  required ReadyValidInterface<S> responses,
  required CacheTransactionPort<T, M, C, R> cache,
  required O options,
  required String name,
});
