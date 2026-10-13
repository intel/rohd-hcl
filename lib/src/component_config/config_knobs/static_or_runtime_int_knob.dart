// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_int_knob.dart
// A knob for integer controls that may be static or runtime inputs.
//
// 2026 October 13
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// How an integer module control is configured.
enum StaticOrRuntimeIntMode {
  /// Fix the value at elaboration time.
  staticValue,

  /// Generate a runtime input for the value.
  runtime,
}

/// A [GroupOfKnobs] for an integer control that can be static or runtime.
///
/// Static configurations resolve to their integer value. Runtime
/// configurations resolve to a [StaticOrRuntimeControl] that creates a named
/// [Logic] input with the selected width.
class StaticOrRuntimeIntKnob extends GroupOfKnobs {
  /// Selects whether the control is static or runtime-configurable.
  final ChoiceConfigKnob<StaticOrRuntimeIntMode> modeKnob = ChoiceConfigKnob(
    StaticOrRuntimeIntMode.values,
    value: StaticOrRuntimeIntMode.staticValue,
    choiceLabels: const {
      StaticOrRuntimeIntMode.staticValue: 'Static value',
      StaticOrRuntimeIntMode.runtime: 'Runtime input',
    },
  );

  /// The static value, or `null` when the component should infer its default.
  final IntOptionalConfigKnob staticValueKnob;

  /// Width of the generated runtime input.
  final IntConfigKnob runtimeWidthKnob;

  /// Creates a static-or-runtime integer control.
  StaticOrRuntimeIntKnob({
    int? staticValue = 0,
    int runtimeWidth = 8,
    super.name = 'Integer Control',
  })  : staticValueKnob = IntOptionalConfigKnob(value: staticValue),
        runtimeWidthKnob = IntConfigKnob(value: runtimeWidth),
        super({});

  /// Whether this knob generates a runtime input.
  bool get isRuntime => modeKnob.value == StaticOrRuntimeIntMode.runtime;

  @override
  Map<String, ConfigKnob<dynamic>> get subKnobs => {
        'Mode': modeKnob,
        if (isRuntime) 'Runtime Width': runtimeWidthKnob,
        if (!isRuntime) 'Static Value': staticValueKnob,
      };

  @override
  Map<String, dynamic> toJson() => {
        'Mode': modeKnob.toJson(),
        if (isRuntime) 'Runtime Width': runtimeWidthKnob.toJson(),
        if (!isRuntime) 'Static Value': staticValueKnob.toJson(),
      };

  @override
  void loadJson(Map<String, dynamic> decodedJson) {
    // Preserve saved configurations from before static/runtime selection was
    // available, where the knob was directly represented by its value.
    if (decodedJson.containsKey('value')) {
      staticValueKnob.loadJson(decodedJson);
      modeKnob.value = StaticOrRuntimeIntMode.staticValue;
      return;
    }

    final modeJson = decodedJson['Mode'];
    if (modeJson is! Map) {
      throw RohdHclException('Static-or-runtime integer control has no mode.');
    }
    modeKnob.loadJson(Map<String, dynamic>.from(modeJson));

    final valueName = isRuntime ? 'Runtime Width' : 'Static Value';
    final valueJson = decodedJson[valueName];
    if (valueJson is! Map) {
      throw RohdHclException(
          'Static-or-runtime integer control has no "$valueName".');
    }
    if (isRuntime) {
      runtimeWidthKnob.loadJson(Map<String, dynamic>.from(valueJson));
    } else {
      staticValueKnob.loadJson(Map<String, dynamic>.from(valueJson));
    }
  }

  /// Resolves to a static value or a named runtime [StaticOrRuntimeControl].
  dynamic resolve(String runtimeInputName) {
    if (!isRuntime) {
      return staticValueKnob.value;
    }
    if (runtimeWidthKnob.value <= 0) {
      throw RohdHclException(
          'Runtime input "$runtimeInputName" must have a positive width.');
    }
    return StaticOrRuntimeControl<int>(
      name: runtimeInputName,
      staticConfig: staticValueKnob.value ?? 0,
      runtimeConfig: Logic(
        name: runtimeInputName,
        width: runtimeWidthKnob.value,
      ),
    );
  }
}
