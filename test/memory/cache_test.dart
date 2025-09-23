// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_test.dart
// Cache tests.
//
// 2025 September 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/cache.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('instantiate cache', () async {
    final clk = SimpleClockGenerator(10).clk;

    final reset = Logic();
    final wrPort = ValidDataPortInterface(8, 16);
    final rdPort = ValidDataPortInterface(8, 16);

    final cache =
        MultiPortedCache(clk, reset, [wrPort], [rdPort], ways: 4, lines: 8);

    await cache.build();
  });

  test('cache smoke test', () async {
    final clk = SimpleClockGenerator(10).clk;

    final reset = Logic();

    final wrPort = ValidDataPortInterface(8, 16);
    final wrPort2 = ValidDataPortInterface(8, 16);
    final rdPort = ValidDataPortInterface(8, 16);
    final rdPort2 = ValidDataPortInterface(8, 16);

    final cache = MultiPortedCache(
        clk, reset, [wrPort, wrPort2], [rdPort, rdPort2],
        ways: 4, lines: 51);

    await cache.build();
    unawaited(Simulator.run());

    await clk.nextPosedge;
    await clk.nextPosedge;
    wrPort.en.inject(0);
    rdPort.en.inject(0);
    wrPort.addr.inject(0);
    wrPort.data.inject(0);
    rdPort.addr.inject(0);
    wrPort2.en.inject(0);
    rdPort2.en.inject(0);
    wrPort2.addr.inject(0);
    wrPort2.data.inject(0);
    rdPort2.addr.inject(0);
    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    // write 0x42 to address 1111
    wrPort.en.inject(1);
    wrPort.addr.inject(1111);
    wrPort.data.inject(0x42);
    await clk.nextPosedge;
    wrPort.en.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    // read it back
    rdPort.en.inject(1);
    rdPort.addr.inject(1111);
    await clk.nextPosedge;
    expect(rdPort.data.value, LogicValue.ofInt(0x42, 8));
    expect(rdPort.valid.value, LogicValue.one);
    rdPort.en.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;

    await Simulator.endSimulation();
  });
}
