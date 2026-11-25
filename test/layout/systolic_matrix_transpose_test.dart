// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// systolic_matrix_transpose_test.dart
// Tests for stepped streaming matrix transpose.
//
// 2026 November 23
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  for (final (dimension, width) in [(1, 8), (3, 5), (4, 8)]) {
    test('streams $dimension x $dimension matrices with stalls and reset',
        () async {
      final dut = SystolicMatrixTranspose(
        clk: Logic(),
        reset: Logic(),
        step: Logic(),
        dataIn: LogicArray([dimension], width),
      );
      await dut.build();
      final descriptor =
          TransposeDescriptor.matrix(rows: dimension, columns: dimension);
      final vectors = <Vector>[];
      BigInt pack(List<int> lanes) {
        var result = BigInt.zero;
        for (var i = 0; i < lanes.length; i++) {
          result |= BigInt.from(lanes[i]) << (i * width);
        }
        return result;
      }

      List<List<int>> matrix(int seed) => [
            for (var row = 0; row < dimension; row++)
              [
                for (var column = 0; column < dimension; column++)
                  (seed + row * dimension + column) & ((1 << width) - 1),
              ],
          ];
      List<int> outputRow(List<List<int>> data, int row) => [
            for (var column = 0; column < dimension; column++)
              data.expand((values) => values).toList()[
                  descriptor.permutation.sourceIndex(row * dimension + column)]
          ];
      void cycle(
          {required int reset,
          required int step,
          required List<int> input,
          required int primed,
          List<int>? expected}) {
        final inputs = {
          'clk': 0,
          'reset': reset,
          'step': step,
          'dataIn': pack(input),
        };
        vectors
          ..add(Vector(inputs, {
            'primed': primed,
            if (expected != null) 'dataOut': pack(expected),
          }))
          ..add(Vector({...inputs, 'clk': 1}, const {}));
      }

      final zero = List<int>.filled(dimension, 0);
      cycle(reset: 1, step: 0, input: zero, primed: 0);
      var previous = matrix(3);
      for (final row in previous) {
        cycle(reset: 0, step: 1, input: row, primed: 0);
      }
      for (var block = 0; block < 4; block++) {
        final next = matrix(31 + block * 23);
        for (var row = 0; row < dimension; row++) {
          final expected = outputRow(previous, row);
          cycle(reset: 0, step: 0, input: zero, primed: 1, expected: expected);
          cycle(
              reset: 0,
              step: 1,
              input: next[row],
              primed: 1,
              expected: expected);
        }
        previous = next;
      }
      cycle(
          reset: 0,
          step: 1,
          input: zero,
          primed: 1,
          expected: outputRow(previous, 0));
      cycle(reset: 1, step: 1, input: zero, primed: 0);
      final next = matrix(17);
      for (final row in next) {
        cycle(reset: 0, step: 1, input: row, primed: 0);
      }
      cycle(
          reset: 0,
          step: 0,
          input: zero,
          primed: 1,
          expected: outputRow(next, 0));
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('rejects empty and non-row arrays', () {
    for (final dimensions in [
      <int>[],
      [0],
      [2, 2],
    ]) {
      expect(
          () => SystolicMatrixTranspose(
                clk: Logic(),
                reset: Logic(),
                step: Logic(),
                dataIn: TypedLogicArray<Logic, LogicValue>(
                    dimensions, ({name}) => Logic(name: name, width: 8)),
              ),
          throwsArgumentError);
    }
  });

  for (final unpacked in [0, 1]) {
    test('retains structured rows through a parent with unpacked=$unpacked',
        () async {
      final row = TypedLogicArray<_Sample, (LogicValue, int)>(
        [2],
        ({name}) => _Sample(name: name),
        numUnpackedDimensions: unpacked,
        valueCodec: LogicValueCodec<(LogicValue, int)>(
          decode: (value) => (value, 1),
          encode: (value) => value.$1,
        ),
      );
      final dut = _TypedTransposeParent(row);
      await dut.build();
      expect(dut.dataOut.numUnpackedDimensions, unpacked);
      expect(dut.dataOut.arrayElements.first.formatId, 1);
      expect(dut.dataOut.valueCodec, same(row.valueCodec));
      final vectors = [
        Vector({'clk': 0, 'reset': 1, 'step': 0, 'dataIn': 0}, {'primed': 0}),
        Vector({'clk': 1}, const {}),
        Vector(
            {'clk': 0, 'reset': 0, 'step': 1, 'dataIn': 0x4231}, {'primed': 0}),
        Vector({'clk': 1}, const {}),
        Vector({'clk': 0, 'dataIn': 0x6453}, {'primed': 0}),
        Vector({'clk': 1}, const {}),
        Vector({'clk': 0, 'step': 0, 'dataIn': 0},
            {'primed': 1, 'dataOut': 0x5331}),
        Vector({'clk': 1}, {'dataOut': 0x5331}),
        Vector({'clk': 0, 'step': 1}, {'dataOut': 0x5331}),
        Vector({'clk': 1}, const {}),
        Vector({'clk': 0, 'step': 0}, {'dataOut': 0x6442}),
      ];
      await SimCompare.checkFunctionalVector(dut, vectors);
      expect(dut.dataOut.value.arrayValues,
          [(LogicValue.ofInt(0x42, 8), 1), (LogicValue.ofInt(0x64, 8), 1)]);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  final referencePath = Platform.environment['GEMMINI_TRANSPOSE_VECTORS'];
  test('matches pinned upstream transposer step by step', () async {
    final lines = await File(referencePath!).readAsLines();
    for (final dimension in [1, 2, 4, 16]) {
      final dut = SystolicMatrixTranspose(
        clk: Logic(),
        reset: Logic(),
        step: Logic(),
        dataIn: LogicArray([dimension], 8),
      );
      await dut.build();
      final vectors = <Vector>[];
      var checked = 0;
      for (final line in lines) {
        final fields = line.split(',');
        expect(fields.length, 6);
        if (int.parse(fields[0]) != dimension) {
          continue;
        }

        final input = {
          'clk': 0,
          'reset': int.parse(fields[1]),
          'step': int.parse(fields[2]),
          'dataIn': BigInt.parse(fields[3]),
        };
        final primed = int.parse(fields[4]);
        checked += primed;
        vectors
          ..add(Vector(input, {
            'primed': primed,
            if (primed == 1) 'dataOut': BigInt.parse(fields[5]),
          }))
          ..add(Vector({...input, 'clk': 1}, const {}));
      }
      expect(vectors.length, 2 * (8 * dimension + 40));
      expect(checked, greaterThan(2 * dimension));
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
      await Simulator.reset();
    }
  },
      skip: referencePath == null
          ? 'Set GEMMINI_TRANSPOSE_VECTORS to upstream reference vectors.'
          : null);
}

class _Sample extends LogicStructure implements PayloadShapeMetadata {
  final int formatId;

  _Sample({String? name, this.formatId = 1})
      : super([Logic(name: 'tag', width: 3), Logic(name: 'value', width: 5)],
            name: name ?? 'sample');

  @override
  String get payloadShapeMetadata => 'sample:$formatId';

  @override
  _Sample clone({String? name}) => _Sample(name: name, formatId: formatId);
}

class _TypedTransposeParent<V> extends Module {
  late final TypedLogicArray<_Sample, V> dataOut;

  _TypedTransposeParent(TypedLogicArray<_Sample, V> row) {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final step = addInput('step', Logic());
    final dataIn = addTypedInput('dataIn', row);
    final child = SystolicMatrixTranspose(
        clk: clk, reset: reset, step: step, dataIn: dataIn);
    dataOut = addTypedOutput('dataOut', child.dataOut.clone);
    dataOut <= child.dataOut;
    addOutput('primed') <= child.primed;
  }
}
