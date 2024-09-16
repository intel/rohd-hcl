// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// aggregator.dart
// A flexible aggregator implementation.
//
// 2024 August 27
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//
// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  test('serializer', () async {
    const len = 10;
    const width = 8;
    final dataIn = LogicArray([len], width);
    final clk = SimpleClockGenerator(10).clk;
    final start = Logic();
    final reset = Logic();
    final mod = Serializer(dataIn, clk: clk, reset: reset, enable: start);

    await mod.build();

    unawaited(Simulator.run());
    start.inject(0);
    reset.inject(0);
    var clkCount = 0;
    for (var i = 0; i < len; i++) {
      dataIn.elements[i].inject(i);
    }
    await clk.nextPosedge;

    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    start.inject(1);
    var predictedClk = 0;
    while (mod.done.value.toInt() != 1) {
      await clk.nextPosedge;
      predictedClk = (clkCount + 1) % len;
      expect(mod.count.value.toInt(), equals(predictedClk));
      expect(mod.serialized.value.toInt(), equals(predictedClk));
      clkCount++;
    }
    clkCount = 0;
    predictedClk = 0;
    while ((clkCount == 0) | (mod.done.value.toInt() != 1)) {
      await clk.nextPosedge;
      expect(mod.count.value.toInt(), equals(predictedClk));
      expect(mod.serialized.value.toInt(), equals(predictedClk));
      predictedClk = (clkCount + 1) % len;
      clkCount++;
    }
    await clk.nextPosedge;

    var counting = true;
    start.inject(0);
    for (var disablePos = 0; disablePos < len; disablePos++) {
      clkCount = 0;
      predictedClk = 0;
      var activeClkCount = 0;
      while (mod.done.value.toInt() == 0) {
        if (clkCount == disablePos) {
          counting = false;
          start.inject(0);
        } else {
          start.inject(1);
        }
        await clk.nextPosedge;
        predictedClk = (counting ? activeClkCount + 1 : activeClkCount) % len;
        activeClkCount = counting ? activeClkCount + 1 : activeClkCount;
        expect(mod.count.value.toInt(), equals(predictedClk));
        expect(mod.serialized.value.toInt(), equals(predictedClk));
        clkCount = clkCount + 1;
        start.inject(1);
        counting = true;
      }
      await clk.nextPosedge;
    }
    await Simulator.endSimulation();
  });

  test('deserializer rollover', () async {
    const len = 6;
    const width = 4;
    final dataIn = Logic(width: width);
    final clk = SimpleClockGenerator(10).clk;
    final enable = Logic();
    final reset = Logic();
    final mod =
        Deserializer(dataIn, len, clk: clk, reset: reset, enable: enable);

    await mod.build();
    unawaited(Simulator.run());

    enable.inject(0);
    reset.inject(0);
    await clk.nextPosedge;
    reset.inject(1);

    var clkCount = 0;
    await clk.nextPosedge;
    reset.inject(0);
    dataIn.inject(255);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    enable.inject(1);
    await clk.nextPosedge;
    clkCount++;
    var value = BigInt.from(15) << ((len - 1) * width);
    expect(mod.count.value.toInt(), equals(clkCount));
    expect(mod.deserialized.value.toBigInt(), equals(value));
    for (var i = 0; i < len * 2 - 2; i++) {
      BigInt nxtValue;
      if (i < len - 1) {
        dataIn.inject(15);
        nxtValue = (value >> width) | value;
        if (i == len - 2) {
          clkCount = -1;
        }
      } else {
        dataIn.inject(0);
        nxtValue = value >> width;
      }
      await clk.nextPosedge;
      clkCount++;
      expect(mod.count.value.toInt(), equals(clkCount));
      expect(mod.deserialized.value.toBigInt(), equals(nxtValue));
      value = nxtValue;
    }

    await Simulator.endSimulation();
  });

  test('deserializer enable', () async {
    const len = 6;
    const width = 4;
    final dataIn = Logic(width: width);
    final clk = SimpleClockGenerator(10).clk;
    final enable = Logic();
    final reset = Logic();
    final mod =
        Deserializer(dataIn, len, clk: clk, reset: reset, enable: enable);
    await mod.build();
    unawaited(Simulator.run());

    enable.inject(0);
    reset.inject(0);
    await clk.nextPosedge;
    reset.inject(1);

    await clk.nextPosedge;
    reset.inject(0);
    dataIn.inject(15);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    var value = BigInt.from(15) << ((len - 1) * width);
    enable.inject(1);
    var clkCount = 0;
    var nxtValue = value;
    while ((clkCount == 0) | (mod.done.value.toInt() == 0)) {
      await clk.nextPosedge;
      final predictedClk = (clkCount + 1) % len;
      expect(mod.count.value.toInt(), equals(predictedClk));
      expect(mod.deserialized.value.toBigInt(), equals(nxtValue));
      nxtValue = (value >> width) | value;
      value = nxtValue;
      clkCount = clkCount + 1;
    }
    clkCount = 0;
    dataIn.inject(0);
    while ((clkCount == 0) | (mod.done.value.toInt() == 0)) {
      await clk.nextPosedge;
      final predictedClk = (clkCount + 1) % len;
      nxtValue = value >> width;
      expect(mod.count.value.toInt(), equals(predictedClk));
      expect(mod.deserialized.value.toBigInt(), equals(nxtValue));

      clkCount = clkCount + 1;
      value = nxtValue;
    }
    var counting = true;
    nxtValue = BigInt.from(0);
    for (var disablePos = 0; disablePos < len; disablePos++) {
      clkCount = 0;
      var activeClkCount = 0;
      dataIn.inject(15);
      while ((clkCount == 0) | (mod.done.value.toInt() == 0)) {
        if (clkCount == disablePos) {
          counting = false;
          enable.inject(0);
        }
        await clk.nextPosedge;
        final predictedClk =
            counting ? (activeClkCount + 1) % len : activeClkCount;
        if ((predictedClk == 1) & counting) {
          nxtValue = BigInt.from(15) << ((len - 1) * width);
        } else if (counting) {
          nxtValue = (value >> width) | value;
        }
        expect(mod.count.value.toInt(), equals(predictedClk));
        expect(mod.deserialized.value.toBigInt(), equals(nxtValue));
        value = nxtValue;
        clkCount = clkCount + 1;
        activeClkCount = counting ? activeClkCount + 1 : activeClkCount;
        enable.inject(1);
        counting = true;
      }
      clkCount = 0;
      activeClkCount = 0;
      nxtValue = value;
      dataIn.inject(0);
      while ((clkCount == 0) | (mod.done.value.toInt() == 0)) {
        if (clkCount == disablePos) {
          counting = false;
          enable.inject(0);
        }
        if (counting) {
          nxtValue = value >> width;
        }

        final predictedClk =
            counting ? (activeClkCount + 1) % len : activeClkCount;
        await clk.nextPosedge;
        expect(mod.count.value.toInt(), equals(predictedClk));
        expect(mod.deserialized.value.toBigInt(), equals(nxtValue));
        clkCount = clkCount + 1;
        activeClkCount = counting ? activeClkCount + 1 : activeClkCount;
        enable.inject(1);
        value = nxtValue;
        counting = true;
      }
    }
    await Simulator.endSimulation();
  });

  test('serializer timing', () async {
    const len = 10;
    const width = 8;
    final dataIn = LogicArray([len], width);
    final clk = SimpleClockGenerator(10).clk;
    final start = Logic();
    final reset = Logic();
    unawaited(Simulator.run());
    for (final testFlopped in [false, true]) {
      final mod = Serializer(dataIn,
          clk: clk, reset: reset, enable: start, flopInput: testFlopped);

      await mod.build();

      start.put(0);
      reset.put(0);
      var clkCount = testFlopped ? 0 : 0;
      for (var i = 0; i < len; i++) {
        dataIn.elements[i].put(i);
      }
      await clk.nextPosedge;

      reset.put(1);
      await clk.nextPosedge;
      reset.inject(0);
      await clk.nextPosedge;
      await clk.nextPosedge;
      await clk.nextPosedge;
      start.put(1);
      var predictedClk = 0;
      if (testFlopped) {
        await clk.nextPosedge;
      }
      while (mod.done.value.toInt() != 1) {
        expect(mod.count.value.toInt(), equals(predictedClk));
        expect(mod.serialized.value.toInt(), equals(predictedClk));
        await clk.nextPosedge;
        predictedClk = (clkCount + 1) % len;
        clkCount++;
      }
      expect(mod.count.value.toInt(), equals(predictedClk));
      expect(mod.serialized.value.toInt(), equals(predictedClk));
      clkCount = 0;
      predictedClk = 0;
      await clk.nextPosedge;

      while ((clkCount == 0) | (mod.done.value.toInt() != 1)) {
        expect(mod.count.value.toInt(), equals(predictedClk));
        expect(mod.serialized.value.toInt(), equals(predictedClk));
        predictedClk = (clkCount + 1) % len;
        await clk.nextPosedge;
        clkCount++;
      }
      expect(mod.count.value.toInt(), equals(predictedClk));
      expect(mod.serialized.value.toInt(), equals(predictedClk));
    }

    await clk.nextPosedge;
    await clk.nextPosedge;
    await Simulator.endSimulation();
  });
}
