// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_float_to_fixed.dart
// Configurator for a FloatToFixed converter.
//
// 2024 November 1
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FloatToFixed].
class FloatToFixedConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'conversion';

  /// Width of exponent, must be greater than 0.
  final IntConfigKnob exponentWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of mantissa, must be greater than 0.
  final IntConfigKnob mantissaWidthKnob = PositiveIntConfigKnob(value: 23);

  /// Whether the input format includes an explicit J bit.
  final ToggleConfigKnob inputExplicitJBitKnob = ToggleConfigKnob(value: false);

  /// Optional width of the integer part of the fixed-point output.
  final IntOptionalConfigKnob integerWidthKnob = IntOptionalConfigKnob(
    value: null,
  );

  /// Optional width of the fractional part of the fixed-point output.
  final IntOptionalConfigKnob fractionWidthKnob = IntOptionalConfigKnob(
    value: null,
  );

  /// Whether to generate the overflow output.
  final ToggleConfigKnob checkOverflowKnob = ToggleConfigKnob(value: false);

  /// Rounding mode used for the conversion.
  final FloatingPointRoundingModeKnob roundingModeKnob =
      FloatingPointRoundingModeKnob(value: FloatingPointRoundingMode.truncate);

  @override
  final String name = 'Float To Fixed Converter';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Input exponent width': exponentWidthKnob,
    'Input mantissa width': mantissaWidthKnob,
    'Input explicit J bit': inputExplicitJBitKnob,
    'Output integer width': integerWidthKnob,
    'Output fraction width': fractionWidthKnob,
    'Check overflow': checkOverflowKnob,
    'Rounding mode': roundingModeKnob,
  });

  @override
  Module createModule() => FloatToFixed(
        FloatingPoint(
          exponentWidth: exponentWidthKnob.value,
          mantissaWidth: mantissaWidthKnob.value,
          explicitJBit: inputExplicitJBitKnob.value,
        ),
        integerWidth: integerWidthKnob.value,
        fractionWidth: fractionWidthKnob.value,
        checkOverflow: checkOverflowKnob.value,
        roundingMode: roundingModeKnob.value,
        definitionName: 'FloatToFixed',
      );
}
