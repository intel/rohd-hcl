// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sparse_to_dense_test.dart
// Tests for combinational boolean sparse-to-dense scatter.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

int _reference(List<int> indices, List<int> valids, int outputWidth) {
  var result = 0;
  for (var i = 0; i < indices.length; i++) {
    if (valids[i] == 1 && indices[i] < outputWidth) {
      result |= 1 << indices[i];
    }
  }
  return result;
}

List<Vector> _exhaustiveVectors(int count, int indexWidth, int outputWidth) {
  final vectors = <Vector>[];
  final choices = 1 << (indexWidth + 1);
  var combinations = 1;
  for (var i = 0; i < count; i++) {
    combinations *= choices;
  }
  for (var encoded = 0; encoded < combinations; encoded++) {
    var remaining = encoded;
    final indices = <int>[];
    final valids = <int>[];
    for (var i = 0; i < count; i++) {
      final choice = remaining % choices;
      remaining ~/= choices;
      indices.add(choice & ((1 << indexWidth) - 1));
      valids.add(choice >> indexWidth);
    }
    vectors.add(Vector({
      for (var i = 0; i < count; i++) 'index$i': indices[i],
      for (var i = 0; i < count; i++) 'valid$i': valids[i],
    }, {
      'out': _reference(indices, valids, outputWidth),
    }));
  }
  return vectors;
}

// Keep this composition in sync with the reduction tree documentation.
Logic _documentedScatter(List<Logic> indices, List<Logic> valids, int width) {
  final terms = [
    for (var i = 0; i < indices.length; i++)
      (Const(1, width: width) << indices[i]) & valids[i].replicate(width),
  ];
  return ReductionTree<Logic, Logic>(
    terms,
    (inputs, {depth = 0, control, name = ''}) => inputs.reduce((a, b) => a | b),
  ).out;
}

class _Composition extends Module {
  _Composition() {
    final indices = [
      for (var i = 0; i < 3; i++)
        addInput('index$i', Logic(width: 3), width: 3),
    ];
    final valids = [
      for (var i = 0; i < 3; i++) addInput('valid$i', Logic()),
    ];
    addOutput('out', width: 5) <= _documentedScatter(indices, valids, 5);
  }
}

class _MixedGeometry extends Module {
  _MixedGeometry() {
    final index = addInput('index', Logic(width: 4), width: 4);
    final valid = addInput('valid', Logic());
    final small = SparseToDense([index], [valid], outputWidth: 3);
    final large = SparseToDense(
      [index, index, index],
      [valid, valid, valid],
      outputWidth: 5,
    );
    final other = SparseToDense(
      [index, index, index],
      [valid, valid, valid],
      outputWidth: 3,
    );
    addOutput('smallOut', width: 3) <= small.out;
    addOutput('largeOut', width: 5) <= large.out;
    addOutput('other', width: 3) <= other.out;
  }
}

void main() {
  tearDown(Simulator.reset);

  for (final (count, indexWidth, outputWidth) in [
    (1, 1, 1),
    (1, 2, 5),
    (2, 2, 4),
    (3, 2, 3),
  ]) {
    test('exhaustive N$count I$indexWidth O$outputWidth', () async {
      final indices = List.generate(count, (_) => Logic(width: indexWidth));
      final valids = List.generate(count, (_) => Logic());
      final dut = SparseToDense(indices, valids, outputWidth: outputWidth);
      expect(dut.inputCount, count);
      expect(dut.indexWidth, indexWidth);
      expect(dut.outputWidth, outputWidth);
      expect(dut.out.width, outputWidth);
      final vectors = _exhaustiveVectors(count, indexWidth, outputWidth);
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('four-state shift, valid masking and collision resolution', () async {
    final dut = SparseToDense(
      [Logic(width: 3), Logic(width: 3)],
      [Logic(), Logic()],
      outputWidth: 5,
    );
    final vectors = [
      Vector(
          {'index0': 'x01', 'valid0': 0, 'index1': 2, 'valid1': 1}, {'out': 4}),
      Vector({'index0': 'z01', 'valid0': 1, 'index1': 2, 'valid1': 1},
          {'out': LogicValue.ofString('xx1xx')}),
      Vector({'index0': 'x01', 'valid0': 1, 'index1': 2, 'valid1': 0},
          {'out': LogicValue.ofString('xxxxx')}),
      Vector({'index0': 1, 'valid0': 'x', 'index1': 2, 'valid1': 1},
          {'out': LogicValue.ofString('001x0')}),
      Vector({'index0': 1, 'valid0': 'z', 'index1': 2, 'valid1': 0},
          {'out': LogicValue.ofString('000x0')}),
      Vector(
          {'index0': 1, 'valid0': 'z', 'index1': 1, 'valid1': 1}, {'out': 2}),
      Vector(
          {'index0': 7, 'valid0': 'x', 'index1': 0, 'valid1': 0}, {'out': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('bounded hardware for very wide index', () async {
    final dut = SparseToDense([Logic(width: 64)], [Logic()], outputWidth: 3);
    final vectors = [
      Vector({'index0': 2, 'valid0': 1}, {'out': 4}),
      Vector({'index0': BigInt.one << 40, 'valid0': 1}, {'out': 0}),
    ];
    await dut.build();
    expect(dut.dumpSystemVerilog(), isNot(contains('18446744073709551616')));
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('mixed geometries elaborate together', () async {
    final dut = _MixedGeometry();
    final vectors = [
      Vector(
          {'index': 2, 'valid': 1}, {'smallOut': 4, 'largeOut': 4, 'other': 4}),
      Vector({'index': 4, 'valid': 1},
          {'smallOut': 0, 'largeOut': 16, 'other': 0}),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('documented composition', () async {
    final dut = _Composition();
    final vectors = [
      Vector({
        'index0': 1,
        'valid0': 1,
        'index1': 1,
        'valid1': 1,
        'index2': 7,
        'valid2': 1,
      }, {
        'out': 2,
      }),
    ];
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('rejects invalid geometry and valid signals', () {
    expect(() => SparseToDense([], [], outputWidth: 1),
        throwsA(isA<RohdHclException>()));
    expect(() => SparseToDense([Logic()], [], outputWidth: 1),
        throwsA(isA<RohdHclException>()));
    expect(() => SparseToDense([Logic()], [Logic()], outputWidth: 0),
        throwsA(isA<RohdHclException>()));
    expect(() => SparseToDense([Logic()], [Logic()], outputWidth: -1),
        throwsA(isA<RohdHclException>()));
    expect(
        () => SparseToDense([Logic(), Logic(width: 2)], [Logic(), Logic()],
            outputWidth: 2),
        throwsA(isA<RohdHclException>()));
    expect(() => SparseToDense([Logic()], [Logic(width: 2)], outputWidth: 2),
        throwsA(isA<RohdHclException>()));
    expect(() => SparseToDense([Logic(width: 0)], [Logic()], outputWidth: 2),
        throwsA(isA<RohdHclException>()));
  });
}
