// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_control_test.dart
// Tests for composing and selecting static or runtime controls.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _TestModule extends Module {}

class _TypedSelectHarness extends Module {
  late final Logic selected;

  _TypedSelectHarness(Logic schema) {
    final inputs = List.generate(2, (index) {
      final bits = addInput('data$index', Logic(width: schema.width),
          width: schema.width);
      return schema.cloneTyped(name: 'value$index')..gets(bits);
    });
    final selector = addInput('sel', Logic());
    selected = StaticOrRuntimeParameter.runtime(selector, name: 'sel')
        .select<Logic>(inputs[0], inputs[1]);
    addOutput('out', width: schema.width) <= selected;
  }
}

class _ConstantSelectHarness extends Module {
  late final Logic selected;

  _ConstantSelectHarness() {
    FixedPoint fixed(int value) =>
        FixedPoint.constant(FixedPointValue.withSignedness(
            integer: LogicValue.ofInt(value >> 4, 4),
            fraction: LogicValue.ofInt(value & 0xf, 4)));
    selected = StaticOrRuntimeParameter.runtime(addInput('sel', Logic()),
            name: 'select')
        .select<Logic>(fixed(0x12), fixed(0x34));
    addOutput('out', width: 8) <= selected;
  }
}

class _ControlStructure extends LogicStructure {
  final Logic bits;

  _ControlStructure() : this._(Logic(width: 2));

  _ControlStructure._(this.bits) : super([bits]);

  @override
  _ControlStructure clone({String? name}) => _ControlStructure();
}

void main() {
  tearDown(Simulator.reset);

  test('runtime selection retains widened structured constants', () async {
    final dut = _ConstantSelectHarness();
    expect(dut.selected, isA<FixedPoint>());
    await dut.build();
    final vectors = [
      Vector({'sel': 0}, {'out': 0x34}),
      Vector({'sel': 1}, {'out': 0x12}),
      Vector({'sel': LogicValue.x}, {'out': LogicValue.ofString('00x10xx0')}),
    ];
    await SimCompare.checkFunctionalVector(dut, vectors);
    SimCompare.checkIverilogVector(dut, vectors);
  });

  test('typed boolean constructors preserve values and validate width', () {
    final signal = Logic(name: 'source');
    final staticControl = StaticOrRuntimeParameter.staticValue(value: true);
    final runtime = StaticOrRuntimeParameter.runtime(signal, name: 'enable');
    expect(staticControl.staticConfig, isTrue);
    expect(staticControl.isRuntime, isFalse);
    expect(runtime.name, 'enable');
    expect(runtime.runtimeConfig, same(signal));
    expect(
        StaticOrRuntimeParameter.fromLogic(signal, fallbackName: 'fallback')
            .name,
        'source');
    expect(
        StaticOrRuntimeParameter.fromLogic(Logic(), fallbackName: 'fallback')
            .name,
        'fallback');
    expect(
        () => StaticOrRuntimeParameter.runtime(Logic(width: 2), name: 'enable'),
        throwsA(isA<RohdHclException>()));
  });

  test('rebinding retains a static boolean and creates no input', () {
    final parent = _TestModule();
    final control =
        StaticOrRuntimeParameter(name: 'enable', staticConfig: true);
    final child = control.forChild(parent);

    expect(child, isA<StaticOrRuntimeParameter>());
    expect(child.staticConfig, isTrue);
    expect(child.isRuntime, isFalse);
    expect(parent.inputs, isEmpty);
  });

  test('rebinding creates and forwards an internal runtime input', () {
    final external = Logic(width: 3);
    final parent = _TestModule();
    final child = _TestModule();
    final control = StaticOrRuntimeControl<int>(
        name: 'limit', staticConfig: 7, runtimeConfig: external);
    final rebound = control.forChild(parent, name: 'childLimit');

    expect(parent.inputSource('limit'), same(external));
    expect(rebound.staticConfig, 7);
    expect(rebound.runtimeConfig, same(parent.input('limit')));
    rebound.getRuntimeInput(child);
    expect(child.inputSource('childLimit'), same(parent.input('limit')));
    expect(control.getRuntimeInput(parent), same(parent.input('limit')));
  });

  test('dynamic factories preserve existing typed controls', () {
    final signal = Logic();
    final original = StaticOrRuntimeControl<bool>(
        name: 'original', staticConfig: true, runtimeConfig: signal);
    final boolean = StaticOrRuntimeParameter.ofDynamic(original);
    expect(boolean.name, 'original');
    expect(boolean.runtimeConfig, same(signal));

    final generic = StaticOrRuntimeControl<bool>.ofDynamic(original,
        name: 'renamed',
        defaultValue: false,
        convertStatic: (value) => value as bool);
    expect(generic.name, 'renamed');
    expect(generic.staticConfig, isTrue);
    expect(generic.runtimeConfig, same(signal));
    expect(
        () => StaticOrRuntimeParameter.ofDynamic(StaticOrRuntimeControl<bool>(
            name: 'wide', staticConfig: false, runtimeConfig: Logic(width: 2))),
        throwsA(isA<RohdHclException>()));
  });

  test('selection prunes static controls and propagates unknown runtime values',
      () {
    final whenTrue = Logic()..put(1);
    final whenFalse = Logic()..put(0);
    final staticTrue =
        StaticOrRuntimeParameter(name: 'select', staticConfig: true);
    final staticFalse = StaticOrRuntimeParameter(name: 'select');
    expect(staticTrue.select(whenTrue, whenFalse), same(whenTrue));
    expect(staticFalse.select(whenTrue, whenFalse), same(whenFalse));

    final select = Logic();
    final parent = _TestModule();
    final control =
        StaticOrRuntimeParameter(name: 'select', runtimeConfig: select);
    final result = control.select(whenTrue, whenFalse, module: parent);
    expect(parent.inputSource('select'), same(select));
    select.put(0);
    expect(result.value, LogicValue.zero);
    select.put(1);
    expect(result.value, LogicValue.one);
    select.put(LogicValue.x);
    expect(result.value, LogicValue.x);
    select.put(LogicValue.z);
    expect(result.value, LogicValue.x);

    final constants = control.select<Logic>(Const(1), Const(0));
    select.put(1);
    expect(constants.value, LogicValue.one);
    expect(() => staticTrue.select(Logic(width: 2), Logic()),
        throwsA(isA<PortWidthMismatchException>()));
  });

  test('typed selection validates semantic formats and accepts packed bridges',
      () {
    final signed = FixedPoint(integerWidth: 3, fractionWidth: 4);
    final unsigned =
        FixedPoint(integerWidth: 4, fractionWidth: 4, signed: false);
    final runtime = StaticOrRuntimeParameter.runtime(Logic(), name: 'sel');
    final fixed = StaticOrRuntimeParameter.staticValue(value: true);
    expect(() => runtime.select<Logic>(signed, unsigned), throwsArgumentError);
    expect(() => fixed.select<Logic>(signed, unsigned), throwsArgumentError);

    final firstField =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(11)));
    final secondField =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(13)));
    final firstElement = GfLogic(firstField);
    final secondElement = GfLogic(firstField);
    expect(
        StaticOrRuntimeParameter.runtime(Const(1), name: 'sel')
            .select<Logic>(firstElement, secondElement),
        same(firstElement));
    expect(
        () => runtime.select<Logic>(GfLogic(firstField), GfLogic(secondField)),
        throwsArgumentError);
    final firstArray = TypedLogicArray<GfLogic, LogicValue>(
        [2], ({name}) => GfLogic(firstField, name: name));
    final secondArray = TypedLogicArray<GfLogic, LogicValue>(
        [2], ({name}) => GfLogic(secondField, name: name));
    expect(() => runtime.select<Logic>(firstArray, secondArray),
        throwsArgumentError);

    final select = Logic()..put(1);
    final packed = Logic(width: 8)..put(0xa6);
    signed.fraction.put(1);
    signed.integer.put(2);
    final result = StaticOrRuntimeParameter.runtime(select, name: 'sel')
        .select<Logic>(packed, signed);
    expect(result, isA<FixedPoint>());
    expect(result.value, LogicValue.ofInt(0xa6, 8));
  });

  test('runtime selection retains widened payloads in simulation and RTL',
      () async {
    final field =
        BinaryExtensionField(modulus: BinaryPolynomial(BigInt.from(0x11b)));
    for (final schema in <Logic>[
      GfLogic(field),
      FixedPoint(integerWidth: 3, fractionWidth: 4),
    ]) {
      final dut = _TypedSelectHarness(schema);
      expect(sameDeclaredPayloadShape(dut.selected, schema), isTrue);
      expect(dut.selected.runtimeType, schema.runtimeType);
      final vectors = [
        Vector({'sel': 0, 'data0': 0xa5, 'data1': 0x35}, {'out': 0x35}),
        Vector({'sel': 1}, {'out': 0xa5}),
        Vector({'sel': LogicValue.x}, {'out': LogicValue.ofString('x01x0101')}),
      ];
      await dut.build();
      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
      await Simulator.reset();
    }
  });

  test('structured sources are reused only when they are identical', () {
    final parent = _TestModule();
    final source = _ControlStructure();
    final control = StaticOrRuntimeControl<int>(
        name: 'control', staticConfig: 0, runtimeConfig: source);
    expect(
        control.getRuntimeInput(parent), same(control.getRuntimeInput(parent)));
    final child = _TestModule();
    final rebound = control.forChild(parent);
    expect(rebound.runtimeConfig, same(parent.input('control')));
    rebound.getRuntimeInput(child);
    expect(child.inputSource('control'), same(parent.input('control')));

    final different = StaticOrRuntimeControl<int>(
        name: 'control', staticConfig: 0, runtimeConfig: _ControlStructure());
    expect(() => different.getRuntimeInput(parent),
        throwsA(isA<RohdHclException>()));
  });
}
