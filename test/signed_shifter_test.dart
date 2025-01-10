// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// signed_shifter_test.dart
// Tests for signed shifter
//
// 2025 January 8
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('sigend shifter test', () {
    final bits = Const(16, width: 32);
    final shift = Logic(width: 3);

    final shifter = SignedShifter(bits, shift);
    var expected = 16;
    for (var i = 0; i < 4; i++) {
      shift.put(i);
      expect(shifter.shifted.value.toInt(), equals(expected));
      expected = expected << 1;
    }
    expected = 1;
    for (var i = 4; i < 8; i++) {
      shift.put(i);
      expect(shifter.shifted.value.toInt(), equals(expected));
      expected = expected << 1;
    }
  });
}
