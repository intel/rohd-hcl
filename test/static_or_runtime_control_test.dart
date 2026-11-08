// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_control_test.dart
// Tests for composing and selecting static or runtime controls.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _TestModule extends Module {}

class _ControlStructure extends LogicStructure {
  final Logic bits;

  _ControlStructure() : this._(Logic(width: 2));

  _ControlStructure._(this.bits) : super([bits]);

  @override
  _ControlStructure clone({String? name}) => _ControlStructure();
}

void main() {
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
