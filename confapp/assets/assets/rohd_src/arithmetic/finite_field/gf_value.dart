// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// gf_value.dart
// Immutable values in binary extension fields.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/binary_extension_field.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_polynomial.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An immutable element of a [BinaryExtensionField].
///
/// Bit `i` of [value] is the coefficient of `x^i` in the field's polynomial
/// basis. Equality includes the field descriptor, not only the packed bits.
/// {@category Arithmetic}
@immutable
class GfValue {
  /// The field to which this element belongs.
  final BinaryExtensionField field;

  /// The packed polynomial-basis coefficients.
  final BigInt value;

  /// Creates an element of [field] from packed [value].
  GfValue(this.field, this.value) {
    if (value.isNegative || value >= field.size) {
      throw RohdHclException(
          'Finite-field element $value does not fit in ${field.degree} bits.');
    }
  }

  /// The packed coefficients as a two-state [LogicValue].
  LogicValue get logicValue => LogicValue.ofBigInt(value, field.degree);

  /// Whether this is the additive identity.
  bool get isZero => value == BigInt.zero;

  /// Adds [other] in this binary extension field.
  GfValue operator +(GfValue other) {
    _requireCompatible(other);
    return GfValue(field, value ^ other.value);
  }

  /// Subtracts [other], which is identical to addition in characteristic two.
  GfValue operator -(GfValue other) => this + other;

  /// Multiplies [other] using polynomial multiplication and modular reduction.
  GfValue operator *(GfValue other) {
    _requireCompatible(other);
    return field.fromPolynomial(
      BinaryPolynomial(value) * BinaryPolynomial(other.value),
    );
  }

  /// Divides by non-zero [other].
  GfValue operator /(GfValue other) {
    _requireCompatible(other);
    return this * other.inverse();
  }

  /// Returns this element squared.
  GfValue square() => this * this;

  /// Raises this element to a non-negative [exponent].
  GfValue pow(BigInt exponent) {
    if (exponent.isNegative) {
      throw RohdHclException('Finite-field exponents must be non-negative.');
    }

    var result = field.one;
    var factor = this;
    var remainingExponent = exponent;
    while (remainingExponent != BigInt.zero) {
      if (remainingExponent.isOdd) {
        result *= factor;
      }
      remainingExponent >>= 1;
      if (remainingExponent != BigInt.zero) {
        factor = factor.square();
      }
    }
    return result;
  }

  /// Returns the multiplicative inverse of this non-zero element.
  GfValue inverse() {
    if (isZero) {
      throw RohdHclException(
          'Zero has no multiplicative inverse in a finite field.');
    }
    return pow(field.size - BigInt.two);
  }

  void _requireCompatible(GfValue other) =>
      field.requireCompatible(other.field);

  @override
  bool operator ==(Object other) =>
      other is GfValue && field == other.field && value == other.value;

  @override
  int get hashCode => Object.hash(field, value);

  @override
  String toString() => 'GF(2^${field.degree}):0x${value.toRadixString(16)}';
}
