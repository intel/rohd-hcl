// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_constants.dart
// Constants for floating point values.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

/// Critical threshold constants
enum FloatingPointConstants {
  /// smallest possible number.
  negativeInfinity,

  /// The number zero, negative form.
  negativeZero,

  /// The number zero, positive form.
  positiveZero,

  /// Smallest possible number, most exponent negative, LSB set in mantissa.
  smallestPositiveSubnormal,

  /// Largest possible subnormal, most negative exponent, mantissa all 1s.
  largestPositiveSubnormal,

  /// Smallest possible positive number, most negative exponent, mantissa is 0.
  smallestPositiveNormal,

  /// Largest number smaller than one.
  largestLessThanOne,

  /// The number one.
  one,

  /// Smallest number greater than one.
  smallestLargerThanOne,

  /// Largest positive number, most positive exponent, full mantissa.
  largestNormal,

  /// Largest possible number.
  positiveInfinity,

  /// Not a Number, demarked by all 1s in exponent and any 1 in mantissa.
  nan,
}
