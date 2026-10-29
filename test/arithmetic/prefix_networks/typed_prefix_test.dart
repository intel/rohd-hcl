// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_prefix_test.dart
// Tests for typed prefix network generators.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

enum _Topology { ripple, sklansky, koggeStone, brentKung }

enum _Phase { idle, busy, done, error }

class _Affine extends LogicStructure {
  Logic get scale => elements[0];
  Logic get offset => elements[1];

  _Affine({String? name, int width = 4})
      : super([
          Logic(name: 'scale', width: width),
          Logic(name: 'offset', width: width)
        ], name: name ?? 'affine');

  @override
  _Affine clone({String? name}) =>
      _Affine(name: name ?? this.name, width: scale.width);
}

typedef _AffineValue = ({LogicValue scale, LogicValue offset});

_AffineValue _decode(LogicValue bits) =>
    (scale: bits.getRange(0, 4), offset: bits.getRange(4, 8));

LogicValue _encode(_AffineValue value) =>
    LogicValue.of([value.offset, value.scale]);

const _codec = LogicValueCodec<_AffineValue>(decode: _decode, encode: _encode);

ParallelPrefix<T> _tree<T extends Logic>(
        _Topology topology, List<T> inputs, T Function(T a, T b) operation) =>
    switch (topology) {
      _Topology.ripple => Ripple<T>(inputs, operation),
      _Topology.sklansky => Sklansky<T>(inputs, operation),
      _Topology.koggeStone => KoggeStone<T>(inputs, operation),
      _Topology.brentKung => BrentKung<T>(inputs, operation),
    };

class _Harness<T extends Logic> extends Module {
  late final ParallelPrefix<T> tree;

  _Harness(_Topology topology, T schema,
      {int count = 5, T Function(T a, T b)? operation}) {
    tree = _tree<T>(
        topology,
        [
          for (var i = 0; i < count; i++)
            schema.cloneTyped(name: 'payload$i')
              ..gets(addInput('data$i', Logic(width: schema.width),
                  width: schema.width))
        ],
        operation ??
            (a, b) => mux<T>(a[0], a, b, outputGenerator: a.cloneTyped));
    for (var i = 0; i < count; i++) {
      addOutput('result$i', width: schema.width) <= tree.val[i];
    }
  }
}

Future<void> _compare(Module dut, List<Vector> vectors,
    {bool systemC = false}) async {
  await dut.build();
  await SimCompare.checkFunctionalVector(dut, vectors);
  SimCompare.checkIverilogVector(dut, vectors);
  if (systemC) {
    expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
  }
}

void _expectPayload<T extends Logic>(T schema, T signal) {
  expect(signal.runtimeType, schema.runtimeType);
  expect(sameDeclaredPayloadShape(schema, signal), isTrue);
}

void _checkPayload<T extends Logic>(String label, T schema,
    {bool systemC = false}) {
  // First flagged payload wins; this associative operation is order-sensitive.
  for (final topology in _Topology.values) {
    test('$label prefix $topology', () async {
      final dut = _Harness<T>(topology, schema);
      for (var i = 0; i < 5; i++) {
        _expectPayload<T>(schema, dut.tree.val[i]);
        expect(sameDeclaredPayloadShape(schema, dut.tree.input('i$i')), isTrue);
      }
      expect(() => dut.tree.val.clear(), throwsUnsupportedError);
      final vectors = <Vector>[];
      for (final frame in [
        [0x12, 0x24, 0xa3, 0xb5, 0x26],
        [0x31, 0x42, 0x53, 0x64, 0x75],
        [0x12, 0x24, 0x36, 0x48, 0x50],
      ]) {
        final values = frame.map((v) => v & ((1 << schema.width) - 1)).toList();
        var winner = values.first;
        final expected = <String, int>{};
        for (var i = 0; i < values.length; i++) {
          if ((winner & 1) == 0) {
            winner = values[i];
          }
          expected['result$i'] = winner;
        }
        vectors.add(Vector(
            {for (var i = 0; i < values.length; i++) 'data$i': values[i]},
            expected));
      }
      await _compare(dut, vectors, systemC: systemC);
    });
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  _checkPayload('scalar', Logic(width: 8));
  _checkPayload('structured', _Affine(), systemC: true);
  _checkPayload<Logic>('structure with Logic static type', _Affine());
  _checkPayload('enum', LogicEnum<_Phase>(_Phase.values), systemC: true);
  _checkPayload('floating-point', FloatingPoint32());
  _checkPayload('fixed-point', FixedPoint(integerWidth: 3, fractionWidth: 4));
  _checkPayload(
      'rank-zero', TypedLogicArray<_Affine, LogicValue>([], _Affine.new));
  _checkPayload(
      'unpacked multidimensional',
      TypedLogicArray<_Affine, LogicValue>([2, 2], _Affine.new,
          numUnpackedDimensions: 2),
      systemC: true);
  _checkPayload(
      'custom codec',
      TypedLogicArray<_Affine, _AffineValue>([2], _Affine.new,
          valueCodec: _codec));

  // Affine composition modulo 16 changes when operands are swapped.
  for (final topology in _Topology.values) {
    for (final count in [1, 2, 3, 5, 8, 9, 17]) {
      test('noncommutative affine prefix $topology count=$count', () async {
        final dut = _Harness<_Affine>(topology, _Affine(),
            count: count,
            operation: (left, right) => _Affine()
              ..scale.gets(right.scale * left.scale)
              ..offset.gets(right.scale * left.offset + right.offset));
        final random = Random(17);
        final vectors = <Vector>[];
        for (var trial = 0; trial < 20; trial++) {
          final values = List.generate(count, (_) => random.nextInt(256));
          var scale = 1;
          var offset = 0;
          final expected = <String, int>{};
          for (var i = 0; i < count; i++) {
            final nextScale = values[i] & 0xf;
            final nextOffset = values[i] >> 4;
            offset = (nextScale * offset + nextOffset) & 0xf;
            scale = (nextScale * scale) & 0xf;
            expected['result$i'] = scale | (offset << 4);
          }
          vectors.add(Vector(
              {for (var i = 0; i < count; i++) 'data$i': values[i]}, expected));
        }
        await _compare(dut, vectors, systemC: count == 5);
      });
    }

    // Preserve scalar widths and permit mutable ports for Const inputs/results.
    test('scalar width and constant compatibility $topology', () async {
      final inputs = [
        for (var i = 0; i < 5; i++) Logic(width: i + 2)..put((1 << (i + 1)) | 1)
      ];
      final tree = _tree<Logic>(topology, inputs,
          (left, right) => left.zeroExtend(right.width) | right);
      await tree.build();
      var expected = 0;
      for (var i = 0; i < inputs.length; i++) {
        expected |= inputs[i].value.toInt();
        expect(tree.val[i].width, inputs[i].width);
        expect(tree.val[i].value.toInt(), expected);
      }
      final constants = _tree<Logic>(
          topology,
          [for (var i = 0; i < 5; i++) Const(3, width: 4)],
          (a, b) => Const(1, width: 4));
      await constants.build();
      expect(constants.val.first.value.toInt(), 3);
      for (final output in constants.val.skip(1)) {
        expect(output, isNot(isA<Const>()));
        expect(output.value.toInt(), 1);
      }
    });

    test('invalid payload schemas rejected $topology', () {
      expect(() => _tree<Logic>(topology, [], (a, b) => a | b),
          throwsA(isA<RohdHclException>()));
      final array = TypedLogicArray<_Affine, LogicValue>([2, 2], _Affine.new);
      final reshaped = TypedLogicArray<_Affine, LogicValue>([4], _Affine.new);
      expect(() => _tree(topology, [array, reshaped], (a, b) => a),
          throwsA(isA<RohdHclException>()));
      expect(
          () => _tree<_Affine>(
              topology, [_Affine(), _Affine()], (a, b) => _Affine(width: 3)),
          throwsA(isA<RohdHclException>()));
      expect(
          () => _tree<Logic>(
              topology, [_Affine(), _Affine()], (a, b) => Logic(width: 8)),
          throwsA(isA<RohdHclException>()));
    });

    // Unknown and high-impedance bits retain the original bitwise semantics.
    test('four-state scalar prefix $topology', () async {
      final dut = _Harness<Logic>(topology, Logic(width: 4),
          operation: (a, b) => a | b);
      final values = [
        LogicValue.ofString('00x0'),
        LogicValue.ofString('0100'),
        LogicValue.ofString('000z'),
        LogicValue.ofString('0011'),
        LogicValue.ofString('1000'),
      ];
      var value = values.first;
      final expected = <String, LogicValue>{};
      for (var i = 0; i < values.length; i++) {
        if (i > 0) {
          value = value | values[i];
        }
        expected['result$i'] = value;
      }
      await _compare(dut, [
        Vector({for (var i = 0; i < values.length; i++) 'data$i': values[i]},
            expected)
      ]);
    });

    test('four-state prefix adder $topology', () async {
      final adder = ParallelPrefixAdder(
          Logic(name: 'a', width: 4), Logic(name: 'b', width: 4),
          carryIn: Logic(name: 'carryIn'),
          ppGen: (inputs, operation) => _tree(topology, inputs, operation));
      await _compare(adder, [
        Vector({'a': 0, 'b': 0, 'carryIn': LogicValue.x},
            {'sum': LogicValue.ofString('0000x')}),
        Vector({'a': 15}, {'sum': LogicValue.ofString('xxxxx')}),
        Vector({'a': LogicValue.ofString('001z'), 'carryIn': 0},
            {'sum': LogicValue.ofString('0001x')}),
        Vector({'a': LogicValue.ofString('000x'), 'b': 1},
            {'sum': LogicValue.ofString('000xx')}),
      ]);
    });

    // Exhaustive carry-in and carry-out, including singleton adders.
    for (final width in [1, 4]) {
      for (final carryIn in [false, true]) {
        test('typed prefix adder $topology width=$width carryIn=$carryIn',
            () async {
          ParallelPrefix<GeneratePropagate>? observed;
          ParallelPrefix<GeneratePropagate> generator(
              List<GeneratePropagate> inputs,
              GeneratePropagate Function(GeneratePropagate, GeneratePropagate)
                  operation) {
            observed = _tree(topology, inputs, operation);
            return observed!;
          }

          final a = Logic(name: 'a', width: width);
          final b = Logic(name: 'b', width: width);
          final ci = Logic(name: 'carryIn');
          final adder = ParallelPrefixAdder(a, b,
              carryIn: carryIn ? ci : null, ppGen: generator);
          for (final pair in observed!.val) {
            _expectPayload<GeneratePropagate>(GeneratePropagate(), pair);
          }
          final vectors = [
            for (var av = 0; av < (1 << width); av++)
              for (var bv = 0; bv < (1 << width); bv++)
                for (var cv = 0; cv < (carryIn ? 2 : 1); cv++)
                  Vector({'a': av, 'b': bv, if (carryIn) 'carryIn': cv},
                      {'sum': av + bv + cv}),
          ];
          await _compare(adder, vectors, systemC: carryIn);
        });
      }
    }
  }
}
