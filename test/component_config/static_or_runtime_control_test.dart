// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_control_test.dart
// Tests for static-or-runtime control API compatibility.
//
// 2026 September 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart'
    show
        BinaryExtensionField,
        BinaryPolynomial,
        FixedPoint,
        FixedPointValue,
        GfLogic;
import 'package:rohd_hcl/src/exceptions.dart';
// This test intentionally imports the deprecated compatibility path.
// ignore: deprecated_member_use_from_same_package
import 'package:rohd_hcl/src/static_or_runtime_parameter.dart';
import 'package:test/test.dart';

class _TestModule extends Module {
  _TestModule({super.definitionName});
}

class _MisclonedField extends GfLogic {
  final BinaryExtensionField cloneField;

  _MisclonedField(super.field, this.cloneField, {super.name});

  @override
  _MisclonedField clone({String? name}) =>
      _MisclonedField(cloneField, cloneField, name: name ?? this.name);
}

class _MisclonedRecord extends LogicStructure {
  final BinaryExtensionField cloneField;

  _MisclonedRecord(BinaryExtensionField field, this.cloneField,
      {bool withConstant = true, String? name})
      : super([
          if (withConstant) Const(1) else Logic(name: 'flag'),
          GfLogic(field, name: 'field'),
        ], name: name ?? 'record');

  @override
  _MisclonedRecord clone({String? name}) =>
      _MisclonedRecord(cloneField, cloneField,
          withConstant: false, name: name ?? this.name);
}

void main() {
  tearDown(Simulator.reset);

  test('legacy static-or-runtime import path remains available', () {
    final parameter =
        StaticOrRuntimeParameter(name: 'enabled', staticConfig: true);

    expect(parameter.staticConfig, isTrue);
  });

  test('typed runtime input preserves shape, source, and values', () {
    final source = LogicArray([2], 4);
    final control = StaticOrRuntimeControl<int>(
        name: 'setting', staticConfig: 0, runtimeConfig: source);
    final module = _TestModule();
    final input = control.resolveTyped(module,
        staticToLogic: (value) => Const(value, width: 8));

    expect(input, isA<LogicArray>());
    expect(module.inputSource('setting'), same(source));
    expect(control.getTypedRuntimeInput(module), same(input));
    source.put(0xa5);
    expect(input.value.toInt(), 0xa5);
  });

  test('typed control can reuse a directly registered typed input', () {
    final source = LogicArray([2], 4);
    final module = _TestModule();
    final input = module.addTypedInput<Logic>('setting', source);
    final control = StaticOrRuntimeControl<int>(
        name: 'setting', staticConfig: 0, runtimeConfig: source);

    expect(control.getTypedRuntimeInput(module), same(input));
  });

  test('typed resolution handles static values and constant runtime signals',
      () {
    final module = _TestModule();
    const fixed = StaticOrRuntimeControl<int>(name: 'fixed', staticConfig: 5);
    final fixedValue = fixed.resolveTyped(module,
        staticToLogic: (value) => Const(value, width: 8));
    final runtime = StaticOrRuntimeControl<int>(
        name: 'runtime', staticConfig: 0, runtimeConfig: Const(7, width: 8));
    final input = runtime.getTypedRuntimeInput(module)!;

    expect(fixedValue.value.toInt(), 5);
    expect(module.inputs.keys, ['runtime']);
    expect(input, isNot(isA<Const>()));
    expect(input.value.toInt(), 7);
  });

  test('typed runtime input preserves structures containing constants',
      () async {
    final source = FixedPoint.constant(FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(3, 4), fraction: LogicValue.ofInt(1, 4)));
    final control = StaticOrRuntimeControl<int>(
        name: 'setting', staticConfig: 0, runtimeConfig: source);
    final module = _TestModule();
    final input = control.getTypedRuntimeInput(module);
    expect(input, isA<FixedPoint>());
    final fixedInput = input! as FixedPoint;
    expect(fixedInput.signed, isTrue);
    expect(fixedInput.integerWidth, 3);
    expect(fixedInput.fractionWidth, 4);
    expect(input.value, source.value);
    expect(module.inputSource('setting'), same(source));
    expect(control.getTypedRuntimeInput(module), same(input));
    final rebound = control.forChild(module, name: 'childSetting');
    final child = _TestModule();
    expect(rebound.getTypedRuntimeInput(child), isA<FixedPoint>());
    expect(child.inputSource('childSetting'), same(input));
    module.addOutput('value', width: 8) <= input;
    final parent = _TestModule(definitionName: 'constant_control_parent');
    parent.addOutput('result', width: 8) <= module.output('value');
    await parent.build();
    final vectors = [
      Vector({}, {'result': 0x31})
    ];
    await SimCompare.checkFunctionalVector(parent, vectors);
    SimCompare.checkIverilogVector(parent, vectors);
  });

  test('typed runtime input rejects flattened constant-containing structures',
      () {
    final source = FixedPoint.constant(FixedPointValue.withSignedness(
        integer: LogicValue.ofInt(3, 4), fraction: LogicValue.ofInt(1, 4)));
    final control = StaticOrRuntimeControl<int>(
        name: 'setting', staticConfig: 0, runtimeConfig: source);
    final module = _TestModule();
    expect(control.getRuntimeInput(module), isNot(isA<FixedPoint>()));
    expect(() => control.getTypedRuntimeInput(module),
        throwsA(isA<RohdHclException>()));
  });

  test('typed input rejects an existing flattened input', () {
    final source = LogicArray([2], 4);
    final module = _TestModule();
    final control = StaticOrRuntimeControl<int>(
        name: 'setting', staticConfig: 0, runtimeConfig: source);
    expect(control.getRuntimeInput(module), isNot(isA<LogicArray>()));

    expect(() => control.getTypedRuntimeInput(module),
        throwsA(isA<RohdHclException>()));
  });

  test('typed inputs reject clones with incompatible semantic metadata', () {
    final first =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final second =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    final source = _MisclonedField(first, second);
    final control = StaticOrRuntimeControl<int>(
        name: 'setting', staticConfig: 0, runtimeConfig: source);
    expect(() => control.getTypedRuntimeInput(_TestModule()),
        throwsA(isA<PortTypeException>()));

    expect(() => _TestModule().addTypedInput<Logic>('setting', source),
        throwsA(isA<PortTypeException>()));

    final structured = StaticOrRuntimeControl<int>(
        name: 'setting',
        staticConfig: 0,
        runtimeConfig: _MisclonedRecord(first, second));
    expect(() => structured.getTypedRuntimeInput(_TestModule()),
        throwsA(isA<PortTypeException>()));
  });

  test('requiring a new input preserves duplicate-port errors', () {
    final source = Logic(width: 8);
    final module = _TestModule();
    final control = StaticOrRuntimeControl<int>(
        name: 'setting', staticConfig: 0, runtimeConfig: source)
      ..getTypedRuntimeInput(module);

    expect(() => control.getTypedRuntimeInput(module, reuseExisting: false),
        throwsA(isA<UnavailableReservedNameException>()));
  });
}
