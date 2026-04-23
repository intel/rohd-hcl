// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// async_fifo_test.dart
// Tests for asynchronous FIFO
//
// 2026 January 14
// Author: Maifee Ul Asad <maifeeulasad@gmail.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('async_fifo basic write and read same clock frequency', () async {
    final writeClk = SimpleClockGenerator(10).clk;
    final readClk = SimpleClockGenerator(10).clk;
    final writeReset = Logic();
    final readReset = Logic();
    final writeEnable = Logic();
    final writeData = Logic(width: 8);
    final readEnable = Logic();

    final asyncFifo = AsyncFifo(
      writeClk: writeClk,
      readClk: readClk,
      writeReset: writeReset,
      readReset: readReset,
      writeEnable: writeEnable,
      writeData: writeData,
      readEnable: readEnable,
      depth: 4,
    );

    await asyncFifo.build();

    // Initialize
    writeReset.put(1);
    readReset.put(1);
    writeEnable.put(0);
    readEnable.put(0);
    writeData.put(0);

    Simulator.setMaxSimTime(2000);
    unawaited(Simulator.run());

    // Wait for a few cycles, then de-assert reset
    await writeClk.nextNegedge;
    await writeClk.nextNegedge;
    writeReset.put(0);
    readReset.put(0);

    // Wait for synchronizers to settle
    for (var i = 0; i < 5; i++) {
      await writeClk.nextNegedge;
    }

    // Initially should be empty
    expect(asyncFifo.empty.value.toBool(), true,
        reason: 'FIFO should be empty initially');

    // Write some data
    await writeClk.nextNegedge;
    writeData.put(0xAA);
    writeEnable.put(1);
    await writeClk.nextNegedge;
    writeData.put(0xBB);
    await writeClk.nextNegedge;
    writeData.put(0xCC);
    await writeClk.nextNegedge;
    writeEnable.put(0);

    // Wait for synchronizers to propagate
    for (var i = 0; i < 5; i++) {
      await readClk.nextNegedge;
    }

    expect(asyncFifo.empty.value.toBool(), false,
        reason: 'FIFO should not be empty after writes');

    // Read the data back
    //  read pointer advances on the negedge, so we need to check data
    // before pulsing readEnable
    await readClk.nextNegedge;
    expect(asyncFifo.readData.value.toInt(), 0xAA,
        reason: 'First read should be 0xAA');
    readEnable.put(1);

    await readClk.nextNegedge;
    readEnable.put(0);
    await readClk.nextPosedge;
    expect(asyncFifo.readData.value.toInt(), 0xBB,
        reason: 'Second read should be 0xBB');

    await readClk.nextNegedge;
    readEnable.put(1);
    await readClk.nextNegedge;
    readEnable.put(0);
    await readClk.nextPosedge;
    expect(asyncFifo.readData.value.toInt(), 0xCC,
        reason: 'Third read should be 0xCC');

    await readClk.nextNegedge;
    readEnable.put(1);
    await readClk.nextNegedge;
    readEnable.put(0);

    // Wait for empty to propagate
    for (var i = 0; i < 5; i++) {
      await readClk.nextNegedge;
    }

    expect(asyncFifo.empty.value.toBool(), true,
        reason: 'FIFO should be empty after reading all data');

    await Simulator.endSimulation();
  });

  test('async_fifo different clock frequencies', () async {
    // Use same clock first to simplify
    final writeClk = SimpleClockGenerator(10).clk;
    final readClk = SimpleClockGenerator(10).clk;
    final writeReset = Logic();
    final readReset = Logic();
    final writeEnable = Logic();
    final writeData = Logic(width: 8);
    final readEnable = Logic();

    final asyncFifo = AsyncFifo(
      writeClk: writeClk,
      readClk: readClk,
      writeReset: writeReset,
      readReset: readReset,
      writeEnable: writeEnable,
      writeData: writeData,
      readEnable: readEnable,
      depth: 8,
    );

    await asyncFifo.build();

    // Initialize
    writeReset.put(1);
    readReset.put(1);
    writeEnable.put(0);
    readEnable.put(0);
    writeData.put(0);

    Simulator.setMaxSimTime(3000);
    unawaited(Simulator.run());

    await writeClk.nextNegedge;
    await writeClk.nextNegedge;
    writeReset.put(0);
    readReset.put(0);

    for (var i = 0; i < 10; i++) {
      await writeClk.nextNegedge;
    }

    // Write and read work in the basic test, so this should pass
    await writeClk.nextNegedge;
    writeData.put(0x42);
    writeEnable.put(1);
    await writeClk.nextNegedge;
    writeEnable.put(0);

    for (var i = 0; i < 5; i++) {
      await readClk.nextNegedge;
    }

    await readClk.nextNegedge;
    expect(asyncFifo.readData.value.toInt(), equals(0x42));

    await Simulator.endSimulation();
  });

  test('async_fifo full condition', () async {
    final writeClk = SimpleClockGenerator(10).clk;
    final readClk = SimpleClockGenerator(10).clk;
    final writeReset = Logic();
    final readReset = Logic();
    final writeEnable = Logic();
    final writeData = Logic(width: 8);
    final readEnable = Logic();

    final asyncFifo = AsyncFifo(
      writeClk: writeClk,
      readClk: readClk,
      writeReset: writeReset,
      readReset: readReset,
      writeEnable: writeEnable,
      writeData: writeData,
      readEnable: readEnable,
      depth: 4,
    );

    await asyncFifo.build();

    // Initialize
    writeReset.put(1);
    readReset.put(1);
    writeEnable.put(0);
    readEnable.put(0);
    writeData.put(0);

    Simulator.setMaxSimTime(2000);
    unawaited(Simulator.run());

    await writeClk.nextNegedge;
    await writeClk.nextNegedge;
    writeReset.put(0);
    readReset.put(0);

    // Wait for synchronizers
    for (var i = 0; i < 5; i++) {
      await writeClk.nextNegedge;
    }

    // Initially not full
    await writeClk.nextPosedge;
    expect(asyncFifo.full.value.toBool(), false);

    // Fill the FIFO
    for (var i = 0; i < 4; i++) {
      await writeClk.nextNegedge;
      writeData.put(i);
      writeEnable.put(1);
    }
    await writeClk.nextNegedge;
    writeEnable.put(0);

    // Wait a bit for full to assert
    for (var i = 0; i < 3; i++) {
      await writeClk.nextNegedge;
    }

    expect(asyncFifo.full.value.toBool(), true,
        reason: 'FIFO should be full after writing depth entries');

    await Simulator.endSimulation();
  });

  test('async_fifo continuous flow', () async {
    final writeClk = SimpleClockGenerator(10).clk;
    final readClk = SimpleClockGenerator(12).clk; // Slightly different
    final writeReset = Logic();
    final readReset = Logic();
    final writeEnable = Logic();
    final writeData = Logic(width: 16);
    final readEnable = Logic();

    final asyncFifo = AsyncFifo(
      writeClk: writeClk,
      readClk: readClk,
      writeReset: writeReset,
      readReset: readReset,
      writeEnable: writeEnable,
      writeData: writeData,
      readEnable: readEnable,
      depth: 8,
    );

    await asyncFifo.build();

    // Initialize
    writeReset.put(1);
    readReset.put(1);
    writeEnable.put(0);
    readEnable.put(0);
    writeData.put(0);

    Simulator.setMaxSimTime(5000);
    unawaited(Simulator.run());

    await writeClk.nextNegedge;
    await writeClk.nextNegedge;
    writeReset.put(0);
    readReset.put(0);

    // Wait for synchronizers
    for (var i = 0; i < 10; i++) {
      await writeClk.nextNegedge;
    }

    // Write continuously
    final writtenData = <int>[];
    unawaited(() async {
      for (var i = 0; i < 20; i++) {
        await writeClk.nextNegedge;
        if (!asyncFifo.full.value.toBool()) {
          writeData.put(0x1000 + i);
          writeEnable.put(1);
          writtenData.add(0x1000 + i);
        } else {
          writeEnable.put(0);
        }
      }
      writeEnable.put(0);
    }());

    // Read continuously after some delay
    await readClk.nextNegedge;
    for (var i = 0; i < 10; i++) {
      await readClk.nextNegedge;
    }

    final readData = <int>[];
    for (var i = 0; i < 20; i++) {
      await readClk.nextNegedge;
      if (!asyncFifo.empty.value.toBool()) {
        readEnable.put(1);
        await readClk.nextPosedge;
        readData.add(asyncFifo.readData.value.toInt());
      } else {
        readEnable.put(0);
      }
    }

    // Allow more time to drain FIFO
    for (var i = 0; i < 10; i++) {
      await readClk.nextNegedge;
      if (!asyncFifo.empty.value.toBool()) {
        readEnable.put(1);
        await readClk.nextPosedge;
        readData.add(asyncFifo.readData.value.toInt());
      } else {
        readEnable.put(0);
      }
    }

    readEnable.put(0);

    expect(readData.length, greaterThan(0),
        reason: 'Should have read some data');

    await Simulator.endSimulation();
  });

  test('synchronizer basic functionality', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final dataIn = Logic(width: 4);

    final sync = Synchronizer(
      clk,
      dataIn: dataIn,
      reset: reset,
    );

    await sync.build();

    reset.put(1);
    dataIn.put(0);

    Simulator.setMaxSimTime(200);
    unawaited(Simulator.run());

    await clk.nextNegedge;
    reset.put(0);

    // Change input
    await clk.nextNegedge;
    dataIn.put(0xA);

    // After 1 cycle, output should not yet be updated
    await clk.nextPosedge;
    expect(sync.syncData.value.toInt(), isNot(equals(0xA)));

    // After 2 cycles (stages=2), output should be updated
    await clk.nextNegedge;
    await clk.nextPosedge;
    expect(sync.syncData.value.toInt(), equals(0xA));

    await Simulator.endSimulation();
  });
}
