// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_compute_floating_point.dart
// Configurators for floating-point classification and comparison.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

abstract class _FloatingPointFormatConfigurator extends Configurator {
  /// Width of the exponent.
  final IntConfigKnob exponentWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of the mantissa, including the J bit when it is explicit.
  final IntConfigKnob mantissaWidthKnob = PositiveIntConfigKnob(value: 23);

  /// Whether the input mantissa stores its J bit.
  final ToggleConfigKnob explicitJBitKnob = ToggleConfigKnob(value: false);

  /// Whether to canonicalize explicit-J-bit values.
  final ToggleConfigKnob alignExplicitJBitKnob = ToggleConfigKnob(value: false);

  /// Whether comparison treats subnormal values as zero.
  final ToggleConfigKnob subNormalAsZeroKnob = ToggleConfigKnob(value: false);

  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'floating-point';

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Exponent Width': exponentWidthKnob,
        'Mantissa Width': mantissaWidthKnob,
        'Explicit J Bit': explicitJBitKnob,
        'Align Explicit J Bit': alignExplicitJBitKnob,
        'Subnormal As Zero': subNormalAsZeroKnob,
      };

  FloatingPoint createValue() => FloatingPoint(
        exponentWidth: exponentWidthKnob.value,
        mantissaWidth: mantissaWidthKnob.value,
        explicitJBit: explicitJBitKnob.value,
        subNormalAsZero: subNormalAsZeroKnob.value,
      );
}

/// Configures a floating-point classifier.
class FloatingPointClassifierConfigurator
    extends _FloatingPointFormatConfigurator {
  @override
  String get name => 'Floating-Point Classifier';

  @override
  Module createModule() => FloatingPointClassifier(
        createValue(),
        alignExplicitJBit: alignExplicitJBitKnob.value,
      );
}

/// Configures a floating-point comparator.
class FloatingPointComparatorConfigurator
    extends _FloatingPointFormatConfigurator {
  @override
  String get name => 'Floating-Point Comparator';

  @override
  Module createModule() => FloatingPointComparator(createValue(), createValue(),
      alignExplicitJBit: alignExplicitJBitKnob.value);
}
