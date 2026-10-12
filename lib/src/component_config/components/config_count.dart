// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_count.dart
// Configurator for bit occurrence counting.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [Count].
class CountConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.bitOperations;

  @override
  String get subcategory => 'population-count';

  /// Width of the bus to count.
  final IntConfigKnob widthKnob = IntConfigKnob(value: 8);

  /// Whether to count ones rather than zeros.
  final ToggleConfigKnob countOneKnob = ToggleConfigKnob(value: true);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': widthKnob,
    'Count Ones': countOneKnob,
  });

  @override
  Module createModule() =>
      Count(Logic(width: widthKnob.value), countOne: countOneKnob.value);

  @override
  String get name => 'Count';
}
