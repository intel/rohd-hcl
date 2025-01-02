// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// count_test.dart
// Tests for Count
//
// 2023 June 8
// Author: Rahul Gautham Putcha <rahul.gautham.putcha@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/count.dart';
import 'package:test/test.dart';

void main() {
  test('count all 1s', () {
    final bus = Const(bin('01101'), width: 5);
    final mod = Count(bus);
    expect(mod.count.value.toInt(), 3);
  });

  test('count all 1s when input is all 1s', () {
    final bus = Const(bin('11111'), width: 5);
    final mod = Count(bus);
    expect(mod.count.value.toInt(), 5);
  });
  test('count all 1s when input is all 0s', () {
    final bus = Const(bin('00000'), width: 5);
    final mod = Count(bus);
    expect(mod.count.value.toInt(), 0);
  });

  test('count all 0s', () {
    final bus = Const(bin('001101'), width: 6);
    final mod = Count(bus, countOne: false);
    expect(mod.count.value.toInt(), 3);
  });
  test('count all 0s when input is all 1s', () {
    final bus = Const(bin('11111'), width: 5);
    final mod = Count(bus, countOne: false);
    expect(mod.count.value.toInt(), 0);
  });
  test('count all 0s when input is all 0s', () {
    final bus = Const(bin('00000'), width: 5);
    final mod = Count(bus, countOne: false);
    expect(mod.count.value.toInt(), 5);
  });

  test('width of count output is correct', () {
    expect(Count(Const(0, width: 1)).count.width, 1);
    expect(Count(Const(0, width: 2)).count.width, 2);
    expect(Count(Const(0, width: 3)).count.width, 2);
    expect(Count(Const(0, width: 4)).count.width, 3);
    expect(Count(Const(0, width: 7)).count.width, 3);
    expect(Count(Const(0, width: 8)).count.width, 4);
  });
}
