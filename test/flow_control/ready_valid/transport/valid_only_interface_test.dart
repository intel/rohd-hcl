// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// valid_only_interface_test.dart
// Tests typed valid-only interface registration.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/bit_operations/selection/priority_mux.dart' as general;
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:test/test.dart';

enum _State { first, second }

class _Payload extends LogicStructure {
  _Payload({String? name})
      : super([Logic(name: 'low', width: 4), Logic(name: 'high', width: 4)],
            name: name ?? 'data');

  @override
  _Payload clone({String? name}) => _Payload(name: name ?? this.name);
}

class _WrongWidthClone extends Logic {
  _WrongWidthClone({super.name, super.width = 8});

  @override
  _WrongWidthClone clone({String? name}) =>
      _WrongWidthClone(name: name ?? this.name, width: width + 1);
}

class _EmptyModule extends Module {}

class _PassThrough<T extends Logic> extends Module {
  _PassThrough(ValidOnlyInterface<T> input, ValidOnlyInterface<T> output) {
    final localInput = addPairInterfacePorts(input, PairRole.consumer,
        uniquify: (name) => 'input_$name');
    final localOutput = addPairInterfacePorts(output, PairRole.provider,
        uniquify: (name) => 'output_$name');
    localOutput.data <= localInput.data;
    localOutput.valid <= localInput.valid;
  }
}

class _PayloadRegistration extends Module {
  _PayloadRegistration(Logic source, Logic destination,
      {required bool shared}) {
    final input = _Payload(name: 'input_data');
    final output = _Payload(name: 'output_data');
    if (shared) {
      connectTypedPayloadPorts(this,
          name: 'input_data', local: input, source: source, input: true);
      connectTypedPayloadPorts(this,
          name: 'output_data',
          local: output,
          source: destination,
          output: true);
    } else {
      final bridge = input.cloneTyped(name: 'input_data_input_bridge')
        ..gets(source);
      input <= addTypedInput('input_data', bridge);
      final registered = addTypedPayloadOutput(this, 'output_data', output);
      registered <= output;
      destination <= registered;
    }
    output <= input;
  }
}

class _PayloadRegistrationTop extends Module {
  _PayloadRegistrationTop({required bool shared}) {
    final source = addInput('source', Logic(width: 8), width: 8);
    final destination = Logic(width: 8);
    _PayloadRegistration(source, destination, shared: shared);
    addOutput('result', width: 8) <= destination;
  }
}

class _Retyped<T extends Logic> extends Module {
  _Retyped(ValidOnlyInterface<T> target, ValidOnlyInterface<Logic> source) {
    addPairInterfaceFrom(target, source, PairRole.consumer);
  }
}

class _ReadyRetyped<T extends Logic> extends Module {
  _ReadyRetyped(
      ReadyAndValidInterface<T> target, ReadyAndValidInterface<Logic> source) {
    addPairInterfaceFrom(target, source, PairRole.consumer);
  }
}

class _RoleRegistration extends Module {
  _RoleRegistration(PairInterface target, PairInterface source, PairRole role) {
    addPairInterfaceFrom(target, source, role);
  }
}

FixedPoint _constantFixed() => FixedPoint.constant(
    FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(3, 4), fraction: LogicValue.ofInt(1, 4)),
    name: 'data');

class _ConstantValidPort extends Module {
  _ConstantValidPort(ValidOnlyInterface<Logic> source) {
    final local = addPairInterfaceFrom(
        ValidOnlyInterface(
            FixedPoint(integerWidth: 3, fractionWidth: 4, name: 'data')),
        source,
        PairRole.consumer);
    addOutput('out', width: 8) <= local.data;
  }
}

class _ConstantReadyPort extends Module {
  _ConstantReadyPort(ReadyAndValidInterface<Logic> source) {
    final local = addPairInterfaceFrom(
        ReadyAndValidInterface(
            FixedPoint(integerWidth: 3, fractionWidth: 4, name: 'data')),
        source,
        PairRole.consumer);
    addOutput('out', width: 8) <= local.data;
  }
}

class _ConstantInterfaces extends Module {
  late final _ConstantValidPort validOnly;
  late final _ConstantReadyPort readyValid;

  _ConstantInterfaces() {
    final validSource = ValidOnlyInterface<Logic>(_constantFixed());
    validSource.valid <= addInput('validOnly', Logic());
    validOnly = _ConstantValidPort(validSource);
    final readySource = ReadyAndValidInterface<Logic>(_constantFixed());
    readySource.valid <= addInput('readyValid', Logic());
    readyValid = _ConstantReadyPort(readySource);
    addOutput('first', width: 8) <= validOnly.output('out');
    addOutput('second', width: 8) <= readyValid.output('out');
  }
}

class _ScalarValidConsumer extends Module {
  _ScalarValidConsumer(ValidOnlyInterface<Logic> source) {
    final local = addPairInterfacePorts(source, PairRole.consumer);
    addOutput('out', width: source.data.width) <= local.data;
  }
}

class _ScalarReadyConsumer extends Module {
  _ScalarReadyConsumer(ReadyValidInterface<Logic> source) {
    final local = addPairInterfacePorts(source, PairRole.consumer);
    local.ready <= Const(1);
    addOutput('out', width: source.data.width) <= local.data;
  }
}

class _ScalarConstantHarness extends Module {
  _ScalarConstantHarness(
      {ReadyValidInterface<Logic> Function(Logic)? readyValid}) {
    final valid = addInput('validIn', Logic());
    final constant = Const(LogicValue.ofString('10xz'));
    if (readyValid != null) {
      final source = readyValid(constant);
      source.valid <= valid;
      addOutput('out', width: 4) <= _ScalarReadyConsumer(source).output('out');
    } else {
      final source = ValidOnlyInterface<Logic>(constant);
      source.valid <= valid;
      addOutput('out', width: 4) <= _ScalarValidConsumer(source).output('out');
    }
  }
}

class _ScalarConstantAdapter extends Module {
  _ScalarConstantAdapter() {
    final source = ReadyThenValidInterface<Logic>(Const(0xa5, width: 8));
    source.valid <= addInput('validIn', Logic());
    final downstream = source.toDownstreamReadyAndValid(
        addInput('clk', Logic()), addInput('reset', Logic()));
    downstream.ready <= addInput('readyOut', Logic());
    addOutput('out', width: 8) <= downstream.data;
    addOutput('validOut') <= downstream.valid;
  }
}

class _InOutRegistration extends Module {
  _InOutRegistration(PairInterface source,
      {bool input = false, bool output = false}) {
    addInterfacePorts(source,
        inputTags: input ? [PairDirection.fromProvider] : null,
        outputTags: output ? [PairDirection.fromProvider] : null,
        inOutTags: [PairDirection.fromProvider]);
  }
}

class _FieldPayload extends LogicStructure {
  final BinaryExtensionField field;

  _FieldPayload(this.field, {String name = 'data'})
      : super([GfLogic(field, name: 'field')], name: name);

  @override
  _FieldPayload clone({String? name}) =>
      _FieldPayload(field, name: name ?? this.name);
}

class _DomainLogic extends Logic implements PayloadShapeMetadata {
  @override
  final String payloadShapeMetadata;

  _DomainLogic(this.payloadShapeMetadata, {super.name}) : super(width: 3);

  @override
  _DomainLogic clone({String? name}) =>
      _DomainLogic(payloadShapeMetadata, name: name ?? this.name);
}

class _MisclonedField extends GfLogic {
  final BinaryExtensionField cloneField;

  _MisclonedField(super.field, this.cloneField, {super.name});

  @override
  _MisclonedField clone({String? name}) =>
      _MisclonedField(cloneField, cloneField, name: name ?? this.name);
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

class _FieldMuxHarness extends Module {
  _FieldMuxHarness(BinaryExtensionField first, BinaryExtensionField second) {
    final selector = addInput('selector', Logic());
    final input = addInput('inputData', Logic(width: 3), width: 3);
    final a = GfLogic.of(input, field: first);
    final b = GfLogic.of(input, field: second);
    final firstMux = general.PriorityMux<GfLogic>(selector, [a], a);
    final secondMux = general.PriorityMux<GfLogic>(selector, [b], b);
    addOutput('first', width: 3) <= firstMux.result;
    addOutput('second', width: 3) <= secondMux.result;
  }
}

void main() {
  test('flow-control interface clones reject changed packed widths', () {
    expect(() => ValidOnlyInterface<Logic>(_WrongWidthClone()).clone(),
        throwsA(isA<RohdHclException>()));
    expect(() => ReadyValidInterface<Logic>(_WrongWidthClone()).clone(),
        throwsA(isA<RohdHclException>()));
    expect(
        () => ClockGateControlInterface(
            additionalPorts: [_WrongWidthClone(name: 'control')]).clone(),
        throwsA(isA<RohdHclException>()));
  });

  test('typed output registration rejects changed packed widths', () {
    expect(
        () => addTypedPayloadOutput<Logic>(
            _EmptyModule(), 'out', _WrongWidthClone()),
        throwsA(isA<RohdHclException>()));
    expect(
        () => addTypedPayloadOutput<Logic>(
            _EmptyModule(), 'out', Logic(width: 8),
            generator: ({name}) => Logic(name: name, width: 9)),
        throwsA(isA<RohdHclException>()));
    expect(
        addTypedPayloadOutput<Logic>(_EmptyModule(), 'out', Const(0, width: 8),
            generator: ({name}) => Logic(name: name, width: 8)).width,
        8);
  });
  tearDown(Simulator.reset);

  final readyValidTypes = <String, ReadyValidInterface<Logic> Function(Logic)?>{
    'valid-only': null,
    'ready/valid': ReadyValidInterface<Logic>.new,
    'ready-and-valid': ReadyAndValidInterface<Logic>.new,
    'ready-then-valid': ReadyThenValidInterface<Logic>.new,
    'valid-then-ready': ValidThenReadyInterface<Logic>.new,
    'irrevocable': IrrevocableReadyValidInterface<Logic>.new,
  };
  for (final entry in readyValidTypes.entries) {
    test('${entry.key} accepts scalar constants', () async {
      final dut = _ScalarConstantHarness(readyValid: entry.value);
      await dut.build();
      final vectors = [
        Vector({'validIn': 1}, {'out': LogicValue.ofString('10xz')})
      ];
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
    });
  }

  test('interface clones reject changed payload metadata', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    final validOnly =
        ValidOnlyInterface<Logic>(_MisclonedField(first, second, name: 'data'));
    expect(validOnly.clone, throwsA(isA<LogicConstructionException>()));
    for (final factory in readyValidTypes.values
        .whereType<ReadyValidInterface<Logic> Function(Logic)>()) {
      final channel = factory(_MisclonedField(first, second, name: 'data'));
      expect(channel.clone, throwsA(isA<LogicConstructionException>()));
    }
  });

  test('typed interface registration rejects changed bridge and output clones',
      () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    for (final role in [PairRole.consumer, PairRole.provider]) {
      expect(
          () => _RoleRegistration(
              ValidOnlyInterface<Logic>(
                  _MisclonedField(first, second, name: 'data')),
              ValidOnlyInterface<Logic>(Logic(name: 'data', width: 3)),
              role),
          throwsA(isA<LogicConstructionException>()));
      expect(
          () => _RoleRegistration(
              ReadyValidInterface<Logic>(
                  _MisclonedField(first, second, name: 'data')),
              ReadyValidInterface<Logic>(Logic(name: 'data', width: 3)),
              role),
          throwsA(isA<LogicConstructionException>()));
    }
    expect(
        () => _Retyped(
            ValidOnlyInterface<Logic>(
                _SecondCloneField(first, second, name: 'data')),
            ValidOnlyInterface<Logic>(Logic(name: 'data', width: 3))),
        throwsA(anyOf(
            isA<LogicConstructionException>(), isA<PortTypeException>())));
    expect(
        () => _ReadyRetyped(
            ReadyAndValidInterface<Logic>(
                _SecondCloneField(first, second, name: 'data')),
            ReadyAndValidInterface<Logic>(Logic(name: 'data', width: 3))),
        throwsA(anyOf(
            isA<LogicConstructionException>(), isA<PortTypeException>())));
  });

  test('ready/valid storage rejects changed downstream payload clones', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    ReadyValidInterface<Logic> upstream() =>
        ReadyValidInterface<Logic>(Logic(name: 'data', width: 3));
    ReadyValidInterface<Logic> downstream() => ReadyValidInterface<Logic>(
        _MisclonedField(first, second, name: 'data'));

    expect(
        () => ReadyValidRegister<Logic>(
            clk: Logic(),
            reset: Logic(),
            upstream: upstream(),
            downstream: downstream()),
        throwsA(isA<LogicConstructionException>()));
    expect(
        () => ReadyValidFallThroughBuffer<Logic>(
            clk: Logic(),
            reset: Logic(),
            upstream: upstream(),
            downstream: downstream()),
        throwsA(isA<LogicConstructionException>()));
    expect(
        () => ReadyValidElasticPipeline<Logic>(
            clk: Logic(),
            reset: Logic(),
            upstream: upstream(),
            downstream: downstream(),
            depth: 1),
        throwsA(isA<LogicConstructionException>()));
    expect(
        () => ReadyValidQueue<Logic>(
            clk: Logic(),
            reset: Logic(),
            upstream: upstream(),
            downstream: downstream(),
            depth: 1),
        throwsA(isA<LogicConstructionException>()));
  });

  test('ready-then-valid adapter accepts a scalar constant', () async {
    final dut = _ScalarConstantAdapter();
    await dut.build();
    final vectors = [
      Vector({'clk': 0, 'reset': 1, 'validIn': 0, 'readyOut': 0}, {}),
      Vector({'clk': 1}, {'validOut': 0}),
      Vector({'clk': 0, 'reset': 0, 'validIn': 1}, {}),
      Vector({'clk': 1}, {'validOut': 1, 'out': 0xa5}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('typed interfaces accept matching structured constant sources',
      () async {
    final dut = _ConstantInterfaces();
    expect(dut.validOnly.input('data'), isA<FixedPoint>());
    expect(dut.readyValid.input('data'), isA<FixedPoint>());
    await dut.build();
    final vectors = [
      Vector({'validOnly': 1, 'readyValid': 1}, {'first': 0x31, 'second': 0x31})
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
    final incompatible = FixedPoint(
        integerWidth: 4, fractionWidth: 4, signed: false, name: 'data');
    expect(
        () => _Retyped(ValidOnlyInterface(incompatible),
            ValidOnlyInterface<Logic>(_constantFixed())),
        throwsA(isA<PortTypeException>()));
    expect(
        () => _ReadyRetyped(ReadyAndValidInterface(incompatible.clone()),
            ReadyAndValidInterface<Logic>(_constantFixed())),
        throwsA(isA<PortTypeException>()));
  });

  test('registers structured payload ports in both directions', () async {
    final module = _PassThrough(
        ValidOnlyInterface(_Payload()), ValidOnlyInterface(_Payload()));
    await module.build();
    expect(module.input('input_data'), isA<_Payload>());
    expect(module.output('output_data'), isA<_Payload>());
    final vectors = [
      Vector({'input_data': 0xa5, 'input_valid': 1},
          {'output_data': 0xa5, 'output_valid': 1}),
      Vector({'input_data': 0x3c, 'input_valid': 0},
          {'output_data': 0x3c, 'output_valid': 0}),
    ];
    await SimCompare.checkFunctionalVector(module, vectors);
    SimCompare.checkIverilogVector(module, vectors);
  });

  test('shared payload registration preserves manual wiring RTL', () async {
    final shared = _PayloadRegistrationTop(shared: true);
    final manual = _PayloadRegistrationTop(shared: false);
    await shared.build();
    await manual.build();
    String withoutTimestamp(Module module) => module
        .dumpSystemVerilog()
        .replaceFirst(RegExp(r' \* Generation time:.*\n'), '');
    expect(withoutTimestamp(shared), withoutTimestamp(manual));
  });

  test('preserves unpacked typed array schemas', () async {
    TypedLogicArray<_Payload, LogicValue> array() =>
        TypedLogicArray<_Payload, LogicValue>(
          [2, 2],
          _Payload.new,
          numUnpackedDimensions: 1,
          name: 'data',
        );
    final module =
        _PassThrough(ValidOnlyInterface(array()), ValidOnlyInterface(array()));
    await module.build();
    final input =
        module.input('input_data') as TypedLogicArray<_Payload, LogicValue>;
    final output =
        module.output('output_data') as TypedLogicArray<_Payload, LogicValue>;
    expect(input.dimensions, [2, 2]);
    expect(output.numUnpackedDimensions, 1);
    expect(module.dumpSystemVerilog(), contains('module'));
  });

  test('allows packed bridges and rejects incompatible structured layouts',
      () async {
    final bridged = _Retyped(ValidOnlyInterface(_Payload()),
        ValidOnlyInterface(Logic(name: 'data', width: 8)));
    await bridged.build();
    expect(bridged.input('data'), isA<_Payload>());
    expect(
        () => _Retyped(
              ValidOnlyInterface(_Payload()),
              ValidOnlyInterface(LogicStructure([
                Logic(name: 'other', width: 4),
                Logic(name: 'high', width: 4),
              ], name: 'data')),
            ),
        throwsA(isA<PortTypeException>()));
  });

  test('valid-only ports preserve field domains and allow packed bridges', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    expect(
      () => _Retyped(ValidOnlyInterface(GfLogic(first, name: 'data')),
          ValidOnlyInterface<Logic>(GfLogic(second, name: 'data'))),
      throwsA(isA<PortTypeException>()),
    );
    expect(
      () => _Retyped(ValidOnlyInterface(_FieldPayload(first)),
          ValidOnlyInterface<Logic>(_FieldPayload(second))),
      throwsA(isA<PortTypeException>()),
    );
    expect(
      () => _ReadyRetyped(ReadyAndValidInterface(GfLogic(first, name: 'data')),
          ReadyAndValidInterface<Logic>(GfLogic(second, name: 'data'))),
      throwsA(isA<PortTypeException>()),
    );
    final compatible = _Retyped(
        ValidOnlyInterface(GfLogic(first, name: 'data')),
        ValidOnlyInterface<Logic>(GfLogic(first, name: 'data')));
    final packed = _Retyped(ValidOnlyInterface(GfLogic(first, name: 'data')),
        ValidOnlyInterface<Logic>(Logic(name: 'data', width: 3)));
    expect(compatible.input('data'), isA<GfLogic>());
    expect(packed.input('data'), isA<GfLogic>());
  });

  test('payload shapes and identities distinguish semantic formats', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    final fieldA = _FieldPayload(first);
    final fieldB = _FieldPayload(second);
    expect(sameRohdPayloadShape(fieldA, fieldA.clone()), isTrue);
    expect(sameRohdPayloadShape(fieldA, fieldB), isFalse);
    expect(payloadShapeIdentity(fieldA), isNot(payloadShapeIdentity(fieldB)));
    TypedLogicArray<GfLogic, LogicValue> array(BinaryExtensionField field) =>
        TypedLogicArray<GfLogic, LogicValue>(
            [2], ({name}) => GfLogic(field, name: name));
    expect(sameRohdPayloadShape(array(first), array(second)), isFalse);
    expect(payloadShapeIdentity(array(first)),
        isNot(payloadShapeIdentity(array(second))));

    final signed = FixedPoint(integerWidth: 2, fractionWidth: 2);
    final unsigned =
        FixedPoint(integerWidth: 3, fractionWidth: 2, signed: false);
    expect(sameRohdPayloadShape(signed, unsigned), isFalse);
    expect(payloadShapeIdentity(signed), isNot(payloadShapeIdentity(unsigned)));

    final normal = FloatingPoint(exponentWidth: 3, mantissaWidth: 2);
    final explicit =
        FloatingPoint(exponentWidth: 3, mantissaWidth: 2, explicitJBit: true);
    expect(sameRohdPayloadShape(normal, explicit), isFalse);
    expect(payloadShapeIdentity(normal), isNot(payloadShapeIdentity(explicit)));
  });

  test('typed operations reject incompatible same-width field operands', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    expect(
      () => general.PriorityMux<GfLogic>(
          Logic(), [GfLogic(second)], GfLogic(first)),
      throwsArgumentError,
    );
    expect(
      () => Ripple<GfLogic>(
          [GfLogic(first), GfLogic(second)], (left, right) => left + right),
      throwsA(isA<RohdHclException>()),
    );
  });

  test('typed arrays compare semantic formats at every element', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    TypedLogicArray<GfLogic, LogicValue> array({required bool mixed}) =>
        TypedLogicArray<GfLogic, LogicValue>(
          [2],
          ({name}) => GfLogic(mixed && name!.endsWith('1') ? second : first,
              name: name),
        );
    final uniform = array(mixed: false);
    final mixed = array(mixed: true);
    expect(sameRohdPayloadShape(uniform, mixed), isFalse);
    expect(payloadShapeIdentity(uniform), isNot(payloadShapeIdentity(mixed)));
    expect(
      () => general.PriorityMux<TypedLogicArray<GfLogic, LogicValue>>(
          Logic(), [mixed], uniform),
      throwsArgumentError,
    );
  });

  test('custom payload domains participate in typed connection checks', () {
    expect(
      () => _Retyped(
        ValidOnlyInterface(_DomainLogic('custom_a', name: 'data')),
        ValidOnlyInterface<Logic>(_DomainLogic('custom_b', name: 'data')),
      ),
      throwsA(isA<PortTypeException>()),
    );
    expect(
      () => _Retyped(
        ValidOnlyInterface(_DomainLogic('custom_a', name: 'data')),
        ValidOnlyInterface<Logic>(
            LogicEnum<_State>(_State.values, width: 3, name: 'data')),
      ),
      throwsA(isA<PortTypeException>()),
    );
    final compatible = _Retyped(
      ValidOnlyInterface(_DomainLogic('custom_a', name: 'data')),
      ValidOnlyInterface<Logic>(_DomainLogic('custom_a', name: 'data')),
    );
    expect(compatible.input('data'), isA<_DomainLogic>());
  });

  test('provider inOut registration rejects non-net payload ports', () {
    expect(() => _InOutRegistration(ValidOnlyInterface(_Payload())),
        throwsA(isA<PortTypeException>()));
    expect(() => _InOutRegistration(ReadyAndValidInterface(_Payload())),
        throwsA(isA<PortTypeException>()));
  });

  test('provider inOut cannot overlap input or output registration', () {
    for (final makeInterface in <PairInterface Function()>[
      () => ValidOnlyInterface(_Payload()),
      () => ReadyAndValidInterface(_Payload()),
    ]) {
      expect(() => _InOutRegistration(makeInterface(), input: true),
          throwsA(isA<PortTypeException>()));
      expect(() => _InOutRegistration(makeInterface(), output: true),
          throwsA(isA<PortTypeException>()));
    }
  });

  test('different field domains generate distinct compatible RTL', () async {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    final dut = _FieldMuxHarness(first, second);
    await dut.build();
    final vectors = [
      Vector({'selector': 0, 'inputData': 5}, {'first': 5, 'second': 5}),
      Vector({'selector': 1, 'inputData': 3}, {'first': 3, 'second': 3}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });
}
