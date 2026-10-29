// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_serialization_test.dart
// Tests for serialization of arrays with typed leaves.
//
// 2026 October 21
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _Word extends LogicStructure {
  Logic get data => elements[0];
  Logic get last => elements[1];

  _Word({String? name})
      : super([Logic(name: 'data', width: 4), Logic(name: 'last')],
            name: name ?? 'word');

  @override
  _Word clone({String? name}) => _Word(name: name ?? this.name);
}

typedef _WordValue = ({LogicValue data, LogicValue last});

_WordValue _decodeWord(LogicValue value) =>
    (data: value.getRange(0, 4), last: value[4]);

LogicValue _encodeWord(_WordValue value) =>
    LogicValue.of([value.last, value.data]);

const _wordCodec =
    LogicValueCodec<_WordValue>(decode: _decodeWord, encode: _encodeWord);

enum _Phase { idle, busy, done }

TypedLogicArray<_Word, _WordValue> _words(List<int> dimensions,
        {int numUnpackedDimensions = 0}) =>
    TypedLogicArray<_Word, _WordValue>(dimensions, _Word.new,
        valueCodec: _wordCodec, numUnpackedDimensions: numUnpackedDimensions);

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  for (final dimensions in [
    [1],
    [3],
    [3, 2],
    [3, 2, 2],
  ]) {
    for (final flopInput in [false, true]) {
      // Pause both ends mid-transfer and change the external input after
      // latching to distinguish held data from a combinational pass-through.
      test('structured round trip $dimensions flopInput=$flopInput', () async {
        final source = _words(dimensions);
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic()..put(1);
        final enable = Logic()..put(0);
        final receive = Logic()..put(0);
        for (var i = 0; i < source.arrayElements.length; i++) {
          source.arrayElements[i].data.put((i + 1) % 16);
          source.arrayElements[i].last.put(i % 2);
        }
        final expected = source.value;
        final tx = Serializer(source,
            clk: clk, reset: reset, enable: enable, flopInput: flopInput);
        final rx = Deserializer<_Word, _WordValue>(
            tx.serialized, dimensions.first,
            valueCodec: _wordCodec, clk: clk, reset: reset, enable: receive);
        await tx.build();
        await rx.build();

        expect(tx.input('deserialized'),
            isA<TypedLogicArray<_Word, _WordValue>>());
        expect(rx.deserialized.dimensions, dimensions);
        expect(rx.deserialized.valueCodec, same(_wordCodec));
        if (dimensions.length == 1) {
          expect(tx.serialized.dimensions, isEmpty);
          expect(tx.serialized.scalar, isA<_Word>());
          expect(rx.input('serialized'),
              isA<TypedLogicArray<_Word, _WordValue>>());
        } else {
          final slice = tx.serialized;
          expect(slice.dimensions, dimensions.sublist(1));
          expect(slice.valueCodec, same(_wordCodec));
        }

        Simulator.setMaxSimTime(1000);
        unawaited(Simulator.run());
        await clk.nextNegedge;
        reset.inject(0);
        enable.inject(1);
        if (flopInput) {
          await clk.nextPosedge;
          await clk.nextNegedge;
          for (final word in source.arrayElements) {
            word.data.inject(15);
            word.last.inject(0);
          }
        }

        for (var i = 0; i < dimensions.first; i++) {
          expect(tx.count.value.toInt(), i);
          expect(
              tx.serialized.value,
              expected.getRange(
                  i * tx.serialized.width, (i + 1) * tx.serialized.width));
          expect(tx.done.value.toBool(), i == dimensions.first - 1);
          if (i == 1) {
            enable.inject(0);
            receive.inject(0);
            final held = tx.serialized.value;
            await clk.nextPosedge;
            await clk.nextNegedge;
            expect(tx.count.value.toInt(), i);
            expect(tx.serialized.value, held);
            enable.inject(1);
          }
          receive.inject(1);
          await clk.nextPosedge;
          expect(rx.done.value.toBool(), i == dimensions.first - 1);
          if (i < dimensions.first - 1) {
            await clk.nextNegedge;
          }
        }
        expect(rx.deserialized.value, expected);
        expect(rx.deserialized.value.arrayValues, expected.arrayValues);
        for (var i = 0; i < source.arrayElements.length; i++) {
          final word = rx.deserialized.arrayElements[i];
          expect(word.data.value.toInt(), (i + 1) % 16);
          expect(word.last.value.toInt(), i % 2);
        }

        await clk.nextNegedge;
        reset.inject(1);
        await clk.nextPosedge;
        expect(rx.deserialized.value.toBigInt(), BigInt.zero);
        expect(rx.count.value.toInt(), 0);
        await Simulator.endSimulation();
      });
    }
  }

  // Early last completes a partial aggregate without overwriting its tail.
  test('typed scalar deserializer supports last and enable', () async {
    final word = _Word();
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(1);
    final enable = Logic()..put(0);
    final last = Logic()..put(0);
    final rx = Deserializer<_Word, _WordValue>(word, 3,
        valueCodec: _wordCodec,
        clk: clk,
        reset: reset,
        enable: enable,
        last: last);
    await rx.build();
    Simulator.setMaxSimTime(300);
    unawaited(Simulator.run());
    await clk.nextNegedge;
    reset.inject(0);
    word.data.inject(6);
    word.last.inject(1);
    last.inject(1);
    await clk.nextPosedge;
    expect(rx.done.value.toBool(), isFalse);
    expect(rx.deserialized.value.toBigInt(), BigInt.zero);
    await clk.nextNegedge;
    enable.inject(1);
    await clk.nextPosedge;
    expect(rx.done.value.toBool(), isTrue);
    expect(rx.deserialized.arrayElements[0].data.value.toInt(), 6);
    expect(rx.deserialized.arrayElements[0].last.value.toInt(), 1);
    expect(rx.deserialized.arrayElements[1].value.toInt(), 0);
    await Simulator.endSimulation();
  });

  test('deserializer retains unpacked slice dimensions', () async {
    final source = _words([2, 2], numUnpackedDimensions: 1);
    final rx = Deserializer<_Word, _WordValue>(source, 3,
        valueCodec: _wordCodec, clk: Logic(), reset: Logic());
    await rx.build();
    expect(rx.deserialized.dimensions, [3, 2, 2]);
    expect(rx.deserialized.numUnpackedDimensions, 2);
  });

  // Enum mapping must survive cloning, selection, and registration.
  test('enum leaves retain their mapping', () async {
    final source = TypedLogicArray<LogicEnum<_Phase>, LogicValue>(
        [3], ({name}) => LogicEnum(_Phase.values, name: name));
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(1);
    final enable = Logic()..put(0);
    final tx = Serializer(source, clk: clk, reset: reset, enable: enable);
    final rx = Deserializer<LogicEnum<_Phase>, LogicValue>(tx.serialized, 3,
        valueCodec: source.valueCodec, clk: clk, reset: reset, enable: enable);
    for (var i = 0; i < 3; i++) {
      source.arrayElements[i].put(_Phase.values[i]);
    }
    await tx.build();
    await rx.build();
    final serial = tx.serialized.scalar;
    expect(serial.mapping, source.arrayElements.first.mapping);
    Simulator.setMaxSimTime(100);
    unawaited(Simulator.run());
    await clk.nextNegedge;
    reset.inject(0);
    enable.inject(1);
    for (var i = 0; i < 3; i++) {
      expect(serial.valueEnum, _Phase.values[i]);
      await clk.nextPosedge;
      if (i < 2) {
        await clk.nextNegedge;
      }
    }
    expect(rx.deserialized.arrayElements.map((leaf) => leaf.valueEnum),
        _Phase.values);
    await Simulator.endSimulation();
  });

  test('plain constant input becomes a driveable deserializer port', () async {
    final rx = Deserializer<Logic, LogicValue>(Const(5, width: 4), 1,
        valueCodec: LogicValueCodec.logicValue, clk: Logic(), reset: Logic());
    await rx.build();
    expect(rx.deserialized.arrayElements.first, isNot(isA<Const>()));
    expect(rx.input('serialized').width, 4);
  });

  test('invalid lengths, empty dimensions and mismatched leaves fail', () {
    expect(() => Serializer(_words([0]), clk: Logic(), reset: Logic()),
        throwsArgumentError);
    expect(() => Serializer(_words([2, 0]), clk: Logic(), reset: Logic()),
        throwsArgumentError);
    expect(
        () => Deserializer<_Word, _WordValue>(_Word(), 0,
            valueCodec: _wordCodec, clk: Logic(), reset: Logic()),
        throwsArgumentError);
    expect(
        () => Deserializer<_Word, _WordValue>(_words([0]), 2,
            valueCodec: _wordCodec, clk: Logic(), reset: Logic()),
        throwsArgumentError);
    expect(
        () => Deserializer<_Word, _WordValue>(Logic(width: 5), 2,
            valueCodec: _wordCodec, clk: Logic(), reset: Logic()),
        throwsArgumentError);
  });

  // The same packed vectors must simulate through typed structure/array ports
  // in ROHD and in the generated SystemVerilog.
  for (final dimensions in [
    [2],
    [2, 2],
  ]) {
    test('typed serializer vectors $dimensions', () async {
      final tx = Serializer(_words(dimensions),
          clk: Logic(), reset: Logic(), enable: Logic());
      await tx.build();
      final width = tx.serialized.width;
      final packed = 3 | (5 << width);
      final vectors = [
        Vector({'clk': 0, 'reset': 1, 'enable': 0, 'deserialized': packed}, {}),
        Vector({'clk': 1}, {'serialized': 3, 'count': 0, 'done': 0}),
        Vector({'clk': 0, 'reset': 0, 'enable': 1}, {}),
        Vector({'clk': 1}, {'serialized': 5, 'count': 1, 'done': 1}),
        Vector({'clk': 0}, {}),
        Vector({'clk': 1}, {'serialized': 3, 'count': 0, 'done': 0}),
      ];
      await SimCompare.checkFunctionalVector(tx, vectors);
      SimCompare.checkIverilogVector(tx, vectors);
    });

    test('typed deserializer vectors $dimensions', () async {
      final source =
          dimensions.length == 1 ? _Word() : _words(dimensions.sublist(1));
      final rx = Deserializer<_Word, _WordValue>(source, 2,
          valueCodec: _wordCodec,
          clk: Logic(),
          reset: Logic(),
          enable: Logic());
      await rx.build();
      final vectors = [
        Vector({'clk': 0, 'reset': 1, 'enable': 0, 'serialized': 3}, {}),
        Vector({'clk': 1}, {'deserialized': 0, 'count': 0, 'done': 0}),
        Vector({'clk': 0, 'reset': 0, 'enable': 1}, {}),
        Vector({'clk': 1}, {'deserialized': 3, 'count': 1, 'done': 0}),
        Vector({'clk': 0, 'serialized': 5}, {}),
        Vector({'clk': 1},
            {'deserialized': 3 | (5 << source.width), 'count': 0, 'done': 1}),
      ];
      await SimCompare.checkFunctionalVector(rx, vectors);
      SimCompare.checkIverilogVector(rx, vectors);
    });

    // The full aggregate is captured once at the start of the transfer.
    test('buffered typed serializer vectors $dimensions', () async {
      final tx = Serializer(_words(dimensions),
          clk: Logic(), reset: Logic(), enable: Logic(), flopInput: true);
      await tx.build();
      final packed = 3 | (5 << tx.serialized.width);
      final vectors = [
        Vector({'clk': 0, 'reset': 1, 'enable': 0, 'deserialized': packed}, {}),
        Vector({'clk': 1}, {'serialized': 0, 'count': 0, 'done': 0}),
        Vector({'clk': 0, 'reset': 0, 'enable': 1}, {}),
        Vector({'clk': 1}, {'serialized': 3, 'count': 0, 'done': 0}),
        Vector({'clk': 0, 'deserialized': 0}, {}),
        Vector({'clk': 1}, {'serialized': 5, 'count': 1, 'done': 1}),
        Vector({'clk': 0, 'enable': 0}, {}),
        Vector({'clk': 1}, {'serialized': 5, 'count': 1, 'done': 1}),
      ];
      await SimCompare.checkFunctionalVector(tx, vectors);
      SimCompare.checkIverilogVector(tx, vectors);
    });
  }
}
