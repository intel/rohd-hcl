// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// spi_shift_register_test.dart
// Tests for SPI shift register logic.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// Exercise the original SPI wrappers for compatibility.
// ignore_for_file: deprecated_member_use_from_same_package

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

class _Command extends LogicStructure {
  Logic get low => elements[0];
  Logic get high => elements[1];

  _Command({String name = 'command'})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name);

  @override
  _Command clone({String? name}) => _Command(name: name ?? this.name);
}

class _MisclonedField extends GfLogic {
  final BinaryExtensionField replacement;

  _MisclonedField(super.field, this.replacement, {super.name});

  @override
  _MisclonedField clone({String? name}) =>
      _MisclonedField(replacement, replacement, name: name ?? this.name);
}

class _Response extends LogicStructure {
  Logic get status => elements[0];
  Logic get data => elements[1];

  _Response({String name = 'response'})
      : super([Logic(name: 'status', width: 3), Logic(name: 'value', width: 5)],
            name: name);

  @override
  _Response clone({String? name}) => _Response(name: name ?? this.name);
}

class _TypedPairHarness extends Module {
  late final TypedSpiMain<_Command, _Response> main;
  late final TypedSpiSub<_Response, _Command> sub;

  _TypedPairHarness() {
    final intf = SpiInterface(dataLength: 8);
    final mainData = _Command()
      ..gets(addInput('mainIn', Logic(width: 8), width: 8));
    final subData = _Response()
      ..gets(addInput('subIn', Logic(width: 8), width: 8));
    main = TypedSpiMain<_Command, _Response>(intf,
        clk: addInput('clock', Logic()),
        reset: addInput('mainReset', Logic()),
        start: addInput('start', Logic()),
        busIn: mainData,
        busOutSchema: _Response());
    sub = TypedSpiSub<_Response, _Command>(
        intf: intf,
        reset: addInput('subReset', Logic()),
        busIn: subData,
        busOutSchema: _Command());
    addOutput('mainOut', width: 8) <= main.busOut;
    addOutput('subOut', width: 8) <= sub.busOut;
    addOutput('status', width: 3) <= main.busOut.status;
    addOutput('commandHigh', width: 4) <= sub.busOut.high;
  }
}

FixedPoint _constantFixed(int value) =>
    FixedPoint.constant(FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(value >> 4, 4),
        fraction: LogicValue.ofInt(value & 0xf, 4)));

class _ConstantPairHarness extends Module {
  late final TypedSpiMain<Logic, Logic> main;
  late final TypedSpiSub<Logic, Logic> sub;

  _ConstantPairHarness() {
    final intf = SpiInterface(dataLength: 8);
    main = TypedSpiMain<Logic, Logic>(intf,
        clk: addInput('clock', Logic()),
        reset: addInput('mainReset', Logic()),
        start: addInput('start', Logic()),
        busIn: _constantFixed(0xa6),
        busOutSchema: Logic(width: 8));
    sub = TypedSpiSub<Logic, Logic>(
        intf: intf,
        reset: addInput('subReset', Logic()),
        busIn: _constantFixed(0x69),
        busOutSchema: Logic(width: 8));
    addOutput('mainOut', width: 8) <= main.busOut;
    addOutput('subOut', width: 8) <= sub.busOut;
  }
}

class _TypedReceiveHarness extends Module {
  late final TypedSpiSub<Logic, _Command> sub;

  _TypedReceiveHarness() {
    final intf = SpiInterface(dataLength: 8);
    intf.sclk <= addInput('clock', Logic());
    intf.csb <= addInput('csb', Logic());
    intf.mosi <= addInput('mosi', Logic());
    sub = TypedSpiSub<Logic, _Command>(intf: intf, busOutSchema: _Command());
    addOutput('received', width: 8) <= sub.busOut;
    addOutput('low', width: 4) <= sub.busOut.low;
  }
}

typedef _Nibbles = TypedLogicArray<Logic, LogicValue>;

_Nibbles _nibbles() =>
    _Nibbles([2], ({name}) => Logic(name: name ?? 'nibble', width: 4),
        numUnpackedDimensions: 1);

class _ArrayPairHarness extends Module {
  late final TypedSpiMain<_Nibbles, _Nibbles> main;
  late final TypedSpiSub<Logic, _Nibbles> sub;

  _ArrayPairHarness() {
    final intf = SpiInterface(dataLength: 8);
    final data = _nibbles()..gets(addInput('data', Logic(width: 8), width: 8));
    main = TypedSpiMain<_Nibbles, _Nibbles>(intf,
        clk: addInput('clock', Logic()),
        reset: addInput('reset', Logic()),
        start: addInput('start', Logic()),
        busIn: data,
        busOutSchema: _nibbles());
    sub = TypedSpiSub<Logic, _Nibbles>(
        intf: intf,
        reset: addInput('subReset', Logic()),
        busOutSchema: _nibbles());
    addOutput('received', width: 8) <= sub.busOut.packed;
    addOutput('first', width: 4) <= sub.busOut.arrayElements[0];
  }
}

void main() {
  test('typed SPI receive schemas reject changed clone metadata', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    expect(
        () => TypedSpiMain<Logic, Logic>(SpiInterface(dataLength: 3),
            clk: Logic(),
            reset: Logic(),
            start: Logic(),
            busIn: Logic(width: 3),
            busOutSchema: _MisclonedField(first, second)),
        throwsA(isA<LogicConstructionException>()));
    expect(
        () => TypedSpiSub<Logic, Logic>(
            intf: SpiInterface(dataLength: 3),
            busOutSchema: _MisclonedField(first, second)),
        throwsA(isA<LogicConstructionException>()));
  });

  tearDown(Simulator.reset);

  test('typed SPI retains widened structured constant transmit inputs',
      () async {
    final dut = _ConstantPairHarness();
    expect(dut.main.busIn, isA<FixedPoint>());
    expect(dut.sub.busIn, isA<FixedPoint>());
    final vectors = <Vector>[
      Vector({'clock': 1, 'mainReset': 0, 'subReset': 0, 'start': 0}, {}),
      Vector({'mainReset': 1, 'subReset': 1}, {}),
      Vector({'mainReset': 0, 'subReset': 0, 'start': 1}, {}),
    ];
    for (var bit = 0; bit < 8; bit++) {
      vectors
        ..add(Vector({'clock': 0}, {}))
        ..add(Vector({'clock': 1}, {}));
      if (bit == 0) {
        vectors.add(Vector({'start': 0}, {}));
      }
    }
    vectors.add(Vector({}, {'mainOut': 0x69, 'subOut': 0xa6}));
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('typed SPI ports retain independent schemas and transfer bits',
      () async {
    final dut = _TypedPairHarness();
    expect(dut.main.busIn, isA<_Command>());
    expect(dut.main.busOut, isA<_Response>());
    expect(dut.sub.busIn, isA<_Response>());
    expect(dut.sub.busOut, isA<_Command>());

    final vectors = <Vector>[
      Vector({
        'clock': 1,
        'mainReset': 0,
        'subReset': 0,
        'start': 0,
        'mainIn': 0,
        'subIn': 0,
      }, {}),
      Vector({'mainReset': 1, 'subReset': 1}, {}),
      Vector({
        'mainReset': 0,
        'subReset': 0,
        'mainIn': 0xa6,
        'subIn': 0x69,
        'start': 1,
      }, {}),
    ];
    for (var bit = 0; bit < 8; bit++) {
      vectors
        ..add(Vector({'clock': 0}, {}))
        ..add(Vector({'clock': 1}, {}));
      if (bit == 0) {
        vectors.add(Vector({'start': 0, 'mainIn': 0, 'subIn': 0}, {}));
      }
    }
    vectors.add(Vector({}, {
      'mainOut': 0x69,
      'subOut': 0xa6,
      'status': 1,
      'commandHigh': 0xa,
    }));
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
  });

  test('typed receive-only SPI subordinate preserves output fields', () async {
    final dut = _TypedReceiveHarness();
    expect(dut.sub.busIn, isNull);
    expect(dut.sub.busOut, isA<_Command>());
    final vectors = <Vector>[
      Vector({'clock': 0, 'csb': 1, 'mosi': 0}, {}),
      Vector({'csb': 0}, {}),
    ];
    for (final bit in [1, 0, 1, 0, 0, 1, 1, 0]) {
      vectors
        ..add(Vector({'clock': 0, 'mosi': bit}, {}))
        ..add(Vector({'clock': 1}, {}));
    }
    vectors.add(Vector({'clock': 0}, {'received': 0xa6, 'low': 6}));
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('typed SPI preserves unpacked array ports in generated HDL', () async {
    final dut = _ArrayPairHarness();
    expect(dut.main.input('busIn'), isA<_Nibbles>());
    expect(dut.main.busOut.numUnpackedDimensions, 1);
    expect(dut.sub.busOut.numUnpackedDimensions, 1);
    final vectors = <Vector>[
      Vector({
        'clock': 1,
        'reset': 0,
        'subReset': 0,
        'start': 0,
        'data': 0,
      }, {}),
      Vector({'reset': 1, 'subReset': 1}, {}),
      Vector({'reset': 0, 'subReset': 0, 'data': 0xa6, 'start': 1}, {}),
    ];
    for (var bit = 0; bit < 8; bit++) {
      vectors
        ..add(Vector({'clock': 0}, {}))
        ..add(Vector({'clock': 1}, {}));
      if (bit == 0) {
        vectors.add(Vector({'start': 0, 'data': 0}, {}));
      }
    }
    vectors.add(Vector({}, {'received': 0xa6, 'first': 6}));
    await dut.build();
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('typed SPI definition names distinguish payload layouts', () {
    TypedSpiMain<Logic, Logic> main(Logic input, Logic output) =>
        TypedSpiMain<Logic, Logic>(SpiInterface(dataLength: 8),
            clk: Logic(),
            reset: Logic(),
            start: Logic(),
            busIn: input,
            busOutSchema: output);
    TypedSpiSub<Logic, Logic> sub(Logic output) => TypedSpiSub<Logic, Logic>(
        intf: SpiInterface(dataLength: 8), busOutSchema: output);
    expect(main(_Command(), _Response()).definitionName,
        isNot(main(_Response(), _Response()).definitionName));
    expect(main(_Command(), _Response()).definitionName,
        isNot(main(_Command(), _Command()).definitionName));
    expect(
        sub(_Response()).definitionName, isNot(sub(_Command()).definitionName));
  });

  test('typed SPI endpoints validate both payload widths', () {
    final intf = SpiInterface(dataLength: 8);
    expect(
        () => TypedSpiMain<Logic, Logic>(intf,
            clk: Logic(),
            reset: Logic(),
            start: Logic(),
            busIn: Logic(width: 7),
            busOutSchema: Logic(width: 8)),
        throwsArgumentError);
    expect(
        () => TypedSpiMain<Logic, Logic>(intf,
            clk: Logic(),
            reset: Logic(),
            start: Logic(),
            busIn: Logic(width: 8),
            busOutSchema: Logic(width: 7)),
        throwsArgumentError);
    expect(
        () => TypedSpiSub<Logic, Logic>(
            intf: intf, busIn: Logic(width: 7), busOutSchema: Logic(width: 8)),
        throwsArgumentError);
    expect(
        () => TypedSpiSub<Logic, Logic>(
            intf: intf, busOutSchema: Logic(width: 7)),
        throwsArgumentError);
  });

  test('legacy SPI wrappers retain flat ports and definition names', () {
    final intf = SpiInterface(dataLength: 8);
    final main = SpiMain(intf,
        clk: Logic(), reset: Logic(), start: Logic(), busIn: _Command());
    final sub = SpiSub(intf: intf, busIn: _Response());
    expect(main.input('busIn'), isNot(isA<LogicStructure>()));
    expect(main.busOut, isNot(isA<LogicStructure>()));
    expect(sub.input('busIn'), isNot(isA<LogicStructure>()));
    expect(sub.busOut, isNot(isA<LogicStructure>()));
    expect(main.definitionName, 'SpiMain_W8_8_1');
    expect(sub.definitionName, 'SpiSub_W8_8_1');
  });

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
