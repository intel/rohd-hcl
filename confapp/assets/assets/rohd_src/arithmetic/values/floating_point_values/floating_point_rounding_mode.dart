// Copyright (C) 2024-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_rounding_mode.dart
// Floating Point Rounding Modes
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

/// Floating Point Rounding Modes
enum FloatingPointRoundingMode {
  /// Truncate the result.
  ///
  /// This is retained for compatibility and has the same finite-result
  /// behavior as [roundTowardsZero].
  truncate,

  /// Round to nearest, ties to even.  Round to the nearest value with an even
  /// LSB.
  roundNearestEven,

  /// Round to nearest, with exact ties rounded away from zero.
  roundNearestTiesAway,

  /// Round toward zero.
  roundTowardsZero,

  /// Round toward positive infinity.
  roundTowardsInfinity,

  /// Round toward negative infinity.
  roundTowardsNegativeInfinity
}

/// Divides [value] by `2^[discardedWidth]` using [roundingMode].
///
/// This operates entirely on [BigInt] so value-side arithmetic can round
/// without passing through a host floating-point type.
BigInt roundBigIntByPowerOfTwo(BigInt value, int discardedWidth,
    {required FloatingPointRoundingMode roundingMode}) {
  if (discardedWidth < 0) {
    throw ArgumentError.value(
        discardedWidth, 'discardedWidth', 'Must be non-negative.');
  }
  if (discardedWidth == 0 || value == BigInt.zero) {
    return value;
  }

  final negative = value.isNegative;
  final magnitude = value.abs();
  final quotient = magnitude >> discardedWidth;
  final remainder = magnitude & ((BigInt.one << discardedWidth) - BigInt.one);
  if (remainder == BigInt.zero) {
    return negative ? -quotient : quotient;
  }

  final increment = switch (roundingMode) {
    FloatingPointRoundingMode.truncate ||
    FloatingPointRoundingMode.roundTowardsZero =>
      false,
    FloatingPointRoundingMode.roundTowardsInfinity => !negative,
    FloatingPointRoundingMode.roundTowardsNegativeInfinity => negative,
    FloatingPointRoundingMode.roundNearestTiesAway =>
      remainder >= (BigInt.one << (discardedWidth - 1)),
    FloatingPointRoundingMode.roundNearestEven =>
      remainder > (BigInt.one << (discardedWidth - 1)) ||
          (remainder == (BigInt.one << (discardedWidth - 1)) && quotient.isOdd),
  };
  final rounded = increment ? quotient + BigInt.one : quotient;
  return negative ? -rounded : rounded;
}
