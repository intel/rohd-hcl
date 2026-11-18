// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_control_protection_test.dart
// Tests for typed clock control and error protection.
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

class _ParentNamedPayload extends LogicStructure {
  final String suffix;

  _ParentNamedPayload({String name = 'payload', this.suffix = 'bits'})
      : super([Logic(name: '${name}_$suffix', width: 8)], name: name);

  @override
  _ParentNamedPayload clone({String? name}) =>
      _ParentNamedPayload(name: name ?? this.name, suffix: suffix);
}

class _SecondCloneField extends GfLogic {
  final BinaryExtensionField replacement;
  final bool preserveNext;

  _SecondCloneField(super.field, this.replacement,
      {this.preserveNext = true, super.name});

  @override
  _SecondCloneField clone({String? name}) =>
      _SecondCloneField(preserveNext ? field : replacement, replacement,
          preserveNext: false, name: name ?? this.name);
}

enum _State { idle, busy, done }

typedef _PayloadValue = ({LogicValue number, LogicValue flags});
_PayloadValue _decode(LogicValue value) =>
    (number: value.getRange(0, 6), flags: value.getRange(6, 9));
LogicValue _encode(_PayloadValue value) =>
    LogicValue.of([value.flags, value.number]);
const _codec = LogicValueCodec<_PayloadValue>(decode: _decode, encode: _encode);

LogicValue _rawValue(LogicValue value) => value;
const _alternateRawCodec =
    LogicValueCodec<LogicValue>(decode: _rawValue, encode: _rawValue);

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

FixedPoint _constantFixed(int value) =>
    FixedPoint.constant(FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(value >> 4, 4),
        fraction: LogicValue.ofInt(value & 0xf, 4)));

class _StructuredConstantControl extends Module {
  late final ClockGate gate;
  late final Logic delayed;

  _StructuredConstantControl() {
    gate = ClockGate(addInput('clk', Logic()),
        enable: Const(0),
        reset: addInput('reset', Logic()),
        delayControlledSignals: true);
    delayed = gate.controlled<Logic>(_constantFixed(0x31),
        resetValue: _constantFixed(0x52));
    addOutput('result', width: 8) <= delayed;
  }
}

class _StructuredConstantToggle extends Module {
  late final ToggleGate<Logic> gate;

  _StructuredConstantToggle() {
    gate = ToggleGate<Logic>(
        data: _constantFixed(0x31),
        clk: addInput('clk', Logic()),
        reset: addInput('reset', Logic()),
        enable: addInput('enable', Logic()),
        resetValue: _constantFixed(0x52),
        clockGateControlIntf: ClockGateControlInterface(isPresent: false));
    addOutput('result', width: 8) <= gate.gatedData;
  }
}

class _StructuredConstantProtection extends Module {
  late final ParityTransmitter<Logic> tx;
  late final HammingEccTransmitter<Logic> ecc;

  _StructuredConstantProtection() {
    tx = ParityTransmitter<Logic>(_constantFixed(0x31));
    ecc = HammingEccTransmitter<Logic>(_constantFixed(0x31),
        hammingType: HammingType.secded);
    final rx = ParityReceiver<FixedPoint>(tx.transmission,
        dataSchema: FixedPoint(integerWidth: 3, fractionWidth: 4));
    final eccRx = HammingEccReceiver<FixedPoint>(ecc.transmission,
        hammingType: HammingType.secded,
        dataSchema: FixedPoint(integerWidth: 3, fractionWidth: 4));
    addOutput('original', width: 8) <= rx.originalData;
    addOutput('error') <= rx.error;
    addOutput('corrected', width: 8) <= eccRx.correctedData!;
    addOutput('eccError') <= eccRx.error;
  }
}

class _ControlledSignalReset<T extends Logic> extends Module {
  late final ClockGate gate;

  _ControlledSignalReset(T schema, {required bool typedReset}) {
    final data = schema.cloneTyped(name: 'payload')
      ..gets(addInput('data', Logic(width: schema.width), width: schema.width));
    final resetBits =
        addInput('resetData', Logic(width: schema.width), width: schema.width);
    final resetValue = typedReset
        ? (data.cloneTyped(name: 'resetPayload')..gets(resetBits))
        : resetBits;
    gate = ClockGate(addInput('clk', Logic()),
        enable: addInput('enable', Logic()),
        reset: addInput('reset', Logic()),
        delayControlledSignals: true);
    addOutput('result', width: schema.width) <=
        gate.controlled(data, resetValue: resetValue);
  }
}

class _ClockControlConfig extends Module {
  late final ClockGateControlInterface control;

  _ClockControlConfig(ClockGateControlInterface source) {
    control = addPairInterfacePorts(source, PairRole.consumer,
        uniquify: (name) => 'config_$name');
    final gate = ClockGate(addInput('clk', Logic()),
        enable: addInput('enable', Logic()), controlIntf: control);
    addOutput('out') <= gate.gatedClk;
  }
}

class _PortModule extends Module {}

class _CustomCorrectionReceiver extends ErrorCheckingReceiver<Logic> {
  final Logic? result;

  _CustomCorrectionReceiver(Logic schema, this.result)
      : super(Logic(width: schema.width + 1),
            codeWidth: 1,
            supportsErrorCorrection: true,
            name: 'custom_correction',
            dataSchema: schema);

  @override
  Logic calculateCorrectableError() => Const(0);

  @override
  Logic calculateUncorrectableError() => Const(0);

  @override
  Logic? calculateCorrectedData() => result;
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
        expect(samePayloadShape(dut.delayed, schema), isTrue);
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
      expect(samePayloadShape(dut.tx.input('data'), schema), isTrue);
      expect(samePayloadShape(dut.original, schema), isTrue);
      expect(dut.corrected == null, !(type?.hasCorrection ?? false));
      if (dut.corrected != null) {
        expect(samePayloadShape(dut.corrected!, schema), isTrue);
      }
      await _compare(dut, _protectionVectors(dut, type: type));
      expect(schema.value, before, reason: 'A schema is not an output driver.');
    });
  }
}

void main() {
  test('typed reset boundaries accept parent-renamed payloads', () {
    _ParentNamedPayload data() => _ParentNamedPayload(name: 'inputPayload');
    _ParentNamedPayload resetData({String suffix = 'bits'}) =>
        _ParentNamedPayload(name: 'resetPayload', suffix: suffix);
    final constructors = <void Function(_ParentNamedPayload)>[
      (reset) => ShiftRegister<_ParentNamedPayload>(data(),
          clk: Logic(), reset: Logic(), resetValue: reset, depth: 1),
      (reset) => ToggleGate<_ParentNamedPayload>(
          data: data(),
          clk: Logic(),
          reset: Logic(),
          enable: Logic(),
          resetValue: reset),
      (reset) => ClockGate(Logic(),
              enable: Logic(), reset: Logic(), delayControlledSignals: true)
          .controlled(data(), resetValue: reset),
    ];
    for (final construct in constructors) {
      expect(() => construct(resetData()), returnsNormally);
      expect(() => construct(resetData(suffix: 'other')),
          throwsA(anyOf(isA<ArgumentError>(), isA<RohdHclException>())));
    }
  });

  test('clock control retains parent-renamed reset values', () async {
    final dut = _ControlledSignalReset(_ParentNamedPayload(), typedReset: true);
    await _compare(dut, [
      Vector(
          {'clk': 0, 'enable': 0, 'reset': 1, 'data': 3, 'resetData': 5}, {}),
      Vector({'clk': 1}, {'result': 5}),
      Vector({'clk': 0, 'reset': 0, 'data': 7}, {'result': 5}),
      Vector({'clk': 1}, {'result': 7}),
    ]);
  });

  test('corrected data checks declared formats and allows packed bits', () {
    Logic schema() => FixedPoint(integerWidth: 3, fractionWidth: 4);
    expect(
        () => _CustomCorrectionReceiver(schema(),
            FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false)),
        throwsA(isA<RohdHclException>()));
    expect(() => _CustomCorrectionReceiver(schema(), Logic(width: 9)),
        throwsA(isA<RohdHclException>()));
    expect(() => _CustomCorrectionReceiver(schema(), null),
        throwsA(isA<RohdHclException>()));
    Logic array(LogicValueCodec<LogicValue> codec) =>
        TypedLogicArray<Logic, LogicValue>([2], ({name}) => Logic(width: 4),
            valueCodec: codec);
    expect(
        () => _CustomCorrectionReceiver(
            array(LogicValueCodec.logicValue), array(_alternateRawCodec)),
        throwsA(isA<RohdHclException>()));
    expect(
        () => _CustomCorrectionReceiver(
            schema(), FixedPoint(integerWidth: 3, fractionWidth: 4)),
        returnsNormally);
    expect(() => _CustomCorrectionReceiver(schema(), Logic(width: 8)),
        returnsNormally);
    expect(
        () => _CustomCorrectionReceiver(
            Logic(width: 8), FixedPoint(integerWidth: 3, fractionWidth: 4)),
        returnsNormally);
  });

  test('correction preserves payloads with parent-derived field names', () {
    expect(
        () => HammingEccReceiver<_ParentNamedPayload>(Logic(width: 13),
            hammingType: HammingType.secded, dataSchema: _ParentNamedPayload()),
        returnsNormally);
  });

  test('storage and protection reject changing payload clone metadata', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    _SecondCloneField source() => _SecondCloneField(first, second);

    expect(
        () => Fifo<Logic>(Logic(), Logic(),
            writeEnable: Logic(),
            writeData: source(),
            readEnable: Logic(),
            depth: 2),
        throwsA(isA<LogicConstructionException>()));
    expect(
        () => AsyncFifo<Logic>(
            writeClk: Logic(),
            readClk: Logic(),
            writeReset: Logic(),
            readReset: Logic(),
            writeEnable: Logic(),
            writeData: source(),
            readEnable: Logic(),
            depth: 2),
        throwsA(isA<LogicConstructionException>()));
    expect(() => ShiftRegister<Logic>(source(), clk: Logic(), depth: 1),
        throwsA(isA<LogicConstructionException>()));
    expect(
        () => ToggleGate<Logic>(
            enable: Logic(), data: source(), clk: Logic(), reset: Logic()),
        throwsA(isA<LogicConstructionException>()));
    expect(
        () => ParityReceiver<Logic>(Logic(width: 4),
            dataSchema: _SecondCloneField(first, second, preserveNext: false)),
        throwsA(isA<LogicConstructionException>()));
    expect(
        () => ClockGateControlInterface(additionalPorts: [
              _SecondCloneField(first, second,
                  preserveNext: false, name: 'config')
            ]).clone(),
        throwsA(isA<LogicConstructionException>()));
    final bad = _SecondCloneField(first, second, preserveNext: false);
    expect(() => condFlop<Logic>(Logic(), bad),
        throwsA(isA<LogicConstructionException>()));
    expect(() => swap<Logic>(Logic(), (bad, GfLogic(first))),
        throwsA(isA<LogicConstructionException>()));
  });

  tearDown(Simulator.reset);

  test('clock control preserves widened structured constants', () async {
    final dut = _StructuredConstantControl();
    expect(dut.delayed, isA<FixedPoint>());
    expect(dut.gate.inputs.values.whereType<FixedPoint>().length, 2);
    await _compare(dut, [
      Vector({'clk': 0, 'reset': 1}, {}),
      Vector({'clk': 1}, {'result': 0x52}),
      Vector({'clk': 0, 'reset': 0}, {}),
      Vector({'clk': 1}, {'result': 0x31}),
    ]);
  });

  test('toggle gate preserves widened structured constants', () async {
    final dut = _StructuredConstantToggle();
    expect(dut.gate.input('data'), isA<FixedPoint>());
    expect(dut.gate.input('resetValue'), isA<FixedPoint>());
    expect(dut.gate.gatedData, isA<FixedPoint>());
    await _compare(dut, [
      Vector({'clk': 0, 'reset': 1, 'enable': 0}, {}),
      Vector({'clk': 1}, {'result': 0x52}),
      Vector({'clk': 0, 'reset': 0, 'enable': 1}, {'result': 0x31}),
      Vector({'clk': 1}, {'result': 0x31}),
      Vector({'clk': 0, 'enable': 0}, {'result': 0x31}),
    ]);
  });

  test('error transmitter preserves widened structured constants', () async {
    final dut = _StructuredConstantProtection();
    expect(dut.tx.input('data'), isA<FixedPoint>());
    expect(dut.ecc.input('data'), isA<FixedPoint>());
    await _compare(dut, [
      Vector(
          {}, {'original': 0x31, 'error': 0, 'corrected': 0x31, 'eccError': 0})
    ]);
  });

  test('clock and toggle constant resets reject incompatible formats', () {
    final incompatible =
        FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    final gate = ClockGate(Logic(),
        enable: Logic(), reset: Logic(), delayControlledSignals: true);
    expect(
        () => gate.controlled<Logic>(_constantFixed(0x31),
            resetValue: incompatible),
        throwsArgumentError);
    expect(
        () => ToggleGate<Logic>(
            data: _constantFixed(0x31),
            clk: Logic(),
            reset: Logic(),
            enable: Logic(),
            resetValue: incompatible),
        throwsArgumentError);
  });
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

  test('clock-gate additional ports preserve structured configuration',
      () async {
    final control = ClockGateControlInterface(
      additionalPorts: [_Payload(name: 'gate_cfg')],
      gatedClockGenerator: (intf, clk, enable) =>
          clk & (intf.port('gate_cfg') as _Payload).elements[1][0],
    );
    final dut = _ClockControlConfig(control);
    expect(dut.input('config_gate_cfg'), isA<_Payload>());
    await _compare(dut, [
      Vector({'clk': 1, 'enable': 0, 'config_gate_cfg': 0}, {'out': 0}),
      Vector({'config_gate_cfg': 64}, {'out': 1}),
      Vector({'clk': 0}, {'out': 0}),
    ]);
  });

  test('clock-gate configuration supports typed output and packed bridge', () {
    final target = ClockGateControlInterface(
        additionalPorts: [_Payload(name: 'gate_cfg')]);
    final packed =
        PairInterface(portsFromProvider: [Logic(name: 'gate_cfg', width: 9)]);
    final consumer = _PortModule()
      ..addPairInterfaceFrom(target, packed, PairRole.consumer,
          uniquify: (name) => 'input_$name');
    expect(consumer.input('input_gate_cfg'), isA<_Payload>());

    final provider = _PortModule()
      ..addPairInterfacePorts(
          ClockGateControlInterface(
              additionalPorts: [_Payload(name: 'gate_cfg')]),
          PairRole.provider,
          uniquify: (name) => 'output_$name');
    expect(provider.output('output_gate_cfg'), isA<_Payload>());
  });

  test('clock-gate configuration validates only selected payloads', () {
    final target = ClockGateControlInterface(
        additionalPorts: [_Payload(name: 'gate_cfg')]);
    final source = PairInterface(portsFromProvider: [
      FixedPoint(integerWidth: 6, fractionWidth: 2, name: 'gate_cfg')
    ]);
    expect(
        () => _PortModule()
            .addPairInterfaceFrom(target, source, PairRole.consumer),
        throwsA(isA<PortTypeException>()));
    expect(
        () => _PortModule().addInterfaceFrom(target, source,
            inputTags: {PairDirection.fromConsumer}),
        returnsNormally);
  });

  test('controlled rejects incompatible declared reset formats', () {
    final gate = ClockGate(Logic(),
        enable: Logic(), reset: Logic(), delayControlledSignals: true);
    expect(
        () => gate.controlled(
              FixedPoint(integerWidth: 3, fractionWidth: 2),
              resetValue:
                  FixedPoint(integerWidth: 4, fractionWidth: 2, signed: false),
            ),
        throwsArgumentError);
  });

  for (final typedReset in [true, false]) {
    test('controlled registers ${typedReset ? 'typed' : 'packed'} reset',
        () async {
      final dut = _ControlledSignalReset(
          FixedPoint(integerWidth: 3, fractionWidth: 2),
          typedReset: typedReset);
      expect(dut.gate.input('payload_resetValue'),
          typedReset ? isA<FixedPoint>() : isNot(isA<LogicStructure>()));
      await _compare(dut, [
        Vector(
            {'clk': 0, 'enable': 0, 'reset': 1, 'data': 3, 'resetData': 5}, {}),
        Vector({'clk': 1}, {'result': 5}),
        Vector({'clk': 0, 'reset': 0, 'data': 7}, {'result': 5}),
        Vector({'clk': 1}, {'result': 7}),
        Vector({'clk': 0, 'reset': 1, 'resetData': 9}, {'result': 7}),
        Vector({'clk': 1}, {'result': 9}),
      ]);
    });
  }

  test('controlled registers an unpacked typed reset', () async {
    final schema = TypedLogicArray<_Payload, LogicValue>([2], _Payload.new,
        numUnpackedDimensions: 1);
    final dut = _ControlledSignalReset(schema, typedReset: true);
    expect(
        samePayloadShape(dut.gate.input('payload_resetValue'), schema), isTrue);
    await _compare(dut, [
      Vector(
          {'clk': 0, 'enable': 0, 'reset': 1, 'data': 3, 'resetData': 5}, {}),
      Vector({'clk': 1}, {'result': 5}),
      Vector({'clk': 0, 'reset': 0, 'data': 7}, {'result': 5}),
      Vector({'clk': 1}, {'result': 7}),
    ]);
  });

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
