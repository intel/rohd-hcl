// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rf_test.dart
// Tests for register file
//
// 2023 March 13
// Author: Max Korbel <max.korbel@intel.com>
//

// ignore_for_file: avoid_types_on_closure_parameters

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/models/memory_model.dart';
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
      'memory model': (Logic clk, Logic reset, List<DataPortInterface> wrPorts,
              List<DataPortInterface> rdPorts) =>
          MemoryModel(
            clk,
            reset,
            wrPorts,
            rdPorts,
            storage: SparseMemoryStorage(
              addrWidth: addrWidth,
              dataWidth: dataWidth,
              alignAddress: (addr) => addr,
              onInvalidRead: (addr, dataWidth) =>
                  LogicValue.filled(dataWidth, LogicValue.zero),
            ),
          )
    };

    Future<void> waitCycles(Logic clk, int numCycles) async {
      for (var i = 0; i < numCycles; i++) {
        await clk.nextNegedge;
      }
    }

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
        reset.put(1);
        await clk.nextNegedge;
        await clk.nextNegedge;
        reset.put(0);
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
        await waitCycles(clk, mem.readLatency);
        await clk.nextPosedge;
        expect(rdPorts[2].data.value.toInt(), 0xdeadbeef);

        await clk.nextNegedge;
        rdPorts[2].en.put(0);
        await clk.nextNegedge;

        Simulator.endSimulation();
        await Simulator.simulationEnded;
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
        reset.put(1);
        await clk.nextNegedge;
        await clk.nextNegedge;
        reset.put(0);
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

        // read it back out on a different port
        rdPorts[0].en.put(1);
        rdPorts[0].addr.put(4);
        await waitCycles(clk, mem.readLatency);
        await clk.nextPosedge;
        expect(rdPorts[0].data.value.toInt(), 0xff00ff00);

        await clk.nextNegedge;
        rdPorts[0].en.put(0);
        await clk.nextNegedge;

        Simulator.endSimulation();
        await Simulator.simulationEnded;
      });
    }
  });

  test('non-byte-aligned data widths are legal without masks', () {
    DataPortInterface(1, 1);
  });

  group('rf exceptions', () {
    test('mismatch addr width', () {
      expect(
          () => RegisterFile(
                Logic(),
                Logic(),
                [DataPortInterface(32, 31)],
                [DataPortInterface(32, 32)],
              ),
          throwsA(const TypeMatcher<RohdHclException>()));
    });

    test('mismatch data width', () {
      expect(
          () => RegisterFile(
                Logic(),
                Logic(),
                [DataPortInterface(64, 32)],
                [DataPortInterface(32, 32)],
              ),
          throwsA(const TypeMatcher<RohdHclException>()));
    });
  });
}
