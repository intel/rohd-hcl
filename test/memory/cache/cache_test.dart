// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_test.dart
// Tests blocking cache composition and eviction.
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

class _CacheHarness extends Module {
  _CacheHarness(int sets, int ways, CacheReplacement replacement,
      {AssociativeMemoryFunctor tagMemory = parallelAssociativeMemoryFunctor,
      CacheDataStorage dataStorage = CacheDataStorage.registerFile,
      CacheReadDuringFill readDuringFill = CacheReadDuringFill.oldData}) {
    final lookup =
        CacheLookupPort<Logic>(addressWidth: 8, dataSchema: Logic(width: 8));
    final fill =
        CacheFillPort<Logic>(addressWidth: 8, dataSchema: Logic(width: 8));
    lookup.valid <= addInput('lookup_valid', Logic());
    lookup.address <= addInput('lookup_address', Logic(width: 8), width: 8);
    fill.valid <= addInput('fill_valid', Logic());
    fill.address <= addInput('fill_address', Logic(width: 8), width: 8);
    fill.data <= addInput('fill_data', Logic(width: 8), width: 8);
    fill.evictionReady <= addInput('eviction_ready', Logic());
    Cache<Logic>(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      lookup: lookup,
      fill: fill,
      setCount: sets,
      waysPerSet: ways,
      replacement: replacement,
      tagMemory: tagMemory,
      dataStorage: dataStorage,
      readDuringFill: readDuringFill,
    );
    addOutput('lookup_ready') <= lookup.ready;
    addOutput('lookup_hit') <= lookup.hit;
    addOutput('lookup_data', width: 8) <= lookup.data;
    addOutput('fill_ready') <= fill.ready;
    addOutput('eviction_valid') <= fill.evictionValid;
    addOutput('eviction_address', width: 8) <= fill.evictionAddress;
    addOutput('eviction_data', width: 8) <= fill.evictionData;
  }
}

class _Payload extends LogicStructure {
  _Payload({String name = 'payload'})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name);

  @override
  _Payload clone({String? name}) => _Payload(name: name ?? this.name);
}

class _ArrayPortHarness extends Module {
  late final Cache<TypedLogicArray<_Payload, LogicValue>> cache;

  _ArrayPortHarness() {
    _Payload buildPayload({String? name}) => _Payload(name: name ?? 'payload');
    final schema = TypedLogicArray<_Payload, LogicValue>([2], buildPayload);
    final lookup = CacheLookupPort<TypedLogicArray<_Payload, LogicValue>>(
        addressWidth: 8, dataSchema: schema);
    final fill = CacheFillPort<TypedLogicArray<_Payload, LogicValue>>(
        addressWidth: 8, dataSchema: schema);
    lookup.valid <= addInput('lookup_valid', Logic());
    lookup.address <= addInput('lookup_address', Logic(width: 8), width: 8);
    fill.valid <= addInput('fill_valid', Logic());
    fill.address <= addInput('fill_address', Logic(width: 8), width: 8);
    fill.data <= addInput('fill_data', Logic(width: 16), width: 16);
    fill.evictionReady <= Const(1);
    cache = Cache<TypedLogicArray<_Payload, LogicValue>>.fullyAssociative(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      lookup: lookup,
      fill: fill,
      entryCount: 1,
    );
    addOutput('lookup_hit') <= lookup.hit;
    addOutput('lookup_data', width: 16) <= lookup.data;
  }
}

class _ProviderPortModule extends Module {
  _ProviderPortModule(
      CacheLookupPort<_Payload> lookup,
      CacheFillPort<_Payload> fill,
      Logic lookupValid,
      Logic lookupAddress,
      Logic fillValid,
      Logic fillAddress,
      Logic fillData,
      Logic evictionReady) {
    final localLookup = addInterfacePorts(lookup,
        inputTags: [PairDirection.fromConsumer],
        outputTags: [PairDirection.fromProvider],
        uniquify: (name) => 'lookup_$name');
    final localFill = addInterfacePorts(fill,
        inputTags: [PairDirection.fromConsumer],
        outputTags: [PairDirection.fromProvider],
        uniquify: (name) => 'fill_$name');
    localLookup.valid <= addInput('lookup_valid_in', lookupValid);
    localLookup.address <=
        addInput('lookup_address_in', lookupAddress, width: 8);
    localFill.valid <= addInput('fill_valid_in', fillValid);
    localFill.address <= addInput('fill_address_in', fillAddress, width: 8);
    localFill.data <= addInput('fill_data_in', fillData, width: 8);
    localFill.evictionReady <= addInput('eviction_ready_in', evictionReady);
    addOutput('lookup_data_out', width: 8) <= localLookup.data;
    addOutput('eviction_data_out', width: 8) <= localFill.evictionData;
  }
}

class _ProviderPortHarness extends Module {
  _ProviderPortHarness() {
    final lookup =
        CacheLookupPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    final fill =
        CacheFillPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    lookup.ready <= addInput('lookup_ready_in', Logic());
    lookup.hit <= addInput('lookup_hit_in', Logic());
    lookup.data <= addInput('lookup_data_in', Logic(width: 8), width: 8);
    fill.ready <= addInput('fill_ready_in', Logic());
    fill.evictionValid <= addInput('eviction_valid_in', Logic());
    fill.evictionAddress <=
        addInput('eviction_address_in', Logic(width: 8), width: 8);
    fill.evictionData <=
        addInput('eviction_data_in', Logic(width: 8), width: 8);
    final provider = _ProviderPortModule(
      lookup,
      fill,
      addInput('lookup_valid_in', Logic()),
      addInput('lookup_address_in', Logic(width: 8), width: 8),
      addInput('fill_valid_in', Logic()),
      addInput('fill_address_in', Logic(width: 8), width: 8),
      addInput('fill_data_in', Logic(width: 8), width: 8),
      addInput('eviction_ready_in', Logic()),
    );
    addOutput('lookup_valid_out') <= lookup.valid;
    addOutput('lookup_address_out', width: 8) <= lookup.address;
    addOutput('lookup_data_out', width: 8) <=
        provider.output('lookup_data_out');
    addOutput('fill_valid_out') <= fill.valid;
    addOutput('fill_data_out', width: 8) <= fill.data;
    addOutput('eviction_ready_out') <= fill.evictionReady;
    addOutput('eviction_data_out', width: 8) <=
        provider.output('eviction_data_out');
  }
}

class _TypedHarness extends Module {
  late final CacheLookupPort<_Payload> lookup;
  late final CacheFillPort<_Payload> fill;
  late final Cache<_Payload> cache;

  _TypedHarness(
      {CacheDataStorage dataStorage = CacheDataStorage.registerFile}) {
    lookup = CacheLookupPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    fill = CacheFillPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    lookup.valid <= addInput('lookup_valid', Logic());
    lookup.address <= addInput('lookup_address', Logic(width: 8), width: 8);
    fill.valid <= addInput('fill_valid', Logic());
    fill.address <= addInput('fill_address', Logic(width: 8), width: 8);
    fill.data <= addInput('fill_data', Logic(width: 8), width: 8);
    fill.evictionReady <= addInput('eviction_ready', Logic());
    cache = Cache<_Payload>.fullyAssociative(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      lookup: lookup,
      fill: fill,
      entryCount: 1,
      dataStorage: dataStorage,
    );
    addOutput('lookup_hit') <= lookup.hit;
    addOutput('lookup_data', width: 8) <= lookup.data;
    addOutput('eviction_valid') <= fill.evictionValid;
    addOutput('eviction_data', width: 8) <= fill.evictionData;
  }
}

class _MixedPayloadHarness extends Module {
  _MixedPayloadHarness() {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final valid = addInput('valid', Logic());
    final address = addInput('address', Logic(width: 8), width: 8);
    final fill = addInput('fill', Logic());
    final inputData = addInput('input_data', Logic(width: 8), width: 8);
    final scalarLookup =
        CacheLookupPort<Logic>(addressWidth: 8, dataSchema: Logic(width: 8));
    final scalarFill =
        CacheFillPort<Logic>(addressWidth: 8, dataSchema: Logic(width: 8));
    final typedLookup =
        CacheLookupPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    final typedFill =
        CacheFillPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    for (final lookup in [scalarLookup, typedLookup]) {
      lookup.valid <= valid;
      lookup.address <= address;
    }
    for (final port in [scalarFill, typedFill]) {
      port.valid <= fill;
      port.address <= address;
      port.data <= inputData;
      port.evictionReady <= Const(1);
    }
    Cache<Logic>.fullyAssociative(
      clk: clk,
      reset: reset,
      lookup: scalarLookup,
      fill: scalarFill,
      entryCount: 1,
      name: 'scalar_cache',
    );
    Cache<_Payload>.fullyAssociative(
      clk: clk,
      reset: reset,
      lookup: typedLookup,
      fill: typedFill,
      entryCount: 1,
      name: 'structured_cache',
    );
    addOutput('scalar_data', width: 8) <= scalarLookup.data;
    addOutput('structured_data', width: 8) <= typedLookup.data;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('cache ports clone their typed payloads and role directions', () {
    final lookup =
        CacheLookupPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    final fill =
        CacheFillPort<_Payload>(addressWidth: 8, dataSchema: _Payload());
    final lookupClone = lookup.clone();
    final fillClone = fill.clone();
    expect(lookupClone.data, isA<_Payload>());
    expect(fillClone.data, isA<_Payload>());
    expect(fillClone.evictionData, isA<_Payload>());
    expect(identical(lookup.data, lookupClone.data), isFalse);
    expect(identical(fill.data, fillClone.data), isFalse);
    expect(lookupClone.getPorts([PairDirection.fromProvider]).keys,
        unorderedEquals(['valid', 'address']));
    expect(lookupClone.getPorts([PairDirection.fromConsumer]).keys,
        unorderedEquals(['ready', 'hit', 'data']));
    expect(fillClone.getPorts([PairDirection.fromProvider]).keys,
        unorderedEquals(['valid', 'address', 'data', 'evictionReady']));
    expect(
        fillClone.getPorts([PairDirection.fromConsumer]).keys,
        unorderedEquals(
            ['ready', 'evictionValid', 'evictionAddress', 'evictionData']));
  });

  test('cache construction rejects incompatible typed array shapes', () {
    _Payload buildPayload({String? name}) => _Payload(name: name ?? 'payload');
    final first = CacheLookupPort<Logic>(
      addressWidth: 8,
      dataSchema: TypedLogicArray<_Payload, LogicValue>([2], buildPayload),
    );
    final second = CacheLookupPort<Logic>(
      addressWidth: 8,
      dataSchema: TypedLogicArray<_Payload, LogicValue>([1, 2], buildPayload),
    );
    expect(first.clone().data, isA<TypedLogicArray<_Payload, LogicValue>>());
    expect(
      () => Cache<Logic>(
        clk: Logic(),
        reset: Logic(),
        lookup: first,
        fill: CacheFillPort<Logic>(addressWidth: 8, dataSchema: second.data),
        setCount: 1,
        waysPerSet: 1,
      ),
      throwsArgumentError,
    );
  });

  test('cache port registration preserves typed array data', () async {
    final dut = _ArrayPortHarness();
    expect(dut.cache.input('lookup_valid').width, 1);
    expect(dut.cache.input('lookup_address').width, 8);
    expect(dut.cache.output('lookup_hit').width, 1);
    expect(dut.cache.input('fill_data'),
        isA<TypedLogicArray<_Payload, LogicValue>>());
    expect(dut.cache.output('lookup_data'),
        isA<TypedLogicArray<_Payload, LogicValue>>());
    expect(dut.cache.input('eviction_ready').width, 1);
    expect(dut.cache.output('eviction_valid').width, 1);
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lookup_valid': 1,
        'lookup_address': 5,
        'fill_valid': 0,
        'fill_address': 5,
        'fill_data': 0x1234,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fill_valid': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'fill_valid': 0},
          {'lookup_hit': 1, 'lookup_data': 0x1234}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('cache ports register typed provider endpoints', () async {
    final dut = _ProviderPortHarness();
    final vectors = [
      Vector({
        'lookup_ready_in': 1,
        'lookup_hit_in': 1,
        'lookup_data_in': 0x12,
        'fill_ready_in': 1,
        'eviction_valid_in': 1,
        'eviction_address_in': 0x34,
        'eviction_data_in': 0x56,
        'lookup_valid_in': 1,
        'lookup_address_in': 0x78,
        'fill_valid_in': 1,
        'fill_address_in': 0x9a,
        'fill_data_in': 0xbc,
        'eviction_ready_in': 1,
      }, {
        'lookup_valid_out': 1,
        'lookup_address_out': 0x78,
        'lookup_data_out': 0x12,
        'fill_valid_out': 1,
        'fill_data_out': 0xbc,
        'eviction_ready_out': 1,
        'eviction_data_out': 0x56,
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('single-port cache rejects mismatched port geometry and payloads', () {
    expect(
      () => Cache<Logic>(
        clk: Logic(),
        reset: Logic(),
        lookup: CacheLookupPort(addressWidth: 7, dataSchema: Logic(width: 8)),
        fill: CacheFillPort(addressWidth: 8, dataSchema: Logic(width: 8)),
        setCount: 2,
        waysPerSet: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => Cache<Logic>(
        clk: Logic(),
        reset: Logic(),
        lookup: CacheLookupPort(addressWidth: 8, dataSchema: Logic(width: 8)),
        fill: CacheFillPort(addressWidth: 8, dataSchema: _Payload()),
        setCount: 2,
        waysPerSet: 1,
      ),
      throwsArgumentError,
    );
  });

  for (final (label, sets, ways, replacement, dataStorage) in [
    (
      'direct mapped',
      4,
      1,
      CacheReplacement.roundRobin,
      CacheDataStorage.registerFile
    ),
    (
      'set associative',
      2,
      2,
      CacheReplacement.roundRobin,
      CacheDataStorage.registerFile
    ),
    (
      'fully associative',
      1,
      4,
      CacheReplacement.roundRobin,
      CacheDataStorage.registerFile
    ),
    (
      'tree PLRU',
      1,
      4,
      CacheReplacement.treePseudoLru,
      CacheDataStorage.registerFile
    ),
    (
      'behavioral direct mapped',
      4,
      1,
      CacheReplacement.roundRobin,
      CacheDataStorage.behavioral
    ),
    (
      'behavioral set associative',
      2,
      2,
      CacheReplacement.roundRobin,
      CacheDataStorage.behavioral
    ),
    (
      'behavioral fully associative',
      1,
      4,
      CacheReplacement.treePseudoLru,
      CacheDataStorage.behavioral
    ),
  ]) {
    test('$label fills, stalls, evicts, updates, and resets', () async {
      final dut =
          _CacheHarness(sets, ways, replacement, dataStorage: dataStorage);
      final addresses = [for (var i = 0; i <= ways; i++) 5 + i * 4];
      final vectors = <Vector>[
        Vector({
          'clk': 0,
          'reset': 1,
          'lookup_valid': 0,
          'lookup_address': 0,
          'fill_valid': 0,
          'fill_address': 0,
          'fill_data': 0,
          'eviction_ready': 0,
        }, {
          'lookup_ready': 0,
          'fill_ready': 0,
          'eviction_valid': 0
        }),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0, 'lookup_valid': 1, 'lookup_address': 5},
            {'lookup_ready': 1, 'lookup_hit': 0, 'lookup_data': 0}),
      ];
      for (var i = 0; i < ways; i++) {
        vectors.addAll([
          Vector({
            'fill_valid': 1,
            'fill_address': addresses[i],
            'fill_data': 0xa0 + i,
          }, {
            'lookup_ready': 1,
            'lookup_hit': i == 0 ? 0 : 1,
            'lookup_data': i == 0 ? 0 : 0xa0 + i - 1,
            'fill_ready': 1,
            'eviction_valid': 0,
          }),
          Vector({'clk': 1}, {}),
          Vector({'clk': 0, 'fill_valid': 0, 'lookup_address': addresses[i]},
              {'lookup_ready': 1, 'lookup_hit': 1, 'lookup_data': 0xa0 + i}),
        ]);
      }
      // The final fill is held stable while its victim is backpressured.
      vectors.addAll([
        Vector({
          'fill_valid': 1,
          'fill_address': addresses.last,
          'fill_data': 0xfe,
        }, {
          'lookup_ready': 0,
          'fill_ready': 0,
          'eviction_valid': 1,
          'eviction_address': 5,
          'eviction_data': 0xa0,
        }),
        Vector({
          'clk': 1
        }, {
          'fill_ready': 0,
          'eviction_valid': 1,
          'eviction_address': 5,
          'eviction_data': 0xa0,
        }),
        Vector({
          'clk': 0,
          'lookup_address': 0x7f,
        }, {
          'fill_ready': 0,
          'eviction_valid': 1,
          'eviction_address': 5,
          'eviction_data': 0xa0,
        }),
        Vector({
          'eviction_ready': 1
        }, {
          'fill_ready': 1,
          'eviction_valid': 1,
          'eviction_address': 5,
          'eviction_data': 0xa0,
        }),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'fill_valid': 0, 'lookup_address': addresses.last},
            {'lookup_hit': 1, 'lookup_data': 0xfe}),
        Vector({'lookup_address': 5}, {'lookup_hit': 0, 'lookup_data': 0}),
        Vector({
          'fill_valid': 1,
          'fill_address': addresses.last,
          'fill_data': 0xab,
        }, {
          'fill_ready': 1,
          'eviction_valid': 0
        }),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'fill_valid': 0, 'lookup_address': addresses.last},
            {'lookup_hit': 1, 'lookup_data': 0xab}),
        Vector({'reset': 1}, {'lookup_ready': 0, 'lookup_hit': 0}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0},
            {'lookup_ready': 1, 'lookup_hit': 0, 'lookup_data': 0}),
      ]);
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (dataStorage == CacheDataStorage.registerFile) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
      if (label == 'set associative') {
        expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
      }
    });
  }

  test('different sets retain independent entries', () async {
    final dut = _CacheHarness(2, 1, CacheReplacement.roundRobin);
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lookup_valid': 1,
        'lookup_address': 5,
        'fill_valid': 0,
        'fill_address': 5,
        'fill_data': 0x55,
        'eviction_ready': 0,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fill_valid': 1},
          {'fill_ready': 1, 'eviction_valid': 0}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'fill_address': 6, 'fill_data': 0x66},
          {'fill_ready': 1, 'eviction_valid': 0}),
      Vector({'clk': 1}, {}),
      Vector(
          {'clk': 0, 'fill_valid': 0}, {'lookup_hit': 1, 'lookup_data': 0x55}),
      Vector({'lookup_address': 6}, {'lookup_hit': 1, 'lookup_data': 0x66}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final storage in CacheDataStorage.values) {
    for (final mode in CacheReadDuringFill.values) {
      test('$storage $mode handles simultaneous lookups and fills', () async {
        final dut = _CacheHarness(2, 1, CacheReplacement.roundRobin,
            dataStorage: storage, readDuringFill: mode);
        final forwarding = mode == CacheReadDuringFill.forward;
        final vectors = [
          Vector({
            'clk': 0,
            'reset': 1,
            'lookup_valid': 1,
            'lookup_address': 5,
            'fill_valid': 0,
            'fill_address': 5,
            'fill_data': 0xa5,
            'eviction_ready': 0,
          }, {}),
          Vector({'clk': 1}, {}),
          Vector({
            'clk': 0,
            'reset': 0,
            'fill_valid': 1
          }, {
            'lookup_ready': 1,
            'lookup_hit': forwarding ? 1 : 0,
            'lookup_data': forwarding ? 0xa5 : 0,
            'fill_ready': 1,
          }),
          Vector({'clk': 1}, {}),
          Vector({
            'clk': 0,
            'fill_data': 0xb6
          }, {
            'lookup_ready': 1,
            'lookup_hit': 1,
            'lookup_data': forwarding ? 0xb6 : 0xa5,
            'fill_ready': 1,
          }),
          Vector({'clk': 1}, {}),
          Vector({
            'clk': 0,
            'fill_address': 6,
            'fill_data': 0xc7
          }, {
            'lookup_ready': 1,
            'lookup_hit': 1,
            'lookup_data': 0xb6,
            'fill_ready': 1,
          }),
          Vector({'clk': 1}, {}),
          Vector({
            'clk': 0,
            'fill_address': 9
          }, {
            'lookup_ready': 0,
            'lookup_hit': 0,
            'fill_ready': 0,
            'eviction_valid': 1,
            'eviction_address': 5,
            'eviction_data': 0xb6,
          }),
        ];
        await dut.build();
        await SimCompare.checkFunctionalVector(dut, vectors);
        if (storage == CacheDataStorage.registerFile) {
          SimCompare.checkIverilogVector(dut, vectors);
        }
      });
    }
  }

  test('forwarding excludes fills incompatible with known address bits',
      () async {
    final dut = _CacheHarness(2, 1, CacheReplacement.roundRobin,
        readDuringFill: CacheReadDuringFill.forward);
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lookup_valid': 1,
        'lookup_address': 5,
        'fill_valid': 0,
        'fill_address': 5,
        'fill_data': 0xa5,
        'eviction_ready': 1,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fill_valid': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({
        'clk': 0,
        'fill_address': LogicValue.ofString('000001x0'),
        'fill_data': 0xc7,
      }, {
        'lookup_ready': 1,
        'lookup_hit': 1,
        'lookup_data': 0xa5,
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final storage in CacheDataStorage.values) {
    test('$storage typed payload preserves shape and stored Z becomes X',
        () async {
      final dut = _TypedHarness(dataStorage: storage);
      expect(dut.lookup.data, isA<_Payload>());
      expect(dut.fill.evictionData, isA<_Payload>());
      expect(dut.cache.input('fill_data').width, 8);
      expect(dut.cache.output('lookup_data').width, 8);
      expect(dut.cache.output('eviction_data').width, 8);
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'lookup_valid': 1,
          'lookup_address': 5,
          'fill_valid': 0,
          'fill_address': 5,
          'fill_data': LogicValue.ofString('10zz0011'),
          'eviction_ready': 0,
        }, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0, 'fill_valid': 1}, {}),
        Vector({'clk': 1}, {}),
        Vector({
          'clk': 0,
          'fill_valid': 0
        }, {
          'lookup_hit': 1,
          'lookup_data': LogicValue.ofString('10xx0011'),
        }),
        Vector({
          'fill_valid': 1,
          'fill_address': 9
        }, {
          'eviction_valid': 1,
          'eviction_data': LogicValue.ofString('10xx0011'),
        }),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (storage == CacheDataStorage.registerFile) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }

  test('scalar and structured caches coexist in generated RTL', () async {
    final dut = _MixedPayloadHarness();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'valid': 1,
        'address': 5,
        'fill': 0,
        'input_data': 0xa5,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fill': 1}, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'fill': 0},
          {'scalar_data': 0xa5, 'structured_data': 0xa5}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final storage in CacheDataStorage.values) {
    test('$storage unknown lookup addresses propagate uncertainty', () async {
      final dut = _CacheHarness(1, 1, CacheReplacement.roundRobin,
          dataStorage: storage);
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'lookup_valid': 1,
          'lookup_address': 5,
          'fill_valid': 0,
          'fill_address': 5,
          'fill_data': 0xa5,
          'eviction_ready': 1,
        }, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0, 'fill_valid': 1}, {}),
        Vector({'clk': 1}, {}),
        Vector({
          'clk': 0,
          'fill_valid': 0,
          'lookup_address': LogicValue.ofString('00000x01'),
        }, {
          'lookup_ready': 1,
          'lookup_hit': LogicValue.x,
          'lookup_data': LogicValue.filled(8, LogicValue.x),
        }),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (storage == CacheDataStorage.registerFile) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }

  for (final storage in CacheDataStorage.values) {
    test('$storage uncertain set selection preserves incompatible sets',
        () async {
      final dut = _CacheHarness(4, 1, CacheReplacement.roundRobin,
          dataStorage: storage);
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'lookup_valid': 1,
          'lookup_address': 2,
          'fill_valid': 0,
          'fill_address': 2,
          'fill_data': 0xa2,
          'eviction_ready': 1,
        }, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0, 'fill_valid': 1}, {'fill_ready': 1}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'fill_address': 3, 'fill_data': 0xa3},
            {'fill_ready': 1}),
        Vector({'clk': 1}, {}),
        Vector({
          'clk': 0,
          'fill_address': LogicValue.ofString('0000010x'),
          'fill_data': 0xa4,
        }, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'fill_valid': 0},
            {'lookup_hit': 1, 'lookup_data': 0xa2}),
        Vector({'lookup_address': 3}, {'lookup_hit': 1, 'lookup_data': 0xa3}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (storage == CacheDataStorage.registerFile) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }

  test('invalid configurations are rejected', () {
    expect(() => _CacheHarness(3, 1, CacheReplacement.roundRobin),
        throwsArgumentError);
    expect(() => _CacheHarness(1, 0, CacheReplacement.roundRobin),
        throwsArgumentError);
    expect(() => _CacheHarness(1, 3, CacheReplacement.treePseudoLru),
        throwsArgumentError);
  });

  test('incompatible tag-memory capabilities are rejected', () {
    const noMask = AssociativeMemoryFunctor(
      identity: 'no_mask',
      capabilities: AssociativeMemoryCapabilities.immutable(
        maximumLookupLatency: 0,
        supportedDuplicateKeyPolicies: {AssociativeDuplicateKeyPolicy.allow},
        supportedMatchSelections: {AssociativeMatchSelection.lowestIndex},
        supportedResultShapes: {AssociativeResultShape.selectedIndex},
        supportedLookupUpdatePolicies: {
          AssociativeLookupUpdatePolicy.lookupAfterUpdate
        },
        supportedUpdateCollisionPolicies: {
          AssociativeUpdateCollisionPolicy.highestPortWins
        },
        resetBehavior: AssociativeMemoryResetBehavior.clearValidity,
        implementationKind: AssociativeMemoryImplementationKind.synthesizable,
        sustainsOneLookupPerPortPerCycle: true,
        supportsIndexedSideRead: true,
      ),
      build: parallelAssociativeMemoryBuilder,
    );
    expect(
        () =>
            _CacheHarness(1, 2, CacheReplacement.roundRobin, tagMemory: noMask),
        throwsArgumentError);
  });

  test('compatible tag-memory functors can be selected', () async {
    final compatible = AssociativeMemoryFunctor(
      identity: 'alternateTags',
      capabilities: parallelAssociativeMemoryFunctor.capabilities,
      build: parallelAssociativeMemoryBuilder,
      buildMultipleSideReads: parallelMultiSideReadBuilder,
    );
    final dut =
        _CacheHarness(2, 2, CacheReplacement.roundRobin, tagMemory: compatible);
    await dut.build();
    expect(dut.output('lookup_ready').width, 1);
  });

  test('replacement factory constructs one policy per set', () async {
    var built = 0;
    final custom = CacheReplacement(
      identity: 'customRoundRobin',
      build: ({
        required clk,
        required reset,
        required validMask,
        required eligibleMask,
        required accesses,
        required allocations,
        required entryCount,
        required name,
      }) {
        built++;
        return RoundRobinReplacement(
          clk: clk,
          reset: reset,
          validMask: validMask,
          eligibleMask: eligibleMask,
          accesses: accesses,
          allocations: allocations,
          entryCount: entryCount,
          name: name,
        );
      },
    );
    final dut = _CacheHarness(4, 2, custom);
    expect(built, 4);
    await dut.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'lookup_valid': 1,
        'lookup_address': 5,
        'fill_valid': 0,
        'fill_address': 5,
        'fill_data': 0xa5,
        'eviction_ready': 1,
      }, {}),
      Vector({'clk': 1}, {}),
      Vector({'clk': 0, 'reset': 0, 'fill_valid': 1}, {'fill_ready': 1}),
      Vector({'clk': 1}, {}),
      Vector(
          {'clk': 0, 'fill_valid': 0}, {'lookup_hit': 1, 'lookup_data': 0xa5}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('named cache constructors create the requested organizations', () async {
    final clk = Logic();
    final reset = Logic();
    CacheLookupPort<Logic> lookup() =>
        CacheLookupPort(addressWidth: 8, dataSchema: Logic(width: 32));
    CacheFillPort<Logic> fill() =>
        CacheFillPort(addressWidth: 8, dataSchema: Logic(width: 32));
    final direct = Cache<Logic>.directMapped(
      clk: clk,
      reset: reset,
      lookup: lookup(),
      fill: fill(),
      entryCount: 4,
    );
    final setAssociative = Cache<Logic>.setAssociative(
      clk: clk,
      reset: reset,
      lookup: lookup(),
      fill: fill(),
      setCount: 2,
      waysPerSet: 2,
      replacement: CacheReplacement.treePseudoLru,
    );
    final fully = Cache<Logic>.fullyAssociative(
      clk: clk,
      reset: reset,
      lookup: lookup(),
      fill: fill(),
      entryCount: 4,
    );
    expect((direct.setCount, direct.waysPerSet), (4, 1));
    expect((setAssociative.setCount, setAssociative.waysPerSet), (2, 2));
    expect((fully.setCount, fully.waysPerSet), (1, 4));
    await direct.build();
    await setAssociative.build();
    await fully.build();
  });

  for (final storage in CacheDataStorage.values) {
    test('$storage reset cancels a stalled eviction', () async {
      final dut = _CacheHarness(1, 1, CacheReplacement.roundRobin,
          dataStorage: storage);
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'lookup_valid': 1,
          'lookup_address': 5,
          'fill_valid': 0,
          'fill_address': 5,
          'fill_data': 0x55,
          'eviction_ready': 0,
        }, {}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0, 'fill_valid': 1}, {'fill_ready': 1}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'fill_address': 9},
            {'fill_ready': 0, 'eviction_valid': 1, 'eviction_address': 5}),
        Vector({'reset': 1},
            {'fill_ready': 0, 'eviction_valid': 0, 'lookup_ready': 0}),
        Vector({'clk': 1}, {}),
        Vector({'clk': 0, 'reset': 0, 'fill_valid': 0},
            {'lookup_ready': 1, 'lookup_hit': 0}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (storage == CacheDataStorage.registerFile) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }

  test('tree PLRU records lookup and fill-hit recency', () async {
    for (final useFillHit in [false, true]) {
      final dut = _CacheHarness(1, 4, CacheReplacement.treePseudoLru);
      final vectors = <Vector>[
        Vector({
          'clk': 0,
          'reset': 1,
          'lookup_valid': 0,
          'lookup_address': 5,
          'fill_valid': 0,
          'fill_address': 5,
          'fill_data': 0,
          'eviction_ready': 0,
        }, {}),
        Vector({'clk': 1}, {}),
      ];
      for (var i = 0; i < 4; i++) {
        vectors.addAll([
          Vector({
            'clk': 0,
            'reset': 0,
            'fill_valid': 1,
            'fill_address': 5 + i * 4,
            'fill_data': i,
          }, {
            'fill_ready': 1,
            'eviction_valid': 0
          }),
          Vector({'clk': 1}, {}),
        ]);
      }
      vectors.addAll([
        Vector({
          'clk': 0,
          'lookup_valid': useFillHit ? 0 : 1,
          'lookup_address': 5,
          'fill_valid': useFillHit ? 1 : 0,
          'fill_address': 5,
          'fill_data': 0x55,
        }, useFillHit ? {'fill_ready': 1} : {'lookup_hit': 1}),
        Vector({'clk': 1}, {}),
        Vector({
          'clk': 0,
          'lookup_valid': 0,
          'fill_valid': 1,
          'fill_address': 21,
        }, {
          'fill_ready': 0,
          'eviction_valid': 1,
          'eviction_address': 9,
          'eviction_data': 1,
        }),
      ]);
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
      await Simulator.reset();
    }
  });

  for (final storage in CacheDataStorage.values) {
    test('$storage set-associative round robin matches a reference model',
        () async {
      const sets = 4;
      const ways = 3;
      final dut = _CacheHarness(sets, ways, CacheReplacement.roundRobin,
          dataStorage: storage);
      final tags = List.generate(sets, (_) => List<int?>.filled(ways, null));
      final data = List.generate(sets, (_) => List<int>.filled(ways, 0));
      final pointers = List<int>.filled(sets, 0);
      final random = Random(23);
      final vectors = <Vector>[
        Vector({
          'clk': 0,
          'reset': 1,
          'lookup_valid': 0,
          'lookup_address': 0,
          'fill_valid': 0,
          'fill_address': 0,
          'fill_data': 0,
          'eviction_ready': 1,
        }, {}),
        Vector({'clk': 1}, {}),
      ];
      for (var cycle = 0; cycle < 100; cycle++) {
        final doFill = random.nextBool();
        final lookupAddress = random.nextInt(32);
        final fillAddress = random.nextInt(32);
        final fillData = random.nextInt(256);
        final lookupSet = lookupAddress % sets;
        final fillSet = fillAddress % sets;
        final hitWay = tags[lookupSet].indexOf(lookupAddress);
        final needsEviction = doFill &&
            !tags[fillSet].contains(fillAddress) &&
            !tags[fillSet].contains(null);
        final expected = <String, int>{
          'lookup_ready': needsEviction ? 0 : 1,
          'lookup_hit': !needsEviction && hitWay >= 0 ? 1 : 0,
          'lookup_data':
              !needsEviction && hitWay >= 0 ? data[lookupSet][hitWay] : 0,
          'fill_ready': doFill ? 1 : 0,
          'eviction_valid': 0,
          'eviction_address': 0,
          'eviction_data': 0,
        };
        if (doFill) {
          var way = tags[fillSet].indexOf(fillAddress);
          if (way < 0) {
            final order = [
              for (var i = 0; i < ways; i++) (pointers[fillSet] + i) % ways
            ];
            way = order.firstWhere((i) => tags[fillSet][i] == null,
                orElse: () => order.first);
            if (tags[fillSet][way] != null) {
              expected['eviction_valid'] = 1;
              expected['eviction_address'] = tags[fillSet][way]!;
              expected['eviction_data'] = data[fillSet][way];
            }
            pointers[fillSet] = (way + 1) % ways;
          }
          tags[fillSet][way] = fillAddress;
          data[fillSet][way] = fillData;
        }
        vectors.addAll([
          Vector({
            'clk': 0,
            'reset': 0,
            'lookup_valid': 1,
            'lookup_address': lookupAddress,
            'fill_valid': doFill ? 1 : 0,
            'fill_address': fillAddress,
            'fill_data': fillData,
          }, expected),
          Vector({'clk': 1}, {}),
        ]);
      }
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      if (storage == CacheDataStorage.registerFile) {
        SimCompare.checkIverilogVector(dut, vectors);
      }
    });
  }
}
