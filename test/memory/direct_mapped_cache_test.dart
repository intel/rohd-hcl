// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// direct_mapped_cache_test.dart
// Tests for the DirectMappedCache component.
//
// 2025 October 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('DirectMappedCache', () {
    test('cache miss then hit', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(32, 8);
      final readPort = ValidDataPortInterface(32, 8);

      final cache = DirectMappedCache(clk, reset, [fillPort], [readPort]);

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      readPort.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Read from address 0x10 (cache miss)
      readPort.en.inject(1);
      readPort.addr.inject(0x10);

      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), false); // Miss

      readPort.en.inject(0);
      await clk.nextPosedge;

      // Fill address 0x10 with data 0xDEADBEEF
      fillPort.en.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xDEADBEEF);
      fillPort.valid.inject(1);

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Read from address 0x10 again (cache hit)
      readPort.en.inject(1);
      readPort.addr.inject(0x10);

      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), true); // Hit
      expect(readPort.data.value.toInt(), 0xDEADBEEF);

      readPort.en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });

    test('different addresses map to different lines', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(32, 8);
      final readPort = ValidDataPortInterface(32, 8);

      final cache = DirectMappedCache(clk, reset, [fillPort], [readPort]);

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      readPort.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Fill multiple addresses
      final addresses = [0x00, 0x01, 0x02, 0x03];
      final dataValues = [0x1111, 0x2222, 0x3333, 0x4444];

      for (var i = 0; i < addresses.length; i++) {
        fillPort.en.inject(1);
        fillPort.addr.inject(addresses[i]);
        fillPort.data.inject(dataValues[i]);
        fillPort.valid.inject(1);

        await clk.nextPosedge;
      }

      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Read back all addresses
      for (var i = 0; i < addresses.length; i++) {
        readPort.en.inject(1);
        readPort.addr.inject(addresses[i]);

        await clk.nextPosedge;
        expect(readPort.valid.value.toBool(), true,
            reason: 'Address 0x${addresses[i].toRadixString(16)} should hit');
        expect(readPort.data.value.toInt(), dataValues[i],
            reason: 'Data should match for address '
                '0x${addresses[i].toRadixString(16)}');
      }

      readPort.en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });

    test('conflict miss - same line index, different tag', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort = ValidDataPortInterface(32, 8);
      final readPort = ValidDataPortInterface(32, 8);

      final cache = DirectMappedCache(clk, reset, [fillPort], [readPort]);

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort.en.inject(0);
      readPort.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Fill address 0x10 (line 0, tag 1)
      fillPort.en.inject(1);
      fillPort.addr.inject(0x10);
      fillPort.data.inject(0xAAAA);
      fillPort.valid.inject(1);

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Read address 0x10 (should hit)
      readPort.en.inject(1);
      readPort.addr.inject(0x10);

      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), true);
      expect(readPort.data.value.toInt(), 0xAAAA);

      readPort.en.inject(0);
      await clk.nextPosedge;

      // Fill address 0x00 (line 0, tag 0) - conflicts with 0x10
      fillPort.en.inject(1);
      fillPort.addr.inject(0x00);
      fillPort.data.inject(0xBBBB);
      fillPort.valid.inject(1);

      await clk.nextPosedge;
      fillPort.en.inject(0);
      await clk.nextPosedge;

      // Read address 0x10 again (should miss now - evicted by 0x00)
      readPort.en.inject(1);
      readPort.addr.inject(0x10);

      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), false); // Miss due to conflict

      readPort.en.inject(0);
      await clk.nextPosedge;

      // Read address 0x00 (should hit)
      readPort.en.inject(1);
      readPort.addr.inject(0x00);

      await clk.nextPosedge;
      expect(readPort.valid.value.toBool(), true);
      expect(readPort.data.value.toInt(), 0xBBBB);

      readPort.en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });

    test('multiple read and fill ports', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final fillPort1 = ValidDataPortInterface(32, 8);
      final fillPort2 = ValidDataPortInterface(32, 8);
      final readPort1 = ValidDataPortInterface(32, 8);
      final readPort2 = ValidDataPortInterface(32, 8);

      final cache = DirectMappedCache(
          clk, reset, [fillPort1, fillPort2], [readPort1, readPort2]);

      await cache.build();
      unawaited(Simulator.run());

      // Reset
      reset.inject(1);
      fillPort1.en.inject(0);
      fillPort2.en.inject(0);
      readPort1.en.inject(0);
      readPort2.en.inject(0);

      await clk.nextPosedge;
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;

      // Fill different addresses on both ports (different cache lines)
      // 0x01 maps to line 1, 0x02 maps to line 2
      fillPort1.en.inject(1);
      fillPort1.addr.inject(0x01);
      fillPort1.data.inject(0x1111);
      fillPort1.valid.inject(1);

      fillPort2.en.inject(1);
      fillPort2.addr.inject(0x02);
      fillPort2.data.inject(0x2222);
      fillPort2.valid.inject(1);

      await clk.nextPosedge;
      fillPort1.en.inject(0);
      fillPort2.en.inject(0);
      await clk.nextPosedge;

      // Read from both ports simultaneously
      readPort1.en.inject(1);
      readPort1.addr.inject(0x01);

      readPort2.en.inject(1);
      readPort2.addr.inject(0x02);

      await clk.nextPosedge;
      expect(readPort1.valid.value.toBool(), true);
      expect(readPort1.data.value.toInt(), 0x1111);
      expect(readPort2.valid.value.toBool(), true);
      expect(readPort2.data.value.toInt(), 0x2222);

      readPort1.en.inject(0);
      readPort2.en.inject(0);
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });
  });
}
