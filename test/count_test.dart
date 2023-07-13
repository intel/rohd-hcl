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
import 'package:rohd_hcl/src/count.dart';
import 'package:test/test.dart';

void main() {
  test('count all 1s', () {
    final bus = Const(bin('01101'), width: 5);
    final mod = Count(bus);
    expect(mod.index.value.toInt(), 3);
  });

  test('count all 0s', () {
    final bus = Const(bin('001101'), width: 6);
    final mod = Count(bus, countOne: false);
    expect(mod.index.value.toInt(), 3);
  });
}
