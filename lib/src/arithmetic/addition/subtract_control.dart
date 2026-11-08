// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// subtract_control.dart
// Normalizes static and runtime subtraction controls.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Resolves a unified subtraction control or its legacy runtime input.
StaticOrRuntimeParameter resolveSubtractControl(
    StaticOrRuntimeParameter? subtract, Logic? subtractIn) {
  final subtractIsActive =
      subtract != null && (subtract.isRuntime || subtract.staticConfig);
  if (subtractIn != null && subtractIsActive) {
    throw RohdHclException(
        "Provide either 'subtractIn' or 'subtract', but not both.");
  }
  return subtractIn != null
      ? StaticOrRuntimeParameter(name: 'subtractIn', runtimeConfig: subtractIn)
      : subtract ?? StaticOrRuntimeParameter.staticValue(value: false);
}

/// Identifies the elaborated subtraction mode for an HDL definition name.
String subtractControlSuffix(
    StaticOrRuntimeParameter? subtract, Logic? subtractIn) {
  final control = resolveSubtractControl(subtract, subtractIn);
  return control.isRuntime ? 'SR' : (control.staticConfig ? 'S1' : 'S0');
}
