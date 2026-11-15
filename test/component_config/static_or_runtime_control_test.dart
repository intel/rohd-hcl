// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_control_test.dart
// Tests for static-or-runtime control API compatibility.
//
// 2026 September 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';
// This test intentionally imports the deprecated compatibility path.
// ignore: deprecated_member_use_from_same_package
import 'package:rohd_hcl/src/static_or_runtime_parameter.dart';
import 'package:test/test.dart';

class _TestModule extends Module {}

void main() {
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

  test('typed input rejects an existing flattened input', () {
    final source = LogicArray([2], 4);
    final module = _TestModule();
    final control = StaticOrRuntimeControl<int>(
        name: 'setting', staticConfig: 0, runtimeConfig: source);
    expect(control.getRuntimeInput(module), isNot(isA<LogicArray>()));

    expect(() => control.getTypedRuntimeInput(module),
        throwsA(isA<RohdHclException>()));
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
