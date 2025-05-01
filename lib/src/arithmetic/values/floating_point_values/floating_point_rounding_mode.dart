// Copyright (C) 2024-2025 Intel Corporation
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
  /// Truncate the result, no rounding.
  truncate,

  /// Round to nearest, ties to even.  Round to the nearest value with an even
  /// LSB.
  roundNearestEven,

  /// Round to nearest, tieas away from zero.  Round up for positive numbers,
  /// round down for negative numbers.
  roundNearestTiesAway,

  /// Round toward zero. Truncate.
  roundTowardsZero,

  /// Round toward +infinity. Round up.
  roundTowardsInfinity,

  /// Round toward -infinity.  Round down.
  roundTowardsNegativeInfinity
}
