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

  /// Round to nearest, ties to even.
  roundNearestEven,

  /// Round to nearest, tieas away from zero.
  roundNearestTiesAway,

  /// Round toward zero.
  roundTowardsZero,

  /// Round toward +infinity.
  roundTowardsInfinity,

  /// Round toward -infinity.
  roundTowardsNegativeInfinity
}
