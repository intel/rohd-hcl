// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_bool_knob.dart
// A knob for boolean controls that may be static or runtime inputs.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// How a boolean module control is configured.
enum StaticOrRuntimeBoolMode {
  /// Fix the control low at elaboration time.
  disabled,

  /// Fix the control high at elaboration time.
  enabled,

  /// Generate a runtime input for the control.
  runtime,
}

/// A [ConfigKnob] for a boolean control that can be static or runtime.
class StaticOrRuntimeBoolKnob
    extends ChoiceConfigKnob<StaticOrRuntimeBoolMode> {
  /// Creates a static-or-runtime boolean selection knob.
  StaticOrRuntimeBoolKnob({
    super.value = StaticOrRuntimeBoolMode.disabled,
  }) : super(
          StaticOrRuntimeBoolMode.values,
          choiceLabels: const {
            StaticOrRuntimeBoolMode.disabled: 'Static false',
            StaticOrRuntimeBoolMode.enabled: 'Static true',
            StaticOrRuntimeBoolMode.runtime: 'Runtime input',
          },
        );

  /// Returns the static value or a named runtime input for this selection.
  dynamic resolve(String runtimeInputName) => switch (value) {
        StaticOrRuntimeBoolMode.disabled => false,
        StaticOrRuntimeBoolMode.enabled => true,
        StaticOrRuntimeBoolMode.runtime => Logic(name: runtimeInputName),
      };
}
