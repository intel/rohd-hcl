// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// parallel_associative_memory_test.dart
// Tests typed associative ports and parallel memory behavior.
//
// 2026 November 5
// Author: GitHub Copilot

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

class _Key extends LogicStructure {
  _Key({String? name})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name ?? 'key');

  @override
  _Key clone({String? name}) => _Key(name: name ?? this.name);
}

class _OtherKey extends LogicStructure {
  _OtherKey({String? name})
      : super([Logic(name: 'bits', width: 8)], name: name ?? 'otherKey');

  @override
  _OtherKey clone({String? name}) => _OtherKey(name: name ?? this.name);
}

enum _Phase { idle, busy, done }

typedef _KeyValue = ({LogicValue low, LogicValue high});

_KeyValue _decode(LogicValue value) =>
    (low: value.getRange(0, 4), high: value.getRange(4, 8));
LogicValue _encode(_KeyValue value) => [value.high, value.low].concat();

const _codec = LogicValueCodec<_KeyValue>(decode: _decode, encode: _encode);

AssociativeMemoryContract _contract(
        {AssociativeMatchSelection selection =
            AssociativeMatchSelection.lowestIndex,
        AssociativeUpdateCollisionPolicy collision =
            AssociativeUpdateCollisionPolicy.highestPortWins,
        AssociativeMemoryResetTiming resetTiming =
            AssociativeMemoryResetTiming.synchronous}) =>
    AssociativeMemoryContract(
      lookupLatency: 0,
      updateLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: selection,
      resultShape: AssociativeResultShape.matchVectorAndSelectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: collision,
      resetBehavior: AssociativeMemoryResetBehavior.clearValidity,
      resetTiming: resetTiming,
      implementationKind: AssociativeMemoryImplementationKind.synthesizable,
    );

class _Harness<T extends Logic> extends Module {
  late final TypedAssociativeUpdatePortInterface<T> update;
  late final TypedAssociativeLookupPortInterface<T> lookup;
  late final ParallelAssociativeMemory memory;

  _Harness(T schema, AssociativeMatchSelection selection) {
    update = TypedAssociativeUpdatePortInterface<T>(schema, indexWidth: 2);
    lookup = TypedAssociativeLookupPortInterface<T>(schema,
        indexWidth: 2, matchEntryCount: 3);
    update.en <= addInput('write', Logic());
    update.index <= addInput('address', Logic(width: 2), width: 2);
    update.entryValid <= addInput('entryValid', Logic());
    update.key <=
        addInput('data', Logic(width: schema.width), width: schema.width);
    lookup.en <= addInput('queryEnable', Logic());
    lookup.key <=
        addInput('query', Logic(width: schema.width), width: schema.width);
    memory = ParallelAssociativeMemory(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      updates: [update],
      lookups: [lookup],
      entryCount: 3,
      contract: _contract(selection: selection),
      enableValidTracking: true,
    );
    addOutput('hit') <= lookup.hit;
    addOutput('index', width: 2) <= lookup.index;
    addOutput('matchBits', width: 3) <= lookup.matchVector!;
    addOutput('count', width: 2) <= memory.validCount!;
  }
}

class _CollisionHarness extends Module {
  _CollisionHarness(AssociativeUpdateCollisionPolicy collision) {
    final update0 = AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 1);
    final update1 = AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 1);
    final lookup = AssociativeLookupPortInterface(keyWidth: 8, indexWidth: 1);
    final write = addInput('write', Logic());
    final index = addInput('address', Logic());
    for (final update in [update0, update1]) {
      update.en <= write;
      update.index <= index;
      update.entryValid <= Const(1);
    }
    update0.key <= Const(7, width: 8);
    update1.key <= Const(8, width: 8);
    lookup.en <= Const(1);
    lookup.key <= addInput('query', Logic(width: 8), width: 8);
    ParallelAssociativeMemory(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      updates: [update0, update1],
      lookups: [lookup],
      entryCount: 2,
      contract: AssociativeMemoryContract(
        lookupLatency: 0,
        updateLatency: 0,
        duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
        matchSelection: AssociativeMatchSelection.lowestIndex,
        resultShape: AssociativeResultShape.selectedIndex,
        lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
        updateCollisionPolicy: collision,
        resetBehavior: AssociativeMemoryResetBehavior.clearValidity,
        implementationKind: AssociativeMemoryImplementationKind.synthesizable,
      ),
    );
    addOutput('hit') <= lookup.hit;
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final selection in AssociativeMatchSelection.values) {
    test('typed structured keys use $selection and match Icarus', () async {
      final schema = _Key();
      final dut = _Harness(schema, selection);
      expect(dut.update.clone().key, isA<_Key>());
      expect(dut.lookup.clone().key, isA<_Key>());
      expect(sameDeclaredPayloadShape(dut.memory.input('update_key_0'), schema),
          isTrue);
      expect(sameDeclaredPayloadShape(dut.memory.input('lookup_key_0'), schema),
          isTrue);
      final vectors = [
        Vector({
          'clk': 0,
          'reset': 1,
          'write': 0,
          'entryValid': 1,
          'address': 2,
          'data': 0x21,
          'queryEnable': 1,
          'query': 0x21,
        }, {}),
        Vector({'clk': 1}, {'hit': 0, 'count': 0}),
        Vector({'clk': 0, 'reset': 0, 'write': 1}, {}),
        Vector({'clk': 1}, {'hit': 1, 'index': 2, 'matchBits': 4, 'count': 1}),
        Vector({'clk': 0, 'address': 0}, {}),
        Vector({
          'clk': 1
        }, {
          'hit': 1,
          'index': selection == AssociativeMatchSelection.lowestIndex ? 0 : 2,
          'matchBits': 5,
          'count': 2,
        }),
        Vector({'clk': 0, 'entryValid': 0}, {}),
        Vector({'clk': 1}, {'hit': 1, 'index': 2, 'matchBits': 4, 'count': 1}),
        Vector({'clk': 0, 'write': 0, 'queryEnable': 0},
            {'hit': 0, 'index': 0, 'matchBits': 0}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('typed array keys preserve shape and codec', () async {
    final schema =
        TypedLogicArray<_Key, _KeyValue>([2], _Key.new, valueCodec: _codec);
    final dut = _Harness(schema, AssociativeMatchSelection.lowestIndex);
    expect(dut.update.key.valueCodec, same(_codec));
    expect(dut.lookup.clone().key.valueCodec, same(_codec));
    expect(sameDeclaredPayloadShape(dut.memory.input('update_key_0'), schema),
        isTrue);
    await dut.build();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'write': 0,
        'entryValid': 1,
        'address': 1,
        'data': 0x1234,
        'queryEnable': 1,
        'query': 0x1234,
      }, {}),
      Vector({'clk': 1}, {'hit': 0}),
      Vector({'clk': 0, 'reset': 0, 'write': 1}, {}),
      Vector({'clk': 1}, {'hit': 1, 'index': 1, 'matchBits': 2}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  for (final schema in <Logic>[
    LogicEnum<_Phase>(_Phase.values),
    FixedPoint(integerWidth: 3, fractionWidth: 4),
    TypedLogicArray<_Key, LogicValue>([], _Key.new),
    TypedLogicArray<_Key, LogicValue>([2, 2], _Key.new,
        numUnpackedDimensions: 2),
  ]) {
    test('preserves ${schema.runtimeType} associative keys', () async {
      final dut =
          _Harness<Logic>(schema, AssociativeMatchSelection.lowestIndex);
      expect(sameDeclaredPayloadShape(dut.update.clone().key, schema), isTrue);
      expect(sameDeclaredPayloadShape(dut.lookup.clone().key, schema), isTrue);
      expect(sameDeclaredPayloadShape(dut.memory.input('update_key_0'), schema),
          isTrue);
      expect(sameDeclaredPayloadShape(dut.memory.input('lookup_key_0'), schema),
          isTrue);
      await dut.build();
    });
  }

  test('floating-point keys compare encodings rather than numeric values',
      () async {
    final dut =
        _Harness(FloatingPoint32(), AssociativeMatchSelection.lowestIndex);
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'write': 0,
        'entryValid': 1,
        'address': 0,
        'data': 0,
        'queryEnable': 1,
        'query': 0x80000000,
      }, {}),
      Vector({'clk': 1}, {'hit': 0}),
      Vector({'clk': 0, 'reset': 0, 'write': 1}, {}),
      Vector({'clk': 1}, {'hit': 0}),
      Vector({'clk': 0, 'address': 1, 'data': 0x7fc00001, 'query': 0x7fc00001},
          {}),
      Vector({'clk': 1}, {'hit': 1, 'index': 1}),
      Vector({'clk': 0, 'write': 0, 'query': 0x7fc00002}, {'hit': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('rejects incompatible key layouts and reset timing', () {
    final update = TypedAssociativeUpdatePortInterface(_Key(), indexWidth: 2);
    final lookup =
        TypedAssociativeLookupPortInterface(_OtherKey(), indexWidth: 2);
    ParallelAssociativeMemory create(AssociativeLookupPortInterface lookup,
            AssociativeMemoryContract contract) =>
        ParallelAssociativeMemory(
          clk: Logic(),
          reset: Logic(),
          updates: [update],
          lookups: [lookup],
          entryCount: 3,
          contract: contract,
        );
    expect(() => create(lookup, _contract()), throwsArgumentError);
    final compatible = TypedAssociativeLookupPortInterface(_Key(),
        indexWidth: 2, matchEntryCount: 3);
    expect(
        () => create(compatible,
            _contract(resetTiming: AssociativeMemoryResetTiming.asynchronous)),
        throwsArgumentError);
  });

  for (final collision in [
    AssociativeUpdateCollisionPolicy.lowestPortWins,
    AssociativeUpdateCollisionPolicy.highestPortWins,
  ]) {
    test('$collision determines the stored key', () async {
      final dut = _CollisionHarness(collision);
      final firstWins =
          collision == AssociativeUpdateCollisionPolicy.lowestPortWins;
      final vectors = [
        Vector(
            {'clk': 0, 'reset': 1, 'write': 0, 'address': 0, 'query': 7}, {}),
        Vector({'clk': 1}, {'hit': 0}),
        Vector({'clk': 0, 'reset': 0, 'write': 1}, {}),
        Vector({'clk': 1}, {'hit': firstWins ? 1 : 0}),
        Vector({'clk': 0, 'write': 0, 'query': 8}, {'hit': firstWins ? 0 : 1}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('functor resolves typed ports and rejects unsupported latency',
      () async {
    final update = TypedAssociativeUpdatePortInterface(_Key(), indexWidth: 2);
    final lookup = TypedAssociativeLookupPortInterface(_Key(), indexWidth: 2);
    final binding = parallelAssociativeMemoryFunctor(
      clk: Logic(),
      reset: Logic(),
      updatePorts: [update],
      lookupPorts: [lookup],
      entryCount: 3,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.selectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      name: 'typed_associative',
    );
    expect(binding.memory, isA<ParallelAssociativeMemory>());
    await binding.memory!.build();
    expect(
      () => parallelAssociativeMemoryFunctor(
        clk: Logic(),
        reset: Logic(),
        updatePorts: [update],
        lookupPorts: [lookup],
        entryCount: 3,
        lookupLatency: 1,
        duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
        matchSelection: AssociativeMatchSelection.lowestIndex,
        resultShape: AssociativeResultShape.selectedIndex,
        lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
        updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
        name: 'unsupported_associative',
      ),
      throwsArgumentError,
    );
  });
}
