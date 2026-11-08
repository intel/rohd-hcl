// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_format.dart
// Format conversion policies for fixed-point arithmetic.
//
// 2026 November 3
// Authors:
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

/// Overflow behavior used when converting a fixed-point value to a narrower
/// integer format.
enum FixedPointOverflowMode {
  /// Retain the least-significant bits, discarding overflowing high bits.
  wrap,

  /// Clamp overflowing values to the nearest representable endpoint.
  saturate,
}
