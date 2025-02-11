// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_64_value.dart
// Implementation of 64-bit Floating-Point value representations.
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a double-precision floating-point value.
class FloatingPoint64Value extends FloatingPointValue {
  /// The exponent width
  @override
  final int exponentWidth = 11;

  /// The mantissa width
  @override
  final int mantissaWidth = 52;

  /// Constructor for a double precision floating point value
  factory FloatingPoint64Value(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa}) =>
      populator().populate(sign: sign, exponent: exponent, mantissa: mantissa);

  @protected
  @override
  FloatingPoint64Value.unpop() : super.uninitialized();

  static FloatingPointValuePopulator<FloatingPoint64Value> populator() =>
      FloatingPoint64ValuePopulator(FloatingPoint64Value.unpop());

  @override
  FloatingPointValuePopulator clonePopulator() => populator();
}

class FloatingPoint64ValuePopulator
    extends FloatingPointValuePopulator<FloatingPoint64Value> {
  FloatingPoint64ValuePopulator(super._unpopulated);

  @override
  FloatingPoint64Value ofDouble(double inDouble,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (roundingMode != FloatingPointRoundingMode.roundNearestEven) {
      return super.ofDouble(inDouble, roundingMode: roundingMode);
    }

    final byteData = ByteData(8)..setFloat64(0, inDouble);
    final accum = byteData.buffer
        .asUint8List()
        .map((b) => LogicValue.ofInt(b, 64))
        .reduce((accum, v) => (accum << 8) | v);

    return populate(
        sign: accum[-1],
        exponent: accum.slice(exponentWidth + mantissaWidth - 1, mantissaWidth),
        mantissa: accum.slice(mantissaWidth - 1, 0));
  }
}
