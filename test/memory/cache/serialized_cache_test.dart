// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serialized_cache_test.dart
// Tests a latency-bearing transactional cache.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _SynchronousArray<T extends Logic> extends Memory<T> {
  @override
  final int readLatency;

  _SynchronousArray(super.clk, super.reset, super.writePorts, super.readPorts,
      {required int entryCount, required this.readLatency, required super.name})
      : super(
            definitionName: 'TestSynchronousArray_E${entryCount}_'
                'L${readLatency}_D${writePorts.first.dataWidth}') {
    final read = DataPortInterface<T>.typed(rdPorts.single.data, addrWidth);
    read.en <= rdPorts.single.en;
    read.addr <= rdPorts.single.addr;
    RegisterFile<T>(clk, reset, wrPorts, [read], numEntries: entryCount);
    Logic result = read.data;
    for (var stage = 0; stage < readLatency; stage++) {
      result = flop(clk, result, reset: reset);
    }
    rdPorts.single.data <= result;
  }
}

class _Data extends LogicStructure {
  _Data({String name = 'data'})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name);

  @override
  _Data clone({String? name}) => _Data(name: name ?? this.name);
}

class _Metadata extends LogicStructure {
  _Metadata({String name = 'metadata'})
      : super([Logic(name: 'dirty'), Logic(name: 'shared')], name: name);

  @override
  _Metadata clone({String? name}) => _Metadata(name: name ?? this.name);
}

class _Context extends LogicStructure {
  _Context({String name = 'context'})
      : super([Logic(name: 'source', width: 2), Logic(name: 'flags', width: 2)],
            name: name);

  @override
  _Context clone({String? name}) => _Context(name: name ?? this.name);
}

class _Result extends LogicStructure {
  _Result({String name = 'result'})
      : super([Logic(name: 'error'), Logic(name: 'detail')], name: name);

  @override
  _Result clone({String? name}) => _Result(name: name ?? this.name);
}

class _MismatchedProvider extends Module implements BehavioralModelProvider {
  _MismatchedProvider() {
    addInput('clk', Logic());
  }

  @override
  BehavioralModel get behavioralModel => _MismatchedModel();
}

class _MismatchedModel implements BehavioralModel {
  @override
  BehavioralModelDescription get description =>
      InferredSramDescription(addressWidth: 2, dataWidth: 8, entryCount: 4);

  @override
  String generateSystemC(
          {required String className,
          SystemCModelOptions options = const SystemCModelOptions()}) =>
      throw StateError('Port validation must precede export.');
}

class _TypedHarness extends Module {
  _TypedHarness(
      {required bool behavioral,
      bool inferredSram = false,
      bool behavioralTags = false}) {
    CacheTransactionPort<_Data, _Metadata, _Context, _Result> port() =>
        CacheTransactionPort(
          addressWidth: 8,
          tokenWidth: 2,
          operationWidth: 3,
          dataSchema: _Data(),
          writeMaskWidth: 2,
          lineMetadataSchema: _Metadata(),
          contextSchema: _Context(),
          resultSchema: _Result(),
        );
    final external = port();
    final internal = port();
    external.requests.valid <= addInput('iv', Logic());
    external.requests.data.operation <=
        addInput('op', Logic(width: 3), width: 3);
    external.requests.data.address <=
        addInput('addr', Logic(width: 8), width: 8);
    external.requests.data.token <=
        addInput('token', Logic(width: 2), width: 2);
    external.requests.data.data <= addInput('data', Logic(width: 8), width: 8);
    external.requests.data.writeMask <=
        addInput('mask', Logic(width: 2), width: 2);
    external.requests.data.lineMetadata <=
        addInput('meta', Logic(width: 2), width: 2);
    external.requests.data.context <=
        addInput('ctx', Logic(width: 4), width: 4);
    external.responses.ready <= addInput('rr', Logic());
    external.evictions.ready <= addInput('er', Logic());
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    CacheTransactionAdapter(
      clk: clk,
      reset: reset,
      requests: external.requests,
      responses: external.responses,
      evictions: external.evictions,
      cache: internal,
      maxOutstanding: 2,
    );
    final factory = inferredSram
        ? inferredSramArray<_Data>()
        : MemoryArrayFunctor<_Data>(
            identity: behavioral ? 'typedBehavioralSram' : 'typedFlopSram',
            capabilities: MemoryArrayCapabilities(
              readLatency: 1,
              readCollision: MemoryArrayReadCollision.oldData,
              writeCollision: MemoryArrayWriteCollision.disallow,
              supportsMaskedWrites: false,
              implementation: behavioral
                  ? MemoryArrayImplementation.simulationOnly
                  : MemoryArrayImplementation.synthesizable,
              maxReadPorts: 1,
              maxWritePorts: 1,
              maxConcurrentAccesses: 1,
            ),
            build: ({
              required clk,
              required reset,
              required writePorts,
              required readPorts,
              required entryCount,
              required name,
            }) =>
                behavioral
                    ? MemoryModel<_Data>(clk, reset, writePorts, readPorts,
                        asyncReset: false, name: name)
                    : _SynchronousArray<_Data>(
                        clk, reset, writePorts, readPorts,
                        entryCount: entryCount, readLatency: 1, name: name),
          );
    SerializedCache<_Data, _Metadata, _Context, _Result>(
      clk: clk,
      reset: reset,
      ports: [internal],
      setCount: 2,
      waysPerSet: 2,
      dataMemory: factory,
      tagMemory: behavioralTags
          ? behavioralParallelAssociativeMemoryFunctor
          : parallelAssociativeMemoryFunctor,
    );
    addOutput('ir') <= external.requests.ready;
    addOutput('rv') <= external.responses.valid;
    addOutput('rt', width: 2) <= external.responses.data.token;
    addOutput('rs', width: 2) <= external.responses.data.status;
    addOutput('rd', width: 8) <= external.responses.data.data;
    addOutput('rm', width: 2) <= external.responses.data.lineMetadata;
    addOutput('rc', width: 4) <= external.responses.data.context;
    addOutput('ev') <= external.evictions.valid;
    addOutput('et', width: 2) <= external.evictions.data.token;
    addOutput('ec') <= external.evictions.data.cause;
    addOutput('ea', width: 8) <= external.evictions.data.address;
    addOutput('ed', width: 8) <= external.evictions.data.data;
    addOutput('em', width: 2) <= external.evictions.data.lineMetadata;
  }
}

class _Harness extends Module {
  _Harness(int latency,
      {required bool behavioral,
      bool behavioralReplacement = false,
      BehavioralReplacementKind replacementKind =
          BehavioralReplacementKind.roundRobin,
      bool behavioralMetadata = false,
      bool behavioralTags = false,
      bool synchronousMetadata = false,
      bool inferredSram = false,
      bool twoPorts = false,
      bool useAdapter = false}) {
    if (twoPorts && useAdapter) {
      throw ArgumentError('The test harness uses one adapter port.');
    }
    final port = CacheTransactionPort<Logic, Logic, Logic, Logic>(
      addressWidth: 8,
      tokenWidth: 2,
      operationWidth: 3,
      dataSchema: Logic(width: 8),
      writeMaskWidth: 2,
      lineMetadataSchema: Logic(width: 2),
      contextSchema: Logic(width: 4),
      resultSchema: Logic(width: 2),
    );
    port.requests.valid <= addInput('iv', Logic());
    port.requests.data.operation <= addInput('op', Logic(width: 3), width: 3);
    port.requests.data.address <= addInput('addr', Logic(width: 8), width: 8);
    port.requests.data.token <= addInput('token', Logic(width: 2), width: 2);
    port.requests.data.data <= addInput('data', Logic(width: 8), width: 8);
    port.requests.data.writeMask <= addInput('mask', Logic(width: 2), width: 2);
    port.requests.data.lineMetadata <=
        addInput('meta', Logic(width: 2), width: 2);
    port.requests.data.context <= addInput('ctx', Logic(width: 4), width: 4);
    port.responses.ready <= addInput('rr', Logic());
    port.evictions.ready <= addInput('er', Logic());
    final internal = useAdapter
        ? CacheTransactionPort<Logic, Logic, Logic, Logic>(
            addressWidth: 8,
            tokenWidth: 2,
            operationWidth: 3,
            dataSchema: Logic(width: 8),
            writeMaskWidth: 2,
            lineMetadataSchema: Logic(width: 2),
            contextSchema: Logic(width: 4),
            resultSchema: Logic(width: 2),
          )
        : port;
    final other = twoPorts
        ? CacheTransactionPort<Logic, Logic, Logic, Logic>(
            addressWidth: 8,
            tokenWidth: 2,
            operationWidth: 3,
            dataSchema: Logic(width: 8),
            writeMaskWidth: 2,
            lineMetadataSchema: Logic(width: 2),
            contextSchema: Logic(width: 4),
            resultSchema: Logic(width: 2),
          )
        : null;
    if (other != null) {
      other.requests.valid <= addInput('iv1', Logic());
      other.requests.data.operation <=
          addInput('op1', Logic(width: 3), width: 3);
      other.requests.data.address <=
          addInput('addr1', Logic(width: 8), width: 8);
      other.requests.data.token <=
          addInput('token1', Logic(width: 2), width: 2);
      other.requests.data.data <= addInput('data1', Logic(width: 8), width: 8);
      other.requests.data.writeMask <= Const(3, width: 2);
      other.requests.data.lineMetadata <= Const(0, width: 2);
      other.requests.data.context <= Const(0, width: 4);
      other.responses.ready <= addInput('rr1', Logic());
      other.evictions.ready <= addInput('er1', Logic());
    }
    final factory = inferredSram
        ? inferredSramArray<Logic>()
        : MemoryArrayFunctor<Logic>(
            identity: behavioral ? 'behavioralSram' : 'flopSram',
            capabilities: MemoryArrayCapabilities(
              readLatency: latency,
              readCollision: MemoryArrayReadCollision.oldData,
              writeCollision: MemoryArrayWriteCollision.disallow,
              supportsMaskedWrites: false,
              implementation: behavioral
                  ? MemoryArrayImplementation.simulationOnly
                  : MemoryArrayImplementation.synthesizable,
              maxReadPorts: 1,
              maxWritePorts: 1,
              maxConcurrentAccesses: 1,
            ),
            build: ({
              required clk,
              required reset,
              required writePorts,
              required readPorts,
              required entryCount,
              required name,
            }) =>
                behavioral
                    ? MemoryModel<Logic>(clk, reset, writePorts, readPorts,
                        readLatency: latency, asyncReset: false, name: name)
                    : _SynchronousArray<Logic>(
                        clk, reset, writePorts, readPorts,
                        entryCount: entryCount,
                        readLatency: latency,
                        name: name),
          );
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    if (useAdapter) {
      final adapter = CacheTransactionAdapter(
        clk: clk,
        reset: reset,
        requests: port.requests,
        responses: port.responses,
        evictions: port.evictions,
        cache: internal,
        maxOutstanding: 2,
      );
      port.tokenConflict <= adapter.duplicateRequest;
    }
    SerializedCache<Logic, Logic, Logic, Logic>(
      clk: clk,
      reset: reset,
      ports: [internal, if (other != null) other],
      setCount: 2,
      waysPerSet: 2,
      dataMemory: factory,
      tagMemory: behavioralTags
          ? behavioralParallelAssociativeMemoryFunctor
          : parallelAssociativeMemoryFunctor,
      metadataMemory: behavioralMetadata
          ? behavioralRegisterFileArray<Logic>()
          : synchronousMetadata
              ? inferredSramArray<Logic>()
              : null,
      replacement: behavioralReplacement
          ? CacheReplacement.behavioral(replacementKind)
          : replacementKind == BehavioralReplacementKind.roundRobin
              ? CacheReplacement.roundRobin
              : CacheReplacement.treePseudoLru,
    );
    addOutput('ir') <= port.requests.ready;
    addOutput('conflict') <= port.tokenConflict;
    addOutput('rv') <= port.responses.valid;
    addOutput('rt', width: 2) <= port.responses.data.token;
    addOutput('rs', width: 2) <= port.responses.data.status;
    addOutput('rd', width: 8) <= port.responses.data.data;
    addOutput('rm', width: 2) <= port.responses.data.lineMetadata;
    addOutput('rc', width: 4) <= port.responses.data.context;
    addOutput('ev') <= port.evictions.valid;
    addOutput('et', width: 2) <= port.evictions.data.token;
    addOutput('ec') <= port.evictions.data.cause;
    addOutput('ea', width: 8) <= port.evictions.data.address;
    addOutput('ed', width: 8) <= port.evictions.data.data;
    addOutput('em', width: 2) <= port.evictions.data.lineMetadata;
    if (other != null) {
      addOutput('ir1') <= other.requests.ready;
      addOutput('rv1') <= other.responses.valid;
      addOutput('rs1', width: 2) <= other.responses.data.status;
      addOutput('rd1', width: 8) <= other.responses.data.data;
      addOutput('conflict1') <= other.tokenConflict;
    }
  }
}

List<Vector> _vectors(int latency, {bool useAdapter = false}) {
  final vectors = <Vector>[];
  void cycle(Map<String, dynamic> inputs,
      [Map<String, dynamic> outputs = const {}]) {
    vectors
      ..add(Vector({'clk': 0, ...inputs}, outputs))
      ..add(Vector({'clk': 1}, {}));
  }

  void request(int op, int address, int data, int meta,
      {int mask = 3, int token = 1, int context = 5}) {
    cycle({
      'iv': 1,
      'op': op,
      'addr': address,
      'data': data,
      'mask': mask,
      'meta': meta,
      'token': token,
      'ctx': context,
      'rr': 0,
      'er': 0,
    }, {
      'ir': 1
    });
    if (useAdapter) {
      cycle({'iv': 0});
    }
  }

  void waitRead() {
    cycle({'iv': 0});
    for (var i = 0; i < latency; i++) {
      cycle({});
    }
  }

  void response(int status, {int data = 0, int meta = 0}) {
    cycle({'rr': 0},
        {'rv': 1, 'rt': 1, 'rs': status, 'rd': data, 'rm': meta, 'rc': 5});
    cycle({'rr': 1}, {'rv': 1});
  }

  void fill(int address, int data, int meta) {
    request(CacheTransactionOperation.fill.code, address, data, meta);
    cycle({'iv': 0});
    cycle({});
    response(CacheTransactionStatus.completed.code);
  }

  void lookup(int address, {required bool hit, int data = 0, int meta = 0}) {
    request(CacheTransactionOperation.lookup.code, address, 0, 0);
    if (hit) {
      waitRead();
    } else {
      cycle({'iv': 0});
    }
    response(
        hit
            ? CacheTransactionStatus.hit.code
            : CacheTransactionStatus.miss.code,
        data: data,
        meta: meta);
  }

  cycle({
    'reset': 1,
    'iv': 0,
    'op': 0,
    'addr': 0,
    'token': 0,
    'data': 0,
    'mask': 0,
    'meta': 0,
    'ctx': 0,
    'rr': 0,
    'er': 0,
  });
  cycle({'reset': 0});
  fill(0, 0xa1, 3);
  fill(2, 0xb2, 1);
  lookup(0, hit: true, data: 0xa1, meta: 3);
  request(CacheTransactionOperation.update.code, 0, 0x0f, 2, mask: 1);
  waitRead();
  cycle({});
  response(CacheTransactionStatus.hit.code, data: 0xa1, meta: 3);
  lookup(0, hit: true, data: 0xaf, meta: 2);
  request(CacheTransactionOperation.invalidate.code, 2, 0, 0);
  waitRead();
  cycle({}, {'ev': 1, 'et': 1, 'ec': 1, 'ea': 2, 'ed': 0xb2, 'em': 1});
  cycle({'er': 1}, {'ev': 1, 'ea': 2, 'ed': 0xb2});
  cycle({'er': 0});
  response(CacheTransactionStatus.hit.code, data: 0xb2, meta: 1);
  lookup(2, hit: false);
  fill(4, 0xc4, 1);
  request(CacheTransactionOperation.fill.code, 6, 0xd6, 0);
  waitRead();
  cycle({}, {'ev': 1, 'ec': 0, 'ea': 0, 'ed': 0xaf, 'em': 2});
  cycle({'er': 1}, {'ev': 1, 'ea': 0, 'ed': 0xaf, 'em': 2});
  cycle({'er': 0});
  response(CacheTransactionStatus.completed.code);
  lookup(6, hit: true, data: 0xd6);
  lookup(4, hit: true, data: 0xc4, meta: 1);
  return vectors;
}

Future<void> _checkBehavioralHierarchy(Module dut, List<Vector> vectors) async {
  final hierarchy = generateBehavioralSystemCHierarchy(
    dut,
    select: (module) =>
        module is InferredSram ||
        module is BehavioralParallelAssociativeMemory ||
        module is BehavioralReplacementPolicy,
    unknownOutputs: SystemCUnknownOutputPolicy.zeroUntilReset,
  );
  final dir = await Directory.systemTemp.createTemp('cache_systemc_miter_');
  try {
    final cpp = StringBuffer(hierarchy.source)..writeln('''
#include <iostream>
using namespace sc_core;
using namespace sc_dt;
int sc_main(int, char**) {
''');
    for (final entry in {...dut.inputs, ...dut.outputs}.entries) {
      final width = entry.value.width;
      final type = width == 1 ? 'bool' : 'sc_uint<$width>';
      cpp.writeln('sc_signal<$type> ${entry.key};');
    }
    cpp.writeln('${hierarchy.topClassName} dut("dut");');
    for (final name in [...dut.inputs.keys, ...dut.outputs.keys]) {
      cpp.writeln('dut.$name($name);');
    }
    for (final (step, vector) in vectors.indexed) {
      for (final entry in vector.inputValues.entries) {
        cpp.writeln('${entry.key} = ${entry.value};');
      }
      cpp.writeln('sc_start(1, SC_NS);');
      for (final entry in vector.expectedOutputValues.entries) {
        cpp.writeln('if (${entry.key}.read() != ${entry.value}) {'
            ' std::cerr << "vector $step: ${entry.key}" << std::endl;'
            ' return 1; }');
      }
    }
    cpp.writeln('return 0;\n}');
    await File('${dir.path}/test.cpp').writeAsString(cpp.toString());
    final compile = await Process.run('g++', [
      '-std=c++17',
      '${dir.path}/test.cpp',
      '-lsystemc',
      '-o',
      '${dir.path}/test'
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');
    final run = await Process.run('${dir.path}/test', []);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
  } finally {
    await dir.delete(recursive: true);
  }
}

List<Vector> _referenceVectors(int latency) {
  final random = Random(761);
  final entries = [
    for (var set = 0; set < 2; set++)
      List<({int address, int data, int meta})?>.filled(2, null)
  ];
  final nextWay = [0, 0];
  final vectors = <Vector>[];
  void cycle(Map<String, dynamic> inputs,
      [Map<String, dynamic> outputs = const {}]) {
    vectors
      ..add(Vector({'clk': 0, ...inputs}, outputs))
      ..add(Vector({'clk': 1}, {}));
  }

  cycle({
    'reset': 1,
    'iv': 0,
    'op': 0,
    'addr': 0,
    'token': 1,
    'data': 0,
    'mask': 3,
    'meta': 0,
    'ctx': 5,
    'rr': 0,
    'er': 0,
  });
  cycle({'reset': 0});
  for (var n = 0; n < 80; n++) {
    final op = random.nextInt(4);
    final address = random.nextInt(12);
    final data = random.nextInt(256);
    final meta = random.nextInt(4);
    final mask = random.nextInt(4);
    final set = address % 2;
    final ways = entries[set];
    final hitWay = ways.indexWhere((entry) => entry?.address == address);
    final hit = hitWay >= 0;
    final old = hit ? ways[hitWay] : null;
    var status = hit
        ? CacheTransactionStatus.hit.code
        : CacheTransactionStatus.miss.code;
    var responseData = old?.data ?? 0;
    var responseMeta = old?.meta ?? 0;
    ({int address, int data, int meta})? eviction;
    var evictionCause = 0;
    var way = hitWay;
    if (op == CacheTransactionOperation.fill.code) {
      status = CacheTransactionStatus.completed.code;
      responseData = 0;
      responseMeta = 0;
      if (!hit) {
        final order = [nextWay[set], (nextWay[set] + 1) % 2];
        way =
            order.firstWhere((i) => ways[i] == null, orElse: () => order.first);
        eviction = ways[way];
        nextWay[set] = (way + 1) % 2;
      }
    } else if (op == CacheTransactionOperation.invalidate.code && hit) {
      eviction = old;
      evictionCause = CacheTransactionEvictionCause.invalidation.code;
    }

    cycle({
      'iv': 1,
      'op': op,
      'addr': address,
      'data': data,
      'mask': mask,
      'meta': meta,
      'rr': 0,
      'er': 0,
    }, {
      'ir': 1
    });
    cycle({'iv': 0});
    final readNeeded = (op != CacheTransactionOperation.fill.code && hit) ||
        (op == CacheTransactionOperation.fill.code && eviction != null);
    if (readNeeded) {
      for (var i = 0; i < latency; i++) {
        cycle({});
      }
    }
    if (eviction != null) {
      cycle({}, {
        'ev': 1,
        'ea': eviction.address,
        'ed': eviction.data,
        'em': eviction.meta,
        'ec': evictionCause,
      });
      cycle({'er': 1}, {'ev': 1, 'ea': eviction.address, 'ed': eviction.data});
    }
    final writes = op == CacheTransactionOperation.fill.code ||
        (hit &&
            (op == CacheTransactionOperation.update.code ||
                op == CacheTransactionOperation.invalidate.code));
    if (writes) {
      cycle({'er': 0});
    }
    if (op == CacheTransactionOperation.fill.code) {
      ways[way] = (address: address, data: data, meta: meta);
    } else if (op == CacheTransactionOperation.update.code && hit) {
      final low = mask & 1 == 0 ? old!.data & 0x0f : data & 0x0f;
      final high = mask & 2 == 0 ? old!.data & 0xf0 : data & 0xf0;
      ways[hitWay] = (address: address, data: high | low, meta: meta);
    } else if (op == CacheTransactionOperation.invalidate.code && hit) {
      ways[hitWay] = null;
    }
    cycle({
      'rr': 0
    }, {
      'rv': 1,
      'rt': 1,
      'rs': status,
      'rd': responseData,
      'rm': responseMeta,
      'rc': 5,
    });
    cycle({'rr': 1}, {'rv': 1});
  }
  return vectors;
}

void main() {
  tearDown(Simulator.reset);

  test('rejects unsupported operation without modifying state', () async {
    final dut = _Harness(1, behavioral: false);
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'iv': 0,
        'op': 7,
        'addr': 0,
        'token': 1,
        'data': 0xaa,
        'mask': 3,
        'meta': 0,
        'ctx': 5,
        'rr': 0,
        'er': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'iv': 1}, {'ir': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'iv': 0}, {}),
      Vector({'clk': 1}, {'rv': 1, 'rs': 3, 'rt': 1, 'rc': 5}),
      Vector({'clk': 0, 'rr': 1}, {'rv': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'rr': 0, 'iv': 1, 'op': 0}, {'ir': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'iv': 0}, {}),
      Vector({'clk': 1}, {'rv': 1, 'rs': 1, 'rd': 0, 'rm': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('rejects zero-latency arrays for the serialized core', () {
    expect(() => _Harness(0, behavioral: false), throwsArgumentError);
    expect(() => _Harness(1, behavioral: false, synchronousMetadata: true),
        throwsArgumentError);
  });

  for (final behavioral in [false, true]) {
    test('four-state data and set isolation behavioral=$behavioral', () async {
      final dut = _Harness(1, behavioral: behavioral);
      final vectors = <Vector>[];
      void cycle(Map<String, dynamic> inputs,
          [Map<String, dynamic> outputs = const {}]) {
        vectors
          ..add(Vector({'clk': 0, ...inputs}, outputs))
          ..add(Vector({'clk': 1}, {}));
      }

      cycle({
        'reset': 1,
        'iv': 0,
        'op': 1,
        'addr': 1,
        'token': 1,
        'data': 0xa5,
        'mask': 3,
        'meta': 1,
        'ctx': LogicValue.ofString('10xz'),
        'rr': 0,
        'er': 0,
      });
      cycle({'reset': 0, 'iv': 1}, {'ir': 1});
      cycle({'iv': 0});
      cycle({});
      cycle({'rr': 1}, {'rv': 1, 'rs': 2, 'rc': LogicValue.ofString('10xz')});
      cycle({
        'rr': 0,
        'iv': 1,
        'op': 1,
        'addr': LogicValue.ofString('000001x0'),
        'data': 0x55,
        'ctx': 5,
      }, {
        'ir': 1
      });
      cycle({'iv': 0});
      cycle({});
      cycle({'rr': 1}, {'rv': 1, 'rs': 2});
      cycle({'rr': 0, 'iv': 1, 'op': 0, 'addr': 1}, {'ir': 1});
      cycle({'iv': 0});
      cycle({});
      cycle({'rr': 1}, {'rv': 1, 'rs': 0, 'rd': 0xa5, 'rm': 1});
      cycle({
        'rr': 0,
        'iv': 1,
        'op': 1,
        'addr': 1,
        'data': LogicValue.ofString('10xz10xz'),
      }, {
        'ir': 1
      });
      cycle({'iv': 0});
      cycle({});
      cycle({'rr': 1}, {'rv': 1, 'rs': 2});
      cycle({'rr': 0, 'iv': 1, 'op': 0}, {'ir': 1});
      cycle({'iv': 0});
      cycle({});
      cycle(
          {'rr': 1}, {'rv': 1, 'rs': 0, 'rd': LogicValue.ofString('10xx10xx')});
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (!behavioral) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }

  for (final behavioral in [false, true]) {
    test(
        'unknown update mask preserves determinable bits '
        'behavioral=$behavioral', () async {
      final dut = _Harness(1, behavioral: behavioral);
      final vectors = <Vector>[];
      void cycle(Map<String, dynamic> inputs,
          [Map<String, dynamic> outputs = const {}]) {
        vectors
          ..add(Vector({'clk': 0, ...inputs}, outputs))
          ..add(Vector({'clk': 1}, {}));
      }

      cycle({
        'reset': 1,
        'iv': 0,
        'op': CacheTransactionOperation.fill.code,
        'addr': 1,
        'token': 1,
        'data': 0xa5,
        'mask': 3,
        'meta': 1,
        'ctx': 5,
        'rr': 0,
        'er': 0,
      });
      cycle({'reset': 0, 'iv': 1}, {'ir': 1});
      cycle({'iv': 0});
      cycle({});
      cycle({'rr': 1}, {'rv': 1, 'rs': CacheTransactionStatus.completed.code});
      cycle({
        'rr': 0,
        'iv': 1,
        'op': CacheTransactionOperation.update.code,
        'data': 0xc3,
        'mask': LogicValue.ofString('x1'),
        'meta': 2,
      }, {
        'ir': 1
      });
      cycle({'iv': 0});
      cycle({});
      cycle({});
      cycle({
        'rr': 1
      }, {
        'rv': 1,
        'rs': CacheTransactionStatus.hit.code,
        'rd': 0xa5,
        'rm': 1,
      });
      cycle({'rr': 0, 'iv': 1, 'op': CacheTransactionOperation.lookup.code},
          {'ir': 1});
      cycle({'iv': 0});
      cycle({});
      cycle({
        'rr': 1
      }, {
        'rv': 1,
        'rs': CacheTransactionStatus.hit.code,
        'rd': LogicValue.ofString('1xx00011'),
        'rm': 2,
      });
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (!behavioral) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }

  test('transaction adapter composes with the latency-bearing cache', () async {
    final dut = _Harness(2, behavioral: false, useAdapter: true);
    final vectors = _vectors(2, useAdapter: true);
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('typed transactions use inferred SRAM data', () async {
    final dut = _TypedHarness(behavioral: false, inferredSram: true);
    final vectors = _vectors(1, useAdapter: true);
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    await _checkBehavioralHierarchy(dut, vectors);
  });
  test('typed transactions use behavioral tags with inferred SRAM data',
      () async {
    final dut = _TypedHarness(
        behavioral: false, inferredSram: true, behavioralTags: true);
    final vectors = _vectors(1, useAdapter: true);
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    await _checkBehavioralHierarchy(dut, vectors);
  });

  for (final behavioral in [false, true]) {
    test('typed transactions through adapter and core behavioral=$behavioral',
        () async {
      final dut = _TypedHarness(behavioral: behavioral);
      final vectors = _vectors(1, useAdapter: true);
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (!behavioral) {
        SimCompare.checkIverilogVector(dut, vectors);
        expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
      }
    });
  }

  for (final behavioral in [false, true]) {
    test(
        'serialized cache matches independent reference behavioral=$behavioral',
        () async {
      final dut = _Harness(2, behavioral: behavioral);
      final vectors = _referenceVectors(2);
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (!behavioral) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }

  test('behavioral tags and replacement match randomized cache reference',
      () async {
    final dut = _Harness(1,
        behavioral: false,
        inferredSram: true,
        behavioralTags: true,
        behavioralReplacement: true);
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, _referenceVectors(1));
  });

  for (final behavioralTags in [false, true]) {
    test('lower-numbered request port wins, behavioralTags=$behavioralTags',
        () async {
      final dut = _Harness(1,
          behavioral: false, twoPorts: true, behavioralTags: behavioralTags);
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'iv': 0,
          'op': 1,
          'addr': 0,
          'token': 1,
          'data': 0x11,
          'mask': 3,
          'meta': 0,
          'ctx': 0,
          'rr': 0,
          'er': 0,
          'iv1': 0,
          'op1': 1,
          'addr1': 0,
          'token1': 1,
          'data1': 0x22,
          'rr1': 0,
          'er1': 0,
        }, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0, 'iv': 1, 'iv1': 1}, {'ir': 1, 'ir1': 0}),
        Vector({'clk': 1}, {'ir1': 0, 'conflict': 1, 'conflict1': 0}),
        Vector({'clk': 0, 'iv': 0}, {'ir1': 0}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0}, {'ir1': 0}),
        Vector({'clk': 1}, {'rv': 1, 'rv1': 0}),
        Vector({'clk': 0}, {'rv': 1, 'ir1': 0}),
        Vector({'clk': 1}, {'rv': 1, 'ir1': 0}),
        Vector({'clk': 0, 'rr': 1}, {'rv': 1, 'ir1': 0}),
        Vector({'clk': 1}, {'ir1': 1}),
        Vector({'clk': 0, 'rr': 0}, {'ir1': 1}),
        Vector({'clk': 1}, {'ir1': 0, 'conflict1': 1}),
        Vector({'clk': 0, 'iv1': 0}, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0}, {}),
        Vector({'clk': 1}, {'rv1': 1, 'rs1': 2}),
        Vector({'clk': 0, 'rr1': 1}, {'rv1': 1}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'rr1': 0, 'iv': 1, 'op': 0}, {'ir': 1}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'iv': 0}, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0}, {}),
        Vector({'clk': 1}, {'rv': 1, 'rs': 0, 'rd': 0x22}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (behavioralTags) {
        await _checkBehavioralHierarchy(dut, vectors);
      } else {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }

  for (final resetDuringEviction in [false, true]) {
    for (final behavioralTags in [false, true]) {
      test(
          'reset cancels ${resetDuringEviction ? 'eviction' : 'pipeline'} '
          'behavioralTags=$behavioralTags', () async {
        final dut =
            _Harness(2, behavioral: false, behavioralTags: behavioralTags);
        final vectors = <Vector>[];
        void cycle(Map<String, dynamic> inputs,
            [Map<String, dynamic> outputs = const {}]) {
          vectors
            ..add(Vector({'clk': 0, ...inputs}, outputs))
            ..add(Vector({'clk': 1}, {}));
        }

        void fill(int address, int data) {
          cycle({'iv': 1, 'op': 1, 'addr': address, 'data': data, 'rr': 0},
              {'ir': 1});
          cycle({'iv': 0});
          cycle({});
          cycle({'rr': 1}, {'rv': 1, 'rs': 2});
          cycle({'rr': 0});
        }

        cycle({
          'reset': 1,
          'iv': 0,
          'op': 0,
          'addr': 0,
          'token': 1,
          'data': 0,
          'mask': 3,
          'meta': 0,
          'ctx': 0,
          'rr': 0,
          'er': 0,
        });
        cycle({'reset': 0});
        fill(0, 0x11);
        if (resetDuringEviction) {
          fill(2, 0x22);
          cycle({'iv': 1, 'op': 1, 'addr': 4, 'data': 0x44}, {'ir': 1});
          cycle({'iv': 0});
          cycle({});
          cycle({});
          cycle({}, {'ev': 1, 'ea': 0, 'ed': 0x11});
        } else {
          cycle({'iv': 1, 'op': 0, 'addr': 0}, {'ir': 1});
          cycle({'iv': 0});
        }
        cycle({'reset': 1}, {'ir': 0, 'rv': 0, 'ev': 0});
        cycle({'reset': 0});
        fill(8, 0x88);
        cycle({'iv': 1, 'op': 0, 'addr': 8}, {'ir': 1});
        cycle({'iv': 0});
        cycle({});
        cycle({});
        cycle({}, {'rv': 1, 'rs': 0, 'rd': 0x88});
        await dut.build();
        await SimCompare.checkFunctionalVector(dut, vectors);
        if (behavioralTags) {
          await _checkBehavioralHierarchy(dut, vectors);
        } else {
          SimCompare.checkIverilogVector(dut, vectors);
        }
      });
    }
  }

  for (final latency in [1, 2, 3]) {
    for (final behavioral in [false, true]) {
      test('serialized cache latency $latency behavioral=$behavioral',
          () async {
        final dut = _Harness(latency, behavioral: behavioral);
        final vectors = _vectors(latency);
        await dut.build();
        await SimCompare.checkFunctionalVector(dut, vectors);
        if (!behavioral) {
          SimCompare.checkIverilogVector(dut, vectors);
          if (latency == 1) {
            expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
          }
        }
      });
    }
  }
  test('serialized cache uses inferred single-port SRAM data', () async {
    final dut = _Harness(1, behavioral: false, inferredSram: true);
    final vectors = _vectors(1);
    await dut.build();
    final observed = List<Vector?>.filled(vectors.length, null);
    for (final (step, vector) in vectors.indexed) {
      Simulator.registerAction(1 + step * 10, () {
        unawaited(Simulator.postTick.first.then((_) {
          observed[step] = Vector(vector.inputValues, {
            for (final output in dut.outputs.entries)
              if (output.value.value.isValid)
                output.key: output.value.value.toBigInt()
          });
        }));
      });
    }
    await SimCompare.checkFunctionalVector(dut, vectors);
    final observedVectors = observed.map((vector) => vector!).toList();
    SimCompare.checkIverilogVector(dut, observedVectors);
    await _checkBehavioralHierarchy(dut, observedVectors);
    expect(() => generateBehavioralSystemCHierarchy(dut, select: (_) => true),
        throwsUnsupportedError);
  });
  test('SystemC hierarchy rejects mismatched behavioral ports', () async {
    final dut = _MismatchedProvider();
    await dut.build();
    expect(() => generateBehavioralSystemCHierarchy(dut, select: (_) => true),
        throwsStateError);
  });
  for (final kind in BehavioralReplacementKind.values) {
    test('SRAM cache and Dart behavioral replacement match RTL backends: $kind',
        timeout: const Timeout(Duration(minutes: 3)), () async {
      final rtl = _Harness(1,
          behavioral: false, inferredSram: true, replacementKind: kind);
      final software = _Harness(1,
          behavioral: false,
          inferredSram: true,
          behavioralTags: true,
          behavioralReplacement: true,
          replacementKind: kind);
      await rtl.build();
      await software.build();
      final vectors = _vectors(1);
      final observed = List<Vector?>.filled(vectors.length, null);
      for (final (step, vector) in vectors.indexed) {
        Simulator.registerAction(1 + step * 10, () {
          for (final input in vector.inputValues.entries) {
            rtl.input(input.key).put(input.value);
            software.input(input.key).put(input.value);
          }
          unawaited(Simulator.postTick.first.then((_) {
            if (step >= 2) {
              for (final output in rtl.outputs.entries) {
                expect(software.output(output.key).value, output.value.value,
                    reason: '${output.key} differs at vector $step');
              }
            }
            for (final output in vector.expectedOutputValues.entries) {
              final signal = rtl.output(output.key);
              expect(signal.value,
                  LogicValue.ofInt(output.value as int, signal.width),
                  reason: '${output.key} differs at vector $step');
            }
            observed[step] = Vector(vector.inputValues, {
              if (step >= 2)
                for (final output in rtl.outputs.entries)
                  if (output.value.value.isValid)
                    output.key: output.value.value.toBigInt()
            });
          }));
        });
      }
      await Simulator.run();
      final trace = observed.map((vector) => vector!).toList();
      SimCompare.checkIverilogVector(rtl, trace);
      await _checkBehavioralHierarchy(software, trace);
    });
  }
  test('serialized cache uses common behavioral metadata factory', () async {
    final dut = _Harness(1,
        behavioral: false, inferredSram: true, behavioralMetadata: true);
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, _vectors(1));
  });
  for (final latency in [1, 2, 3]) {
    test('behavioral replacement at serialized latency $latency', () async {
      final dut =
          _Harness(latency, behavioral: true, behavioralReplacement: true);
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, _vectors(latency));
    });

    test('serialized RTL and software components match every cycle $latency',
        () async {
      final rtl = _Harness(latency, behavioral: false);
      final software =
          _Harness(latency, behavioral: true, behavioralReplacement: true);
      await rtl.build();
      await software.build();
      final vectors = _vectors(latency);
      for (final (index, vector) in vectors.indexed) {
        final time = 1 + index * 10;
        Simulator.registerAction(time, () {
          for (final entry in vector.inputValues.entries) {
            rtl.input(entry.key).put(entry.value);
            software.input(entry.key).put(entry.value);
          }
        });
        if (index >= 2) {
          Simulator.registerAction(time + 1, () {
            for (final entry in rtl.outputs.entries) {
              expect(software.output(entry.key).value, entry.value.value,
                  reason: '${entry.key} differs at vector $index');
            }
          });
        }
      }
      await Simulator.run();
      expect(software.dumpSystemVerilog, throwsUnsupportedError);
    });
  }
}
