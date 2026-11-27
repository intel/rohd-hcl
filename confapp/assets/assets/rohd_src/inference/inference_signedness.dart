// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inference_signedness.dart
// Shared static-or-runtime signedness control for inference components.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/static_or_runtime_control.dart';

/// A validated static or runtime signedness selection.
@immutable
class InferenceSignedness {
  final StaticOrRuntimeParameter _parameter;

  /// Creates signedness from a `bool`, 1-bit [Logic], compatible parameter,
  /// or `null`.
  factory InferenceSignedness(
    dynamic value, {
    required String name,
    bool defaultValue = false,
  }) {
    if (value is StaticOrRuntimeParameter) {
      return InferenceSignedness._(
        StaticOrRuntimeParameter(
          name: name,
          runtimeConfig: value.runtimeConfig,
          staticConfig: value.staticConfig,
        ),
      );
    }
    if (value is Logic) {
      return InferenceSignedness._(
        StaticOrRuntimeParameter(name: name, runtimeConfig: value),
      );
    }
    if (value == null || value is bool) {
      return InferenceSignedness._(
        StaticOrRuntimeParameter(
          name: name,
          staticConfig: value as bool? ?? defaultValue,
        ),
      );
    }
    throw ArgumentError.value(
      value,
      name,
      'Must be a bool, 1-bit Logic, StaticOrRuntimeParameter, or null.',
    );
  }

  const InferenceSignedness._(this._parameter);

  /// Whether signedness is selected by a runtime input.
  bool get isRuntime => _parameter.isRuntime;

  /// Static signedness when [isRuntime] is false.
  bool get staticValue => _parameter.staticConfig;

  /// Stable identity for generated definition names.
  String get identity =>
      isRuntime ? 'runtime' : (staticValue ? 'signed' : 'unsigned');

  /// Resolves signedness to logic owned by [module].
  Logic resolve(Module module) => _parameter.getLogic(module);

  /// Returns a child-owned signedness configuration.
  StaticOrRuntimeParameter childConfiguration(Module module) =>
      _parameter.forChild(module);
}
