// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_control_protection_test.dart
// Tests for typed control protection.
//
// 2026 October 23
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

class _Payload extends LogicStructure {
  FixedPoint get number => elements[0] as FixedPoint;

  _Payload({String? name})
      : super([
          FixedPoint(integerWidth: 3, fractionWidth: 2, name: 'number'),
          Logic(width: 3, name: 'flags'),
        ], name: name ?? 'payload');

  @override
  _Payload clone({String? name}) => _Payload(name: name ?? this.name);
}

enum _State { idle, busy, done }

typedef _PayloadValue = ({LogicValue number, LogicValue flags});
_PayloadValue _decode(LogicValue value) =>
    (number: value.getRange(0, 6), flags: value.getRange(6, 9));
LogicValue _encode(_PayloadValue value) =>
    LogicValue.of([value.flags, value.number]);
const _codec = LogicValueCodec<_PayloadValue>(decode: _decode, encode: _encode);

class _Controlled<T extends Logic> extends Module {
  late final ClockGate gate;
  late final T delayed;

  _Controlled(T schema, {bool present = true, bool delay = true}) {
    final data = schema.cloneTyped(name: 'freeClk')
      ..gets(addInput('data', Logic(width: schema.width), width: schema.width));
    gate = ClockGate(addInput('clk', Logic()),
        enable: addInput('enable', Logic()),
        reset: addInput('reset', Logic()),
        controlIntf: ClockGateControlInterface(isPresent: present),
        delayControlledSignals: delay);
    delayed = gate.controlled(data, resetValue: 2);
    final ports = gate.outputs.length + gate.inputs.length;
    expect(identical(gate.controlled(data), delayed), isTrue);
    expect(gate.outputs.length + gate.inputs.length, ports);
    if (!present || !delay) {
      expect(identical(delayed, data), isTrue);
    }
    addOutput('result', width: schema.width) <= delayed;
  }
}

class _Protection<T extends Logic> extends Module {
  late final ErrorCheckingTransmitter<T> tx;
  late final ErrorCheckingReceiver<T> rx;
  late final T original;
  late final T? corrected;

  _Protection(T schema, {HammingType? type}) {
    final raw =
        addInput('data', Logic(width: schema.width), width: schema.width);
    final data = schema.cloneTyped(name: 'payload')..gets(raw);
    tx = type == null
        ? ParityTransmitter<T>(data)
        : HammingEccTransmitter<T>(data, hammingType: type);
    final legacy = type == null
        ? ParityTransmitter<Logic>(raw)
        : HammingEccTransmitter<Logic>(raw, hammingType: type);
    final mask = addInput('mask', Logic(width: tx.transmission.width),
        width: tx.transmission.width);
    final received = tx.transmission ^ mask;
    rx = type == null
        ? ParityReceiver<T>(received, dataSchema: schema)
        : HammingEccReceiver<T>(received,
            dataSchema: schema, hammingType: type);
    original = rx.originalData;
    corrected = rx.correctedData;
    addOutput('original', width: schema.width) <= original;
    if (corrected != null) {
      addOutput('corrected', width: schema.width) <= corrected!;
    }
    addOutput('sameEncoding') <= tx.transmission.eq(legacy.transmission);
    addOutput('error') <= rx.error;
    addOutput('correctable') <= rx.correctableError;
    addOutput('uncorrectable') <= rx.uncorrectableError;
  }
}

class _ConstantControl extends Module {
  _ConstantControl() {
    final gate = ClockGate(addInput('clk', Logic()),
        enable: Const(0),
        reset: addInput('reset', Logic()),
        delayControlledSignals: true);
    final delayed =
        gate.controlled<Logic>(Const(0xa5, width: 8), resetValue: 0);
    addOutput('result', width: 8) <= delayed;
  }
}

Future<void> _compare(Module dut, List<Vector> vectors,
    {bool systemC = false}) async {
  await dut.build();
  await SimCompare.checkFunctionalVector(dut, vectors);
  if (systemC) {
    expect(SimCompare.checkSystemCVector(dut, vectors), isTrue);
  } else {
    SimCompare.checkIverilogVector(dut, vectors);
  }
}

List<Vector> _clockVectors({bool bypass = false}) => [
      Vector({'clk': 0, 'enable': 0, 'reset': 1, 'data': 1},
          bypass ? {'result': 1} : {}),
      Vector({'clk': 1}, {'result': bypass ? 1 : 2}),
      Vector({'clk': 0, 'reset': 0}, {'result': bypass ? 1 : 2}),
      Vector({'clk': 1}, {'result': 1}),
      Vector({'clk': 0, 'data': 2}, {'result': bypass ? 2 : 1}),
      // Controlled signals use the free clock even while the gated clock stops.
      Vector({'clk': 1}, {'result': 2}),
      Vector({'clk': 0, 'data': 1, 'enable': 1}, {'result': bypass ? 1 : 2}),
      Vector({'clk': 1}, {'result': 1}),
      Vector({'clk': 0, 'reset': 1}, {}),
      Vector({'clk': 1}, {'result': bypass ? 1 : 2}),
    ];

List<Vector> _protectionVectors<T extends Logic>(_Protection<T> dut,
    {HammingType? type}) {
  final corrects = type?.hasCorrection ?? false;
  return [
    Vector({
      'data': 2,
      'mask': 0
    }, {
      'original': 2,
      if (corrects) 'corrected': 2,
      'sameEncoding': 1,
      'error': 0,
      'correctable': 0,
      'uncorrectable': 0,
    }),
    for (var bit = 0; bit < dut.tx.transmission.width; bit++)
      Vector({
        'mask': BigInt.one << bit
      }, {
        if (corrects) 'corrected': 2,
        'sameEncoding': 1,
        'error': 1,
        'correctable': corrects ? 1 : 0,
        'uncorrectable': corrects ? 0 : 1,
      }),
    if (type != null && type != HammingType.sec)
      Vector({'mask': 3}, {'error': 1, 'uncorrectable': 1, 'correctable': 0}),
    Vector({
      'data': 1,
      'mask': 0
    }, {
      'original': 1,
      if (corrects) 'corrected': 1,
      'sameEncoding': 1,
      'error': 0,
    }),
  ];
}

void _checkPayload<T extends Logic>(String label, T schema) {
  for (final present in [true, false]) {
    for (final delay in [true, false]) {
      test('$label controlled present=$present delay=$delay', () async {
        final dut = _Controlled<T>(schema, present: present, delay: delay);
        expect(sameDeclaredPayloadShape(dut.delayed, schema), isTrue);
        await _compare(dut, _clockVectors(bypass: !present || !delay));
      });
    }
  }
  for (final type in [null, ...HammingType.values]) {
    // Flip each data/code bit, including bits invalid under an enum schema.
    test('$label ${type ?? 'parity'} preserves payload and wire encoding',
        () async {
      final before = schema.value;
      final dut = _Protection<T>(schema, type: type);
      expect(sameDeclaredPayloadShape(dut.tx.input('data'), schema), isTrue);
      expect(sameDeclaredPayloadShape(dut.original, schema), isTrue);
      expect(dut.corrected == null, !(type?.hasCorrection ?? false));
      if (dut.corrected != null) {
        expect(sameDeclaredPayloadShape(dut.corrected!, schema), isTrue);
      }
      await _compare(dut, _protectionVectors(dut, type: type));
      expect(schema.value, before, reason: 'A schema is not an output driver.');
    });
  }
}

void main() {
  tearDown(Simulator.reset);
  _checkPayload('scalar', Logic(width: 8));
  _checkPayload('fixed point', FixedPoint(integerWidth: 3, fractionWidth: 2));
  _checkPayload(
      'floating point', FloatingPoint(exponentWidth: 3, mantissaWidth: 4));
  _checkPayload('nested structure', _Payload());
  _checkPayload('enum', LogicEnum<_State>(_State.values));
  _checkPayload(
      'rank-zero enum',
      TypedLogicArray<LogicEnum<_State>, LogicValue>(
          [], LogicEnum<_State>(_State.values).clone));
  _checkPayload('legacy array', LogicArray([2, 2], 2));
  _checkPayload(
      'rank zero', TypedLogicArray<_Payload, LogicValue>([], _Payload.new));
  _checkPayload('multidimensional',
      TypedLogicArray<_Payload, LogicValue>([2, 2], _Payload.new));
  _checkPayload(
      'unpacked',
      TypedLogicArray<_Payload, LogicValue>([2, 2], _Payload.new,
          numUnpackedDimensions: 1));
  _checkPayload(
      'codec',
      TypedLogicArray<_Payload, _PayloadValue>([2], _Payload.new,
          valueCodec: _codec));

  test('controlled structure SystemC', () async {
    await _compare(_Controlled(_Payload()), _clockVectors(), systemC: true);
  }, testOn: 'vm');

  test('scalar constants produce driveable controlled and transmitter ports',
      () async {
    final parity = ParityTransmitter<Logic>(Const(0xa5, width: 8));
    final ecc = HammingEccTransmitter<Logic>(Const(0xa5, width: 8));
    expect(parity.input('data'), isNot(isA<Const>()));
    expect(ecc.input('data'), isNot(isA<Const>()));
    expect(parity.transmission.value.getRange(0, 8), LogicValue.ofInt(0xa5, 8));
    expect(ecc.transmission.value.getRange(0, 8), LogicValue.ofInt(0xa5, 8));
    await _compare(_ConstantControl(), [
      Vector({'clk': 0, 'reset': 1}, {}),
      Vector({'clk': 1}, {'result': 0}),
      Vector({'clk': 0, 'reset': 0}, {'result': 0}),
      Vector({'clk': 1}, {'result': 0xa5}),
    ]);
  });
  test('typed SECDED SystemC', () async {
    final dut = _Protection(_Payload(), type: HammingType.secded);
    await _compare(dut, _protectionVectors(dut, type: HammingType.secded),
        systemC: true);
  }, testOn: 'vm');

  test('typed receiver requires a matching schema', () {
    expect(
        () => ParityReceiver<_Payload>(Logic(width: 9)), throwsArgumentError);
    expect(() => HammingEccReceiver<_Payload>(Logic(width: 12)),
        throwsArgumentError);
    expect(() => ParityReceiver(Logic(width: 8), dataSchema: _Payload()),
        throwsArgumentError);
    expect(() => HammingEccReceiver(Logic(width: 11), dataSchema: _Payload()),
        throwsArgumentError);
    expect(() => ParityReceiver(Logic()), throwsArgumentError);
  });

  test('legacy receivers keep scalar outputs', () {
    final parity = ParityReceiver(Logic(width: 9));
    final ecc = HammingEccReceiver(Logic(width: 12));
    expect(parity.originalData, isNot(isA<LogicStructure>()));
    expect(ecc.originalData, isNot(isA<LogicStructure>()));
    expect(ecc.correctedData, isNot(isA<LogicStructure>()));
    expect(parity.originalData.width, 8);
    expect(ecc.correctedData!.width, 8);
  });
}
