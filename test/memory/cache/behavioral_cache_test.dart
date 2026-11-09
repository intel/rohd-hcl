// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_cache_test.dart
// Tests concurrent behavioral cache transactions and backing storage.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Harness extends Module {
  late final BehavioralCacheBackingStore backing;
  late final BehavioralCache<Logic, Logic, Logic, Logic> cache;

  _Harness(
      {int maxOutstanding = 4,
      int operationsPerCycle = 2,
      int operationLatency = 1,
      int waysPerSet = 1,
      int addressWidth = 8,
      BehavioralCacheReplacement? replacement}) {
    backing = BehavioralCacheBackingStore(
        addressWidth: addressWidth, dataWidth: 8, metadataWidth: 2);
    final ports = [
      for (var index = 0; index < 2; index++)
        CacheTransactionPort<Logic, Logic, Logic, Logic>(
          addressWidth: addressWidth,
          tokenWidth: 2,
          operationWidth: 3,
          dataSchema: Logic(width: 8),
          writeMaskWidth: 2,
          lineMetadataSchema: Logic(width: 2),
          contextSchema: Logic(width: 2),
          resultSchema: Logic(width: 2),
        ),
    ];
    for (final (index, port) in ports.indexed) {
      final prefix = 'p$index';
      port.requests.valid <= addInput('${prefix}_iv', Logic());
      port.requests.data.operation <=
          addInput('${prefix}_op', Logic(width: 3), width: 3);
      port.requests.data.address <=
          addInput('${prefix}_addr', Logic(width: addressWidth),
              width: addressWidth);
      port.requests.data.token <=
          addInput('${prefix}_token', Logic(width: 2), width: 2);
      port.requests.data.data <=
          addInput('${prefix}_data', Logic(width: 8), width: 8);
      port.requests.data.writeMask <=
          addInput('${prefix}_mask', Logic(width: 2), width: 2);
      port.requests.data.lineMetadata <=
          addInput('${prefix}_meta', Logic(width: 2), width: 2);
      port.requests.data.context <=
          addInput('${prefix}_ctx', Logic(width: 2), width: 2);
      port.responses.ready <= addInput('${prefix}_rr', Logic());
      port.evictions.ready <= addInput('${prefix}_er', Logic());
      addOutput('${prefix}_ir') <= port.requests.ready;
      addOutput('${prefix}_conflict') <= port.tokenConflict;
      addOutput('${prefix}_rv') <= port.responses.valid;
      addOutput('${prefix}_rt', width: 2) <= port.responses.data.token;
      addOutput('${prefix}_status', width: 2) <= port.responses.data.status;
      addOutput('${prefix}_rd', width: 8) <= port.responses.data.data;
      addOutput('${prefix}_rm', width: 2) <= port.responses.data.lineMetadata;
      addOutput('${prefix}_rc', width: 2) <= port.responses.data.context;
      addOutput('${prefix}_ev') <= port.evictions.valid;
      addOutput('${prefix}_et', width: 2) <= port.evictions.data.token;
      addOutput('${prefix}_ea', width: addressWidth) <=
          port.evictions.data.address;
      addOutput('${prefix}_ed', width: 8) <= port.evictions.data.data;
      addOutput('${prefix}_em', width: 2) <= port.evictions.data.lineMetadata;
    }
    cache = BehavioralCache<Logic, Logic, Logic, Logic>(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      ports: ports,
      setCount: 2,
      waysPerSet: waysPerSet,
      maxOutstanding: maxOutstanding,
      operationsPerCycle: operationsPerCycle,
      operationLatency: operationLatency,
      replacement: replacement,
      backingStore: backing,
    );
  }
}

class _LastWayReplacement implements BehavioralCacheReplacement {
  final allocations = <int>[];
  final accesses = <int>[];
  int resets = 0;

  @override
  int select(int set, List<bool> valid) {
    final invalid = valid.lastIndexOf(false);
    return invalid < 0 ? valid.length - 1 : invalid;
  }

  @override
  void access(int set, int way) => accesses.add(way);

  @override
  void allocate(int set, int way) => allocations.add(way);

  @override
  void reset() {
    allocations.clear();
    accesses.clear();
    resets++;
  }
}

class _Payload extends LogicStructure {
  _Payload({String name = 'payload'})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name);

  @override
  _Payload clone({String? name}) => _Payload(name: name ?? this.name);
}

class _TypedHarness extends Module {
  final BehavioralCacheBackingStore backing = BehavioralCacheBackingStore(
      addressWidth: 8, dataWidth: 8, metadataWidth: 8);

  _TypedHarness() {
    CacheTransactionPort<_Payload, _Payload, _Payload, _Payload> port() =>
        CacheTransactionPort(
          addressWidth: 8,
          tokenWidth: 2,
          operationWidth: 3,
          dataSchema: _Payload(),
          writeMaskWidth: 2,
          lineMetadataSchema: _Payload(),
          contextSchema: _Payload(),
          resultSchema: _Payload(),
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
        addInput('meta', Logic(width: 8), width: 8);
    external.requests.data.context <=
        addInput('ctx', Logic(width: 8), width: 8);
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
    BehavioralCache<_Payload, _Payload, _Payload, _Payload>(
      clk: clk,
      reset: reset,
      ports: [internal],
      setCount: 2,
      waysPerSet: 2,
      maxOutstanding: 2,
      backingStore: backing,
    );
    addOutput('ir') <= external.requests.ready;
    addOutput('rv') <= external.responses.valid;
    addOutput('status', width: 2) <= external.responses.data.status;
    addOutput('rd', width: 8) <= external.responses.data.data;
    addOutput('rm', width: 8) <= external.responses.data.lineMetadata;
    addOutput('rc', width: 8) <= external.responses.data.context;
  }
}

Map<String, int> _initial() => {
      'clk': 0,
      'reset': 1,
      for (var index = 0; index < 2; index++) ...{
        'p${index}_iv': 0,
        'p${index}_op': 0,
        'p${index}_addr': 0,
        'p${index}_token': 0,
        'p${index}_data': 0,
        'p${index}_mask': 3,
        'p${index}_meta': 0,
        'p${index}_ctx': 0,
        'p${index}_rr': 0,
        'p${index}_er': 0,
      },
    };

void main() {
  tearDown(Simulator.reset);

  test('concurrent ports retain ordering while another set stalls', () async {
    final dut = _Harness();
    dut.backing.write(BigInt.one,
        data: LogicValue.ofInt(0xa5, 8), metadata: LogicValue.ofInt(1, 2));
    final vectors = [
      Vector(_initial(), {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'p0_iv': 1,
        'p0_op': BehavioralCacheOperation.readThrough.code,
        'p0_addr': 1,
        'p0_ctx': 2,
        'p1_iv': 1,
        'p1_op': CacheTransactionOperation.fill.code,
        'p1_addr': 0,
        'p1_data': 0x34,
        'p1_meta': 2,
      }, {
        'p0_ir': 1,
        'p1_ir': 1,
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0, 'p1_iv': 0}, {}),
      Vector({
        'clk': 1
      }, {
        'p0_rv': 1,
        'p0_status': CacheTransactionStatus.miss.code,
        'p0_rd': 0xa5,
        'p0_rm': 1,
        'p0_rc': 2,
        'p1_rv': 1,
        'p1_status': CacheTransactionStatus.completed.code,
      }),
      Vector({
        'clk': 0,
        'p0_iv': 1,
        'p0_op': CacheTransactionOperation.update.code,
        'p0_token': 1,
        'p0_data': 0xc3,
        'p0_mask': 2,
        'p0_meta': 2,
        'p1_iv': 1,
        'p1_token': 1,
        'p1_addr': 2,
        'p1_data': 0x77,
        'p1_meta': 1,
      }, {
        'p0_ir': 1,
        'p1_ir': 1,
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0, 'p1_iv': 0}, {}),
      Vector({
        'clk': 1
      }, {
        'p0_rt': 0,
        'p0_rd': 0xa5,
        'p1_ev': 1,
        'p1_et': 1,
        'p1_ea': 0,
        'p1_ed': 0x34,
        'p1_em': 2,
      }),
      Vector({'clk': 0, 'p0_rr': 1, 'p1_rr': 1}, {'p1_ev': 1}),
      Vector({
        'clk': 1
      }, {
        'p0_rv': 1,
        'p0_rt': 1,
        'p0_status': CacheTransactionStatus.hit.code,
        'p0_rd': 0xa5,
        'p1_rv': 0,
        'p1_ev': 1,
      }),
      Vector({
        'clk': 0,
        'p0_rr': 0,
        'p0_iv': 1,
        'p0_token': 2,
        'p0_op': CacheTransactionOperation.lookup.code,
      }, {
        'p1_ed': 0x34,
        'p0_ir': 1,
      }),
      Vector({'clk': 1}, {'p1_ev': 1}),
      Vector({'clk': 0, 'p0_iv': 0}, {'p1_ev': 1}),
      Vector({'clk': 1}, {'p0_rt': 1, 'p1_ev': 1}),
      Vector({'clk': 0, 'p0_rr': 1, 'p1_er': 1}, {'p1_ed': 0x34}),
      Vector({
        'clk': 1
      }, {
        'p0_rv': 1,
        'p0_rt': 2,
        'p0_rd': 0xc5,
        'p0_rm': 2,
        'p1_ev': 0,
        'p1_rv': 1,
        'p1_rt': 1,
        'p1_status': CacheTransactionStatus.completed.code,
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    final written = dut.backing.read(BigInt.zero);
    expect(written.data, LogicValue.ofInt(0x34, 8));
    expect(written.metadata, LogicValue.ofInt(2, 2));
  });

  test('write allocation, same-set ordering, tokens and reset', () async {
    final dut = _Harness();
    dut.backing.write(BigInt.one,
        data: LogicValue.ofInt(0xa5, 8), metadata: LogicValue.ofInt(1, 2));
    final vectors = [
      Vector(_initial(), {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'p0_iv': 1,
        'p0_op': BehavioralCacheOperation.writeAllocate.code,
        'p0_addr': 1,
        'p0_data': 0xc3,
        'p0_mask': 'x1',
        'p0_meta': 2,
        'p1_iv': 1,
        'p1_op': CacheTransactionOperation.lookup.code,
        'p1_addr': 1,
      }, {
        'p0_ir': 1,
        'p1_ir': 1
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0, 'p1_iv': 0}, {}),
      Vector({
        'clk': 1
      }, {
        'p0_rv': 1,
        'p0_status': CacheTransactionStatus.miss.code,
        'p0_rd': 0xa5,
        'p0_rm': 1,
        'p1_rv': 1,
        'p1_status': CacheTransactionStatus.hit.code,
        'p1_rd': '1xx00011',
        'p1_rm': 2,
      }),
      Vector({'clk': 0, 'p0_iv': 1}, {'p0_ir': 0, 'p0_conflict': 1}),
      Vector({'clk': 1}, {'p0_rv': 1}),
      Vector({'clk': 0, 'reset': 1, 'p0_iv': 0}, {'p0_rv': 0, 'p1_rv': 0}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'p0_iv': 1,
        'p0_op': CacheTransactionOperation.lookup.code,
        'p0_addr': 1,
      }, {
        'p0_ir': 1
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {}),
      Vector({
        'clk': 1
      }, {
        'p0_rv': 1,
        'p0_status': CacheTransactionStatus.miss.code,
        'p0_rd': 0,
      }),
      Vector({
        'clk': 0,
        'p0_rr': 1,
        'p0_iv': 1,
        'p0_op': BehavioralCacheOperation.readThrough.code,
      }, {
        'p0_ir': 0,
        'p0_conflict': 1
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {'p0_ir': 1, 'p0_conflict': 0}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {}),
      Vector({
        'clk': 1
      }, {
        'p0_rv': 1,
        'p0_status': CacheTransactionStatus.miss.code,
        'p0_rd': 0xa5,
        'p0_rm': 1,
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    expect(dut.backing.read(BigInt.one).data, LogicValue.ofInt(0xa5, 8));
  });

  test('independent eviction channels write back on their own handshakes',
      () async {
    final dut = _Harness();
    final vectors = [
      Vector(_initial(), {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'p0_iv': 1,
        'p0_op': CacheTransactionOperation.fill.code,
        'p0_addr': 0,
        'p0_data': 0x10,
        'p0_meta': 1,
        'p1_iv': 1,
        'p1_op': CacheTransactionOperation.fill.code,
        'p1_addr': 1,
        'p1_data': 0x11,
        'p1_meta': 2,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0, 'p1_iv': 0}, {}),
      Vector({'clk': 1}, {'p0_rv': 1, 'p1_rv': 1}),
      Vector({
        'clk': 0,
        'p0_iv': 1,
        'p0_token': 1,
        'p0_addr': 2,
        'p0_data': 0x20,
        'p1_iv': 1,
        'p1_token': 1,
        'p1_op': CacheTransactionOperation.invalidate.code,
        'p1_addr': 1,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0, 'p1_iv': 0}, {}),
      Vector({
        'clk': 1
      }, {
        'p0_ev': 1,
        'p0_ea': 0,
        'p0_ed': 0x10,
        'p1_ev': 1,
        'p1_ea': 1,
        'p1_ed': 0x11,
      }),
      Vector({
        'clk': 0,
        'p0_rr': 1,
        'p1_rr': 1,
        'p0_er': 1,
      }, {}),
      Vector({
        'clk': 1
      }, {
        'p0_ev': 0,
        'p0_rv': 1,
        'p0_rt': 1,
        'p1_ev': 1,
        'p1_rv': 0,
      }),
      Vector({'clk': 0, 'p1_er': 1}, {'p1_ed': 0x11}),
      Vector({
        'clk': 1
      }, {
        'p1_ev': 0,
        'p1_rv': 1,
        'p1_rt': 1,
        'p1_status': CacheTransactionStatus.hit.code,
        'p1_rd': 0x11,
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    expect(dut.backing.read(BigInt.zero).data, LogicValue.ofInt(0x10, 8));
    final invalidated = dut.backing.read(BigInt.one);
    expect(invalidated.data, LogicValue.ofInt(0x11, 8));
    expect(invalidated.metadata, LogicValue.ofInt(2, 2));
  });

  test('an older blocked request cannot replace a stalled eviction offer',
      () async {
    final dut = _Harness();
    late BehavioralCacheImage image;
    Simulator.registerAction(161, () => image = dut.cache.snapshot());
    Simulator.registerAction(221, () => dut.cache.restore(image));
    final vectors = [
      Vector(_initial(), {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'p0_iv': 1,
        'p0_op': CacheTransactionOperation.fill.code,
        'p0_addr': 0,
        'p0_data': 0x10,
        'p1_iv': 1,
        'p1_op': CacheTransactionOperation.fill.code,
        'p1_addr': 1,
        'p1_data': 0x11,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0, 'p1_iv': 0}, {}),
      Vector({'clk': 1}, {'p0_rv': 1, 'p1_rv': 1}),
      Vector({
        'clk': 0,
        'p0_rr': 1,
        'p1_rr': 1,
        'p1_iv': 1,
        'p1_token': 1,
        'p1_addr': 2,
        'p1_data': 0x22,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'p1_iv': 0,
        'p0_iv': 1,
        'p0_token': 1,
        'p0_addr': 4,
        'p0_data': 0x44,
      }, {}),
      Vector({'clk': 1}, {'p1_ev': 1, 'p1_ea': 0}),
      Vector({
        'clk': 0,
        'p0_token': 2,
        'p0_addr': 3,
        'p0_data': 0x33,
      }, {
        'p0_ir': 1
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {}),
      Vector({'clk': 1}, {'p0_ev': 1, 'p0_et': 2, 'p0_ea': 1}),
      Vector({'clk': 0, 'p1_er': 1}, {'p0_et': 2, 'p0_ea': 1}),
      Vector({'clk': 1}, {'p0_ev': 1, 'p0_et': 2, 'p0_ea': 1}),
      Vector({'clk': 0, 'p0_er': 1}, {'p0_et': 2, 'p0_ea': 1}),
      Vector({'clk': 1}, {'p0_ev': 1, 'p0_et': 1, 'p0_ea': 2}),
      Vector({'clk': 0}, {}),
      Vector({'clk': 1}, {'p0_ev': 0, 'p0_rv': 1, 'p0_rt': 1, 'p0_status': 2}),
      Vector({'clk': 0}, {}),
      Vector({'clk': 1}, {'p0_rv': 1, 'p0_rt': 2, 'p0_status': 2}),
      Vector({'clk': 0, 'p0_er': 0, 'p0_rr': 0},
          {'p0_ev': 1, 'p0_et': 2, 'p0_ea': 1}),
      Vector({'clk': 1}, {'p0_ev': 1, 'p0_et': 2}),
      Vector({'clk': 0, 'p0_er': 1}, {}),
      Vector({'clk': 1}, {'p0_ev': 1, 'p0_et': 1, 'p0_ea': 2}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
  });

  test('capacity, arbitration, configured latency and unsupported operation',
      () async {
    final dut = _Harness(maxOutstanding: 1, operationLatency: 2);
    final vectors = [
      Vector(_initial(), {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'p0_iv': 1,
        'p0_op': 7,
        'p1_iv': 1,
        'p1_op': CacheTransactionOperation.lookup.code,
      }, {
        'p0_ir': 1,
        'p1_ir': 0
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {'p1_ir': 0, 'p0_rv': 0}),
      Vector({'clk': 1}, {'p0_rv': 0}),
      Vector({'clk': 0}, {'p1_ir': 0}),
      Vector({
        'clk': 1
      }, {
        'p0_rv': 1,
        'p0_status': CacheTransactionStatus.error.code,
        'p1_ir': 0,
      }),
      Vector({'clk': 0, 'p0_rr': 1}, {'p1_ir': 0}),
      Vector({'clk': 1}, {'p1_ir': 1}),
      Vector({'clk': 0}, {'p1_ir': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p1_iv': 0}, {}),
      Vector({'clk': 1}, {'p1_rv': 0}),
      Vector({'clk': 0}, {}),
      Vector({'clk': 1},
          {'p1_rv': 1, 'p1_status': CacheTransactionStatus.miss.code}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
  });

  test('round robin prefers invalid ways and resets independently', () {
    final replacement = BehavioralCacheRoundRobin(setCount: 2, waysPerSet: 3);
    expect(replacement.select(0, [false, false, false]), 0);
    replacement.allocate(0, 0);
    expect(replacement.select(0, [true, false, false]), 1);
    expect(replacement.select(1, [true, true, true]), 0);
    replacement.allocate(0, 2);
    expect(replacement.select(0, [true, true, true]), 0);
    replacement.reset();
    expect(replacement.select(0, [true, true, true]), 0);
    expect(() => replacement.select(0, [true]), throwsArgumentError);
  });

  test('custom replacement controls victims and observes committed accesses',
      () async {
    final replacement = _LastWayReplacement();
    final dut = _Harness(waysPerSet: 2, replacement: replacement);
    final vectors = [
      Vector(_initial(), {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'p0_iv': 1,
        'p0_op': CacheTransactionOperation.fill.code,
        'p0_addr': 0,
        'p0_data': 0x11,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {}),
      Vector({'clk': 1}, {'p0_rv': 1}),
      Vector({
        'clk': 0,
        'p0_rr': 1,
        'p0_iv': 1,
        'p0_token': 1,
        'p0_addr': 2,
        'p0_data': 0x22,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {}),
      Vector({'clk': 1}, {'p0_rv': 1}),
      Vector({
        'clk': 0,
        'p0_iv': 1,
        'p0_token': 2,
        'p0_op': CacheTransactionOperation.lookup.code,
        'p0_addr': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {}),
      Vector({'clk': 1}, {'p0_rv': 1, 'p0_rd': 0x11}),
      Vector({
        'clk': 0,
        'p0_iv': 1,
        'p0_token': 3,
        'p0_op': CacheTransactionOperation.fill.code,
        'p0_addr': 4,
        'p0_data': 0x44,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {}),
      Vector({'clk': 1}, {'p0_ev': 1, 'p0_ea': 0, 'p0_ed': 0x11}),
      Vector({'clk': 0, 'p0_er': 1}, {}),
      Vector({'clk': 1}, {'p0_rv': 1}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    expect(replacement.resets, 1);
    expect(replacement.allocations, [1, 0, 1]);
    expect(replacement.accesses, [1]);
  });

  test('typed transactions compose with the existing adapter', () async {
    final dut = _TypedHarness();
    dut.backing.write(BigInt.one,
        data: LogicValue.ofInt(0xa5, 8), metadata: LogicValue.ofInt(0x3c, 8));
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'iv': 0,
        'op': 0,
        'addr': 1,
        'token': 1,
        'data': 0,
        'mask': 3,
        'meta': 0,
        'ctx': 0x9a,
        'rr': 0,
        'er': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'iv': 1,
        'op': BehavioralCacheOperation.readThrough.code,
      }, {
        'ir': 1
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'iv': 0}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0}, {}),
      Vector({
        'clk': 1
      }, {
        'rv': 1,
        'status': CacheTransactionStatus.miss.code,
        'rd': 0xa5,
        'rm': 0x3c,
        'rc': 0x9a,
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
  });

  test('operations and backing writebacks match an independent model',
      () async {
    final dut = _Harness();
    final random = Random(829);
    final backing = <int, ({int data, int metadata})>{};
    for (var address = 0; address < 8; address++) {
      final block = (data: address * 17, metadata: address % 4);
      backing[address] = block;
      dut.backing.write(BigInt.from(address),
          data: LogicValue.ofInt(block.data, 8),
          metadata: LogicValue.ofInt(block.metadata, 2));
    }
    final lines =
        List<({int address, int data, int metadata})?>.filled(2, null);
    final vectors = <Vector>[
      Vector(_initial(), {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0}, {}),
    ];
    for (var iteration = 0; iteration < 120; iteration++) {
      final port = iteration % 2;
      final prefix = 'p$port';
      final op = random.nextInt(6);
      final address = random.nextInt(8);
      final data = random.nextInt(256);
      final metadata = random.nextInt(4);
      final mask = random.nextInt(4);
      final context = random.nextInt(4);
      final set = address % 2;
      final current = lines[set];
      final hit = current?.address == address;
      final readThrough = op == BehavioralCacheOperation.readThrough.code;
      final writeAllocate = op == BehavioralCacheOperation.writeAllocate.code;
      final fill = op == CacheTransactionOperation.fill.code;
      final update = op == CacheTransactionOperation.update.code;
      final invalidate = op == CacheTransactionOperation.invalidate.code;
      final allocates = !hit && (fill || readThrough || writeAllocate);
      final before = hit
          ? (data: current!.data, metadata: current.metadata)
          : readThrough || writeAllocate
              ? backing[address]
              : null;
      final victim = hit && invalidate
          ? current
          : allocates
              ? current
              : null;
      final status = fill
          ? CacheTransactionStatus.completed.code
          : hit
              ? CacheTransactionStatus.hit.code
              : CacheTransactionStatus.miss.code;
      final response = <String, dynamic>{
        '${prefix}_rv': 1,
        '${prefix}_rt': 0,
        '${prefix}_status': status,
        '${prefix}_rd': fill ? 0 : before?.data ?? 0,
        '${prefix}_rm': fill ? 0 : before?.metadata ?? 0,
        '${prefix}_rc': context,
      };
      vectors
        ..add(Vector({
          'clk': 0,
          '${prefix}_iv': 1,
          '${prefix}_op': op,
          '${prefix}_addr': address,
          '${prefix}_data': data,
          '${prefix}_mask': mask,
          '${prefix}_meta': metadata,
          '${prefix}_ctx': context,
          '${prefix}_rr': 0,
          '${prefix}_er': 0,
        }, {
          '${prefix}_ir': 1,
        }))
        ..add(Vector({'clk': 1}, {}))
        ..add(Vector({'clk': 0, '${prefix}_iv': 0}, {}))
        ..add(Vector(
            {'clk': 1},
            victim == null
                ? response
                : {
                    '${prefix}_ev': 1,
                    '${prefix}_ea': victim.address,
                    '${prefix}_ed': victim.data,
                    '${prefix}_em': victim.metadata,
                  }));
      if (victim != null) {
        backing[victim.address] =
            (data: victim.data, metadata: victim.metadata);
        vectors
          ..add(Vector({'clk': 0, '${prefix}_er': 1},
              {'${prefix}_ev': 1, '${prefix}_ea': victim.address}))
          ..add(Vector({'clk': 1}, response));
      }
      if (invalidate && hit) {
        lines[set] = null;
      } else if (fill || readThrough || writeAllocate || (update && hit)) {
        var newData = fill ? data : before!.data;
        if (update || writeAllocate) {
          if (mask & 1 != 0) {
            newData = (newData & 0xf0) | (data & 0x0f);
          }
          if (mask & 2 != 0) {
            newData = (newData & 0x0f) | (data & 0xf0);
          }
        }
        lines[set] = (
          address: address,
          data: newData,
          metadata: readThrough ? before!.metadata : metadata
        );
      }
      vectors
        ..add(Vector({'clk': 0, '${prefix}_rr': 1}, response))
        ..add(Vector({'clk': 1}, {}));
    }
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    for (final entry in backing.entries) {
      final block = dut.backing.read(BigInt.from(entry.key));
      expect(block.data, LogicValue.ofInt(entry.value.data, 8));
      expect(block.metadata, LogicValue.ofInt(entry.value.metadata, 2));
    }
  });

  test('backing store validates widths and retains four-state values', () {
    final store = BehavioralCacheBackingStore(
        addressWidth: 8, dataWidth: 8, metadataWidth: 2);
    expect(store.read(BigInt.zero).data, LogicValue.of('xxxxxxxx'));
    store.write(BigInt.one,
        data: LogicValue.of('10z001x1'), metadata: LogicValue.of('1z'));
    expect(store.read(BigInt.one).data, LogicValue.of('10x001x1'));
    expect(store.read(BigInt.one).metadata, LogicValue.of('1x'));
    expect(() => store.read(BigInt.from(256)), throwsRangeError);
    expect(
        () => store.write(BigInt.zero,
            data: LogicValue.ofInt(0, 4), metadata: LogicValue.ofInt(0, 2)),
        throwsArgumentError);
  });

  test('backing snapshots retain metadata and restore atomically', () {
    final store = BehavioralCacheBackingStore(
        addressWidth: 8, dataWidth: 8, metadataWidth: 2);
    expect(store.peek(1), isNull);
    store.poke(1, LogicValue.ofInt(0xa5, 8));
    expect(store.read(BigInt.one).metadata, LogicValue.of('xx'));
    store.write(BigInt.two,
        data: LogicValue.of('10x10001'), metadata: LogicValue.of('01'));
    final snapshot = store.snapshot();
    expect(
        () => snapshot.entries[BigInt.zero] = (
              data: LogicValue.ofInt(0, 8),
              metadata: LogicValue.ofInt(0, 2),
            ),
        throwsUnsupportedError);
    store
      ..write(BigInt.one,
          data: LogicValue.ofInt(0x33, 8), metadata: LogicValue.ofInt(3, 2))
      ..poke(3, LogicValue.ofInt(0x55, 8))
      ..load(snapshot);
    expect(store.peek(1), LogicValue.ofInt(0xa5, 8));
    expect(store.read(BigInt.one).metadata, LogicValue.of('xx'));
    expect(store.peek(3), LogicValue.ofInt(0x55, 8));
    store.load(snapshot, replace: true);
    expect(store.peek(3), isNull);
    expect(store.read(BigInt.two).data, LogicValue.of('10x10001'));
    expect(store.read(BigInt.two).metadata, LogicValue.of('01'));
    final invalid = BehavioralCacheBackingStoreImage(
      addressWidth: 8,
      dataWidth: 8,
      metadataWidth: 2,
      entries: {
        BigInt.zero: (
          data: LogicValue.ofInt(0, 8),
          metadata: LogicValue.ofInt(0, 2),
        ),
        BigInt.from(4): (
          data: LogicValue.ofInt(0, 4),
          metadata: LogicValue.ofInt(0, 2),
        ),
      },
    );
    expect(() => store.load(invalid, replace: true), throwsArgumentError);
    expect(store.peek(0), isNull);
    expect(store.peek(1), LogicValue.ofInt(0xa5, 8));
    expect(store.read(BigInt.two).metadata, LogicValue.of('01'));
  });

  test('backing state preserves wide addresses and packed four-state fields',
      () {
    final address = (BigInt.one << 75) + BigInt.from(19);
    final data = LogicValue.ofString('${'10xz' * 20}01');
    final metadata = LogicValue.ofString('z101x');
    final store = BehavioralCacheBackingStore(
        addressWidth: 80, dataWidth: data.width, metadataWidth: metadata.width)
      ..write(address, data: data, metadata: metadata);
    final image = store.snapshot();
    expect(image.entries.keys, [address]);
    expect(store.peekBigInt(address),
        data ^ LogicValue.filled(data.width, LogicValue.zero));
    store.pokeBigInt(address + BigInt.one, LogicValue.ofInt(9, data.width));
    expect(store.peekBigInt(address + BigInt.one)!.toBigInt(), BigInt.from(9));
    final restored = BehavioralCacheBackingStore(
        addressWidth: 80, dataWidth: data.width, metadataWidth: metadata.width)
      ..load(image, replace: true);
    expect(restored.read(address).data,
        data ^ LogicValue.filled(data.width, LogicValue.zero));
    expect(restored.read(address).metadata,
        metadata ^ LogicValue.filled(metadata.width, LogicValue.zero));
    expect(restored.read(address + BigInt.one).data,
        LogicValue.filled(data.width, LogicValue.x));
  });

  test('resident cache distinguishes wide tags across snapshot restore',
      () async {
    final dut = _Harness(addressWidth: 80, waysPerSet: 2);
    await dut.build();
    final low = BigInt.zero;
    final high = BigInt.one << 75;
    dut.cache
      ..poke(low,
          data: LogicValue.ofInt(1, 8), metadata: LogicValue.ofInt(1, 2))
      ..poke(high,
          data: LogicValue.ofInt(2, 8), metadata: LogicValue.ofInt(2, 2));
    final image = dut.cache.snapshot();
    dut.cache.poke(high,
        data: LogicValue.ofInt(3, 8), metadata: LogicValue.ofInt(0, 2));
    dut.cache.restore(image);
    expect(dut.cache.peek(low)!.data.toInt(), 1);
    expect(dut.cache.peek(high)!.data.toInt(), 2);
    expect(dut.cache.peek(high)!.metadata.toInt(), 2);
  });

  test('snapshot restores an in-flight eviction and backing state', () async {
    final dut = _Harness();
    late BehavioralCacheImage image;
    Simulator.registerAction(21, () {
      dut.cache.poke(BigInt.zero,
          data: LogicValue.ofInt(0xa5, 8), metadata: LogicValue.ofInt(2, 2));
    });
    Simulator.registerAction(61, () {
      image = dut.cache.snapshot();
      expect(image.outstandingCount, 1);
      expect(dut.backing.peek(0), isNull);
    });
    Simulator.registerAction(81, () {
      expect(dut.backing.peek(0), LogicValue.ofInt(0xa5, 8));
      expect(dut.cache.peek(BigInt.two)!.data, LogicValue.ofInt(0x33, 8));
      dut.cache.restore(image);
      expect(dut.backing.peek(0), isNull);
      expect(dut.cache.peek(BigInt.zero)!.data, LogicValue.ofInt(0xa5, 8));
      expect(dut.cache.peek(BigInt.two), isNull);
    });
    final vectors = [
      Vector(_initial(), {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'p0_iv': 1,
        'p0_op': CacheTransactionOperation.fill.code,
        'p0_addr': 2,
        'p0_data': 0x33,
        'p0_meta': 1,
      }, {
        'p0_ir': 1
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {}),
      Vector({'clk': 1}, {'p0_ev': 1, 'p0_ea': 0, 'p0_ed': 0xa5}),
      Vector({'clk': 0, 'p0_er': 1}, {'p0_ev': 1}),
      Vector({'clk': 1}, {'p0_ev': 0, 'p0_rv': 1}),
      Vector({'clk': 0, 'p0_er': 0}, {'p0_ev': 1, 'p0_rv': 0}),
      Vector({'clk': 1}, {'p0_ev': 1, 'p0_ed': 0xa5}),
      Vector({'clk': 0, 'p0_er': 1}, {}),
      Vector({'clk': 1}, {'p0_ev': 0, 'p0_rv': 1}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    expect(dut.backing.peek(0), LogicValue.ofInt(0xa5, 8));
    expect(dut.cache.peek(BigInt.two)!.metadata, LogicValue.ofInt(1, 2));
  });

  test('snapshot restores a stalled response and token ownership', () async {
    final dut = _Harness();
    dut.backing.write(BigInt.one,
        data: LogicValue.ofInt(0xa5, 8), metadata: LogicValue.ofInt(2, 2));
    late BehavioralCacheImage image;
    Simulator.registerAction(61, () {
      image = dut.cache.snapshot();
      expect(image.outstandingCount, 1);
    });
    Simulator.registerAction(81, () {
      expect(dut.cache.snapshot().outstandingCount, 0);
      dut.cache.restore(image);
    });
    final vectors = [
      Vector(_initial(), {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'p0_iv': 1,
        'p0_op': BehavioralCacheOperation.readThrough.code,
        'p0_addr': 1,
        'p0_token': 1,
      }, {
        'p0_ir': 1
      }),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'p0_iv': 0}, {}),
      Vector({'clk': 1}, {'p0_rv': 1, 'p0_rd': 0xa5}),
      Vector({'clk': 0, 'p0_rr': 1}, {'p0_rv': 1}),
      Vector({'clk': 1}, {'p0_rv': 0}),
      Vector({
        'clk': 0,
        'p0_rr': 0,
        'p0_iv': 1
      }, {
        'p0_rv': 1,
        'p0_rt': 1,
        'p0_rd': 0xa5,
        'p0_conflict': 1,
        'p0_ir': 0,
      }),
      Vector({'clk': 1}, {'p0_rv': 1}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
  });

  test('cache state rejects incompatible images and unsupported policies', () {
    final original = _Harness();
    original.cache.poke(BigInt.zero,
        data: LogicValue.ofInt(0x55, 8), metadata: LogicValue.ofInt(1, 2));
    final endpoint = original.cache.stateTransactions;
    expect(endpoint.capabilities.supportsSnapshot, isTrue);
    final completion = endpoint.transact(
        StateTransactionRequest<BehavioralCacheImage>.snapshot(
            transactionId: 7));
    expect(completion.transactionId, 7);
    final image = completion.image!;
    original.cache.poke(BigInt.zero,
        data: LogicValue.ofInt(0x12, 8), metadata: LogicValue.ofInt(0, 2));
    endpoint.transact(StateTransactionRequest<BehavioralCacheImage>.restore(
        transactionId: 8, image: image));
    expect(original.cache.peek(BigInt.zero)!.data, LogicValue.ofInt(0x55, 8));
    final incompatible = _Harness(waysPerSet: 2);
    incompatible.cache.poke(BigInt.zero,
        data: LogicValue.ofInt(0x77, 8), metadata: LogicValue.ofInt(2, 2));
    expect(() => incompatible.cache.restore(image), throwsArgumentError);
    expect(
        incompatible.cache.peek(BigInt.zero)!.data, LogicValue.ofInt(0x77, 8));
    final custom = _Harness(replacement: _LastWayReplacement());
    expect(custom.cache.snapshot, throwsUnsupportedError);
    expect(
        custom.cache.stateTransactions.capabilities.supportsSnapshot, isFalse);
  });
}
