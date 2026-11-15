// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// majority_test.dart
// Tests for strict majority operations.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

String _expectedMajority(String bits) {
  final ones = bits.split('').where((bit) => bit == '1').length;
  final unknowns =
      bits.split('').where((bit) => bit == 'x' || bit == 'z').length;
  final threshold = bits.length ~/ 2 + 1;
  if (ones >= threshold) {
    return '1';
  }
  if (ones + unknowns < threshold) {
    return '0';
  }
  return 'x';
}

Iterable<String> _fourStateInputs(int width) sync* {
  const states = ['0', '1', 'x', 'z'];
  for (var value = 0; value < (1 << (width * 2)); value++) {
    yield [
      for (var bit = width - 1; bit >= 0; bit--)
        states[(value >> (bit * 2)) & 3]
    ].join();
  }
}

class _DualMajority extends Module {
  _DualMajority() {
    final a = addInput('a', Logic(width: 4), width: 4);
    final b = addInput('b', Logic(width: 4), width: 4);
    addOutput('first') <= a.majority();
    addOutput('second') <= b.majority();
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  for (final width in [1, 2, 3, 4, 5]) {
    test('strict majority width $width covers four-state inputs and RTL',
        () async {
      final dut = Majority(Logic(width: width));
      await dut.build();
      final vectors = [
        for (final bits in _fourStateInputs(width))
          Vector({'bits': bits},
              {'majority': LogicValue.ofString(_expectedMajority(bits))})
      ];
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  for (final width in [6, 9, 32]) {
    test('strict majority handles wider mixed-state vectors, width $width',
        () async {
      final dut = Majority(Logic(width: width));
      await dut.build();
      final threshold = width ~/ 2 + 1;
      final inputs = [
        '0' * width,
        '1' * width,
        '${'1' * threshold}${'x' * (width - threshold)}',
        '${'0' * threshold}${'z' * (width - threshold)}',
        '${'1' * (threshold - 1)}x${'0' * (width - threshold)}',
        'z' * width,
      ];
      final vectors = [
        for (final bits in inputs)
          Vector({'bits': bits},
              {'majority': LogicValue.ofString(_expectedMajority(bits))})
      ];
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('full-adder carry uses the same three-input majority in RTL', () async {
    final dut = Compressor3(Logic(width: 3));
    await dut.build();
    final vectors = [
      for (final bits in _fourStateInputs(3))
        Vector({'compressBits': bits},
            {'carry': LogicValue.ofString(_expectedMajority(bits))})
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('multiple majority networks coexist in one RTL module', () async {
    final dut = _DualMajority();
    await dut.build();
    final vectors = [
      for (var a = 0; a < 16; a++)
        for (var b = 0; b < 16; b++)
          Vector({
            'a': a,
            'b': b
          }, {
            'first': int.parse(
                _expectedMajority(a.toRadixString(2).padLeft(4, '0'))),
            'second': int.parse(
                _expectedMajority(b.toRadixString(2).padLeft(4, '0'))),
          })
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('existing value majority keeps its tie and invalid-input behavior', () {
    expect(LogicValue.ofString('10').majority(), isFalse);
    expect(LogicValue.ofString('11x').majority(), isFalse);
    expect(LogicValue.ofString('11z').majority(), isFalse);
  });
}
