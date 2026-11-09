// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_transaction_adapter.dart
// Ready/valid transaction transport with bounded token tracking.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/memory/cache/cache_transaction_contract.dart';

/// Buffers requests and tracks tokens across a transactional cache port.
///
/// The external channels use the protocol-neutral cache transaction payloads.
/// The adapter does not service misses or perform backing-store operations.
/// {@category Memory}
@experimental
class CacheTransactionAdapter<T extends Logic, M extends Logic, C extends Logic,
        R extends Logic> extends Module
    implements
        CacheProtocolAdapter<CacheTransactionRequest<T, M, C>,
            CacheTransactionResponse<T, M, C, R>, T, M, C, R> {
  @override
  final ReadyValidInterface<CacheTransactionRequest<T, M, C>> requests;

  @override
  final ReadyValidInterface<CacheTransactionResponse<T, M, C, R>> responses;

  /// Eviction events presented to the external consumer.
  final ReadyValidInterface<CacheTransactionEviction<T, M, C>> evictions;

  @override
  final CacheTransactionPort<T, M, C, R> cache;

  /// An offered request uses an outstanding token.
  Logic get duplicateRequest => output('duplicateRequest');

  /// The cache offered a response with no outstanding matching token.
  Logic get invalidResponse => output('invalidResponse');

  /// The cache offered an eviction with no outstanding matching token.
  Logic get invalidEviction => output('invalidEviction');

  /// Number of requests tracked, including a buffered request.
  final int maxOutstanding;

  /// Creates a bounded adapter. The supplied channels must be irrevocable.
  CacheTransactionAdapter({
    required Logic clk,
    required Logic reset,
    required this.requests,
    required this.responses,
    required this.evictions,
    required this.cache,
    required this.maxOutstanding,
    super.name = 'cache_transaction_adapter',
  }) : super(
          definitionName: 'CacheTransactionAdapter_N${maxOutstanding}_'
              '${payloadShapeIdentity(requests.data)}_'
              '${payloadShapeIdentity(responses.data)}_'
              '${payloadShapeIdentity(evictions.data)}',
        ) {
    if (clk.width != 1 || reset.width != 1 || maxOutstanding < 1) {
      throw ArgumentError('Invalid adapter clock, reset, or capacity.');
    }
    if (!requests.contract.satisfies(ReadyValidContract.irrevocable) ||
        !responses.contract.satisfies(ReadyValidContract.irrevocable) ||
        !evictions.contract.satisfies(ReadyValidContract.irrevocable) ||
        !sameDeclaredPayloadShape(requests.data, cache.requests.data) ||
        !sameDeclaredPayloadShape(responses.data, cache.responses.data) ||
        !sameDeclaredPayloadShape(evictions.data, cache.evictions.data)) {
      throw ArgumentError('Adapter channels must have matching payloads and '
          'irrevocable contracts.');
    }
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final inputRequests = addInterfacePorts(requests,
        inputTags: [PairDirection.fromProvider],
        outputTags: [PairDirection.fromConsumer],
        uniquify: (signal) => 'input_request_$signal');
    final outputResponses = addInterfacePorts(responses,
        inputTags: [PairDirection.fromConsumer],
        outputTags: [PairDirection.fromProvider],
        uniquify: (signal) => 'output_response_$signal');
    final outputEvictions = addInterfacePorts(evictions,
        inputTags: [PairDirection.fromConsumer],
        outputTags: [PairDirection.fromProvider],
        uniquify: (signal) => 'output_eviction_$signal');
    final localCache = addInterfacePorts(cache,
        inputTags: [PairDirection.fromConsumer],
        outputTags: [PairDirection.fromProvider],
        uniquify: (signal) => 'cache_$signal');
    final cacheRequests = localCache.requests;
    final cacheResponses = localCache.responses;
    final cacheEvictions = localCache.evictions;

    final occupied = [for (var i = 0; i < maxOutstanding; i++) Logic()];
    final tokens = [
      for (var i = 0; i < maxOutstanding; i++)
        Logic(width: requests.data.token.width)
    ];
    Logic combine(List<Logic> values) =>
        values.reduce((left, right) => left | right);
    Logic matches(Logic token) => combine([
          for (var i = 0; i < maxOutstanding; i++)
            occupied[i] & tokens[i].eq(token)
        ]);
    final duplicate = matches(inputRequests.data.token);
    final free = combine([for (final entry in occupied) ~entry]);
    final staged = Logic(name: 'staged');
    final stagedData =
        Logic(name: 'staged_data', width: inputRequests.data.width);
    inputRequests.ready <= ~localReset & ~staged & free & ~duplicate;
    final accept = inputRequests.valid & inputRequests.ready;
    cacheRequests.valid <= ~localReset & staged;
    cacheRequests.data <= stagedData;
    final issue = cacheRequests.valid & cacheRequests.ready;
    staged <=
        flop(localClk, mux(accept, Const(1), mux(issue, Const(0), staged)),
            reset: localReset);
    stagedData <=
        flop(localClk, mux(accept, inputRequests.data, stagedData),
            reset: localReset);

    final responseMatch = matches(cacheResponses.data.token);
    outputResponses.valid <= ~localReset & cacheResponses.valid & responseMatch;
    outputResponses.data <= cacheResponses.data;
    cacheResponses.ready <= ~localReset & outputResponses.ready & responseMatch;
    final finish = cacheResponses.valid & cacheResponses.ready;

    final evictionMatch = matches(cacheEvictions.data.token);
    outputEvictions.valid <= ~localReset & cacheEvictions.valid & evictionMatch;
    outputEvictions.data <= cacheEvictions.data;
    cacheEvictions.ready <= ~localReset & outputEvictions.ready & evictionMatch;

    addOutput('duplicateRequest') <=
        ~localReset & inputRequests.valid & duplicate;
    addOutput('invalidResponse') <=
        ~localReset & cacheResponses.valid & ~responseMatch;
    addOutput('invalidEviction') <=
        ~localReset & cacheEvictions.valid & ~evictionMatch;

    Logic earlierFree = Const(0);
    for (var i = 0; i < maxOutstanding; i++) {
      final allocate = accept & ~occupied[i] & ~earlierFree;
      earlierFree = earlierFree | ~occupied[i];
      final release =
          finish & occupied[i] & tokens[i].eq(cacheResponses.data.token);
      occupied[i] <=
          flop(localClk,
              mux(allocate, Const(1), mux(release, Const(0), occupied[i])),
              reset: localReset);
      tokens[i] <=
          flop(localClk, mux(allocate, inputRequests.data.token, tokens[i]),
              reset: localReset);
    }
  }
}
