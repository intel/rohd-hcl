// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_arithmetic_primitives.dart
// Configurators for arithmetic primitives.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures exact-width signed magnitude hardware.
class AbsoluteValueConfigurator extends Configurator {
  /// Input width.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  @override
  ComponentCategory get category => ComponentCategory.arithmetic;
  @override
  String get subcategory => 'normalization';
  @override
  String get name => 'Absolute Value';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {'Width': widthKnob};
  @override
  Module createModule() => AbsoluteValue(Logic(width: widthKnob.value));
}

/// Configures a wrapping pointer.
class CircularPointerConfigurator extends Configurator {
  /// Number of slots in the circular range.
  final IntConfigKnob slotsKnob = IntConfigKnob(value: 8, minValue: 2);

  /// Width of the runtime increment.
  final IntConfigKnob incrementWidthKnob = PositiveIntConfigKnob(value: 3);

  @override
  ComponentCategory get category => ComponentCategory.arithmetic;
  @override
  String get subcategory => 'accumulation';
  @override
  String get name => 'Circular Pointer';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Slots': slotsKnob,
        'Increment Width': incrementWidthKnob,
      };
  @override
  Module createModule() => CircularPointer(
        Logic(name: 'clk'),
        Logic(name: 'reset'),
        Logic(name: 'increment', width: incrementWidthKnob.value),
        slots: slotsKnob.value,
      );
}

/// Configures unsigned division rounded up.
class CeilDivideConfigurator extends Configurator {
  /// Dividend width.
  final IntConfigKnob dividendWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Divisor width.
  final IntConfigKnob divisorWidthKnob = PositiveIntConfigKnob(value: 8);

  @override
  ComponentCategory get category => ComponentCategory.arithmetic;
  @override
  String get subcategory => 'division-and-roots';
  @override
  String get name => 'Ceil Divide';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Dividend Width': dividendWidthKnob,
        'Divisor Width': divisorWidthKnob,
      };
  @override
  Module createModule() => CeilDivide(
        Logic(name: 'dividend', width: dividendWidthKnob.value),
        Logic(name: 'divisor', width: divisorWidthKnob.value),
      );
}
