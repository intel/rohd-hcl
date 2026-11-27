// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// prbs_standard.dart
// Standard pseudorandom binary sequence polynomials.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/src/binary_math/algebra/binary_polynomial.dart';

/// Common maximal-length pseudorandom binary sequence standards.
///
/// Each value uses the characteristic polynomial convention documented by
/// [BinaryPolynomial].
/// {@category Binary Math}
enum PrbsStandard {
  /// PRBS7 using `x^7 + x^6 + 1`.
  prbs7([7, 6, 0]),

  /// PRBS9 using `x^9 + x^5 + 1`.
  prbs9([9, 5, 0]),

  /// PRBS11 using `x^11 + x^9 + 1`.
  prbs11([11, 9, 0]),

  /// PRBS15 using `x^15 + x^14 + 1`.
  prbs15([15, 14, 0]),

  /// PRBS20 using `x^20 + x^3 + 1`.
  prbs20([20, 3, 0]),

  /// PRBS23 using `x^23 + x^18 + 1`.
  prbs23([23, 18, 0]),

  /// PRBS31 using `x^31 + x^28 + 1`.
  prbs31([31, 28, 0]);

  final List<int> _exponents;

  const PrbsStandard(this._exponents);

  /// The characteristic polynomial for this standard.
  BinaryPolynomial get polynomial => BinaryPolynomial.fromExponents(_exponents);

  /// The sequence register width.
  int get width => _exponents.first;
}
