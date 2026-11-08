// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multi_port_cache_test.dart
// Tests multi-port cache arbitration and eviction.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Payload extends LogicStructure {
  _Payload({String name = 'payload'})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name);

  @override
  _Payload clone({String? name}) => _Payload(name: name ?? this.name);
}

class _Harness extends Module {
  _Harness({
    required CacheEvictionConcurrency evictionConcurrency,
    required CacheReadDuringFill readDuringFill,
    required CacheDataStorage dataStorage,
    int sets = 2,
    int ways = 1,
    int maxFillsPerSet = 1,
    CacheReplacement replacement = CacheReplacement.roundRobin,
    MemoryArrayFunctor<Logic>? dataMemory,
  }) {
    final lookups = [
      for (var i = 0; i < 2; i++)
        CacheLookupPort<Logic>(addressWidth: 8, dataSchema: Logic(width: 8))
    ];
    final fills = [
      for (var i = 0; i < 2; i++)
        CacheFillPort<Logic>(addressWidth: 8, dataSchema: Logic(width: 8))
    ];
    for (var i = 0; i < 2; i++) {
      lookups[i].valid <= addInput('lv$i', Logic());
      lookups[i].address <= addInput('la$i', Logic(width: 8), width: 8);
      fills[i].valid <= addInput('fv$i', Logic());
      fills[i].address <= addInput('fa$i', Logic(width: 8), width: 8);
      fills[i].data <= addInput('fd$i', Logic(width: 8), width: 8);
      fills[i].evictionReady <= addInput('er$i', Logic());
    }
    MultiPortCache<Logic>(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      lookups: lookups,
      fills: fills,
      setCount: sets,
      waysPerSet: ways,
      maxFillsPerSet: maxFillsPerSet,
      replacement: replacement,
      evictionConcurrency: evictionConcurrency,
      readDuringFill: readDuringFill,
      dataStorage: dataStorage,
      dataMemory: dataMemory,
    );
    for (var i = 0; i < 2; i++) {
      addOutput('lr$i') <= lookups[i].ready;
      addOutput('lh$i') <= lookups[i].hit;
      addOutput('ld$i', width: 8) <= lookups[i].data;
      addOutput('fr$i') <= fills[i].ready;
      addOutput('ev$i') <= fills[i].evictionValid;
      addOutput('ea$i', width: 8) <= fills[i].evictionAddress;
      addOutput('ed$i', width: 8) <= fills[i].evictionData;
    }
  }
}

class _TypedHarness extends Module {
  late final CacheLookupPort<_Payload> lookup;
  late final CacheFillPort<_Payload> fill;

  _TypedHarness(CacheDataStorage storage) {
    lookup = CacheLookupPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    fill = CacheFillPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    lookup.valid <= addInput('lv', Logic());
    lookup.address <= addInput('la', Logic(width: 8), width: 8);
    fill.valid <= addInput('fv', Logic());
    fill.address <= addInput('fa', Logic(width: 8), width: 8);
    fill.data <= addInput('fd', Logic(width: 8), width: 8);
    fill.evictionReady <= addInput('er', Logic());
    MultiPortCache<_Payload>(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      lookups: [lookup],
      fills: [fill],
      setCount: 1,
      waysPerSet: 1,
      dataStorage: storage,
    );
    addOutput('lh') <= lookup.hit;
    addOutput('ld', width: 8) <= lookup.data;
    addOutput('ev') <= fill.evictionValid;
    addOutput('ed', width: 8) <= fill.evictionData;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('multi-fill rejects invalid limits and missing deferred commits', () {
    _Harness create({required int limit, required CacheReplacement policy}) =>
        _Harness(
          dataStorage: CacheDataStorage.registerFile,
          evictionConcurrency: CacheEvictionConcurrency.parallel,
          readDuringFill: CacheReadDuringFill.oldData,
          ways: 2,
          maxFillsPerSet: limit,
          replacement: policy,
        );
    expect(() => create(limit: 0, policy: CacheReplacement.roundRobin),
        throwsArgumentError);
    expect(() => create(limit: 3, policy: CacheReplacement.roundRobin),
        throwsArgumentError);
    final noDeferred = CacheReplacement(
        identity: 'noDeferred', build: CacheReplacement.roundRobin.build);
    expect(() => create(limit: 2, policy: noDeferred), throwsArgumentError);
  });

  test('multi-fill confines uncertain addresses and stores Z as X', () async {
    final dut = _Harness(
      dataStorage: CacheDataStorage.registerFile,
      evictionConcurrency: CacheEvictionConcurrency.parallel,
      readDuringFill: CacheReadDuringFill.oldData,
      ways: 2,
      maxFillsPerSet: 2,
    );
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lv0': 1,
        'la0': 0,
        'lv1': 1,
        'la1': 1,
        'fv0': 0,
        'fa0': 0,
        'fd0': LogicValue.ofString('10xz10xz'),
        'er0': 0,
        'fv1': 0,
        'fa1': 1,
        'fd1': 0xa5,
        'er1': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fv0': 1, 'fv1': 1}, {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'fv0': 0,
        'fv1': 0
      }, {
        'lh0': 1,
        'ld0': LogicValue.ofString('10xx10xx'),
        'lh1': 1,
        'ld1': 0xa5
      }),
      Vector({'fv0': 1, 'fa0': LogicValue.ofString('000001x0'), 'fd0': 0x55},
          {'lh1': 1, 'ld1': 0xa5}),
      Vector({'clk': 1}, {'lh1': 1, 'ld1': 0xa5}),
      Vector(
          {'clk': 0, 'fv0': LogicValue.x, 'fa0': 2}, {'lh1': 1, 'ld1': 0xa5}),
      Vector({'clk': 1}, {'lh1': LogicValue.x}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final mode in CacheReadDuringFill.values) {
    test('$mode multi-fill same-block priority and retry', () async {
      final dut = _Harness(
        dataStorage: CacheDataStorage.registerFile,
        evictionConcurrency: CacheEvictionConcurrency.parallel,
        readDuringFill: mode,
        ways: 2,
        maxFillsPerSet: 2,
      );
      final forward = mode == CacheReadDuringFill.forward;
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'lv0': 1,
          'la0': 0,
          'lv1': 1,
          'la1': 2,
          'fv0': 0,
          'fa0': 0,
          'fd0': 0x10,
          'er0': 0,
          'fv1': 0,
          'fa1': 0,
          'fd1': 0x20,
          'er1': 0,
        }, {}),
        Vector({'clk': 1}, {}),
        Vector({
          'clk': 0,
          'reset': 0,
          'fv0': 1,
          'fv1': 1
        }, {
          'fr0': 1,
          'fr1': 0,
          'lh0': forward ? 1 : 0,
          if (forward) 'ld0': 0x10,
        }),
        Vector({'clk': 1}, {}),
        Vector({
          'clk': 0,
          'fv0': 0
        }, {
          'fr1': 1,
          'lh0': 1,
          'ld0': forward ? 0x20 : 0x10,
        }),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'fv1': 0}, {'lh0': 1, 'ld0': 0x20}),
        Vector({
          'fv0': 1,
          'fa0': 0,
          'fd0': 0x30,
          'fv1': 1,
          'fa1': 2,
          'fd1': 0x40,
        }, {
          'fr0': 1,
          'fr1': 1,
          'lh0': 1,
          'ld0': forward ? 0x30 : 0x20,
          'lh1': forward ? 1 : 0,
          if (forward) 'ld1': 0x40,
        }),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'fv0': 0, 'fv1': 0},
            {'lh0': 1, 'ld0': 0x30, 'lh1': 1, 'ld1': 0x40}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('multi-fill limits grants to available ways', () async {
    final dut = _Harness(
      dataStorage: CacheDataStorage.registerFile,
      evictionConcurrency: CacheEvictionConcurrency.parallel,
      readDuringFill: CacheReadDuringFill.oldData,
      maxFillsPerSet: 2,
    );
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lv0': 1,
        'la0': 0,
        'lv1': 1,
        'la1': 2,
        'fv0': 0,
        'fa0': 0,
        'fd0': 0x10,
        'er0': 0,
        'fv1': 0,
        'fa1': 2,
        'fd1': 0x20,
        'er1': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fv0': 1, 'fv1': 1}, {'fr0': 1, 'fr1': 0}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'fv0': 0}, {'lh0': 1, 'ld0': 0x10, 'fr1': 1}),
      Vector({'clk': 1}, {'ev1': 1, 'ea1': 0, 'ed1': 0x10}),
      Vector({'clk': 0, 'fv1': 0, 'er1': 1}, {'ev1': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'er1': 0}, {'lh0': 0, 'lh1': 1, 'ld1': 0x20}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('multi-fill completes later eviction first and reset cancels pending',
      () async {
    final dut = _Harness(
      dataStorage: CacheDataStorage.registerFile,
      evictionConcurrency: CacheEvictionConcurrency.parallel,
      readDuringFill: CacheReadDuringFill.oldData,
      ways: 2,
      maxFillsPerSet: 2,
    );
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lv0': 1,
        'la0': 4,
        'lv1': 1,
        'la1': 6,
        'fv0': 0,
        'fa0': 0,
        'fd0': 0x10,
        'er0': 0,
        'fv1': 0,
        'fa1': 2,
        'fd1': 0x20,
        'er1': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fv0': 1, 'fv1': 1}, {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'fa0': 4, 'fd0': 0x40, 'fa1': 6, 'fd1': 0x60},
          {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1}, {'ev0': 1, 'ev1': 1}),
      Vector({'clk': 0, 'fv0': 0, 'fv1': 0, 'er1': 1},
          {'ev0': 1, 'ea0': 0, 'ed0': 0x10, 'ev1': 1, 'ea1': 2, 'ed1': 0x20}),
      Vector({'clk': 1}, {'ev0': 1, 'ev1': 0, 'lr0': 0}),
      Vector({'clk': 0, 'er1': 0}, {'ev0': 1, 'ea0': 0, 'ed0': 0x10}),
      Vector({'clk': 1}, {'ev0': 1, 'ea0': 0, 'ed0': 0x10}),
      Vector({'clk': 0, 'er0': 1}, {'ev0': 1}),
      Vector({'clk': 1}, {}),
      Vector(
          {'clk': 0, 'er0': 0}, {'lh0': 1, 'ld0': 0x40, 'lh1': 1, 'ld1': 0x60}),
      Vector({'fv0': 1, 'fa0': 8, 'fv1': 1, 'fa1': 10}, {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1}, {'ev0': 1, 'ev1': 1}),
      Vector({'clk': 0, 'reset': 1, 'fv0': 0, 'fv1': 0},
          {'ev0': 0, 'ev1': 0, 'lr0': 0}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0},
          {'lr0': 1, 'lh0': 0, 'lh1': 0, 'ev0': 0, 'ev1': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('multi-fill commits two evictions on the same edge', () async {
    final dut = _Harness(
      dataStorage: CacheDataStorage.registerFile,
      evictionConcurrency: CacheEvictionConcurrency.parallel,
      readDuringFill: CacheReadDuringFill.oldData,
      ways: 2,
      maxFillsPerSet: 2,
    );
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lv0': 1,
        'la0': 4,
        'lv1': 1,
        'la1': 6,
        'fv0': 0,
        'fa0': 0,
        'fd0': 0x10,
        'er0': 0,
        'fv1': 0,
        'fa1': 2,
        'fd1': 0x20,
        'er1': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fv0': 1, 'fv1': 1}, {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'fa0': 4, 'fd0': 0x40, 'fa1': 6, 'fd1': 0x60},
          {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1},
          {'ev0': 1, 'ea0': 0, 'ed0': 0x10, 'ev1': 1, 'ea1': 2, 'ed1': 0x20}),
      Vector({'clk': 0, 'fv0': 0, 'fv1': 0, 'er0': 1, 'er1': 1},
          {'ev0': 1, 'ev1': 1}),
      Vector({'clk': 1}, {'ev0': 0, 'ev1': 0}),
      Vector({'clk': 0, 'er0': 0, 'er1': 0},
          {'lr0': 1, 'lh0': 1, 'ld0': 0x40, 'lh1': 1, 'ld1': 0x60}),
      Vector({'fv0': 1, 'fa0': 8, 'fv1': 1, 'fa1': 10}, {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1}, {'ev0': 1, 'ev1': 1}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final storage in CacheDataStorage.values) {
    for (final arbitration in CacheEvictionConcurrency.values) {
      for (final replacement in [
        CacheReplacement.roundRobin,
        CacheReplacement.treePseudoLru
      ]) {
        test('$storage $arbitration ${replacement.identity} parallel same-set',
            () async {
          final dut = _Harness(
            dataStorage: storage,
            evictionConcurrency: arbitration,
            readDuringFill: CacheReadDuringFill.oldData,
            ways: 2,
            maxFillsPerSet: 2,
            replacement: replacement,
          );
          final parallel = arbitration == CacheEvictionConcurrency.parallel;
          final vectors = [
            Vector({
              'clk': 0,
              'reset': 1,
              'lv0': 1,
              'la0': 0,
              'lv1': 1,
              'la1': 2,
              'fv0': 0,
              'fa0': 0,
              'fd0': 0x10,
              'er0': 0,
              'fv1': 0,
              'fa1': 2,
              'fd1': 0x12,
              'er1': 0,
            }, {}),
            Vector({'clk': 1}, {}),
            Vector({'clk': 0, 'reset': 0, 'fv0': 1, 'fv1': 1},
                {'fr0': 1, 'fr1': 1, 'lh0': 0, 'lh1': 0}),
            Vector({'clk': 1}, {}),
            Vector({'clk': 0, 'fv0': 0, 'fv1': 0},
                {'lh0': 1, 'ld0': 0x10, 'lh1': 1, 'ld1': 0x12}),
            Vector({
              'fv0': 1,
              'fa0': 0,
              'fd0': 0x30,
              'fv1': 1,
              'fa1': 4,
              'fd1': 0x40,
            }, {
              'fr0': 1,
              'fr1': 1,
              'ld0': 0x10,
              'ld1': 0x12
            }),
            Vector({'clk': 1}, {'ev1': 1, 'ea1': 2, 'ed1': 0x12, 'lr0': 0}),
            Vector({'clk': 0, 'fv0': 0, 'fv1': 0, 'er1': 1}, {'ev1': 1}),
            Vector({'clk': 1}, {}),
            Vector({
              'clk': 0,
              'er1': 0,
              'la1': 4
            }, {
              'lh0': 1,
              'ld0': 0x30,
              'lh1': 1,
              'ld1': 0x40,
            }),
            Vector({
              'fv0': 1,
              'fa0': 6,
              'fd0': 0x60,
              'fv1': 1,
              'fa1': 8,
              'fd1': 0x80
            }, {
              'fr0': 1,
              'fr1': 1
            }),
            Vector({
              'clk': 1
            }, {
              'ev0': 1,
              'ea0': 0,
              'ed0': 0x30,
              'ev1': parallel ? 1 : 0,
              if (parallel) 'ea1': 4,
              if (parallel) 'ed1': 0x40,
            }),
            Vector({'clk': 0, 'fv0': 0, 'fv1': 0, 'er0': 1}, {'ev0': 1}),
            Vector({'clk': 1}, {'ev0': 0, 'ev1': 1, 'ea1': 4, 'ed1': 0x40}),
            Vector({'clk': 0, 'er0': 0, 'er1': 1}, {'ev1': 1, 'lr0': 0}),
            Vector({'clk': 1}, {}),
            Vector({'clk': 0, 'er1': 0, 'la0': 6, 'la1': 8},
                {'lh0': 1, 'ld0': 0x60, 'lh1': 1, 'ld1': 0x80}),
          ];
          await dut.build();
          await SimCompare.checkFunctionalVector(dut, vectors);
          if (storage == CacheDataStorage.registerFile) {
            SimCompare.checkIverilogVector(dut, vectors);
            if (parallel && replacement == CacheReplacement.roundRobin) {
              expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
            }
          }
        });
      }
    }
  }

  test('custom data-array factory is used for every set', () async {
    var builds = 0;
    final factory = MemoryArrayFunctor<Logic>(
      identity: 'customFlops',
      capabilities: const MemoryArrayCapabilities(
        readLatency: 0,
        readCollision: MemoryArrayReadCollision.combinational,
        writeCollision: MemoryArrayWriteCollision.unspecified,
        supportsMaskedWrites: true,
        implementation: MemoryArrayImplementation.synthesizable,
      ),
      build: ({
        required clk,
        required reset,
        required writePorts,
        required readPorts,
        required entryCount,
        required name,
      }) {
        builds++;
        return RegisterFile<Logic>(clk, reset, writePorts, readPorts,
            numEntries: entryCount, name: name);
      },
    );
    final dut = _Harness(
      dataStorage: CacheDataStorage.registerFile,
      evictionConcurrency: CacheEvictionConcurrency.parallel,
      readDuringFill: CacheReadDuringFill.oldData,
      dataMemory: factory,
    );
    expect(builds, 2);
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lv0': 1,
        'la0': 0,
        'lv1': 1,
        'la1': 1,
        'fv0': 0,
        'fa0': 0,
        'fd0': 0x10,
        'er0': 0,
        'fv1': 0,
        'fa1': 1,
        'fd1': 0x11,
        'er1': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fv0': 1, 'fv1': 1}, {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'fv0': 0, 'fv1': 0},
          {'lh0': 1, 'ld0': 0x10, 'lh1': 1, 'ld1': 0x11}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('cache rejects an array with insufficient simultaneous ports', () {
    final factory = MemoryArrayFunctor<Logic>(
      identity: 'sharedPort',
      capabilities: const MemoryArrayCapabilities(
        readLatency: 0,
        readCollision: MemoryArrayReadCollision.combinational,
        writeCollision: MemoryArrayWriteCollision.disallow,
        supportsMaskedWrites: false,
        implementation: MemoryArrayImplementation.external,
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
          throw StateError('An incompatible array must not be built.'),
    );
    expect(
      () => _Harness(
        dataStorage: CacheDataStorage.registerFile,
        evictionConcurrency: CacheEvictionConcurrency.parallel,
        readDuringFill: CacheReadDuringFill.oldData,
        dataMemory: factory,
      ),
      throwsArgumentError,
    );
  });

  test('multi-fill rejects insufficient directional array concurrency', () {
    for (final capabilities in [
      const MemoryArrayCapabilities(
        readLatency: 0,
        readCollision: MemoryArrayReadCollision.combinational,
        writeCollision: MemoryArrayWriteCollision.disallow,
        supportsMaskedWrites: false,
        implementation: MemoryArrayImplementation.external,
        maxConcurrentReads: 3,
      ),
      const MemoryArrayCapabilities(
        readLatency: 0,
        readCollision: MemoryArrayReadCollision.combinational,
        writeCollision: MemoryArrayWriteCollision.disallow,
        supportsMaskedWrites: false,
        implementation: MemoryArrayImplementation.external,
        maxConcurrentWrites: 1,
      ),
    ]) {
      final factory = MemoryArrayFunctor<Logic>(
        identity: 'limitedPorts',
        capabilities: capabilities,
        build: ({
          required clk,
          required reset,
          required writePorts,
          required readPorts,
          required entryCount,
          required name,
        }) =>
            throw StateError('An incompatible array must not be built.'),
      );
      expect(
        () => _Harness(
          dataStorage: CacheDataStorage.registerFile,
          evictionConcurrency: CacheEvictionConcurrency.parallel,
          readDuringFill: CacheReadDuringFill.oldData,
          ways: 2,
          maxFillsPerSet: 2,
          dataMemory: factory,
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects mismatched payload layouts even when widths match', () {
    expect(
      () => MultiPortCache<Logic>(
        clk: Logic(),
        reset: Logic(),
        lookups: [
          CacheLookupPort<Logic>(addressWidth: 8, dataSchema: Logic(width: 8))
        ],
        fills: [CacheFillPort<Logic>(addressWidth: 8, dataSchema: _Payload())],
        setCount: 1,
        waysPerSet: 1,
      ),
      throwsArgumentError,
    );
  });

  for (final storage in CacheDataStorage.values) {
    test('$storage preserves typed payloads and normalizes stored Z', () async {
      final dut = _TypedHarness(storage);
      expect(dut.lookup.data, isA<_Payload>());
      expect(dut.fill.evictionData, isA<_Payload>());
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'lv': 1,
          'la': 1,
          'fv': 0,
          'fa': 1,
          'fd': LogicValue.ofString('10xz10xz'),
          'er': 0,
        }, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0, 'fv': 1}, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'fv': 0},
            {'lh': 1, 'ld': LogicValue.ofString('10xx10xx')}),
        Vector({'fv': 1, 'fa': 2, 'fd': 0x22}, {}),
        Vector({'clk': 1}, {'ev': 1, 'ed': LogicValue.ofString('10xx10xx')}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (storage == CacheDataStorage.registerFile) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }

  test('forwarding excludes fills incompatible with known address bits',
      () async {
    final dut = _Harness(
      dataStorage: CacheDataStorage.registerFile,
      evictionConcurrency: CacheEvictionConcurrency.parallel,
      readDuringFill: CacheReadDuringFill.forward,
    );
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lv0': 1,
        'la0': 5,
        'lv1': 0,
        'la1': 0,
        'fv0': 0,
        'fa0': 5,
        'fd0': 0xa5,
        'er0': 0,
        'fv1': 0,
        'fa1': 0,
        'fd1': 0,
        'er1': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fv0': 1}, {'fr0': 1}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'fa0': LogicValue.ofString('000001x0'),
        'fd0': 0xc7,
      }, {
        'lr0': 1,
        'lh0': 1,
        'ld0': 0xa5,
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('parallel mode allows the later eviction to complete first', () async {
    final dut = _Harness(
      dataStorage: CacheDataStorage.registerFile,
      evictionConcurrency: CacheEvictionConcurrency.parallel,
      readDuringFill: CacheReadDuringFill.oldData,
    );
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lv0': 1,
        'la0': 2,
        'lv1': 1,
        'la1': 3,
        'fv0': 0,
        'fa0': 0,
        'fd0': 0x10,
        'er0': 0,
        'fv1': 0,
        'fa1': 1,
        'fd1': 0x11,
        'er1': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fv0': 1, 'fv1': 1}, {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'fa0': 2, 'fd0': 0x20, 'fa1': 3, 'fd1': 0x21},
          {'fr0': 1, 'fr1': 1}),
      Vector({'clk': 1}, {'ev0': 1, 'ev1': 1}),
      Vector({'clk': 0, 'fv0': 0, 'fv1': 0, 'er1': 1},
          {'ev0': 1, 'ea0': 0, 'ed0': 0x10, 'ev1': 1, 'ea1': 1, 'ed1': 0x11}),
      Vector({'clk': 1}, {'ev0': 1, 'ev1': 0, 'lr0': 0}),
      Vector({'clk': 0, 'er1': 0}, {'ev0': 1, 'ea0': 0, 'ed0': 0x10}),
      Vector({'clk': 1}, {'ev0': 1, 'ea0': 0, 'ed0': 0x10}),
      Vector({'clk': 0, 'er0': 1}, {'ev0': 1}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'er0': 0},
          {'lr0': 1, 'lh0': 1, 'ld0': 0x20, 'lh1': 1, 'ld1': 0x21}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final storage in CacheDataStorage.values) {
    for (final arbitration in CacheEvictionConcurrency.values) {
      test('$storage $arbitration independent fills and stalled evictions',
          () async {
        final dut = _Harness(
          dataStorage: storage,
          evictionConcurrency: arbitration,
          readDuringFill: CacheReadDuringFill.oldData,
        );
        final parallel = arbitration == CacheEvictionConcurrency.parallel;
        final vectors = [
          Vector({
            'clk': 0,
            'reset': 1,
            'lv0': 1,
            'la0': 0,
            'lv1': 1,
            'la1': 1,
            'fv0': 0,
            'fa0': 0,
            'fd0': 0x10,
            'er0': 0,
            'fv1': 0,
            'fa1': 1,
            'fd1': 0x11,
            'er1': 0,
          }, {}),
          Vector({'clk': 1}, {}),
          Vector({'clk': 0, 'reset': 0, 'fv0': 1, 'fv1': 1},
              {'fr0': 1, 'fr1': 1, 'lh0': 0, 'lh1': 0}),
          Vector({'clk': 1}, {}),
          Vector({'clk': 0, 'fv0': 0, 'fv1': 0},
              {'lh0': 1, 'ld0': 0x10, 'lh1': 1, 'ld1': 0x11}),
          Vector({
            'fv0': 1,
            'fa0': 2,
            'fd0': 0x20,
            'fv1': 1,
            'fa1': 3,
            'fd1': 0x21,
          }, {
            'fr0': 1,
            'fr1': 1,
            'lh0': 1,
            'lh1': 1
          }),
          Vector({
            'clk': 1
          }, {
            'lr0': 0,
            'lr1': 0,
            'fr0': 0,
            'fr1': 0,
            'ev0': 1,
            'ea0': 0,
            'ed0': 0x10,
            'ev1': parallel ? 1 : 0,
          }),
          Vector({
            'clk': 0,
            'fv0': 0,
            'fv1': 0
          }, {
            'ev0': 1,
            'ea0': 0,
            'ed0': 0x10,
            'ev1': parallel ? 1 : 0,
            if (parallel) 'ea1': 1,
            if (parallel) 'ed1': 0x11,
          }),
          Vector({'clk': 1}, {'ev0': 1, 'ev1': parallel ? 1 : 0}),
          Vector({'clk': 0, 'er0': 1}, {'ev0': 1, 'ev1': parallel ? 1 : 0}),
          Vector({'clk': 1}, {'ev0': 0, 'ev1': 1, 'ea1': 1, 'ed1': 0x11}),
          Vector({'clk': 0, 'er0': 0, 'er1': 1}, {'lr0': 0, 'ev1': 1}),
          Vector({'clk': 1}, {}),
          Vector({
            'clk': 0,
            'er1': 0,
            'la0': 2,
            'la1': 3
          }, {
            'lr0': 1,
            'lr1': 1,
            'lh0': 1,
            'ld0': 0x20,
            'lh1': 1,
            'ld1': 0x21,
          }),
        ];
        await dut.build();
        await SimCompare.checkFunctionalVector(dut, vectors);
        if (storage == CacheDataStorage.registerFile) {
          SimCompare.checkIverilogVector(dut, vectors);
          if (parallel) {
            expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
          }
        }
      });
    }
  }

  for (final storage in CacheDataStorage.values) {
    for (final mode in CacheReadDuringFill.values) {
      for (final replacement in [
        CacheReplacement.roundRobin,
        CacheReplacement.treePseudoLru
      ]) {
        test('$storage $mode ${replacement.identity} same-set arbitration',
            () async {
          final dut = _Harness(
            dataStorage: storage,
            evictionConcurrency: CacheEvictionConcurrency.parallel,
            readDuringFill: mode,
            ways: 2,
            replacement: replacement,
          );
          final forward = mode == CacheReadDuringFill.forward;
          final vectors = [
            Vector({
              'clk': 0,
              'reset': 1,
              'lv0': 1,
              'la0': 0,
              'lv1': 1,
              'la1': 2,
              'fv0': 0,
              'fa0': 0,
              'fd0': 0x10,
              'er0': 0,
              'fv1': 0,
              'fa1': 2,
              'fd1': 0x12,
              'er1': 0,
            }, {}),
            Vector({'clk': 1}, {}),
            Vector({
              'clk': 0,
              'reset': 0,
              'fv0': 1,
              'fv1': 1
            }, {
              'fr0': 1,
              'fr1': 0,
              'lh0': forward ? 1 : 0,
              if (forward) 'ld0': 0x10,
              'lh1': 0,
            }),
            Vector({'clk': 1}, {}),
            Vector({
              'clk': 0,
              'fv0': 0
            }, {
              'fr1': 1,
              'lh0': 1,
              'ld0': 0x10,
              'lh1': forward ? 1 : 0,
              if (forward) 'ld1': 0x12,
            }),
            Vector({'clk': 1}, {}),
            Vector({'clk': 0, 'fv1': 0}, {'lh1': 1, 'ld1': 0x12}),
            Vector({
              'fv0': 1,
              'fa0': 4,
              'fd0': 0x14,
              'fv1': 1,
              'fa1': 4,
              'fd1': 0xff,
              'la0': 4,
            }, {
              'fr0': 1,
              'fr1': 0,
              'lh0': forward ? 1 : 0,
              if (forward) 'ld0': 0x14,
            }),
            Vector({'clk': 1}, {'ev0': 1, 'lr0': 0, 'fr1': 0}),
            Vector({'clk': 0, 'fv0': 0, 'er0': 1}, {'ev0': 1, 'fr1': 0}),
            Vector({'clk': 1}, {}),
            Vector({
              'clk': 0,
              'er0': 0
            }, {
              'fr1': 1,
              'lh0': 1,
              'ld0': forward ? 0xff : 0x14,
            }),
            Vector({'clk': 1}, {}),
            Vector({'clk': 0, 'fv1': 0}, {'lh0': 1, 'ld0': 0xff, 'ev1': 0}),
            Vector({'fv0': 1, 'fa0': 6, 'fd0': 0x16}, {'fr0': 1}),
            Vector({'clk': 1}, {'ev0': 1}),
            Vector({'clk': 0, 'fv0': 0, 'reset': 1},
                {'ev0': 0, 'lr0': 0, 'fr1': 0}),
            Vector({'clk': 1}, {}),
            Vector({'clk': 0, 'reset': 0}, {'ev0': 0, 'lr0': 1, 'lh0': 0}),
          ];
          await dut.build();
          await SimCompare.checkFunctionalVector(dut, vectors);
          if (storage == CacheDataStorage.registerFile) {
            SimCompare.checkIverilogVector(dut, vectors);
          }
        });
      }
    }
  }
}
