// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

/// Builds one-hot per-bit selects for [sources], where `sources[j]` is the
/// index of the input that bit `j` takes. Returns the select words and the
/// expected output for [inputVals].
(List<int>, int) _oneHotFor(List<int> sources, List<int> inputVals) {
  final n = inputVals.length;
  final selects = List.filled(n, 0);
  var expected = 0;
  for (var j = 0; j < sources.length; j++) {
    selects[sources[j]] |= 1 << j;
    expected |= ((inputVals[sources[j]] >> j) & 1) << j;
  }
  return (selects, expected);
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('bitwise mux with two inputs picks each bit from its own source',
      () async {
    // Width 4 corners: all-b, all-a, and two mixed one-hot patterns.
    const width = 4;
    final selects = [
      Logic(name: 'select0', width: width),
      Logic(name: 'select1', width: width),
    ];
    final inputs = [
      Logic(name: 'input0', width: width),
      Logic(name: 'input1', width: width),
    ];
    final dut = BitwiseMux(selects, inputs);

    await dut.build();

    final inputVals = [0x3, 0xC];
    final vectors = [
      for (final sources in [
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [0, 1, 0, 1],
        [1, 0, 0, 1],
      ])
        () {
          final (sel, expected) = _oneHotFor(sources, inputVals);
          return Vector({
            'select0': sel[0],
            'select1': sel[1],
            'input0': inputVals[0],
            'input1': inputVals[1],
          }, {
            'out': expected,
          });
        }(),
    ];

    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('bitwise mux with three inputs selects per bit across all sources',
      () async {
    // Width 3 with each bit choosing a different input, including a bit that
    // takes input 2 and one that takes input 0, to exercise every select.
    const width = 3;
    final selects = [
      for (var i = 0; i < 3; i++) Logic(name: 'select$i', width: width),
    ];
    final inputs = [
      for (var i = 0; i < 3; i++) Logic(name: 'input$i', width: width),
    ];
    final dut = BitwiseMux(selects, inputs);

    await dut.build();

    final inputVals = [0x5, 0x2, 0x7];
    final vectors = [
      for (final sources in [
        [0, 1, 2],
        [2, 2, 2],
        [1, 0, 2],
      ])
        () {
          final (sel, expected) = _oneHotFor(sources, inputVals);
          return Vector({
            'select0': sel[0],
            'select1': sel[1],
            'select2': sel[2],
            'input0': inputVals[0],
            'input1': inputVals[1],
            'input2': inputVals[2],
          }, {
            'out': expected,
          });
        }(),
    ];

    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('bitwise mux rejects mismatched select count and widths', () {
    final a = Logic(width: 4);
    final b = Logic(width: 4);
    expect(() => BitwiseMux([Logic(width: 4)], [a, b]),
        throwsA(isA<RohdHclException>()));
    expect(() => BitwiseMux([Logic(width: 4), Logic(width: 3)], [a, b]),
        throwsA(isA<RohdHclException>()));
    expect(() => BitwiseMux([], []), throwsA(isA<RohdHclException>()));
  });
}
