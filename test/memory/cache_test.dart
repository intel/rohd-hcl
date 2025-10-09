// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cache_test.dart
// Cache tests.
//
// 2025 September 10
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('Cache narrow tests', () {
    const dataWidth = 4;
    const addrWidth = 7;
    final lines = BigInt.two.pow(addrWidth).toInt();

    test('SP Cache singleton read until write matches', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(dataWidth, addrWidth);
      final rdPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache =
          SinglePortedCache(clk, reset, fillPort, rdPort, lines: lines);

      await cache.build();
      WaveDumper(cache, outputPath: 'cache_singleton.vcd');
      File('cache_singleton.v').writeAsStringSync(cache.generateSynth());
      unawaited(Simulator.run());

      await clk.waitCycles(2);
      rdPort.en.inject(0);
      rdPort.addr.inject(0);
      fillPort.en.inject(0);
      fillPort.addr.inject(0);
      fillPort.data.inject(0);
      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.waitCycles(2);

      const first = 0x20;
      // Start a read on an address
      rdPort.en.inject(1);
      rdPort.addr.inject(first);
      await clk.waitCycles(3);
      // rdPort.en.inject(0);

      // write data to address addr
      fillPort.en.inject(1);
      fillPort.valid.inject(1);
      fillPort.addr.inject(first);
      fillPort.data.inject(9);
      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.waitCycles(3);

      await Simulator.endSimulation();
    });
  });
}
