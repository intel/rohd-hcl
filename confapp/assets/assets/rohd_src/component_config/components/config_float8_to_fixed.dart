// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_float8_to_fixed.dart
// Configurator for the runtime-selectable FP8 converter.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [Float8ToFixed].
class Float8ToFixedConfigurator extends Configurator {
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => const {};

  @override
  Module createModule() => Float8ToFixed(Logic(width: 8), Logic());

  @override
  String get name => 'FP8 To Fixed Converter';
}
