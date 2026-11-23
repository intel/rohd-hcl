// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inference_numeric_format.dart
// Numeric and packing policy descriptors for inference hardware.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';

/// Physical interpretation of one inference tensor element.
enum InferenceElementKind {
  /// Unsigned integer bits.
  unsignedInteger,

  /// Two's-complement integer bits.
  signedInteger,

  /// Signed or unsigned fixed-point bits.
  fixedPoint,

  /// Sign, exponent, and mantissa floating-point bits.
  floatingPoint,

  /// Low-precision elements interpreted with a shared group scale.
  blockScaled,
}

/// Scale representation associated with an inference tensor.
enum InferenceScaleKind {
  /// Tensor elements have no separate scale.
  none,

  /// A signed power-of-two exponent.
  powerOfTwo,

  /// A fixed-point scale.
  fixedPoint,

  /// A floating-point scale.
  floatingPoint,

  /// A shared exponent associated with a group of elements.
  sharedExponent,
}

/// Immutable numeric policy for inference tensor elements.
///
/// This descriptor creates no hardware. It keeps storage, product,
/// accumulation, scale, rounding, and overflow choices explicit when
/// composing inference components.
@immutable
class InferenceNumericFormat {
  /// Physical element interpretation.
  final InferenceElementKind elementKind;

  /// Number of stored bits per tensor element.
  final int elementWidth;

  /// Number of bits produced by one element multiplication.
  final int productWidth;

  /// Number of bits retained by an accumulation.
  final int accumulatorWidth;

  /// Whether fixed-point or block-scaled element bits are signed.
  final bool signed;

  /// Representation of separate scale metadata.
  final InferenceScaleKind scaleKind;

  /// Number of bits in one separate scale.
  final int scaleWidth;

  /// Number of tensor elements sharing one scale.
  final int groupSize;

  /// Fixed-point integer width, excluding the sign bit.
  final int? integerWidth;

  /// Fixed-point fraction width.
  final int? fractionWidth;

  /// Floating-point exponent width.
  final int? exponentWidth;

  /// Floating-point mantissa width.
  final int? mantissaWidth;

  /// Rounding policy applied when narrowing.
  final NumericRoundingMode roundingMode;

  /// Overflow policy applied when narrowing.
  final NumericOverflowMode overflowMode;

  /// Creates a validated numeric format.
  InferenceNumericFormat({
    required this.elementKind,
    required this.elementWidth,
    required this.productWidth,
    required this.accumulatorWidth,
    required this.signed,
    this.scaleKind = InferenceScaleKind.none,
    this.scaleWidth = 0,
    this.groupSize = 1,
    this.integerWidth,
    this.fractionWidth,
    this.exponentWidth,
    this.mantissaWidth,
    this.roundingMode = NumericRoundingMode.nearestEven,
    this.overflowMode = NumericOverflowMode.saturate,
  }) {
    if (elementWidth < 1 ||
        productWidth < 1 ||
        accumulatorWidth < productWidth) {
      throw ArgumentError(
        'Element and product widths must be positive and the accumulator '
        'must be at least as wide as one product.',
      );
    }
    if (scaleKind == InferenceScaleKind.none) {
      if (scaleWidth != 0 || groupSize != 1) {
        throw ArgumentError(
          'An unscaled format must use scaleWidth 0 and groupSize 1.',
        );
      }
    } else if (scaleWidth < 1 || groupSize < 1) {
      throw ArgumentError(
        'A scaled format requires positive scale width and group size.',
      );
    }
    switch (elementKind) {
      case InferenceElementKind.unsignedInteger:
        if (signed) {
          throw ArgumentError('Unsigned integer formats cannot be signed.');
        }
        if (integerWidth != null ||
            fractionWidth != null ||
            exponentWidth != null ||
            mantissaWidth != null) {
          throw ArgumentError(
            'Integer formats do not accept fixed or floating field widths.',
          );
        }
      case InferenceElementKind.signedInteger:
        if (!signed) {
          throw ArgumentError('Signed integer formats must be signed.');
        }
        if (integerWidth != null ||
            fractionWidth != null ||
            exponentWidth != null ||
            mantissaWidth != null) {
          throw ArgumentError(
            'Integer formats do not accept fixed or floating field widths.',
          );
        }
      case InferenceElementKind.fixedPoint:
        if (integerWidth == null ||
            fractionWidth == null ||
            integerWidth! < 0 ||
            fractionWidth! < 0 ||
            elementWidth != integerWidth! + fractionWidth! + (signed ? 1 : 0)) {
          throw ArgumentError(
            'Fixed-point width must equal integer + fraction + sign widths.',
          );
        }
      case InferenceElementKind.floatingPoint:
        if (!signed ||
            exponentWidth == null ||
            mantissaWidth == null ||
            exponentWidth! < 1 ||
            mantissaWidth! < 1 ||
            elementWidth != exponentWidth! + mantissaWidth! + 1) {
          throw ArgumentError(
            'Floating-point width must equal sign + exponent + mantissa.',
          );
        }
      case InferenceElementKind.blockScaled:
        if (scaleKind == InferenceScaleKind.none) {
          throw ArgumentError('Block-scaled elements require scale metadata.');
        }
    }
  }

  /// Creates an unsigned integer inference format.
  factory InferenceNumericFormat.unsignedInteger(
    int width, {
    int? productWidth,
    int? accumulatorWidth,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
  }) {
    final resolvedProductWidth = productWidth ?? width * 2;
    return InferenceNumericFormat(
      elementKind: InferenceElementKind.unsignedInteger,
      elementWidth: width,
      productWidth: resolvedProductWidth,
      accumulatorWidth: accumulatorWidth ?? resolvedProductWidth,
      signed: false,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
    );
  }

  /// Creates a signed integer inference format.
  factory InferenceNumericFormat.signedInteger(
    int width, {
    int? productWidth,
    int? accumulatorWidth,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
  }) {
    final resolvedProductWidth = productWidth ?? width * 2;
    return InferenceNumericFormat(
      elementKind: InferenceElementKind.signedInteger,
      elementWidth: width,
      productWidth: resolvedProductWidth,
      accumulatorWidth: accumulatorWidth ?? resolvedProductWidth,
      signed: true,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
    );
  }

  /// Creates a fixed-point inference format.
  factory InferenceNumericFormat.fixedPoint({
    required bool signed,
    required int integerWidth,
    required int fractionWidth,
    int? productWidth,
    int? accumulatorWidth,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
  }) {
    final elementWidth = integerWidth + fractionWidth + (signed ? 1 : 0);
    final resolvedProductWidth = productWidth ?? elementWidth * 2;
    return InferenceNumericFormat(
      elementKind: InferenceElementKind.fixedPoint,
      elementWidth: elementWidth,
      productWidth: resolvedProductWidth,
      accumulatorWidth: accumulatorWidth ?? resolvedProductWidth,
      signed: signed,
      integerWidth: integerWidth,
      fractionWidth: fractionWidth,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
    );
  }

  /// Creates a floating-point inference format.
  factory InferenceNumericFormat.floatingPoint({
    required int exponentWidth,
    required int mantissaWidth,
    int? productWidth,
    int? accumulatorWidth,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
  }) {
    final elementWidth = exponentWidth + mantissaWidth + 1;
    final resolvedProductWidth = productWidth ?? elementWidth;
    return InferenceNumericFormat(
      elementKind: InferenceElementKind.floatingPoint,
      elementWidth: elementWidth,
      productWidth: resolvedProductWidth,
      accumulatorWidth: accumulatorWidth ?? resolvedProductWidth,
      signed: true,
      exponentWidth: exponentWidth,
      mantissaWidth: mantissaWidth,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
    );
  }

  /// Creates a block-scaled low-precision inference format.
  factory InferenceNumericFormat.blockScaled({
    required int elementWidth,
    required bool signed,
    required InferenceScaleKind scaleKind,
    required int scaleWidth,
    required int groupSize,
    int? productWidth,
    int? accumulatorWidth,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
  }) {
    final resolvedProductWidth = productWidth ?? elementWidth * 2;
    return InferenceNumericFormat(
      elementKind: InferenceElementKind.blockScaled,
      elementWidth: elementWidth,
      productWidth: resolvedProductWidth,
      accumulatorWidth: accumulatorWidth ?? resolvedProductWidth,
      signed: signed,
      scaleKind: scaleKind,
      scaleWidth: scaleWidth,
      groupSize: groupSize,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
    );
  }

  /// Stable identity suitable for generated definition names.
  String get configurationSignature => '${elementKind.name}_E$elementWidth'
      '_P${productWidth}_A${accumulatorWidth}_S${signed ? 1 : 0}'
      '_${scaleKind.name}_SW${scaleWidth}_G$groupSize'
      '_I${integerWidth ?? 0}_F${fractionWidth ?? 0}'
      '_X${exponentWidth ?? 0}_M${mantissaWidth ?? 0}'
      '_${roundingMode.name}_${overflowMode.name}';

  @override
  bool operator ==(Object other) =>
      other is InferenceNumericFormat &&
      elementKind == other.elementKind &&
      elementWidth == other.elementWidth &&
      productWidth == other.productWidth &&
      accumulatorWidth == other.accumulatorWidth &&
      signed == other.signed &&
      scaleKind == other.scaleKind &&
      scaleWidth == other.scaleWidth &&
      groupSize == other.groupSize &&
      integerWidth == other.integerWidth &&
      fractionWidth == other.fractionWidth &&
      exponentWidth == other.exponentWidth &&
      mantissaWidth == other.mantissaWidth &&
      roundingMode == other.roundingMode &&
      overflowMode == other.overflowMode;

  @override
  int get hashCode => Object.hash(
        elementKind,
        elementWidth,
        productWidth,
        accumulatorWidth,
        signed,
        scaleKind,
        scaleWidth,
        groupSize,
        integerWidth,
        fractionWidth,
        exponentWidth,
        mantissaWidth,
        roundingMode,
        overflowMode,
      );
}
