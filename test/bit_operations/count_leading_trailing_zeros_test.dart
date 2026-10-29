// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// count_leading_trailing_zeros_test.dart
// Tests for CountLeadingZeros and CountTrailingZeros.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

int _clz(int v, int w) {
  for (var i = w - 1; i >= 0; i--) {
    if ((v >> i) & 1 == 1) {
      return w - 1 - i;
    }
  }
  return w;
}

int _ctz(int v, int w) {
  for (var i = 0; i < w; i++) {
    if ((v >> i) & 1 == 1) {
      return i;
    }
  }
  return w;
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  // Exhaustive for width 6 covers zero, single-bit, and multi-bit inputs.
  const width = 6;
  final values = List.generate(1 << width, (i) => i);

  test('clz matches reference for every input', () async {
    final inp = Logic(width: width);
    final dut = CountLeadingZeros(inp);
    await dut.build();

    final vectors = [
      for (final v in values) Vector({'inp': v}, {'count': _clz(v, width)})
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });

  test('ctz matches reference for every input', () async {
    final inp = Logic(width: width);
    final dut = CountTrailingZeros(inp);
    await dut.build();

    final vectors = [
      for (final v in values) Vector({'inp': v}, {'count': _ctz(v, width)})
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });
}
