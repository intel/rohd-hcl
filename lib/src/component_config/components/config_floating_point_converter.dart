// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_floating_point_converter.dart
// Configurator for floating-point format conversion.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FloatingPointConverter].
class FloatingPointConverterConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'floating-point';

  /// Width of the source exponent.
  final IntConfigKnob sourceExponentWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of the source mantissa.
  final IntConfigKnob sourceMantissaWidthKnob =
      PositiveIntConfigKnob(value: 23);

  /// Whether the source format includes an explicit J bit.
  final ToggleConfigKnob sourceExplicitJBitKnob =
      ToggleConfigKnob(value: false);

  /// Width of the destination exponent.
  final IntConfigKnob destinationExponentWidthKnob =
      PositiveIntConfigKnob(value: 5);

  /// Width of the destination mantissa.
  final IntConfigKnob destinationMantissaWidthKnob =
      PositiveIntConfigKnob(value: 10);

  /// Whether the destination format includes an explicit J bit.
  final ToggleConfigKnob destinationExplicitJBitKnob =
      ToggleConfigKnob(value: false);

  /// Rounding mode used when reducing precision.
  final FloatingPointRoundingModeKnob roundingModeKnob =
      FloatingPointRoundingModeKnob();

  /// Priority-encoder implementation used during conversion.
  final PriorityEncoderSelectKnob priorityEncoderSelectKnob =
      PriorityEncoderSelectKnob();

  /// Adder implementation used for exponent calculations.
  final AdderSelectKnob adderSelectKnob = AdderSelectKnob();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Source Exponent Width': sourceExponentWidthKnob,
    'Source Mantissa Width': sourceMantissaWidthKnob,
    'Source Explicit J Bit': sourceExplicitJBitKnob,
    'Destination Exponent Width': destinationExponentWidthKnob,
    'Destination Mantissa Width': destinationMantissaWidthKnob,
    'Destination Explicit J Bit': destinationExplicitJBitKnob,
    'Rounding Mode': roundingModeKnob,
    'Priority Encoder': priorityEncoderSelectKnob,
    'Exponent Adder': adderSelectKnob,
  });

  @override
  Module createModule() => FloatingPointConverter(
        FloatingPoint(
            exponentWidth: sourceExponentWidthKnob.value,
            mantissaWidth: sourceMantissaWidthKnob.value,
            explicitJBit: sourceExplicitJBitKnob.value),
        FloatingPoint(
            exponentWidth: destinationExponentWidthKnob.value,
            mantissaWidth: destinationMantissaWidthKnob.value,
            explicitJBit: destinationExplicitJBitKnob.value),
        roundingMode: roundingModeKnob.value,
        priorityGen: priorityEncoderSelectKnob.selectedPriorityEncoder(),
        adderGen: (a, b, {carryIn}) => adderSelectKnob.selectedAdder()(a, b,
            carryIn: carryIn, name: 'exponent_adder'),
      );

  @override
  String get name => 'Floating-Point Converter';
}
