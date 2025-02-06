// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_logic.dart
// Representation of fixed-point signals.
//
// 2024 October 24
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of (un)signed fixed-point logic following
/// Q notation (Qm.n format) as introduced by
/// (Texas Instruments)[https://www.ti.com/lit/ug/spru565b/spru565b.pdf].
class FixedPoint extends Logic {
  /// [signed] indicates whether the representation is signed.
  final bool signed;

  /// [m] is the number of bits reserved for the integer part.
  final int m;

  /// [n] is the number of bits reserved for the fractional part.
  final int n;

  static int _fixedPointWidth(bool s, int a, int b) => s ? 1 + a + b : a + b;

  /// Constructs a [FixedPoint] signal.
  FixedPoint(
      {required this.signed,
      required this.m,
      required this.n,
      super.name,
      super.naming})
      : super(width: _fixedPointWidth(signed, m, n)) {
    if ((m < 0) | (n < 0)) {
      throw RohdHclException('m and n must be non-negative');
    }
    if (max(m, n) == 0) {
      throw RohdHclException('either m or n must be greater than zero');
    }
  }

  /// Retrieve the [FixedPointValue] of this [FixedPoint] logical signal.
  FixedPointValue get fixedPointValue =>
      FixedPointValue(value: value, signed: signed, m: m, n: n);

  /// Clone for I/O ports.
  @override
  FixedPoint clone({String? name}) => FixedPoint(signed: signed, m: m, n: n);

  /// Cast logic to fixed point
  FixedPoint.of(Logic signal,
      {required this.signed, required this.m, required this.n})
      : super(width: _fixedPointWidth(signed, m, n)) {
    this <= signal;
  }

  @override
  void put(dynamic val, {bool fill = false}) {
    if (val is FixedPointValue) {
      if ((signed != val.signed) | (m != val.m) | (n != val.n)) {
        throw RohdHclException('Value is not compatible with signal.');
      }
      super.put(val.value);
    } else {
      throw RohdHclException('Only FixedPointValue is allowed');
    }
  }

  /// Check compatibility
  void _verifyCompatible(dynamic other) {
    if (other is! FixedPoint) {
      throw RohdHclException('Input must be fixed point signal.');
    }
    if ((signed != other.signed) | (m != other.m) | (n != other.n)) {
      throw RohdHclException('Inputs are not comparable.');
    }
  }

  /// Less-than.
  @override
  Logic lt(dynamic other) {
    _verifyCompatible(other);
    if (signed) {
      return mux(this[-1], super.gt(other), super.lt(other));
    } else {
      return super.lt(other);
    }
  }

  /// Less-than-or-equal-to.
  @override
  Logic lte(dynamic other) {
    _verifyCompatible(other);
    if (signed) {
      return mux(this[-1], super.gte(other), super.lte(other));
    } else {
      return super.lte(other);
    }
  }

  /// Greater-than.
  @override
  Logic gt(dynamic other) {
    _verifyCompatible(other);
    if (signed) {
      return mux(this[-1], super.lt(other), super.gt(other));
    } else {
      return super.gt(other);
    }
  }

  /// Greater-than.
  @override
  Logic gte(dynamic other) {
    _verifyCompatible(other);
    if (signed) {
      return mux(this[-1], super.lte(other), super.gte(other));
    } else {
      return super.gte(other);
    }
  }

  /// Greater-than.
  @override
  Logic operator >(dynamic other) => gt(other);

  /// Greater-than-or-equal-to.
  @override
  Logic operator >=(dynamic other) => gte(other);

  @override
  Logic eq(dynamic other) {
    _verifyCompatible(other);
    return super.eq(other);
  }

  @override
  Logic neq(dynamic other) {
    _verifyCompatible(other);
    return super.neq(other);
  }

  @override
  Logic operator %(dynamic other) {
    throw UnimplementedError('Operator not implemented.');
  }

  @override
  Logic operator /(dynamic other) {
    throw UnimplementedError('Operator not implemented.');
  }

  @override
  Logic pow(dynamic exponent) {
    throw UnimplementedError('Operator not implemented.');
  }
}
