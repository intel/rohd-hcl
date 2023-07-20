// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// find_test.dart
// Tests for Find
//
// 2023 June 8
// Author: Max Korbel <max.korbel@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/utils.dart';
import 'package:test/test.dart';

void main() {
  test('find first one', () {
    final bus = Const(bin('0111000100'), width: 10);
    final mod = Find(bus);
    expect(mod.index.value.toInt(), 2);
  });

  test('find nth one', () {
    final bus = Const(bin('10110'), width: 5);
    final mod = Find(bus, n: Const(3, width: log2Ceil(5)));
    expect(mod.index.value.toInt(), 4);
  });

  test('find first zero', () {
    final bus = Const(bin('0111011111'), width: 10);
    final mod = Find(bus, one: false);
    expect(mod.index.value.toInt(), 5);
  });

  test('find nth zero', () {
    final bus = Const(bin('0111001010'), width: 10);
    final mod = Find(bus, one: false, n: Const(3, width: log2Ceil(10)));
    expect(mod.index.value.toInt(), 4);
  });
}
