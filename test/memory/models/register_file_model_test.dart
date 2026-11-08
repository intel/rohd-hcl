// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// register_file_model_test.dart
// Tests for the register-file behavioral memory configuration.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  test('register-file testbench hooks reject wide out-of-range addresses', () {
    final rf = RegisterFile<Logic>(
        Logic(), Logic(), [], [DataPortInterface<Logic>(8, 80)],
        numEntries: 2);
    final low = LogicValue.ofBigInt(BigInt.one, 80);
    final high = LogicValue.ofBigInt((BigInt.one << 75) + BigInt.one, 80);
    rf.setData(low, LogicValue.ofInt(9, 8));
    expect(rf.getData(low), LogicValue.ofInt(9, 8));
    expect(() => rf.getData(high), throwsRangeError);
    expect(() => rf.setData(high, LogicValue.ofInt(3, 8)), throwsRangeError);
    expect(rf.getData(low), LogicValue.ofInt(9, 8));
  });

  test('register-file configuration validates geometry and reset values', () {
    final resetValues = [
      LogicValue.ofInt(1, 8),
      LogicValue.ofInt(2, 8),
    ];
    final config =
        RegisterFileModelConfiguration(numEntries: 2, resetValues: resetValues);
    resetValues[0] = LogicValue.ofInt(3, 8);
    expect(config.resetValues.first, LogicValue.ofInt(1, 8));
    expect(
        () => RegisterFileModelConfiguration(
            numEntries: 3, resetValues: resetValues),
        throwsArgumentError);
    expect(
        () => MemoryModel<Logic>(
              Logic(),
              Logic(),
              [],
              [DataPortInterface<Logic>(8, 2)],
              registerFile: config,
            ),
        throwsArgumentError);
    expect(
        () => MemoryModel<Logic>.registerFile(
              Logic(),
              Logic(),
              [],
              [DataPortInterface<Logic>(16, 2)],
              numEntries: 2,
              resetValues: resetValues,
            ),
        throwsArgumentError);
    expect(
        () => MemoryModel<Logic>.registerFile(
              Logic(),
              Logic(),
              [],
              [MaskedDataPortInterface<Logic>(8, 2)],
            ),
        throwsArgumentError);
  });

  test('four-state transactions and snapshots match RegisterFile', () async {
    final clk = Logic()..put(0);
    final reset = Logic()..put(0);
    final writes = List.generate(
        2,
        (_) => MaskedDataPortInterface<Logic>(16, 2)
          ..en.put(0)
          ..addr.put(0)
          ..data.put(0)
          ..mask.put(0));
    final softwareRead = DataPortInterface<Logic>(16, 2)
      ..en.put(0)
      ..addr.put(0);
    final rtlRead = DataPortInterface<Logic>(16, 2);
    rtlRead.en <= softwareRead.en;
    rtlRead.addr <= softwareRead.addr;
    final resetValues = [
      LogicValue.ofString('0001001000110100'),
      LogicValue.ofString('1010zzzz0000xxxx'),
      LogicValue.ofInt(0xabcd, 16),
    ];
    final model = MemoryModel<Logic>.registerFile(
        clk, reset, writes, [softwareRead],
        numEntries: 3, resetValues: resetValues);
    final rtl = RegisterFile<Logic>(clk, reset, writes, [rtlRead],
        numEntries: 3, resetValue: resetValues);
    await model.build();
    await rtl.build();

    Simulator.registerAction(1, () {
      expect(softwareRead.data.value, rtlRead.data.value,
          reason: 'Disabled read must match before the first clock');
    });
    final scenarios = [
      (
        reset: true,
        enables: ['0', '0'],
        addresses: ['00', '00'],
        masks: ['00', '00'],
        data: ['0000000000000000', '0000000000000000'],
        readEnable: '1',
        readAddress: '01',
      ),
      (
        reset: false,
        enables: ['1', '1'],
        addresses: ['00', '00'],
        masks: ['10', '01'],
        data: ['0101011000000000', '0000000011101111'],
        readEnable: '1',
        readAddress: '00',
      ),
      (
        reset: false,
        enables: ['x', '1'],
        addresses: ['0x', '01'],
        masks: ['01', '00'],
        data: ['1111111111111111', '0000000000000000'],
        readEnable: '1',
        readAddress: '01',
      ),
      (
        reset: false,
        enables: ['1', '0'],
        addresses: ['z0', '00'],
        masks: ['x1', '00'],
        data: ['11111111zzzzzzzz', '0000000000000000'],
        readEnable: 'x',
        readAddress: '00',
      ),
      (
        reset: false,
        enables: ['0', '0'],
        addresses: ['00', '00'],
        masks: ['00', '00'],
        data: ['0000000000000000', '0000000000000000'],
        readEnable: '0',
        readAddress: 'xx',
      ),
      (
        reset: false,
        enables: ['0', '0'],
        addresses: ['00', '00'],
        masks: ['00', '00'],
        data: ['0000000000000000', '0000000000000000'],
        readEnable: '1',
        readAddress: '11',
      ),
    ];
    final random = Random(1977);
    final enables = ['0', '1', 'x', 'z'];
    final addresses = ['00', '01', '10', '11', '0x', 'z0'];
    final masks = ['00', '01', '10', '11', 'x1', '1z'];
    final values = ['0001001000110100', '1010101010101010', '1010zzzz0000xxxx'];
    for (var cycle = 0; cycle < 100; cycle++) {
      scenarios.add((
        reset: false,
        enables:
            List.generate(2, (_) => enables[random.nextInt(enables.length)]),
        addresses: List.generate(
            2, (_) => addresses[random.nextInt(addresses.length)]),
        masks: List.generate(2, (_) => masks[random.nextInt(masks.length)]),
        data: List.generate(2, (_) => values[random.nextInt(values.length)]),
        readEnable: enables[random.nextInt(enables.length)],
        readAddress: addresses[random.nextInt(addresses.length)],
      ));
    }
    late MemoryModelImage saved;
    for (final (cycle, input) in scenarios.indexed) {
      final time = 2 + cycle * 5;
      Simulator.registerAction(time, () {
        reset.put(input.reset ? 1 : 0);
        for (var port = 0; port < 2; port++) {
          writes[port]
            ..en.put(LogicValue.ofString(input.enables[port]))
            ..addr.put(LogicValue.ofString(input.addresses[port]))
            ..mask.put(LogicValue.ofString(input.masks[port]))
            ..data.put(LogicValue.ofString(input.data[port]));
        }
        softwareRead
          ..en.put(LogicValue.ofString(input.readEnable))
          ..addr.put(LogicValue.ofString(input.readAddress));
      });
      Simulator.registerAction(time + 1, () => clk.put(1));
      Simulator.registerAction(time + 2, () {
        expect(softwareRead.data.value, rtlRead.data.value,
            reason: 'Read mismatch at cycle $cycle');
        for (var address = 0; address < 3; address++) {
          final index = LogicValue.ofInt(address, 2);
          expect(model.storage.getData(index), rtl.getData(index),
              reason: 'Word $address differs at cycle $cycle');
        }
        if (cycle == 1) {
          saved = model.snapshot();
        }
        clk.put(0);
      });
    }
    await Simulator.run();
    model.restore(saved);
    expect(model.storage.getData(LogicValue.ofInt(0, 2)),
        LogicValue.ofInt(0x12ef, 16));
    final incompatible = MemoryModel<Logic>.registerFile(
        Logic(),
        Logic(),
        List.generate(2, (_) => MaskedDataPortInterface<Logic>(16, 2)),
        [DataPortInterface<Logic>(16, 2)],
        numEntries: 2);
    expect(() => incompatible.restore(saved), throwsArgumentError);
    final otherReset = MemoryModel<Logic>.registerFile(
      Logic(),
      Logic(),
      List.generate(2, (_) => MaskedDataPortInterface<Logic>(16, 2)),
      [DataPortInterface<Logic>(16, 2)],
      numEntries: 3,
    );
    expect(() => otherReset.restore(saved), throwsArgumentError);
  });
}
