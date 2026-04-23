// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_test.dart
// Tests for memories
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('memory accesses', () {
    const numEntries = 20;
    const dataWidth = 32;
    const addrWidth = 5;

    final memoriesToTestGenerators = {
      'rf': (Logic clk, Logic reset, List<DataPortInterface> wrPorts,
              List<DataPortInterface> rdPorts) =>
          RegisterFile(clk, reset, wrPorts, rdPorts, numEntries: numEntries),
      for (var latency = 0; latency <= 2; latency++)
        'memory model (latency $latency)': (Logic clk,
                Logic reset,
                List<DataPortInterface> wrPorts,
                List<DataPortInterface> rdPorts) =>
            MemoryModel(
              clk,
              reset,
              wrPorts,
              rdPorts,
              readLatency: latency,
              storage: SparseMemoryStorage(
                addrWidth: addrWidth,
                dataWidth: dataWidth,
                alignAddress: (addr) => addr,
                onInvalidRead: (addr, dataWidth) =>
                    LogicValue.filled(dataWidth, LogicValue.zero),
              ),
            )
    };

    for (final memGen in memoriesToTestGenerators.entries) {
      final memGenName = memGen.key;
      final memGenFunc = memGen.value;

      test('$memGenName simple', () async {
        const numWr = 3;
        const numRd = 3;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final wrPorts = [
          for (var i = 0; i < numWr; i++)
            DataPortInterface(dataWidth, addrWidth)..en.put(0)
        ];
        final rdPorts = [
          for (var i = 0; i < numRd; i++)
            DataPortInterface(dataWidth, addrWidth)..en.put(0)
        ];

        final mem = memGenFunc(clk, reset, wrPorts, rdPorts);

        await mem.build();

        unawaited(Simulator.run());

        // a little reset flow
        await clk.nextNegedge;
        reset.inject(1);
        await clk.nextNegedge;
        await clk.nextNegedge;
        reset.inject(0);
        await clk.nextNegedge;
        await clk.nextNegedge;

        // write to addr 0x4 on port 0
        wrPorts[0].en.put(1);
        wrPorts[0].addr.put(3);
        wrPorts[0].data.put(0xdeadbeef);

        await clk.nextNegedge;
        wrPorts[0].en.put(0);
        await clk.nextNegedge;

        // read it back out on a different port
        rdPorts[2].en.put(1);
        rdPorts[2].addr.put(3);
        await clk.waitCycles(mem.readLatency);
        await clk.nextPosedge;
        expect(rdPorts[2].data.value.toInt(), 0xdeadbeef);

        await clk.nextNegedge;
        rdPorts[2].en.put(0);
        await clk.nextNegedge;

        await Simulator.endSimulation();
      });

      test('$memGenName wr masked', () async {
        const numWr = 1;
        const numRd = 1;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final wrPorts = [
          for (var i = 0; i < numWr; i++)
            MaskedDataPortInterface(dataWidth, addrWidth)..en.put(0)
        ];
        final rdPorts = [
          for (var i = 0; i < numRd; i++)
            DataPortInterface(dataWidth, addrWidth)..en.put(0)
        ];

        final mem = memGenFunc(clk, reset, wrPorts, rdPorts);

        await mem.build();

        unawaited(Simulator.run());

        // a little reset flow
        await clk.nextNegedge;
        reset.inject(1);
        await clk.nextNegedge;
        await clk.nextNegedge;
        reset.inject(0);
        await clk.nextNegedge;
        await clk.nextNegedge;

        // write to addr 0x4 on port 0
        wrPorts[0].en.put(1);
        wrPorts[0].mask.put(bin('1010'));
        wrPorts[0].addr.put(4);
        wrPorts[0].data.put(0xffffffff);

        await clk.nextNegedge;
        wrPorts[0].en.put(0);
        await clk.nextNegedge;

        // read it back out
        rdPorts[0].en.put(1);
        rdPorts[0].addr.put(4);
        await clk.waitCycles(mem.readLatency);
        await clk.nextPosedge;
        expect(rdPorts[0].data.value.toInt(), 0xff00ff00);

        await clk.nextNegedge;
        rdPorts[0].en.put(0);
        await clk.nextNegedge;

        await Simulator.endSimulation();
      });

      test('$memGenName driven by flops back to back', () async {
        const numWr = 1;
        const numRd = 1;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        var wrPorts = [
          for (var i = 0; i < numWr; i++)
            MaskedDataPortInterface(dataWidth, addrWidth)..en.put(0)
        ];
        var rdPorts = [
          for (var i = 0; i < numRd; i++)
            DataPortInterface(dataWidth, addrWidth)..en.put(0)
        ];

        final mem = memGenFunc(clk, reset, wrPorts, rdPorts);

        await mem.build();

        wrPorts = wrPorts.map((oldWrPort) {
          final newWrPort = MaskedDataPortInterface(dataWidth, addrWidth)
            ..en.put(0);
          oldWrPort.ports.forEach((key, value) {
            value <= flop(clk, reset: reset, newWrPort.port(key));
          });
          return newWrPort;
        }).toList();

        rdPorts = rdPorts.map((oldRdPort) {
          final newRdPort = DataPortInterface(dataWidth, addrWidth)..en.put(0);
          oldRdPort.getPorts([DataPortGroup.control]).forEach((key, value) {
            value <= flop(clk, reset: reset, newRdPort.port(key));
          });
          newRdPort.data <= oldRdPort.data;
          return newRdPort;
        }).toList();

        unawaited(Simulator.run());

        // a little reset flow
        await clk.nextPosedge;
        reset.inject(1);
        await clk.nextPosedge;
        await clk.nextPosedge;
        reset.inject(0);
        await clk.nextPosedge;
        await clk.nextPosedge;

        // write to addr 0x4 on port 0
        wrPorts[0].en.inject(1);
        wrPorts[0].mask.inject(bin('1010'));
        wrPorts[0].addr.inject(4);
        wrPorts[0].data.inject(0xffffffff);

        await clk.nextPosedge;

        // write to addr 0x5 on port 0
        wrPorts[0].en.inject(1);
        wrPorts[0].mask.inject(bin('0101'));
        wrPorts[0].addr.inject(5);
        wrPorts[0].data.inject(0x55555555);

        rdPorts[0].en.inject(1);
        rdPorts[0].addr.inject(4);
        unawaited(clk.waitCycles(mem.readLatency + 1).then((value) async {
          await clk.nextNegedge;
          expect(rdPorts[0].data.value.toInt(), 0xff00ff00);
        }));

        await clk.nextPosedge;

        wrPorts[0].en.inject(0);

        rdPorts[0].en.inject(1);
        rdPorts[0].addr.inject(5);
        unawaited(clk.waitCycles(mem.readLatency + 1).then((value) async {
          await clk.nextNegedge;
          expect(rdPorts[0].data.value.toInt(), 0x00550055);
        }));

        await clk.nextPosedge;

        rdPorts[0].en.inject(0);

        await clk.waitCycles(10);

        await Simulator.endSimulation();
      });

      test('$memGenName random and bursty streaming writes and reads',
          () async {
        const numWr = 3;
        const numRd = numWr;

        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic();

        final wrPorts = [
          for (var i = 0; i < numWr; i++)
            MaskedDataPortInterface(dataWidth, addrWidth)..en.put(0)
        ];
        final rdPorts = [
          for (var i = 0; i < numRd; i++)
            DataPortInterface(dataWidth, addrWidth)..en.put(0)
        ];

        final mem = memGenFunc(clk, reset, wrPorts, rdPorts);

        await mem.build();

        unawaited(Simulator.run());

        // a little reset flow
        await clk.nextPosedge;
        reset.inject(1);
        await clk.nextPosedge;
        await clk.nextPosedge;
        reset.inject(0);
        await clk.nextPosedge;
        await clk.nextPosedge;

        final rand = Random(123);

        for (var i = 0; i < 100; i++) {
          for (var p = 0; p < numWr; p++) {
            final rdPort = (p + 1) % numRd;
            final rdDelay = rdPort + 1;

            if (i % numWr == p) {
              wrPorts[p].en.inject(0);

              unawaited(clk.waitCycles(rdDelay).then((value) {
                rdPorts[rdPort].en.inject(0);
              }));
            } else {
              final addr = (i * numWr + p) % numEntries;
              final data = rand.nextLogicValue(width: dataWidth);
              final mask = rand.nextLogicValue(width: 4);

              wrPorts[p].en.inject(1);
              wrPorts[p].addr.inject(addr);
              wrPorts[p].data.inject(data);
              wrPorts[p].mask.inject(mask);

              unawaited(clk.waitCycles(rdDelay).then((value) async {
                rdPorts[rdPort].en.inject(1);
                rdPorts[rdPort].addr.inject(addr);

                await clk.waitCycles(mem.readLatency);

                await clk.nextNegedge;

                final rdData = rdPorts[rdPort].data.value;
                for (var m = 0; m < mask.width; m++) {
                  if (mask[m].toBool()) {
                    final actual = rdData.getRange(m * 8, (m + 1) * 8);
                    final expected = data.getRange(m * 8, (m + 1) * 8);
                    expect(
                      actual,
                      expected,
                      reason: '@${Simulator.time} byte $m on rd port $rdPort: '
                          'was $actual, expected $expected',
                    );
                  }
                }
              }));
            }
          }
          await clk.nextPosedge;
        }

        await clk.waitCycles(mem.readLatency + numWr + 1);

        await Simulator.endSimulation();
      });
    }
  });

  test('non-byte-aligned data widths are legal without masks', () {
    DataPortInterface(1, 1);
  });
}
