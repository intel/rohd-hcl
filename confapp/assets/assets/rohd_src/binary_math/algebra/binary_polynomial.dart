// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_polynomial.dart
// Immutable polynomials over GF(2).
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_literal.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// An immutable polynomial with coefficients in GF(2).
///
/// Bit `i` of [coefficients] is the coefficient of `x^i`. For example,
/// `x^3 + x + 1` is represented by `0b1011`.
/// {@category Binary Math}
@immutable
class BinaryPolynomial {
  /// The packed coefficients, with the constant coefficient in bit zero.
  final BigInt coefficients;

  /// Creates a binary polynomial from packed [coefficients].
  BinaryPolynomial(this.coefficients) {
    if (coefficients.isNegative) {
      throw RohdHclException(
          'Binary polynomial coefficients must be non-negative.');
    }
  }

  /// Creates a binary polynomial with coefficients at [exponents] set.
  factory BinaryPolynomial.fromExponents(Iterable<int> exponents) {
    var coefficients = BigInt.zero;
    for (final exponent in exponents) {
      if (exponent < 0) {
        throw RohdHclException(
            'Binary polynomial exponents must be non-negative.');
      }
      coefficients |= BigInt.one << exponent;
    }
    return BinaryPolynomial(coefficients);
  }

  /// Creates a binary polynomial from a ROHD width/radix-encoded [literal].
  ///
  /// For example, `9'h11d` represents `x^8 + x^4 + x^3 + x^2 + 1`.
  /// The value must not contain `x` or `z`.
  factory BinaryPolynomial.fromRadixString(String literal) =>
      BinaryPolynomial(parseBinaryMathRadixString(literal).value);

  /// Creates a binary polynomial from a two-state [value].
  ///
  /// The width of [value] is not retained because leading zero coefficients
  /// are not mathematically significant. The value must not contain `x` or
  /// `z`.
  factory BinaryPolynomial.fromLogicValue(LogicValue value) =>
      BinaryPolynomial(parseBinaryMathLogicValue(value).value);

  /// Creates a binary polynomial from a binary [digits] string.
  ///
  /// Underscores are accepted as separators. The rightmost digit is the
  /// constant coefficient. Use [BinaryPolynomial.fromRadixString] when an
  /// explicit width or a non-binary radix is desired.
  factory BinaryPolynomial.fromBinary(String digits) {
    final compressed = digits.replaceAll('_', '');
    if (compressed.isEmpty) {
      throw RohdHclException('Binary polynomial digits must not be empty.');
    }
    return BinaryPolynomial.fromRadixString("${compressed.length}'b$digits");
  }

  /// Creates a binary polynomial from hexadecimal [digits].
  ///
  /// Underscores are accepted as separators. The inferred width is four times
  /// the number of hexadecimal digits. Use
  /// [BinaryPolynomial.fromRadixString] to specify an exact width that is not a
  /// multiple of four.
  factory BinaryPolynomial.fromHex(String digits) {
    final compressed = digits.replaceAll('_', '');
    if (compressed.isEmpty) {
      throw RohdHclException(
          'Hexadecimal polynomial digits must not be empty.');
    }
    return BinaryPolynomial.fromRadixString(
        "${compressed.length * 4}'h$digits");
  }

  /// The zero polynomial.
  static final zero = BinaryPolynomial(BigInt.zero);

  /// The multiplicative identity polynomial.
  static final one = BinaryPolynomial(BigInt.one);

  /// The degree, or `-1` for the zero polynomial.
  int get degree => coefficients.bitLength - 1;

  /// Whether this is the zero polynomial.
  bool get isZero => coefficients == BigInt.zero;

  /// Returns the coefficient of `x^[exponent]`.
  bool coefficient(int exponent) {
    if (exponent < 0) {
      throw RohdHclException(
          'Binary polynomial exponents must be non-negative.');
    }
    return ((coefficients >> exponent) & BigInt.one) == BigInt.one;
  }

  /// Adds two polynomials over GF(2).
  BinaryPolynomial operator +(BinaryPolynomial other) =>
      BinaryPolynomial(coefficients ^ other.coefficients);

  /// Subtracts two polynomials over GF(2), which is identical to addition.
  BinaryPolynomial operator -(BinaryPolynomial other) => this + other;

  /// Multiplies two polynomials over GF(2).
  BinaryPolynomial operator *(BinaryPolynomial other) {
    var multiplier = other.coefficients;
    var shiftedMultiplicand = coefficients;
    var product = BigInt.zero;

    while (multiplier != BigInt.zero) {
      if (multiplier.isOdd) {
        product ^= shiftedMultiplicand;
      }
      multiplier >>= 1;
      shiftedMultiplicand <<= 1;
    }
    return BinaryPolynomial(product);
  }

  /// Divides this polynomial by [divisor], returning quotient and remainder.
  ({BinaryPolynomial quotient, BinaryPolynomial remainder}) divide(
      BinaryPolynomial divisor) {
    if (divisor.isZero) {
      throw RohdHclException('Cannot divide a binary polynomial by zero.');
    }

    var remainder = coefficients;
    var quotient = BigInt.zero;
    while (remainder != BigInt.zero &&
        remainder.bitLength >= divisor.coefficients.bitLength) {
      final shift = remainder.bitLength - divisor.coefficients.bitLength;
      quotient |= BigInt.one << shift;
      remainder ^= divisor.coefficients << shift;
    }

    return (
      quotient: BinaryPolynomial(quotient),
      remainder: BinaryPolynomial(remainder),
    );
  }

  /// Returns the quotient of division by [divisor].
  BinaryPolynomial operator ~/(BinaryPolynomial divisor) =>
      divide(divisor).quotient;

  /// Returns the remainder after division by [divisor].
  BinaryPolynomial operator %(BinaryPolynomial divisor) =>
      divide(divisor).remainder;

  /// Returns the greatest common divisor of this polynomial and [other].
  BinaryPolynomial gcd(BinaryPolynomial other) {
    var a = this;
    var b = other;
    while (!b.isZero) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }
    return a;
  }

  /// Raises this polynomial to [exponent] modulo [modulus].
  BinaryPolynomial modPow(BigInt exponent, BinaryPolynomial modulus) {
    if (exponent.isNegative) {
      throw RohdHclException(
          'Binary polynomial exponents must be non-negative.');
    }
    if (modulus.isZero) {
      throw RohdHclException('Binary polynomial modulus must be non-zero.');
    }

    var result = one % modulus;
    var factor = this % modulus;
    var remainingExponent = exponent;
    while (remainingExponent != BigInt.zero) {
      if (remainingExponent.isOdd) {
        result = (result * factor) % modulus;
      }
      remainingExponent >>= 1;
      if (remainingExponent != BigInt.zero) {
        factor = (factor * factor) % modulus;
      }
    }
    return result;
  }

  /// Whether this polynomial is irreducible over GF(2).
  ///
  /// Uses the Rabin irreducibility test. Constant polynomials are not
  /// irreducible; every degree-one polynomial is irreducible.
  bool get isIrreducible {
    if (degree <= 0) {
      return false;
    }
    if (degree == 1) {
      return true;
    }
    if (!coefficient(0)) {
      return false;
    }

    final x = BinaryPolynomial(BigInt.two);
    var frobeniusPower = x;
    for (var index = 1; index <= degree ~/ 2; index++) {
      frobeniusPower = (frobeniusPower * frobeniusPower) % this;
      if ((frobeniusPower + x).gcd(this) != one) {
        return false;
      }
    }

    frobeniusPower = x;
    for (var index = 0; index < degree; index++) {
      frobeniusPower = (frobeniusPower * frobeniusPower) % this;
    }
    return frobeniusPower == x;
  }

  /// Returns the formal derivative over GF(2).
  BinaryPolynomial derivative() {
    var derivative = BigInt.zero;
    for (var exponent = 1; exponent <= degree; exponent += 2) {
      if (coefficient(exponent)) {
        derivative |= BigInt.one << (exponent - 1);
      }
    }
    return BinaryPolynomial(derivative);
  }

  /// Evaluates this polynomial for [x] in GF(2).
  bool evaluate({required bool x}) =>
      x ? _hasOddParity(coefficients) : coefficient(0);

  static bool _hasOddParity(BigInt value) {
    var remaining = value;
    var parity = false;
    while (remaining != BigInt.zero) {
      parity = !parity;
      remaining &= remaining - BigInt.one;
    }
    return parity;
  }

  @override
  bool operator ==(Object other) =>
      other is BinaryPolynomial && coefficients == other.coefficients;

  @override
  int get hashCode => coefficients.hashCode;

  @override
  String toString() {
    if (isZero) {
      return '0';
    }
    final terms = <String>[];
    for (var exponent = degree; exponent >= 0; exponent--) {
      if (!coefficient(exponent)) {
        continue;
      }
      terms.add(switch (exponent) {
        0 => '1',
        1 => 'x',
        _ => 'x^$exponent',
      });
    }
    return terms.join(' + ');
  }
}
