// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_float8_to_fixed.dart
// Configurator for a Float8ToFixed converter.
//
// 2024 November 1
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [Float8ToFixed].
class Float8ToFixedConfigurator extends Configurator {
  @override
  final String name = 'FP8 To Fixed Converter';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({});

  @override
  Module createModule() => Float8ToFixed(Logic(width: 8), Logic());
}
