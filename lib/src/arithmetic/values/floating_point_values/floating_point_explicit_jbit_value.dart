// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_explicit_jbit_value.dart
// Implementation of Floating-Point value representation for explicit jbit.
//
// 2025 February 20
// Author:
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A flexible representation of floating point values. A
/// [FloatingPointExplicitJBitValue]is an explicit j-bit form of
/// [FloatingPointValue] where all numbers are represented with an explicit
/// leading 1 (except for zero).
@immutable
class FloatingPointExplicitJBitValue extends FloatingPointValue {
  /// Creates a [FloatingPointValuePopulator] for the same type as `this` and
  /// with the same widths.
  ///
  /// This must be overridden in subclasses so that the correct type of
  /// [FloatingPointValuePopulator] is returned for generating equivalent types
  /// of [FloatingPointValue]s.
  @override
  FloatingPointExplicitJBitPopulator clonePopulator() =>
      FloatingPointExplicitJBitPopulator(
          FloatingPointExplicitJBitValue.uninitialized());

  /// Constructor for a [FloatingPointValue] with the provided [sign],
  /// [exponent], and [mantissa].
  factory FloatingPointExplicitJBitValue(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa}) =>
      populator(exponentWidth: exponent.width, mantissaWidth: mantissa.width)
          .populate(sign: sign, exponent: exponent, mantissa: mantissa);

  /// Creates an unpopulated version of a [FloatingPointExplicitJBitValue],
  /// intended to be called with the [populator].
  @protected
  FloatingPointExplicitJBitValue.uninitialized() : super.uninitialized();

  /// Creates a [FloatingPointExplicitJBitPopulator] with the provided
  /// [exponentWidth] and [mantissaWidth], which can then be used to
  /// complete construction of a [FloatingPointExplicitJBitValue] using
  /// population functions.
  static FloatingPointExplicitJBitPopulator populator(
          {required int exponentWidth, required int mantissaWidth}) =>
      FloatingPointExplicitJBitPopulator(
          FloatingPointExplicitJBitValue.uninitialized()
            ..storedExponentWidth = exponentWidth
            ..storedMantissaWidth = mantissaWidth);

  /// A wrapper around [FloatingPointValuePopulator.ofBinaryStrings] that
  /// computes the widths of the exponent and mantissa from the input string.
  factory FloatingPointExplicitJBitValue.ofBinaryStrings(
          String sign, String exponent, String mantissa) =>
      populator(exponentWidth: exponent.length, mantissaWidth: mantissa.length)
          .ofBinaryStrings(sign, exponent, mantissa);

  /// A wrapper around [FloatingPointValuePopulator.ofSpacedBinaryString] that
  /// computes the widths of the exponent and mantissa from the input string.
  factory FloatingPointExplicitJBitValue.ofSpacedBinaryString(String fp) {
    final split = fp.split(' ');
    return populator(
            exponentWidth: split[1].length, mantissaWidth: split[2].length)
        .ofSpacedBinaryString(fp);
  }

  /// Return true if the JBit is explicitly represented in the mantissa.
  @override
  bool get explicitJBit => true;

  /// Return the cananocalized form of [FloatingPointExplicitJBitValue] which
  /// has the leading 1 at the front of the mantissa, or further right if
  /// subnormal.
  FloatingPointExplicitJBitValue canonicalize() {
    var expVal = exponent.toInt();
    var mant = mantissa;
    if (!isAnInfinity) {
      if (!isNaN) {
        if (mant.or() == LogicValue.one) {
          while ((mant[-1] == LogicValue.zero) & (expVal > 1)) {
            expVal--;
            mant = mant << 1;
          }
          if ((mant[-1] == LogicValue.zero) & (expVal == 1)) {
            // Make canonical: if it cannot be made normal, it is subnormal
            expVal = 0;
          } else if ((mant[-1] == LogicValue.one) & (expVal == 0)) {
            expVal = 1;
          }
        } else {
          expVal = 0;
        }
      } else {
        return populator(
                exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
            .nan;
      }
    }
    return FloatingPointExplicitJBitValue(
        sign: sign,
        exponent: LogicValue.ofInt(expVal, exponentWidth),
        mantissa: mant);
  }

  /// Convert to a [FloatingPointValue] with a mantissa that is one smaller
  /// due to the implicit J-bit.
  FloatingPointValue toFloatingPointValue() {
    final norm = canonicalize();
    return FloatingPointValue(
        sign: norm.sign,
        exponent: norm.exponent,
        mantissa: norm.mantissa.getRange(0, norm.mantissa.width - 1));
  }

  /// Check if the mantissa and exponent form a normal value
  bool isNormalValue() {
    final e = exponent.toInt();
    final m = mantissa.toInt();
    final int normMantissa;
    if (e < mantissa.width) {
      normMantissa = 1 << (mantissa.width - e - 1);
    } else {
      normMantissa = 1;
    }
    return (e > 0) && (m >= normMantissa);
  }

  /// Check if the mantissa and exponent stored are compatible
  bool isLegalValue() {
    final e = exponent.toInt();
    final m = mantissa.toInt();
    // TODO(desmonddak): We need to check this with bit-pattern testing
    // of legal mantissas and that exponents are compatible with those.
    // Basically, if e > 0 then we expect a 1 somewhere.  If e == 0 then
    // we expect anything except a leading 1 in the mantissas.
    final normMantissa = 1 << (mantissa.width - 1);

    return ((e == 0) && (m < normMantissa)) || ((e > 0) && (m >= 1));
  }
}
