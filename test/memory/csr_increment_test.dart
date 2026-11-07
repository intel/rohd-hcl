// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// csr_increment_test.dart
// Tests top-level propagation of CSR logical register increments.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  for (final increment in [1, 4]) {
    for (final asyncReset in [false, true]) {
      test('top forwards increment $increment with asyncReset=$asyncReset',
          () async {
        const base = 0x20;
        final clk = SimpleClockGenerator(10).clk;
        final reset = Logic()..put(0);
        final read = DataPortInterface(16, 8)
          ..en.put(1)
          ..addr.put(base);
        final write = DataPortInterface(16, 8)
          ..en.put(0)
          ..addr.put(base)
          ..data.put(0);
        final config = CsrTopConfig(
          name: 'increment_test',
          blockSize: 16,
          asyncReset: asyncReset,
          blocks: [
            CsrBlockConfig(name: 'block', baseAddr: base, registers: [
              CsrInstanceConfig(
                arch: CsrConfig(
                    name: 'wide',
                    access: CsrAccess.readWrite,
                    fields: const [],
                    isBackdoorReadable: false,
                    isBackdoorWritable: false),
                addr: 0,
                width: 32,
                resetValue: 0x12345678,
              ),
            ]),
          ],
        );
        final top = CsrTop(
          config: config,
          clk: clk,
          reset: reset,
          frontRead: read,
          frontWrite: write,
          allowLargerRegisters: true,
          logicalRegisterIncrement: increment,
        );
        await top.build();
        Simulator.setMaxSimTime(1000);
        final simulation = Simulator.run();

        try {
          reset.inject(1);
          await clk.nextNegedge;
          reset.inject(0);
          await clk.nextNegedge;

          Future<void> settle() {
            final done = Completer<void>();
            Simulator.registerAction(Simulator.time + 1, done.complete);
            return done.future;
          }

          Future<void> checkRead(int address, int expected) async {
            read.addr.inject(address);
            await settle();
            expect(read.data.value, LogicValue.ofInt(expected, 16),
                reason: 'address $address, increment $increment');
          }

          Future<void> writeWord(int address, int value) async {
            await clk.nextNegedge;
            write.addr.inject(address);
            write.data.inject(value);
            write.en.inject(1);
            await clk.nextNegedge;
            write.en.inject(0);
            await settle();
          }

          await checkRead(base, 0x5678);
          await checkRead(base + increment, 0x1234);
          await writeWord(base, 0xbeef);
          await writeWord(base + increment, 0xcafe);
          await checkRead(base, 0xbeef);
          await checkRead(base + increment, 0xcafe);

          if (increment != 1) {
            await checkRead(base + 1, 0);
            await writeWord(base + 1, 0x7777);
            await checkRead(base + increment, 0xcafe);
          }

          await clk.nextNegedge;
          reset.inject(1);
          await settle();
          expect(read.data.value.toInt(), asyncReset ? 0x1234 : 0xcafe);
          await clk.nextNegedge;
          await checkRead(base, 0x5678);
          await checkRead(base + increment, 0x1234);
          reset.inject(0);
        } finally {
          await Simulator.endSimulation();
          await simulation;
        }
      });
    }
  }
}
