// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_multi_cycle_divider.dart
// Configurator for multi-cycle integer division.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [MultiCycleDivider].
class MultiCycleDividerConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'division-and-roots';

  /// Width of the dividend, divisor, quotient, and remainder.
  final IntConfigKnob dataWidthKnob = IntConfigKnob(value: 16);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs =
      UnmodifiableMapView({'Data Width': dataWidthKnob});

  @override
  Module createModule() => MultiCycleDivider(
      MultiCycleDividerInterface(dataWidth: dataWidthKnob.value));

  @override
  String get name => 'Multi-Cycle Divider';
}
