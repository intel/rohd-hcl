// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter_test.dart
// Tests for the counter.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('basic counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final intf = CounterInterface();
    final counter = Counter([intf], clk: clk, reset: reset);

    await counter.build();

    print(counter.generateSynth());
  });
}
