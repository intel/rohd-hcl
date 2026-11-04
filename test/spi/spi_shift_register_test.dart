// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_shift_register_test.dart
// Tests for SPI shift register logic.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/spi/endpoints/spi_shift_register.dart';
import 'package:test/test.dart';

import '../verilator_test_utils.dart';

class _ShiftHarness extends Module {
  _ShiftHarness(int width) {
    final shift = buildSpiShiftRegister(
      width: width,
      clock: addInput('clock', Logic()),
      serialIn: addInput('serialIn', Logic()),
      enable: addInput('enable', Logic()),
      reset: addInput('reset', Logic()),
      parallelIn: addInput('parallelIn', Logic(width: width), width: width),
    );
    addOutput('serialOut') <= shift.serialOut;
    addOutput('parallelOut', width: width) <= shift.parallelOut;
  }
}

class _PairHarness extends Module {
  _PairHarness() {
    final intf = SpiInterface(dataLength: 8);
    final main = SpiMain(intf,
        clk: addInput('clock', Logic()),
        reset: addInput('mainReset', Logic()),
        start: addInput('start', Logic()),
        busIn: addInput('mainIn', Logic(width: 8), width: 8));
    final sub = SpiSub(
        intf: intf,
        reset: addInput('subReset', Logic()),
        busIn: addInput('subIn', Logic(width: 8), width: 8));
    addOutput('mainOut', width: 8) <= main.busOut;
    addOutput('subOut', width: 8) <= sub.busOut;
    addOutput('mosi') <= intf.mosi;
    addOutput('miso') <= intf.miso;
    addOutput('sclk') <= intf.sclk;
    addOutput('csb') <= intf.csb;
  }
}

class _SubHarness extends Module {
  _SubHarness({required bool withReset, required bool withBusIn}) {
    final intf = SpiInterface(dataLength: 4);
    intf.sclk <= addInput('clock', Logic());
    intf.csb <= addInput('csb', Logic());
    intf.mosi <= addInput('mosi', Logic());
    final sub = SpiSub(
      intf: intf,
      reset: withReset ? addInput('reset', Logic()) : null,
      busIn:
          withBusIn ? addInput('parallelIn', Logic(width: 4), width: 4) : null,
    );
    addOutput('received', width: 4) <= sub.busOut;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('SPI endpoints do not use dynamic asynchronous reset values', () async {
    final warnings = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(warnings.add);
    try {
      expect(Simulator.logger.isLoggable(Level.WARNING), isTrue);
      final intf = SpiInterface(dataLength: 8);
      SpiMain(intf,
          clk: Logic(), reset: Logic(), start: Logic(), busIn: Logic(width: 8));
      SpiSub(intf: intf, reset: Logic(), busIn: Logic(width: 8));
      SpiSub(intf: SpiInterface(dataLength: 8));
      SpiSub(intf: SpiInterface(dataLength: 8), reset: Logic());
      SpiSub(intf: SpiInterface(dataLength: 8), busIn: Logic(width: 8));
      expect(
          warnings.where((record) =>
              record.message.contains('asyncReset with non-constant')),
          isEmpty);
    } finally {
      await subscription.cancel();
    }
  });

  for (final width in [1, 8]) {
    test('SPI synchronous first-edge load width=$width', () async {
      final dut = _ShiftHarness(width);
      await dut.build();
      final mask = (1 << width) - 1;
      final initialData = width == 1 ? 1 : 0xa6;
      final afterFirstShift = ((initialData << 1) | 1) & mask;
      final afterSecondShift = (afterFirstShift << 1) & mask;
      final vectors = <Vector>[
        Vector({
          'clock': 0,
          'reset': 0,
          'enable': 0,
          'serialIn': 0,
          'parallelIn': initialData,
        }, {}),
      ];

      void vector(
          {required int clock,
          required int reset,
          required int enable,
          required int input,
          required int parallel,
          required int output,
          required int state}) {
        vectors.add(Vector({
          'clock': clock,
          'reset': reset,
          'enable': enable,
          'serialIn': input,
          'parallelIn': parallel,
        }, {
          'serialOut': output,
          'parallelOut': state,
        }));
      }

      vector(
          clock: 0,
          reset: 1,
          enable: 0,
          input: 0,
          parallel: initialData,
          output: 1,
          state: 0);
      vector(
          clock: 0,
          reset: 0,
          enable: 0,
          input: 1,
          parallel: initialData,
          output: 1,
          state: 0);
      vector(
          clock: 1,
          reset: 0,
          enable: 0,
          input: 1,
          parallel: initialData,
          output: 1,
          state: 0);
      vector(
          clock: 0,
          reset: 0,
          enable: 1,
          input: 1,
          parallel: initialData,
          output: 1,
          state: 0);
      vector(
          clock: 1,
          reset: 0,
          enable: 1,
          input: 1,
          parallel: initialData,
          output: 1,
          state: afterFirstShift);
      vector(
          clock: 0,
          reset: 0,
          enable: 1,
          input: 1,
          parallel: initialData,
          output: afterFirstShift >> (width - 1),
          state: afterFirstShift);
      vector(
          clock: 0,
          reset: 0,
          enable: 1,
          input: 0,
          parallel: 0,
          output: afterFirstShift >> (width - 1),
          state: afterFirstShift);
      vector(
          clock: 1,
          reset: 0,
          enable: 1,
          input: 0,
          parallel: 0,
          output: afterFirstShift >> (width - 1),
          state: afterSecondShift);
      vector(
          clock: 0,
          reset: 0,
          enable: 1,
          input: 0,
          parallel: 0,
          output: afterSecondShift >> (width - 1),
          state: afterSecondShift);
      vector(
          clock: 0,
          reset: 1,
          enable: 0,
          input: 0,
          parallel: initialData,
          output: 1,
          state: 0);

      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
      expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
    });
  }

  test('SPI pair transfers sampled data in generated HDL', () async {
    final dut = _PairHarness();
    await dut.build();
    final vectors = <Vector>[];
    var inputs = <String, int>{
      'clock': 1,
      'mainReset': 0,
      'subReset': 0,
      'start': 0,
      'mainIn': 0,
      'subIn': 0,
    };
    void step(Map<String, int> changes, Map<String, int> expected) {
      inputs = {...inputs, ...changes};
      vectors.add(Vector(inputs, expected));
    }

    step({}, {});
    step({'mainReset': 1, 'subReset': 1}, {'mainOut': 0, 'subOut': 0});
    step({'mainReset': 0, 'subReset': 0, 'mainIn': 0xa6, 'subIn': 0x69},
        {'mainOut': 0, 'subOut': 0, 'mosi': 1, 'miso': 0, 'sclk': 0});
    step({'start': 1}, {'csb': 0, 'mosi': 1, 'miso': 0, 'sclk': 0});

    var mainShift = 0xa6;
    var subShift = 0x69;
    for (var bit = 0; bit < 8; bit++) {
      final mainBit = mainShift >> 7;
      final subBit = subShift >> 7;
      mainShift = ((mainShift << 1) | subBit) & 0xff;
      subShift = ((subShift << 1) | mainBit) & 0xff;
      step({
        'clock': 0
      }, {
        'sclk': 1,
        'mosi': mainBit,
        'miso': subBit,
        'mainOut': mainShift,
        'subOut': subShift,
      });
      step({'clock': 1}, {'mainOut': mainShift, 'subOut': subShift});
      if (bit == 0) {
        step({
          'start': 0,
          'mainIn': 0,
          'subIn': 0
        }, {
          'mosi': mainShift >> 7,
          'miso': subShift >> 7,
        });
      }
    }
    expect(mainShift, 0x69);
    expect(subShift, 0xa6);

    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
    expectNoVerilatorWarnings(dut, ['WIDTHEXPAND', 'UNOPTFLAT']);
  });

  for (final (withReset, withBusIn) in [
    (false, false),
    (false, true),
    (true, false),
  ]) {
    test(
        'SPI sub shifts without parallel load, '
        'reset=$withReset busIn=$withBusIn', () async {
      final dut = _SubHarness(withReset: withReset, withBusIn: withBusIn);
      await dut.build();
      final vectors = <Vector>[];
      var inputs = <String, int>{
        'clock': 0,
        'csb': 1,
        'mosi': 0,
        if (withReset) 'reset': 0,
        if (withBusIn) 'parallelIn': 15,
      };
      void step(Map<String, int> changes, Map<String, int> expected) {
        inputs = {...inputs, ...changes};
        vectors.add(Vector(inputs, expected));
      }

      step({}, {});
      if (withReset) {
        step({'reset': 1}, {'received': 0});
        step({'reset': 0}, {'received': 0});
      }
      step({'csb': 0}, {});
      for (final bit in [1, 0, 1, 1]) {
        step({'clock': 0, 'mosi': bit}, {});
        step({'clock': 1}, {});
      }
      step({'clock': 0}, {'received': 0xb});
      step({'csb': 1, 'mosi': 0}, {'received': 0xb});
      step({'clock': 1}, {'received': 0xb});

      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
      expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
    });
  }
}
