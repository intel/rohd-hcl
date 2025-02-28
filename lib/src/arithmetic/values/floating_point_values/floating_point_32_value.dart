// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_32_value.dart
// Implementation of 32-bit Floating-Point value representations.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a single-precision floating-point value.
class FloatingPoint32Value extends FloatingPointValue {
  @override
  final int exponentWidth = 8;

  @override
  final int mantissaWidth = 23;

  /// Constructor for a single precision floating point value.
  factory FloatingPoint32Value(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa}) =>
      populator().populate(sign: sign, exponent: exponent, mantissa: mantissa);

  /// Creates an unpopulated version, intended to be called with the
  /// [populator].
  @protected
  FloatingPoint32Value.uninitialized() : super.uninitialized();

  /// Creates a [FloatingPointValuePopulator], which can then be used to
  /// complete construction using population functions.
  static FloatingPointValuePopulator<FloatingPoint32Value> populator() =>
      FloatingPoint32ValuePopulator(FloatingPoint32Value.uninitialized());

  @override
  FloatingPointValuePopulator clonePopulator() => populator();
}

/// A special type of [FloatingPointValuePopulator] that adjusts how
/// [FloatingPoint32Value]s are populated.
class FloatingPoint32ValuePopulator
    extends FloatingPointValuePopulator<FloatingPoint32Value> {
  /// Constructor for a 32-bit floating point value populator.
  FloatingPoint32ValuePopulator(super._unpopulated);

  @override
  FloatingPoint32Value ofDouble(double inDouble,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (roundingMode != FloatingPointRoundingMode.roundNearestEven) {
      return super.ofDouble(inDouble, roundingMode: roundingMode);
    }

    final byteData = ByteData(4)..setFloat32(0, inDouble);
    final accum = byteData.buffer
        .asUint8List()
        .map((b) => LogicValue.ofInt(b, 32))
        .reduce((accum, v) => (accum << 8) | v);

    return populate(
        sign: accum[-1],
        exponent: accum.slice(exponentWidth + mantissaWidth - 1, mantissaWidth),
        mantissa: accum.slice(mantissaWidth - 1, 0));
  }
}
