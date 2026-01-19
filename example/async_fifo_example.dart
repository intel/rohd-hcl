// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// async_fifo_example.dart
// Example of how to use an asynchronous FIFO for clock domain crossing.
//
// 2026 January 13
// Author: Maifee Ul Asad <maifeeulasad@gmail.com>

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A simple producer module that writes data into an async FIFO.
class Producer extends Module {
  Logic get writeEnable => output('writeEnable');
  Logic get writeData => output('writeData');

  Producer({
    required Logic clk,
    required Logic reset,
    required Logic full,
    required int dataWidth,
    super.name = 'producer',
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    full = addInput('full', full);

    addOutput('writeEnable');
    addOutput('writeData', width: dataWidth);

    final counter = Logic(name: 'counter', width: dataWidth);

    Sequential(
      clk,
      reset: reset,
      [
        // Increment counter when we can write
        If(~full, then: [
          counter < counter + 1,
        ]),
      ],
    );

    // Write enable when not full
    writeEnable <= ~full;
    writeData <= counter;
  }
}

/// A simple consumer module that reads data from an async FIFO.
class Consumer extends Module {
  Logic get readEnable => output('readEnable');

  Consumer({
    required Logic clk,
    required Logic reset,
    required Logic empty,
    required Logic readData,
    super.name = 'consumer',
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    empty = addInput('empty', empty);
    readData = addInput('readData', readData, width: readData.width);

    addOutput('readEnable');

    final validData = Logic(name: 'validData', width: readData.width);

    Sequential(
      clk,
      reset: reset,
      [
        If(~empty, then: [
          validData < readData,
        ]),
      ],
    );

    // Read enable when not empty
    readEnable <= ~empty;
  }
}

Future<void> main({bool noPrint = false}) async {
  // Create two independent clock domains
  final writeClk = SimpleClockGenerator(10).clk; // 10 time unit period
  final readClk = SimpleClockGenerator(15).clk; // 15 time unit period (slower)

  final writeReset = Logic(name: 'writeReset');
  final readReset = Logic(name: 'readReset');

  // Create the async FIFO
  const dataWidth = 8;
  const fifoDepth = 16;

  final writeEnable = Logic(name: 'writeEnable');
  final writeData = Logic(name: 'writeData', width: dataWidth);
  final readEnable = Logic(name: 'readEnable');

  final asyncFifo = AsyncFifo(
    writeClk: writeClk,
    readClk: readClk,
    writeReset: writeReset,
    readReset: readReset,
    writeEnable: writeEnable,
    writeData: writeData,
    readEnable: readEnable,
    depth: fifoDepth,
    name: 'async_fifo_example',
  );

  // Create producer and consumer
  final producer = Producer(
    clk: writeClk,
    reset: writeReset,
    full: asyncFifo.full,
    dataWidth: dataWidth,
  );

  final consumer = Consumer(
    clk: readClk,
    reset: readReset,
    empty: asyncFifo.empty,
    readData: asyncFifo.readData,
  );

  // Connect producer to FIFO
  writeEnable <= producer.writeEnable;
  writeData <= producer.writeData;

  // Connect FIFO to consumer
  readEnable <= consumer.readEnable;

  // Build the design
  await asyncFifo.build();
  await producer.build();
  await consumer.build();

  // Set up waveform dumper
  if (!noPrint) {
    WaveDumper(asyncFifo, outputPath: 'async_fifo_example.vcd');
  }

  // Initialize
  writeReset.inject(1);
  readReset.inject(1);

  Simulator.setMaxSimTime(2000);
  unawaited(Simulator.run());

  // Hold reset for a few cycles
  await writeClk.nextNegedge;
  await writeClk.nextNegedge;

  writeReset.inject(0);
  readReset.inject(0);

  if (!noPrint) {
    print('\nSimulation started...');
    print('\nMonitoring FIFO status:');
    print('Time | Write | Read | Full | Empty');
    print('-' * 45);

    // Monitor FIFO activity
    var lastWriteData = -1;
    var lastReadData = -1;

    writeClk.posedge.listen((event) {
      if (writeEnable.value.toBool() && !asyncFifo.full.value.toBool()) {
        final wData = writeData.value.toInt();
        if (wData != lastWriteData) {
          print(
            '${Simulator.time.toString().padLeft(4)} | '
            'W:0x${wData.toRadixString(16).padLeft(2, '0')} |      | '
            '${asyncFifo.full.value.toBool() ? 'FULL' : '    '} | '
            '${asyncFifo.empty.value.toBool() ? 'EMPTY' : '     '}',
          );
          lastWriteData = wData;
        }
      }
    });

    readClk.posedge.listen((event) {
      if (readEnable.value.toBool() && !asyncFifo.empty.value.toBool()) {
        final rData = asyncFifo.readData.value.toInt();
        if (rData != lastReadData) {
          print(
            '${Simulator.time.toString().padLeft(4)} |      | '
            'R:0x${rData.toRadixString(16).padLeft(2, '0')} | '
            '${asyncFifo.full.value.toBool() ? 'FULL' : '    '} | '
            '${asyncFifo.empty.value.toBool() ? 'EMPTY' : '     '}',
          );
          lastReadData = rData;
        }
      }
    });
  }

  // Let simulation run
  await Simulator.simulationEnded;
}
