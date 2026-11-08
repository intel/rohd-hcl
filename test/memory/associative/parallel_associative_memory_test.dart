// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// parallel_associative_memory_test.dart
// Tests typed associative ports and parallel memory behavior.
//
// 2026 November 5
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

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

class _SideReadHarness extends Module {
  _SideReadHarness() {
    final update = TypedAssociativeUpdatePortInterface(_Key(), indexWidth: 2);
    final lookup = TypedAssociativeLookupPortInterface(_Key(), indexWidth: 2);
    final sideRead = AssociativeIndexedSideReadRequest(indexWidth: 2);
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    update.en <= addInput('write', Logic());
    update.index <= addInput('write_index', Logic(width: 2), width: 2);
    update.key <= addInput('write_key', Logic(width: 8), width: 8);
    update.entryValid <= addInput('write_valid', Logic());
    lookup.en <= Const(0);
    lookup.key <= Const(0, width: 8);
    sideRead.index <= addInput('side_index', Logic(width: 2), width: 2);
    final binding = parallelAssociativeMemoryFunctor(
      clk: clk,
      reset: reset,
      updatePorts: [update],
      lookupPorts: [lookup],
      sideReadRequest: sideRead,
      requiresValidityMask: true,
      entryCount: 3,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.selectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      name: 'side_read_memory',
    );
    final memory = binding.memory! as ParallelAssociativeMemory;
    addOutput('side_key', width: 8) <= memory.sideReadResponse!.key;
    addOutput('side_valid') <= memory.sideReadResponse!.entryValid;
    addOutput('valid_mask', width: 3) <= memory.validMask!;
  }
}

class _MultiSideReadHarness extends Module {
  _MultiSideReadHarness() {
    final updates = [
      for (var i = 0; i < 2; i++)
        AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 2)
    ];
    final lookup = AssociativeLookupPortInterface(keyWidth: 8, indexWidth: 2);
    final sides = [
      for (var i = 0; i < 2; i++)
        AssociativeIndexedSideReadRequest(indexWidth: 2)
    ];
    for (var i = 0; i < 2; i++) {
      updates[i].en <= addInput('write$i', Logic());
      updates[i].index <= addInput('index$i', Logic(width: 2), width: 2);
      updates[i].key <= addInput('key$i', Logic(width: 8), width: 8);
      updates[i].entryValid <= Const(1);
      sides[i].index <= addInput('side$i', Logic(width: 2), width: 2);
    }
    lookup.en <= Const(0);
    lookup.key <= Const(0, width: 8);
    final binding = parallelAssociativeMemoryFunctor(
      clk: addInput('clk', Logic()),
      reset: addInput('reset', Logic()),
      updatePorts: updates,
      lookupPorts: [lookup],
      sideReadRequests: sides,
      requiresValidityMask: true,
      entryCount: 3,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.selectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      name: 'multiple_side_reads',
    );
    final memory = binding.memory! as AssociativeMultiIndexedSideReadProvider;
    for (var i = 0; i < 2; i++) {
      addOutput('out$i', width: 8) <= memory.sideReadResponses[i].key;
      addOutput('valid$i') <= memory.sideReadResponses[i].entryValid;
    }
  }
}

void main() {
  tearDown(Simulator.reset);

  test('multiple indexed reads observe independent simultaneous updates',
      () async {
    final dut = _MultiSideReadHarness();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'write0': 0,
        'write1': 0,
        'index0': 0,
        'index1': 2,
        'key0': 0x12,
        'key1': 0x34,
        'side0': 0,
        'side1': 2,
      }, {}),
      Vector({'clk': 1}, {'valid0': 0, 'valid1': 0}),
      Vector({'clk': 0, 'reset': 0, 'write0': 1, 'write1': 1}, {}),
      Vector(
          {'clk': 1}, {'out0': 0x12, 'valid0': 1, 'out1': 0x34, 'valid1': 1}),
      Vector({'clk': 0, 'write0': 0, 'write1': 0, 'side0': 2, 'side1': 0},
          {'out0': 0x34, 'out1': 0x12}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('indexed side read observes state and propagates unknown indices',
      () async {
    final dut = _SideReadHarness();
    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'write': 0,
        'write_index': 1,
        'write_key': 0x5a,
        'write_valid': 1,
        'side_index': 1,
      }, {}),
      Vector({'clk': 1}, {'side_key': 0, 'side_valid': 0, 'valid_mask': 0}),
      Vector(
          {'clk': 0, 'reset': 0, 'write': 1}, {'side_key': 0, 'side_valid': 0}),
      Vector({'clk': 1}, {'side_key': 0x5a, 'side_valid': 1, 'valid_mask': 2}),
      Vector({'clk': 0, 'write': 0, 'side_index': 2},
          {'side_key': 0, 'side_valid': 0}),
      Vector({'side_index': 3}, {'side_key': 0, 'side_valid': 0}),
      Vector({
        'side_index': LogicValue.ofString('0x')
      }, {
        'side_key': LogicValue.filled(8, LogicValue.x),
        'side_valid': LogicValue.x,
      }),
      Vector({'side_index': 1, 'write': 1, 'write_valid': 0},
          {'side_key': 0x5a, 'side_valid': 1}),
      Vector({'clk': 1}, {'side_key': 0x5a, 'side_valid': 0, 'valid_mask': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('side-read binding requires a matching request and index width', () {
    final update = AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 2);
    final lookup = AssociativeLookupPortInterface(keyWidth: 8, indexWidth: 2);
    AssociativeMemoryRequest request({required bool sideRead}) =>
        AssociativeMemoryRequest.fromPorts(
          updatePorts: [update],
          lookupPorts: [lookup],
          entryCount: 3,
          lookupLatency: 0,
          duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
          matchSelection: AssociativeMatchSelection.lowestIndex,
          resultShape: AssociativeResultShape.selectedIndex,
          lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
          updateCollisionPolicy:
              AssociativeUpdateCollisionPolicy.highestPortWins,
          requiresIndexedSideRead: sideRead,
          indexedSideReadCount: sideRead ? 1 : 0,
        );
    final binding =
        parallelAssociativeMemoryFunctor.resolve(request(sideRead: true));
    void instantiate(AssociativeIndexedSideReadRequest? sideRead) =>
        binding.instantiate(
          clk: Logic(),
          reset: Logic(),
          updatePorts: [update],
          lookupPorts: [lookup],
          name: 'side_read_validation',
          sideReadRequest: sideRead,
        );
    expect(() => instantiate(null), throwsArgumentError);
    expect(() => instantiate(AssociativeIndexedSideReadRequest(indexWidth: 1)),
        throwsArgumentError);
    final withoutSideRead =
        parallelAssociativeMemoryFunctor.resolve(request(sideRead: false));
    expect(
      () => withoutSideRead.instantiate(
        clk: Logic(),
        reset: Logic(),
        updatePorts: [update],
        lookupPorts: [lookup],
        name: 'unexpected_side_read',
        sideReadRequest: AssociativeIndexedSideReadRequest(indexWidth: 2),
      ),
      throwsArgumentError,
    );
    const unsupported = AssociativeMemoryFunctor(
      identity: 'noSideRead',
      capabilities: AssociativeMemoryCapabilities.immutable(
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
      ),
      build: parallelAssociativeMemoryBuilder,
    );
    expect(() => unsupported.resolve(request(sideRead: true)),
        throwsArgumentError);
  });

  test('multiple indexed side reads require matching ports and builder', () {
    final update = AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 2);
    final lookup = AssociativeLookupPortInterface(keyWidth: 8, indexWidth: 2);
    AssociativeMemoryRequest request(int count) =>
        AssociativeMemoryRequest.fromPorts(
          updatePorts: [update],
          lookupPorts: [lookup],
          entryCount: 3,
          lookupLatency: 0,
          duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
          matchSelection: AssociativeMatchSelection.lowestIndex,
          resultShape: AssociativeResultShape.selectedIndex,
          lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
          updateCollisionPolicy:
              AssociativeUpdateCollisionPolicy.highestPortWins,
          indexedSideReadCount: count,
        );
    final binding = parallelAssociativeMemoryFunctor.resolve(request(2));
    void instantiate(List<AssociativeIndexedSideReadRequest> sides) =>
        binding.instantiate(
          clk: Logic(),
          reset: Logic(),
          updatePorts: [update],
          lookupPorts: [lookup],
          sideReadRequests: sides,
          name: 'side_read_validation',
        );
    expect(
        () => instantiate([AssociativeIndexedSideReadRequest(indexWidth: 2)]),
        throwsArgumentError);
    expect(
        () => instantiate([
              AssociativeIndexedSideReadRequest(indexWidth: 2),
              AssociativeIndexedSideReadRequest(indexWidth: 1),
            ]),
        throwsArgumentError);
    final withoutMultiBuilder = AssociativeMemoryFunctor(
      identity: 'withoutMultiBuilder',
      capabilities: parallelAssociativeMemoryFunctor.capabilities,
      build: parallelAssociativeMemoryBuilder,
    );
    expect(() => withoutMultiBuilder.resolve(request(2)), throwsArgumentError);
    final single = withoutMultiBuilder.resolve(request(1));
    expect(
      () => single.instantiate(
        clk: Logic(),
        reset: Logic(),
        updatePorts: [update],
        lookupPorts: [lookup],
        sideReadRequest: AssociativeIndexedSideReadRequest(indexWidth: 2),
        name: 'missing_side_read_builder',
      ),
      throwsArgumentError,
    );
    expect(() => request(-1), throwsArgumentError);
  });

  test('original associative builder signature remains usable', () {
    var called = false;
    final functor = AssociativeMemoryFunctor(
      identity: 'legacyBuilder',
      capabilities: parallelAssociativeMemoryFunctor.capabilities,
      build: ({
        required clk,
        required reset,
        required updatePorts,
        required lookupPorts,
        required request,
        required contract,
        required name,
      }) {
        called = true;
        return parallelAssociativeMemoryBuilder(
          clk: clk,
          reset: reset,
          updatePorts: updatePorts,
          lookupPorts: lookupPorts,
          request: request,
          contract: contract,
          name: name,
        );
      },
    );
    final binding = functor(
      clk: Logic(),
      reset: Logic(),
      updatePorts: [AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 2)],
      lookupPorts: [AssociativeLookupPortInterface(keyWidth: 8, indexWidth: 2)],
      entryCount: 3,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.selectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      name: 'legacy_binding',
    );
    expect(called, isTrue);
    expect(binding.memory, isA<ParallelAssociativeMemory>());
    final update = AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 2);
    final lookup = AssociativeLookupPortInterface(keyWidth: 8, indexWidth: 2);
    final legacyRequest = AssociativeMemoryRequest.fromPorts(
      updatePorts: [update],
      lookupPorts: [lookup],
      entryCount: 3,
      lookupLatency: 0,
      duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
      matchSelection: AssociativeMatchSelection.lowestIndex,
      resultShape: AssociativeResultShape.selectedIndex,
      lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
      updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
      requiresIndexedSideRead: true,
    );
    final legacyBinding = functor.resolve(legacyRequest);
    expect(
      legacyBinding.instantiate(
        clk: Logic(),
        reset: Logic(),
        updatePorts: [update],
        lookupPorts: [lookup],
        name: 'legacy_side_read_binding',
      ),
      isA<ParallelAssociativeMemory>(),
    );
  });

  test('validity-only binding validates the built mask', () {
    final update = AssociativeUpdatePortInterface(keyWidth: 8, indexWidth: 2);
    final lookup = AssociativeLookupPortInterface(keyWidth: 8, indexWidth: 2);
    final functor = AssociativeMemoryFunctor(
      identity: 'missingMask',
      capabilities: parallelAssociativeMemoryFunctor.capabilities,
      build: ({
        required clk,
        required reset,
        required updatePorts,
        required lookupPorts,
        required request,
        required contract,
        required name,
      }) =>
          ParallelAssociativeMemory(
        clk: clk,
        reset: reset,
        updates: updatePorts,
        lookups: lookupPorts,
        entryCount: request.entryCount,
        contract: contract,
        name: name,
      ),
    );
    expect(
      () => functor(
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
        requiresValidityMask: true,
        name: 'missing_mask',
      ),
      throwsStateError,
    );
  });

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
