// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_transport_modules_test.dart
// Tests for typed transport modules.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

class _Record extends LogicStructure {
  Logic get key => elements[0];
  Logic get tag => elements[1];

  _Record({String? name})
      : super([Logic(name: 'key', width: 4), Logic(name: 'tag', width: 4)],
            name: name ?? 'record');

  @override
  _Record clone({String? name}) => _Record(name: name ?? this.name);
}

enum _Phase { idle, busy, done, error }

typedef _RecordValue = ({LogicValue key, LogicValue tag});

_RecordValue _decode(LogicValue value) =>
    (key: value.getRange(0, 4), tag: value.getRange(4, 8));

LogicValue _encode(_RecordValue value) => LogicValue.of([value.tag, value.key]);

const _codec = LogicValueCodec<_RecordValue>(decode: _decode, encode: _encode);

class _ShiftHarness<T extends Logic> extends Module {
  late final ShiftRegister<T> shift;

  _ShiftHarness(T schema,
      {int depth = 3,
      bool asyncReset = false,
      bool liveReset = false,
      Object? Function(T resetData)? resetValues}) {
    final data = schema.cloneTyped(name: 'payload')
      ..gets(addInput('data', Logic(width: schema.width), width: schema.width));
    final resetData = schema.cloneTyped(name: 'resetPayload')
      ..gets(addInput('resetData', Logic(width: schema.width),
          width: schema.width));
    shift = ShiftRegister<T>(data,
        clk: addInput('clk', Logic()),
        reset: addInput('reset', Logic()),
        enable: addInput('enable', Logic()),
        depth: depth,
        asyncReset: asyncReset,
        resetValue: resetValues != null
            ? resetValues(resetData)
            : liveReset
                ? resetData
                : null);
    addOutput('result', width: schema.width) <= shift.dataOut;
    for (var i = 0; i < depth; i++) {
      addOutput('stage$i', width: schema.width) <= shift.stages[i];
    }
  }
}

class _AsyncHarness<T extends Logic> extends Module {
  late final AsyncFifo<T> fifo;

  _AsyncHarness(T schema) {
    final data = schema.cloneTyped(name: 'payload')
      ..gets(addInput('data', Logic(width: schema.width), width: schema.width));
    fifo = AsyncFifo<T>(
        writeClk: addInput('writeClk', Logic()),
        readClk: addInput('readClk', Logic()),
        writeReset: addInput('writeReset', Logic()),
        readReset: addInput('readReset', Logic()),
        writeEnable: addInput('write', Logic()),
        readEnable: addInput('read', Logic()),
        writeData: data,
        depth: 4);
    addOutput('result', width: schema.width) <= fifo.readData;
    addOutput('full') <= fifo.full;
    addOutput('empty') <= fifo.empty;
  }
}

class _ExtremaHarness<T extends Logic> extends Module {
  late final Extrema<T> extrema;

  _ExtremaHarness(T schema,
      {bool max = true,
      int radix = 2,
      int count = 5,
      Logic Function(T a, T b)? isLessThan}) {
    final data = [
      for (var i = 0; i < count; i++)
        schema.cloneTyped(name: 'payload$i')
          ..gets(addInput('data$i', Logic(width: schema.width),
              width: schema.width))
    ];
    extrema = Extrema<T>(data, max: max, radix: radix, isLessThan: isLessThan);
    addOutput('result', width: schema.width) <= extrema.val;
    addOutput('index', width: extrema.index.width) <= extrema.index;
  }
}

Future<void> _compare(Module dut, List<Vector> vectors,
    {bool systemC = false}) async {
  await dut.build();
  await SimCompare.checkFunctionalVector(dut, vectors);
  SimCompare.checkIverilogVector(dut, vectors);
  if (systemC) {
    expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
  }
}

void _expectPayload<T extends Logic>(T schema, T result) {
  expect(result.runtimeType, schema.runtimeType);
  expect(sameDeclaredPayloadShape(schema, result), isTrue);
}

void _checkTransport<T extends Logic>(String label, T schema,
    {bool systemC = false}) {
  // Hold controls stable before edges; inspect every stage, stalls, and reset.
  for (final asyncReset in [false, true]) {
    test('$label shift asyncReset=$asyncReset', () async {
      final dut =
          _ShiftHarness<T>(schema, liveReset: true, asyncReset: asyncReset);
      _expectPayload<T>(schema, dut.shift.dataOut);
      expect(dut.shift.input('data_in').runtimeType, schema.runtimeType);
      expect(dut.shift.input('resetValue').runtimeType, schema.runtimeType);
      for (final stage in dut.shift.stages) {
        expect(sameDeclaredPayloadShape(schema, stage), isTrue);
      }
      await _compare(
          dut,
          [
            Vector({
              'clk': 0,
              'reset': 0,
              'enable': 0,
              'data': 1,
              'resetData': 2,
            }, {}),
            Vector({'reset': 1},
                asyncReset ? {'result': 2, 'stage0': 2, 'stage1': 2} : {}),
            Vector({'clk': 1}, {'result': 2, 'stage0': 2, 'stage1': 2}),
            Vector({'clk': 0, 'reset': 0, 'enable': 1}, {}),
            Vector({'clk': 1}, {'result': 2, 'stage0': 1, 'stage1': 2}),
            Vector({'clk': 0, 'data': 3}, {}),
            Vector({'clk': 1}, {'result': 2, 'stage0': 3, 'stage1': 1}),
            Vector({'clk': 0, 'enable': 0, 'data': 0}, {}),
            Vector({'clk': 1}, {'result': 2, 'stage0': 3, 'stage1': 1}),
            Vector({'clk': 0, 'enable': 1}, {}),
            Vector({'clk': 1}, {'result': 1, 'stage0': 0, 'stage1': 3}),
            Vector({'clk': 0, 'resetData': 3}, {}),
            Vector({'reset': 1},
                asyncReset ? {'result': 3, 'stage0': 3, 'stage1': 3} : {}),
            Vector({'clk': 1}, {'result': 3, 'stage0': 3, 'stage1': 3}),
          ],
          systemC: systemC);
    });
  }

  // Fill, reject overflow, drain, reject underflow, and wrap using separate
  // clocks.
  test('$label async FIFO preserves payloads and flags', () async {
    final dut = _AsyncHarness<T>(schema);
    _expectPayload<T>(schema, dut.fifo.readData);
    expect(dut.fifo.input('writeData').runtimeType, schema.runtimeType);
    final vectors = <Vector>[
      Vector({
        'writeClk': 0,
        'readClk': 0,
        'writeReset': 1,
        'readReset': 1,
        'write': 0,
        'read': 0,
        'data': 0,
      }, {}),
      Vector({'writeClk': 1, 'readClk': 1}, {}),
      Vector({'writeClk': 0, 'readClk': 0}, {}),
      Vector({'writeClk': 1, 'readClk': 1}, {'empty': 1, 'full': 0}),
      Vector({
        'writeClk': 0,
        'readClk': 0,
        'writeReset': 0,
        'readReset': 0,
      }, {}),
    ];
    void readClocks({Map<String, dynamic> expected = const {}}) {
      for (var i = 0; i < 4; i++) {
        vectors
          ..add(Vector({'readClk': 1}, i == 3 ? expected : {}))
          ..add(Vector({'readClk': 0}, {}));
      }
    }

    for (final values in [
      [1, 2, 3, 0],
      [3, 0, 2, 1],
    ]) {
      for (final value in values) {
        vectors
          ..add(Vector({'data': value, 'write': 1}, {}))
          ..add(Vector({'writeClk': 1}, {}))
          ..add(Vector({'writeClk': 0}, {}));
      }
      vectors
        ..add(Vector({'data': 2}, {'full': 1}))
        ..add(Vector({'writeClk': 1}, {'full': 1}))
        ..add(Vector({'writeClk': 0, 'write': 0}, {}));
      readClocks(expected: {'empty': 0, 'result': values.first});
      for (var i = 0; i < values.length; i++) {
        vectors
          ..add(Vector({'read': 1}, {'result': values[i]}))
          ..add(Vector(
              {'readClk': 1}, i == values.length - 1 ? {'empty': 1} : {}))
          ..add(Vector({'readClk': 0}, {}));
      }
      vectors
        ..add(Vector({'readClk': 1}, {'empty': 1}))
        ..add(Vector({'readClk': 0, 'read': 0}, {}));
      for (var i = 0; i < 4; i++) {
        vectors
          ..add(Vector({'writeClk': 1}, {}))
          ..add(Vector({'writeClk': 0}, {}));
      }
      vectors.add(Vector({}, {'full': 0}));
    }
    await _compare(dut, vectors, systemC: systemC);
  });

  // Select by a small key while carrying all fields, dimensions, and codecs.
  test('$label extrema preserves payload schema', () async {
    final dut = _ExtremaHarness<T>(schema,
        radix: 3, isLessThan: (a, b) => a.getRange(0, 2).lt(b.getRange(0, 2)));
    _expectPayload<T>(schema, dut.extrema.val);
    expect(dut.extrema.input('signal0').runtimeType, schema.runtimeType);
    await _compare(
        dut,
        [
          Vector({'data0': 1, 'data1': 3, 'data2': 2, 'data3': 3, 'data4': 0},
              {'result': 3, 'index': 1}),
          Vector({'data0': 3}, {'result': 3, 'index': 0}),
          Vector({'data0': 0, 'data1': 0, 'data2': 0, 'data3': 0},
              {'result': 0, 'index': 0}),
        ],
        systemC: systemC);
  });
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  _checkTransport('scalar', Logic(width: 8), systemC: true);
  _checkTransport('record', _Record(), systemC: true);
  _checkTransport<Logic>('record with Logic static type', _Record());
  _checkTransport('floating-point', FloatingPoint32());
  _checkTransport('fixed-point', FixedPoint(integerWidth: 3, fractionWidth: 4));
  _checkTransport('enum', LogicEnum<_Phase>(_Phase.values));
  _checkTransport(
      'rank-zero', TypedLogicArray<_Record, LogicValue>([], _Record.new));
  _checkTransport(
      'unpacked multidimensional',
      TypedLogicArray<_Record, LogicValue>([2, 2], _Record.new,
          numUnpackedDimensions: 2),
      systemC: true);
  _checkTransport(
      'custom codec',
      TypedLogicArray<_Record, _RecordValue>([2], _Record.new,
          valueCodec: _codec));

  // Mix live structured resets and packed constants, including omitted entries.
  for (final map in [false, true]) {
    for (final asyncReset in [false, true]) {
      test('per-stage typed resets map=$map asyncReset=$asyncReset', () async {
        final dut = _ShiftHarness(_Record(),
            asyncReset: asyncReset,
            resetValues: (resetData) =>
                map ? {0: resetData, 1: 0x52} : [resetData, 0x52, null]);
        await _compare(
            dut,
            [
              Vector({
                'clk': 0,
                'reset': 0,
                'enable': 0,
                'data': 0xa3,
                'resetData': 0xb7,
              }, {}),
              Vector(
                  {'reset': 1},
                  asyncReset
                      ? {'stage0': 0xb7, 'stage1': 0x52, 'result': 0}
                      : {}),
              Vector({'clk': 1}, {'stage0': 0xb7, 'stage1': 0x52, 'result': 0}),
              Vector({'clk': 0, 'reset': 0, 'enable': 1}, {}),
              Vector(
                  {'clk': 1}, {'stage0': 0xa3, 'stage1': 0xb7, 'result': 0x52}),
              Vector({'clk': 0, 'enable': 0}, {}),
              Vector(
                  {'clk': 1}, {'stage0': 0xa3, 'stage1': 0xb7, 'result': 0x52}),
            ],
            systemC: true);
      });
    }
  }

  // Concurrent traffic at genuinely different frequencies repeatedly wraps.
  test('typed FIFO transfers between independent 10/14 clocks', () async {
    final writeClk = SimpleClockGenerator(10).clk;
    final readClk = SimpleClockGenerator(14).clk;
    final writeReset = Logic()..put(1);
    final readReset = Logic()..put(1);
    final write = Logic()..put(0);
    final read = Logic()..put(0);
    final bits = Logic(width: 8)..put(0);
    final data = _Record()..gets(bits);
    final fifo = AsyncFifo<_Record>(
        writeClk: writeClk,
        readClk: readClk,
        writeReset: writeReset,
        readReset: readReset,
        writeEnable: write,
        writeData: data,
        readEnable: read,
        depth: 4);
    await fifo.build();
    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());
    for (var i = 0; i < 4; i++) {
      await readClk.nextNegedge;
    }
    writeReset.put(0);
    readReset.put(0);
    final expected = [for (var i = 0; i < 40; i++) (i * 37) & 0xff];
    Future<void> produce() async {
      for (final value in expected) {
        await writeClk.nextNegedge;
        while (fifo.full.value.toBool()) {
          await writeClk.nextNegedge;
        }
        bits.put(value);
        write.put(1);
        await writeClk.nextNegedge;
        write.put(0);
      }
    }

    Future<void> consume() async {
      for (final value in expected) {
        await readClk.nextNegedge;
        while (fifo.empty.value.toBool()) {
          await readClk.nextNegedge;
        }
        expect(fifo.readData.value.toInt(), value);
        expect(fifo.readData.key.value.toInt(), value & 0xf);
        expect(fifo.readData.tag.value.toInt(), value >> 4);
        read.put(1);
        await readClk.nextNegedge;
        read.put(0);
      }
    }

    await Future.wait([produce(), consume()]);
    expect(fifo.empty.value.toBool(), isTrue);
    await Simulator.endSimulation();
  });

  // Equal keys with different tags must select the earliest complete record.
  for (final max in [false, true]) {
    for (final radix in [2, 3, 4]) {
      test('record extrema max=$max radix=$radix', () async {
        final dut = _ExtremaHarness(_Record(),
            max: max, radix: radix, isLessThan: (a, b) => a.key.lt(b.key));
        await _compare(
            dut,
            [
              Vector({
                'data0': 0x52,
                'data1': 0x13,
                'data2': 0xa1,
                'data3': 0xf3,
                'data4': 0x61,
              }, {
                'result': max ? 0x13 : 0xa1,
                'index': max ? 1 : 2
              }),
            ],
            systemC: radix == 3);
      });
    }
  }

  // Numeric comparisons must not fall back to unsigned packed-bit ordering.
  test('fixed-point extrema uses signed comparisons', () async {
    final dut = _ExtremaHarness(FixedPoint(integerWidth: 3, fractionWidth: 4),
        max: false);
    await _compare(
        dut,
        [
          Vector({
            'data0': 0x20,
            'data1': 0xf0,
            'data2': 0xe0,
            'data3': 0x10,
            'data4': 0xe0
          }, {
            'result': 0xe0,
            'index': 2
          }),
        ],
        systemC: true);
  });

  test('floating-point extrema uses numeric comparisons', () async {
    final dut = _ExtremaHarness(FloatingPoint32());
    await _compare(
        dut,
        [
          Vector({
            'data0': 0xc0000000,
            'data1': 0xbf800000,
            'data2': 0x40000000,
            'data3': 0x3f800000,
            'data4': 0x40000000,
          }, {
            'result': 0x40000000,
            'index': 2
          }),
        ],
        systemC: true);
  });

  test('singleton extrema retains record and zero index', () async {
    final dut = _ExtremaHarness(_Record(), count: 1);
    await _compare(
        dut,
        [
          Vector({'data0': 0xa3}, {'result': 0xa3, 'index': 0}),
        ],
        systemC: true);
  });

  test('zero-depth typed shift register is combinational', () async {
    final dut = _ShiftHarness(_Record(), depth: 0);
    expect(dut.shift.stages, isEmpty);
    await _compare(dut, [
      Vector({'clk': 0, 'reset': 0, 'enable': 0, 'data': 0xa3, 'resetData': 0},
          {'result': 0xa3}),
      Vector({'data': 0x52}, {'result': 0x52}),
    ]);
  });

  test('scalar shift preserves structured reset bit-pattern support', () async {
    final dut = _ShiftHarness<Logic>(Logic(width: 8),
        resetValues: (_) => _Record()..gets(Const(0xa3, width: 8)));
    await _compare(dut, [
      Vector(
          {'clk': 0, 'reset': 1, 'enable': 0, 'data': 0, 'resetData': 0}, {}),
      Vector({'clk': 1}, {'result': 0xa3, 'stage0': 0xa3, 'stage1': 0xa3}),
    ]);
  });

  test('scalar constants can request driveable Logic ports', () async {
    final shift =
        ShiftRegister<Logic>(Const(3, width: 4), clk: Logic(), depth: 1);
    final extrema = Extrema<Logic>([Const(2, width: 2), Const(9, width: 4)]);
    final fifo = AsyncFifo<Logic>(
        writeClk: Logic(),
        readClk: Logic(),
        writeReset: Logic(),
        readReset: Logic(),
        writeEnable: Logic(),
        writeData: Const(3, width: 4),
        readEnable: Logic(),
        depth: 4);
    await shift.build();
    await extrema.build();
    await fifo.build();
    expect(shift.dataOut, isNot(isA<Const>()));
    expect(fifo.readData, isNot(isA<Const>()));
    expect(extrema.val.value.toInt(), 9);
  });

  test('typed extrema rejects equal-width different array layouts', () {
    final a = TypedLogicArray<_Record, LogicValue>([2, 2], _Record.new);
    final b = TypedLogicArray<_Record, LogicValue>([4], _Record.new);
    expect(() => Extrema([a, b]), throwsA(isA<RohdHclException>()));
    expect(
        () => ShiftRegister(a,
            clk: Logic(), depth: 2, reset: Logic(), resetValue: b),
        throwsA(isA<RohdHclException>()));
  });

  test('typed extrema rejects mismatching array codecs', () {
    final otherCodec =
        // Deliberately distinct codec identity.
        // ignore: prefer_const_constructors
        LogicValueCodec<_RecordValue>(decode: _decode, encode: _encode);
    final a = TypedLogicArray<_Record, _RecordValue>([2], _Record.new,
        valueCodec: _codec);
    final b = TypedLogicArray<_Record, _RecordValue>([2], _Record.new,
        valueCodec: otherCodec);
    expect(() => Extrema([a, b]), throwsA(isA<RohdHclException>()));
  });
}
