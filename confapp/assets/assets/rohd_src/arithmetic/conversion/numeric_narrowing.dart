// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// numeric_narrowing.dart
// Explicit integer rounding, narrowing, and saturation.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Rounding policy applied when discarding low-order binary digits.
/// {@category Arithmetic}
enum NumericRoundingMode {
  /// Discard low-order bits, which rounds an unsigned magnitude toward zero.
  truncate,

  /// Round to the nearest result, selecting an even result for an exact tie.
  nearestEven,

  /// Round to the nearest result, selecting away from zero for an exact tie.
  nearestTiesAway,

  /// Round toward zero.
  towardZero,

  /// Round toward positive infinity.
  towardPositiveInfinity,

  /// Round toward negative infinity.
  towardNegativeInfinity,
}

/// Overflow behavior when a narrowed value is outside its output range.
/// {@category Arithmetic}
enum NumericOverflowMode {
  /// Preserve the low output bits.
  wrap,

  /// Clamp to the nearest representable output endpoint.
  saturate,
}

/// Right-shifts, rounds, and narrows an unsigned or two's-complement value.
///
/// Rounding is performed on the mathematical signed or unsigned value before
/// range handling. [overflowed] indicates a result above the output maximum,
/// while [underflowed] indicates a signed result below the output minimum.
/// [inexact] indicates that at least one non-zero bit was discarded by
/// [shiftRight]. Unknown input bits propagate through ordinary ROHD logic.
/// {@category Arithmetic}
class NumericNarrowing extends Module {
  /// Width of [result].
  final int outputWidth;

  /// Whether the input and output use two's-complement signed interpretation.
  final bool signed;

  /// Number of low-order binary digits discarded before narrowing.
  final int shiftRight;

  /// Rounding policy applied to discarded digits.
  final NumericRoundingMode roundingMode;

  /// Range behavior after rounding.
  final NumericOverflowMode overflowMode;

  /// Rounded and narrowed result.
  Logic get result => output('result');

  /// High when the rounded value exceeds the output maximum.
  Logic get overflowed => output('overflowed');

  /// High when the rounded signed value is below the output minimum.
  Logic get underflowed => output('underflowed');

  /// High when non-zero bits were discarded by [shiftRight].
  Logic get inexact => output('inexact');

  /// Creates combinational numeric narrowing hardware.
  NumericNarrowing(
    Logic value, {
    required this.outputWidth,
    this.signed = false,
    this.shiftRight = 0,
    this.roundingMode = NumericRoundingMode.truncate,
    this.overflowMode = NumericOverflowMode.wrap,
    super.name = 'numeric_narrowing',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              'NumericNarrowing_I${value.width}_O${outputWidth}_'
                  'S${signed ? 1 : 0}_R${shiftRight}_'
                  '${roundingMode.name}_${overflowMode.name}',
        ) {
    if (outputWidth <= 0) {
      throw RohdHclException(
          'Numeric narrowing output width must be positive.');
    }
    if (shiftRight < 0 || shiftRight > value.width) {
      throw RohdHclException(
        'Numeric narrowing right shift must be between zero and '
        'the ${value.width}-bit input width.',
      );
    }

    value = addInput('value', value, width: value.width);
    final result = addOutput('result', width: outputWidth);
    final overflowed = addOutput('overflowed');
    final underflowed = addOutput('underflowed');
    final inexact = addOutput('inexact');

    final calculationWidth =
        (value.width > outputWidth ? value.width : outputWidth) + 2;
    final sign = signed ? value[-1] : Const(0);
    final unsignedValue = value.zeroExtend(calculationWidth);
    final magnitude = Logic(name: 'magnitude', width: calculationWidth)
      ..gets(mux(
        sign,
        (~value).zeroExtend(calculationWidth) + 1,
        unsignedValue,
      ));
    final truncatedMagnitude =
        (magnitude >> shiftRight).named('truncatedMagnitude');

    final discarded =
        shiftRight == 0 ? Const(0) : magnitude.getRange(0, shiftRight).or();
    final guard = shiftRight == 0 ? Const(0) : magnitude[shiftRight - 1];
    final sticky =
        shiftRight <= 1 ? Const(0) : magnitude.getRange(0, shiftRight - 1).or();
    inexact <= discarded;

    final increment = switch (roundingMode) {
      NumericRoundingMode.truncate ||
      NumericRoundingMode.towardZero =>
        Const(0),
      NumericRoundingMode.nearestEven =>
        guard & (sticky | truncatedMagnitude[0]),
      NumericRoundingMode.nearestTiesAway => guard,
      NumericRoundingMode.towardPositiveInfinity => ~sign & discarded,
      NumericRoundingMode.towardNegativeInfinity => sign & discarded,
    };
    final roundedMagnitude =
        (truncatedMagnitude + increment.zeroExtend(calculationWidth))
            .named('roundedMagnitude');

    final positiveMaximum = signed
        ? (BigInt.one << (outputWidth - 1)) - BigInt.one
        : (BigInt.one << outputWidth) - BigInt.one;
    final negativeMagnitudeMaximum =
        signed ? BigInt.one << (outputWidth - 1) : BigInt.zero;
    overflowed <=
        ~sign &
            roundedMagnitude.gt(
              Const(positiveMaximum, width: calculationWidth),
            );
    underflowed <=
        (signed
            ? sign &
                roundedMagnitude.gt(
                  Const(negativeMagnitudeMaximum, width: calculationWidth),
                )
            : Const(0));

    final wrapped = mux(
      sign,
      (~roundedMagnitude + 1).getRange(0, outputWidth),
      roundedMagnitude.getRange(0, outputWidth),
    );
    if (overflowMode == NumericOverflowMode.saturate) {
      final maximum = Const(positiveMaximum, width: outputWidth);
      final minimum = Const(
        signed ? BigInt.one << (outputWidth - 1) : BigInt.zero,
        width: outputWidth,
      );
      result <= mux(overflowed, maximum, mux(underflowed, minimum, wrapped));
    } else {
      result <= wrapped;
    }
  }
}
