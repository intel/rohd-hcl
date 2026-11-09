// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_contract_test.dart
// Tests transactional cache and scheduler API contracts.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

class _Metadata extends LogicStructure {
  _Metadata({String name = 'metadata'})
      : super([Logic(name: 'valid'), Logic(name: 'state', width: 3)],
            name: name);

  @override
  _Metadata clone({String? name}) => _Metadata(name: name ?? this.name);
}

class _QueueHarness extends Module {
  _QueueHarness() {
    final port = CacheTransactionPort<Logic, _Metadata, Logic, Logic>(
      addressWidth: 8,
      tokenWidth: 3,
      operationWidth: 3,
      dataSchema: Logic(width: 8),
      writeMaskWidth: 2,
      lineMetadataSchema: _Metadata(),
      contextSchema: Logic(width: 4),
      resultSchema: Logic(width: 2),
    );
    final request = port.requests.data;
    port.requests.valid <= addInput('valid', Logic());
    request.operation <= addInput('operation', Logic(width: 3), width: 3);
    request.address <= addInput('address', Logic(width: 8), width: 8);
    request.token <= addInput('token', Logic(width: 3), width: 3);
    request.data <= addInput('data', Logic(width: 8), width: 8);
    request.writeMask <= addInput('mask', Logic(width: 2), width: 2);
    request.lineMetadata <= addInput('metadata', Logic(width: 4), width: 4);
    request.context <= addInput('ctx', Logic(width: 4), width: 4);
    final downstream = IrrevocableReadyValidInterface(request.clone());
    downstream.ready <= addInput('ready', Logic());
    ReadyValidQueue<CacheTransactionRequest<Logic, _Metadata, Logic>>(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      upstream: port.requests,
      downstream: downstream,
      depth: 1,
    );
    addOutput('request_ready') <= port.requests.ready;
    addOutput('response_valid') <= downstream.valid;
    addOutput('out_operation', width: 3) <= downstream.data.operation;
    addOutput('out_address', width: 8) <= downstream.data.address;
    addOutput('out_token', width: 3) <= downstream.data.token;
    addOutput('out_data', width: 8) <= downstream.data.data;
    addOutput('out_mask', width: 2) <= downstream.data.writeMask;
    addOutput('out_metadata', width: 4) <= downstream.data.lineMetadata;
    addOutput('out_context', width: 4) <= downstream.data.context;
  }
}

class _SchedulerHarness extends Module {
  _SchedulerHarness() {
    final ports = CacheSchedulerPorts(requestCount: 2, capacities: [2]);
    final valid0 = addInput('valid0', Logic());
    final valid1 = addInput('valid1', Logic());
    final demand0 = addInput('demand0', Logic(width: 2), width: 2);
    final demand1 = addInput('demand1', Logic(width: 2), width: 2);
    final available = addInput('available', Logic(width: 2), width: 2);
    final conflict = addInput('conflict', Logic());
    ports.requests[0].valid <= valid0;
    ports.requests[1].valid <= valid1;
    ports.requests[0].demand[0] <= demand0;
    ports.requests[1].demand[0] <= demand1;
    ports.available[0] <= available;
    ports.conflicts[0] <= [conflict, Const(0)].concat();
    ports.conflicts[1] <= [Const(0), conflict].concat();
    ports.invalidInputs <=
        ports.available[0].gt(Const(2, width: 2)) |
            (ports.requests[0].valid &
                ports.requests[0].demand[0].gt(Const(2, width: 2))) |
            (ports.requests[1].valid &
                ports.requests[1].demand[0].gt(Const(2, width: 2)));
    final first = ~ports.invalidInputs &
        ports.requests[0].valid &
        ports.requests[0].demand[0].lte(ports.available[0]);
    final remaining = ports.available[0] -
        mux(first, ports.requests[0].demand[0], Const(0, width: 2));
    final second = ~ports.invalidInputs &
        ports.requests[1].valid &
        ports.requests[1].demand[0].lte(remaining) &
        ~(first & (ports.conflicts[0][1] | ports.conflicts[1][0]));
    ports.requests[0].grant <= first;
    ports.requests[1].grant <= second;
    addOutput('grant0') <= ports.requests[0].grant;
    addOutput('grant1') <= ports.requests[1].grant;
    addOutput('invalid') <= ports.invalidInputs;
  }
}

class _DifferentShapesHarness extends Module {
  _DifferentShapesHarness() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    for (final width in [8, 16]) {
      final request = CacheTransactionRequest<Logic, Logic, Logic>(
        addressWidth: 8,
        tokenWidth: 2,
        dataSchema: Logic(width: width),
        writeMaskWidth: 1,
        lineMetadataSchema: Logic(),
        contextSchema: Logic(),
      );
      final upstream = IrrevocableReadyValidInterface(request);
      upstream.valid <= Const(1);
      request <= Const(0, width: request.width);
      final downstream = IrrevocableReadyValidInterface(request.clone());
      downstream.ready <= Const(1);
      ReadyValidQueue<CacheTransactionRequest<Logic, Logic, Logic>>(
        clk: clk,
        reset: reset,
        upstream: upstream,
        downstream: downstream,
        depth: 1,
      );
      addOutput('out$width', width: width) <= downstream.data.data;
    }
  }
}

class _CoreContract
    implements
        CacheTransactionCore<_Metadata, _Metadata, _Metadata, _Metadata> {
  @override
  final List<CacheTransactionPort<_Metadata, _Metadata, _Metadata, _Metadata>>
      ports;

  @override
  final CacheTransactionCapabilities capabilities;

  _CoreContract(this.ports, this.capabilities);
}

class _AdapterContract
    implements
        CacheProtocolAdapter<Logic, Logic, _Metadata, _Metadata, _Metadata,
            _Metadata> {
  @override
  final ReadyValidInterface<Logic> requests;

  @override
  final ReadyValidInterface<Logic> responses;

  @override
  final CacheTransactionPort<_Metadata, _Metadata, _Metadata, _Metadata> cache;

  _AdapterContract(this.cache,
      {ReadyValidInterface<Logic>? requests,
      ReadyValidInterface<Logic>? responses})
      : requests = requests ?? ReadyValidInterface(Logic(width: 8)),
        responses = responses ?? ReadyValidInterface(Logic(width: 8));
}

class _EmptyModule extends Module {
  _EmptyModule({required super.name});
}

void main() {
  tearDown(Simulator.reset);

  test('scheduler ports preserve resource geometry and isolate input lists',
      () {
    final capacities = [1, 2, 4];
    final ports = CacheSchedulerPorts(requestCount: 3, capacities: capacities);
    capacities[0] = 5;
    expect(ports.capacities, [1, 2, 4]);
    expect(ports.available.map((signal) => signal.width), [1, 2, 3]);
    expect(ports.requests, hasLength(3));
    expect(
        ports.requests.first.demand.map((signal) => signal.width), [1, 2, 3]);
    expect(ports.conflicts.map((signal) => signal.width), [3, 3, 3]);
    final clone = ports.clone();
    expect(clone.capacities, [1, 2, 4]);
    expect(
        clone.requests.first.demand.map((signal) => signal.width), [1, 2, 3]);
    expect(clone.subInterfaces.keys,
        unorderedEquals(['request_0', 'request_1', 'request_2']));
    expect(identical(clone.requests.first.valid, ports.requests.first.valid),
        isFalse);
    expect(clone.requests.first.getPorts([PairDirection.fromConsumer]).keys,
        ['grant']);
    expect(() => ports.capacities.add(1), throwsUnsupportedError);
    expect(() => CacheSchedulerPorts(requestCount: 0, capacities: [1]),
        throwsArgumentError);
    expect(() => CacheSchedulerPorts(requestCount: 1, capacities: [0]),
        throwsArgumentError);
  });

  test('transaction port clones typed channels and extension widths', () {
    final port = CacheTransactionPort<Logic, _Metadata, _Metadata, Logic>(
      addressWidth: 9,
      tokenWidth: 3,
      operationWidth: 4,
      evictionCauseWidth: 3,
      dataSchema: Logic(width: 8),
      writeMaskWidth: 2,
      lineMetadataSchema: _Metadata(),
      contextSchema: _Metadata(),
      resultSchema: Logic(width: 5),
    );
    final clone = port.clone();
    expect(clone, isA<PairInterface>());
    expect(clone.subInterfaces.keys,
        unorderedEquals(['request', 'response', 'eviction']));
    expect(
        clone.getPorts([PairDirection.fromConsumer]).keys, ['tokenConflict']);
    expect(clone.requests.data.address.width, 9);
    expect(clone.requests.data.token.width, 3);
    expect(clone.requests.data.operation.width, 4);
    expect(clone.requests.data.writeMask.width, 2);
    expect(clone.requests.data.lineMetadata, isA<_Metadata>());
    expect(clone.responses.data.context, isA<_Metadata>());
    expect(clone.responses.data.result.width, 5);
    expect(clone.evictions.data.cause.width, 3);
    expect(identical(clone.requests.data, port.requests.data), isFalse);
  });

  test('scheduler boundary expresses capacity and pair conflicts', () async {
    final dut = _SchedulerHarness();
    final vectors = [
      Vector({
        'valid0': 1,
        'valid1': 1,
        'demand0': 1,
        'demand1': 1,
        'available': 2,
        'conflict': 0,
      }, {
        'grant0': 1,
        'grant1': 1
      }),
      Vector({'available': 1}, {'grant0': 1, 'grant1': 0}),
      Vector({'available': 2, 'conflict': 1}, {'grant0': 1, 'grant1': 0}),
      Vector({'valid0': 0}, {'grant0': 0, 'grant1': 1}),
      Vector({'available': 0}, {'grant0': 0, 'grant1': 0}),
      Vector({'available': 3}, {'grant0': 0, 'grant1': 0, 'invalid': 1}),
      Vector({
        'available': 2,
        'valid0': 1,
        'valid1': 0,
        'demand0': LogicValue.ofString('x1')
      }, {
        'invalid': LogicValue.x,
        'grant0': LogicValue.x,
        'grant1': 0
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('capabilities validate operations and extension encodings', () {
    final ops = {CacheTransactionOperation.lookup};
    final extensions = {4, 9};
    final capabilities = CacheTransactionCapabilities(
      operations: ops,
      extensionOperations: extensions,
      maxOutstanding: 4,
      responseOrdering: CacheTransactionOrdering.outOfOrder,
      sameBlockOrdering: CacheSameBlockOrdering.acceptanceOrder,
      sameCycleOrdering: CacheSameCycleOrdering.lowerPortFirst,
    );
    ops.clear();
    extensions.clear();
    expect(capabilities.operations, {CacheTransactionOperation.lookup});
    expect(capabilities.extensionOperations, {4, 9});
    expect(capabilities.supportsOperationWidth(3), isFalse);
    expect(capabilities.supportsOperationWidth(4), isTrue);
    CacheTransactionPort<Logic, Logic, Logic, Logic> port(int operationWidth) =>
        CacheTransactionPort(
          addressWidth: 8,
          tokenWidth: 2,
          operationWidth: operationWidth,
          dataSchema: Logic(width: 8),
          writeMaskWidth: 1,
          lineMetadataSchema: Logic(),
          contextSchema: Logic(),
          resultSchema: Logic(),
        );
    expect(() => capabilities.validatePort(port(3)), throwsArgumentError);
    expect(() => capabilities.validatePort(port(4)), returnsNormally);
    expect(
        () => capabilities.extensionOperations.add(12), throwsUnsupportedError);
    expect(
      () => CacheTransactionCapabilities(
        operations: {CacheTransactionOperation.lookup},
        extensionOperations: {3},
        maxOutstanding: 1,
        responseOrdering: CacheTransactionOrdering.inOrder,
        sameBlockOrdering: CacheSameBlockOrdering.acceptanceOrder,
        sameCycleOrdering: CacheSameCycleOrdering.lowerPortFirst,
      ),
      throwsArgumentError,
    );
    expect(
      () => CacheTransactionCapabilities(
        operations: {CacheTransactionOperation.lookup},
        maxOutstanding: 1,
        responseOrdering: CacheTransactionOrdering.inOrder,
        sameBlockOrdering: CacheSameBlockOrdering.acceptanceOrder,
        sameCycleOrdering: CacheSameCycleOrdering.lowerPortFirst,
        supportsMaskedUpdates: true,
      ),
      throwsArgumentError,
    );
    expect(CacheTransactionOperation.fill.code, 1);
    expect(CacheTransactionStatus.error.code, 3);
    expect(CacheTransactionEvictionCause.invalidation.code, 1);
  });

  test('transaction channels preserve typed schemas and clone geometry', () {
    final port = CacheTransactionPort<Logic, _Metadata, Logic, Logic>(
      addressWidth: 12,
      tokenWidth: 3,
      operationWidth: 4,
      evictionCauseWidth: 2,
      dataSchema: Logic(width: 16),
      writeMaskWidth: 2,
      lineMetadataSchema: _Metadata(),
      contextSchema: Logic(width: 5),
      resultSchema: Logic(width: 3),
    );
    expect(port.requests.data.lineMetadata, isA<_Metadata>());
    expect(port.responses.data.lineMetadata, isA<_Metadata>());
    expect(port.evictions.data.lineMetadata, isA<_Metadata>());
    expect(port.requests.contract, ReadyValidContract.irrevocable);
    expect(port.responses.contract, ReadyValidContract.irrevocable);
    expect(port.evictions.contract, ReadyValidContract.irrevocable);
    expect(
        sameDeclaredPayloadShape(
            port.requests.data, port.requests.data.clone()),
        isTrue);
    expect(
        sameDeclaredPayloadShape(
            port.responses.data, port.responses.data.clone()),
        isTrue);
    expect(
        sameDeclaredPayloadShape(
            port.evictions.data, port.evictions.data.clone()),
        isTrue);
    expect(port.requests.data.clone().operation.width, 4);
    expect(port.evictions.data.clone().cause.width, 2);
    expect(
      () => CacheTransactionPort<Logic, Logic, Logic, Logic>(
        addressWidth: 8,
        tokenWidth: 2,
        dataSchema: Logic(width: 8),
        writeMaskWidth: 3,
        lineMetadataSchema: Logic(),
        contextSchema: Logic(),
        resultSchema: Logic(),
      ),
      throwsArgumentError,
    );
  });

  test('core and adapter contracts compose structured payload types', () {
    final port =
        CacheTransactionPort<_Metadata, _Metadata, _Metadata, _Metadata>(
      addressWidth: 8,
      tokenWidth: 3,
      dataSchema: _Metadata(),
      writeMaskWidth: 2,
      lineMetadataSchema: _Metadata(),
      contextSchema: _Metadata(),
      resultSchema: _Metadata(),
    );
    final capabilities = CacheTransactionCapabilities(
      operations: {
        CacheTransactionOperation.lookup,
        CacheTransactionOperation.fill
      },
      maxOutstanding: 2,
      responseOrdering: CacheTransactionOrdering.inOrder,
      sameBlockOrdering: CacheSameBlockOrdering.acceptanceOrder,
      sameCycleOrdering: CacheSameCycleOrdering.lowerPortFirst,
    );
    final CacheTransactionCore<_Metadata, _Metadata, _Metadata, _Metadata>
        core = _CoreContract([port], capabilities);
    final CacheProtocolAdapter<Logic, Logic, _Metadata, _Metadata, _Metadata,
        _Metadata> adapter = _AdapterContract(core.ports.single);
    expect(
        () => core.capabilities.validatePort(adapter.cache), returnsNormally);
    expect(adapter.cache.requests.data.clone().data, isA<_Metadata>());
    expect(adapter.cache.responses.data.clone().result, isA<_Metadata>());
    expect(adapter.cache.evictions.data.clone().context, isA<_Metadata>());

    ({
      Module module,
      CacheTransactionCore<_Metadata, _Metadata, _Metadata, _Metadata> core,
    }) makeCore({
      required Logic clk,
      required Logic reset,
      required List<
              CacheTransactionPort<_Metadata, _Metadata, _Metadata, _Metadata>>
          ports,
      required int options,
      required String name,
    }) =>
        (
          module: _EmptyModule(name: name),
          core: _CoreContract(ports, capabilities)
        );
    final coreBuilder = makeCore;
    expect(
        coreBuilder,
        isA<
            CacheTransactionCoreBuilder<int, _Metadata, _Metadata, _Metadata,
                _Metadata>>());
    final binding = coreBuilder(
      clk: Logic(),
      reset: Logic(),
      ports: [port],
      options: 1,
      name: 'custom_core',
    );
    expect(identical(binding.core.ports.single, port), isTrue);

    ({
      Module module,
      CacheProtocolAdapter<Logic, Logic, _Metadata, _Metadata, _Metadata,
          _Metadata> adapter,
    }) makeAdapter({
      required Logic clk,
      required Logic reset,
      required ReadyValidInterface<Logic> requests,
      required ReadyValidInterface<Logic> responses,
      required CacheTransactionPort<_Metadata, _Metadata, _Metadata, _Metadata>
          cache,
      required int options,
      required String name,
    }) =>
        (
          module: _EmptyModule(name: name),
          adapter:
              _AdapterContract(cache, requests: requests, responses: responses)
        );
    final adapterBuilder = makeAdapter;
    expect(
        adapterBuilder,
        isA<
            CacheProtocolAdapterBuilder<int, Logic, Logic, _Metadata, _Metadata,
                _Metadata, _Metadata>>());
    final requests = ReadyValidInterface(Logic(width: 8));
    final responses = ReadyValidInterface(Logic(width: 8));
    final adapterBinding = adapterBuilder(
      clk: Logic(),
      reset: Logic(),
      requests: requests,
      responses: responses,
      cache: port,
      options: 1,
      name: 'custom_adapter',
    );
    expect(identical(adapterBinding.adapter.requests, requests), isTrue);
    expect(identical(adapterBinding.adapter.cache, port), isTrue);
  });

  test('typed requests survive ready/valid buffering and stalls', () async {
    final dut = _QueueHarness();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'valid': 0,
        'ready': 0,
        'operation': 5,
        'address': 0x32,
        'token': 3,
        'data': 0x5a,
        'mask': 2,
        'metadata': 9,
        'ctx': 7,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'valid': 1}, {'request_ready': 1}),
      Vector({'clk': 1}, {'response_valid': 1}),
      Vector({
        'clk': 0,
        'valid': 0,
        'address': 0
      }, {
        'response_valid': 1,
        'request_ready': 0,
        'out_operation': 5,
        'out_address': 0x32,
        'out_token': 3,
        'out_data': 0x5a,
        'out_mask': 2,
        'out_metadata': 9,
        'out_context': 7,
      }),
      Vector({'clk': 1}, {'response_valid': 1, 'out_address': 0x32}),
      Vector({'clk': 0, 'ready': 1}, {'response_valid': 1}),
      Vector({'clk': 1}, {'response_valid': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
  });

  test('differently shaped request queues coexist in generated RTL', () async {
    final dut = _DifferentShapesHarness();
    await dut.build();
    SimCompare.checkIverilogVector(dut, [
      Vector({'clk': 0, 'reset': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0}, {}),
      Vector({'clk': 1}, {'out8': 0, 'out16': 0}),
    ]);
  });
}
