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
import 'package:rohd_hcl/rohd_hcl.dart';
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

  test('Cache smoke test', () async {
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

  group('Cache small tests', () {
    const dataWidth = 4;
    const addrWidth = 7;
    const ways = 4;
    final lines = BigInt.two.pow(addrWidth).toInt() ~/ ways;
    final lineAddrWith = log2Ceil(lines);
    final tagWidth = addrWidth - lineAddrWith;

    test('Cache singleton 2 writes then reads test', () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();

      final wrPort = ValidDataPortInterface(dataWidth, addrWidth);
      final rdPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache = MultiPortedCache(clk, reset, [wrPort], [rdPort],
          ways: ways, lines: lines);

      await cache.build();
      unawaited(Simulator.run());

      await clk.nextPosedge;
      await clk.nextPosedge;
      rdPort.en.inject(0);
      rdPort.addr.inject(0);
      wrPort.en.inject(0);
      wrPort.addr.inject(0);
      wrPort.data.inject(0);
      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;
      // write data to address addr
      const first = 0x20;
      wrPort.en.inject(1);
      wrPort.addr.inject(first);
      wrPort.data.inject(9);
      await clk.nextPosedge;
      wrPort.en.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;
      await clk.nextPosedge;
      const second = 0x40;
      wrPort.addr.inject(second);
      wrPort.data.inject(7);
      wrPort.en.inject(1);
      await clk.nextPosedge;
      wrPort.en.inject(0);
      await clk.nextPosedge;
      // read it back
      rdPort.en.inject(1);
      rdPort.addr.inject(first);
      await clk.nextPosedge;
      rdPort.en.inject(0);

      expect(rdPort.data.value.toInt(), 9);
      expect(rdPort.valid.value, LogicValue.one);
      rdPort.addr.inject(second);
      await clk.nextPosedge;
      rdPort.en.inject(1);

      await clk.nextPosedge;
      expect(rdPort.data.value.toInt(), 7);
      expect(rdPort.valid.value, LogicValue.one);
      rdPort.en.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });

    test('Cache writes then reads test', () async {
      final clk = SimpleClockGenerator(10).clk;

      final reset = Logic();
      final wrPort = ValidDataPortInterface(dataWidth, addrWidth);
      final rdPort = ValidDataPortInterface(dataWidth, addrWidth);

      final cache = MultiPortedCache(clk, reset, [wrPort], [rdPort],
          ways: ways, lines: lines);
      await cache.build();

      // #writes>#ways to the same line can result in eviction. So a test is to
      // write #ways writes to each line to fill it. Then perform reads to
      // verify all are there. This verifies we are not evicting anything less
      // than #ways old.

      // Generate a set of address/data pairs to write and read back.
      final testData = <(LogicValue, LogicValue)>[];
      var data = 0;
      for (var line = 0; line < lines; line++) {
        final lv = LogicValue.ofInt(line, lineAddrWith);
        for (var way = 0; way < ways; way++) {
          final tag = LogicValue.ofInt(way + 1, tagWidth);
          final addr = [tag, lv].swizzle();
          testData.add((addr, LogicValue.ofInt(data, dataWidth)));
          data++;
        }
      }
      unawaited(Simulator.run());
      // reset flow
      wrPort.en.inject(0);
      rdPort.en.inject(0);
      wrPort.addr.inject(0);
      wrPort.data.inject(0);
      rdPort.addr.inject(0);
      reset.inject(1);
      await clk.nextPosedge;
      reset.inject(0);
      // end reset flow

      await clk.nextPosedge;
      // Fill each line of the cache.
      wrPort.en.inject(1);
      for (var i = 0; i < testData.length; i++) {
        final (addr, data) = testData[i];
        wrPort.addr.inject(addr);
        wrPort.data.inject(data);
        await clk.nextPosedge;
      }
      wrPort.en.inject(0);
      await clk.nextPosedge;
      // Read them all back.
      await clk.nextPosedge;
      rdPort.en.inject(1);
      for (var i = 0; i < testData.length; i++) {
        final (addr, data) = testData[i];
        rdPort.addr.inject(addr);
        await clk.nextPosedge;
        expect(rdPort.valid.value, LogicValue.one,
            reason: 'read valid for addr $addr');
        expect(rdPort.data.value, data,
            reason: 'should read $data for addr $addr');
      }
      rdPort.en.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;

      await Simulator.endSimulation();
    });
  });
}
