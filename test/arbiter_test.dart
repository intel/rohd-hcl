// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arbiter_test.dart
// Tests for arbiters
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>
//

import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('priority arbiter', () async {
    const width = 8;

    final vector = Logic(width: width);
    final reqs = List.generate(width, (i) => vector[i]);

    final arb = PriorityArbiter(reqs);

    final grantVec = arb.grants.rswizzle();

    vector.put(bin('00000000'));
    expect(grantVec.value, LogicValue.ofString('00000000'));

    vector.put(bin('00000001'));
    expect(grantVec.value, LogicValue.ofString('00000001'));

    vector.put(bin('00010000'));
    expect(grantVec.value, LogicValue.ofString('00010000'));

    vector.put(bin('00010100'));
    expect(grantVec.value, LogicValue.ofString('00000100'));
  });
}
