// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serialization_test.dart
// Tests for serializer and deserializer components
//
// 2024 August 27
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//
import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  // This test pauses the serializer during processing at each count level
  // to ensure that it completes correctly (monitoring the count and done)
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

  test('serializer for larger structures', () async {
    const len = 10;
    const width = 8;
    final dataIn = LogicArray([len, 2], width);
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
      for (var j = 0; j < 2; j++) {
        dataIn.elements[i].elements[j].inject(i * 2 + j);
      }
    }
    await clk.nextPosedge;

    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    start.inject(1);
    final val = mod.serialized as LogicArray;
    var predictedClk = 0;
    while (mod.done.value.toInt() != 1) {
      expect(val.elements[0].value.toInt(), equals(predictedClk * 2));
      expect(val.elements[1].value.toInt(), equals(predictedClk * 2 + 1));
      await clk.nextPosedge;
      predictedClk = (clkCount + 1) % len;
      expect(mod.count.value.toInt(), equals(predictedClk));
      clkCount++;
    }
    expect(val.elements[0].value.toInt(), equals(predictedClk * 2));
    expect(val.elements[1].value.toInt(), equals(predictedClk * 2 + 1));
    await Simulator.endSimulation();
  });

  test('serializer to deserializer for larger structures', () async {
    const len = 10;
    const width = 8;
    final dataIn = LogicArray([len, 2], width);
    final clk = SimpleClockGenerator(10).clk;
    final start = Logic();
    final reset = Logic();
    final mod = Serializer(dataIn, clk: clk, reset: reset, enable: start);

    final mod2 = Deserializer(mod.serialized, len,
        clk: clk, reset: reset, enable: start);

    await mod.build();
    await mod2.build();
    unawaited(Simulator.run());

    start.inject(0);
    reset.inject(0);
    for (var i = 0; i < len; i++) {
      for (var j = 0; j < 2; j++) {
        dataIn.elements[i].elements[j].inject(i * 2 + j);
      }
    }
    await clk.nextPosedge;

    reset.inject(1);
    await clk.nextPosedge;
    reset.inject(0);
    await clk.nextPosedge;
    start.inject(1);
    while (mod2.done.value.toInt() != 1) {
      await clk.nextPosedge;
    }
    await clk.nextPosedge;

    final dataOut = mod2.deserialized;
    for (var i = 0; i < len; i++) {
      for (var j = 0; j < 2; j++) {
        expect(dataOut.elements[i].elements[j].value,
            equals(dataIn.elements[i].elements[j].value));
      }
    }
    await Simulator.endSimulation();
  });

  // This test does a careful check of the data transfer sequence to make sure
  // data transfer is in expected order by sequencing in first a set of 1s and
  // then a set of zeros and checking all transfers.
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
    var value = BigInt.from(15);
    final mask = ~(value << (width * len));
    expect(mod.count.value.toInt(), equals(clkCount));
    expect(mod.deserialized.value.toBigInt(), equals(value));
    var nxtValue = BigInt.zero;
    for (var i = 0; i < len * 2 - 2; i++) {
      if (i < len - 1) {
        dataIn.inject(15);
        nxtValue = (value << width) | value;
        if (i == len - 2) {
          clkCount = -1;
        }
      } else {
        dataIn.inject(0);
        nxtValue = (nxtValue << width) & mask;
      }
      await clk.nextPosedge;
      clkCount++;
      expect(mod.count.value.toInt(), equals(clkCount));
      expect(mod.deserialized.value.toBigInt(), equals(nxtValue));
      value = nxtValue;
    }

    await Simulator.endSimulation();
  });

  // This test uses enable to pause the deserialization once at each count level
  // to ensure it completes and fires done at the right time.
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
    var value = BigInt.from(15);
    final mask = ~(value << (width * len));
    enable.inject(1);
    var clkCount = 0;
    var nxtValue = value;
    while ((clkCount == 0) | (mod.done.value.toInt() == 0)) {
      await clk.nextPosedge;
      final predictedClk = (clkCount + 1) % len;
      expect(mod.count.value.toInt(), equals(predictedClk));
      expect(mod.deserialized.value.toBigInt(), equals(nxtValue));
      nxtValue = (value << width) | value;
      value = nxtValue;
      clkCount = clkCount + 1;
    }
    clkCount = 0;
    dataIn.inject(0);
    while ((clkCount == 0) | (mod.done.value.toInt() == 0)) {
      await clk.nextPosedge;
      final predictedClk = (clkCount + 1) % len;
      nxtValue = (nxtValue << width) & mask;

      expect(mod.count.value.toInt(), equals(predictedClk));
      clkCount = clkCount + 1;
      value = nxtValue;
    }
    enable.inject(0);
    for (var disablePos = 0; disablePos < len; disablePos++) {
      clkCount = 0;
      var activeClkCount = 0;
      dataIn.inject(0);
      while ((clkCount == 0) | (mod.done.value.toInt() == 0)) {
        if (clkCount == disablePos) {
          enable.inject(0);
        }
        expect(mod.count.value.toInt(), equals(activeClkCount));
        await clk.nextPosedge;
        if (clkCount != disablePos) {
          activeClkCount = (activeClkCount + 1) % len;
        }
        clkCount = clkCount + 1;
        enable.inject(1);
      }
    }
    await clk.nextPosedge;
    await clk.nextPosedge;
    await Simulator.endSimulation();
  });

  // This test ensures that the clock cycles and counts of the serializer
  // line up when doing back-to-back transfers.
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

  test('deserializer to serializer to deserializer', () async {
    const len = 6;
    const width = 4;
    final dataIn = Logic(width: width);
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final deserializer = Deserializer(dataIn, len, clk: clk, reset: reset);

    await deserializer.build();
    final firstDeserializerDone = deserializer.done |
        flop(clk, Const(1), reset: reset, en: deserializer.done);
    final serializer = Serializer(deserializer.deserialized,
        clk: clk, enable: firstDeserializerDone, reset: reset);

    await serializer.build();
    final serializerStart = firstDeserializerDone;
    final deserializer2 = Deserializer(serializer.serialized, len,
        clk: clk, reset: reset, enable: serializerStart);

    await deserializer2.build();
    unawaited(Simulator.run());

    reset.put(0);
    await clk.nextPosedge;
    reset.put(1);
    await clk.nextPosedge;
    await clk.nextPosedge;

    var clkCount = 0;
    await clk.nextPosedge;
    reset.put(0);
    while (deserializer.done.value != LogicValue.one) {
      expect(deserializer.count.value.toInt(), equals(clkCount));
      dataIn.put(clkCount++);
      await clk.nextPosedge;
    }
    dataIn.put(clkCount);
    for (var i = 0; i < len; i++) {
      expect(deserializer.deserialized.elements[i].value.toInt(), equals(i));
    }
    while (deserializer2.done.value != LogicValue.one) {
      if (serializerStart.value == LogicValue.one) {
        expect(serializer.count.value.toInt(),
            equals(serializer.serialized.value.toInt()));
      }
      await clk.nextPosedge;
      clkCount++;
    }
    for (var i = 0; i < len; i++) {
      expect(deserializer2.deserialized.elements[i].value.toInt(), equals(i));
    }
    await clk.nextPosedge;

    await clk.nextPosedge;
    await Simulator.endSimulation();
  });
}
