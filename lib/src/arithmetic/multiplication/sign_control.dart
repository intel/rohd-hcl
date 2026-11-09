// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sign_control.dart
// Normalizes static and runtime multiplier signedness controls.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Resolves a unified signedness control or its legacy runtime selector.
StaticOrRuntimeParameter resolveSignControl(
    StaticOrRuntimeParameter? config, Logic? legacySelector,
    {required String name}) {
  final control = config ?? StaticOrRuntimeParameter.staticValue(value: false);
  if (legacySelector == null) {
    return control;
  }
  if (control.isRuntime || control.staticConfig) {
    throw RohdHclException(
        'Provide either "$name" or its runtime selector, not both.');
  }
  return StaticOrRuntimeParameter(name: name, runtimeConfig: legacySelector);
}
