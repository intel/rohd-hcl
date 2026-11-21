// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_extension_field.dart
// Descriptor for binary extension fields.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/finite_field/gf_value.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_polynomial.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// The basis used to represent elements of a binary extension field.
enum GfBasis {
  /// A polynomial basis modulo an irreducible binary polynomial.
  polynomial,
}

/// An immutable descriptor for a binary extension field GF(2^m).
///
/// Elements use [degree] packed bits as polynomial-basis coefficients and are
/// reduced modulo [modulus]. The modulus must be irreducible over GF(2) and
/// have degree at least one.
/// {@category Arithmetic}
@immutable
class BinaryExtensionField {
  /// The irreducible polynomial defining this field.
  final BinaryPolynomial modulus;

  /// The basis used for packed element representation.
  final GfBasis basis;

  /// Creates a binary extension field defined by [modulus].
  BinaryExtensionField({
    required this.modulus,
    this.basis = GfBasis.polynomial,
  }) {
    if (modulus.degree < 1) {
      throw RohdHclException(
          'A binary extension field modulus must have degree at least one.');
    }
    if (!modulus.isIrreducible) {
      throw RohdHclException(
          'Binary extension field modulus $modulus is reducible over GF(2).');
    }
  }

  /// The extension degree `m` in GF(2^m).
  int get degree => modulus.degree;

  /// The number of elements in the field.
  BigInt get size => BigInt.one << degree;

  /// The order of the field's multiplicative group.
  BigInt get multiplicativeOrder => size - BigInt.one;

  /// The packed mask for one field element.
  BigInt get elementMask => size - BigInt.one;

  /// The additive identity.
  GfValue get zero => GfValue(this, BigInt.zero);

  /// The multiplicative identity.
  GfValue get one => GfValue(this, BigInt.one);

  /// The polynomial-basis element `x`.
  GfValue get x => fromPolynomial(BinaryPolynomial(BigInt.two));

  /// A codec for arrays of values belonging to this field.
  LogicValueCodec<GfValue> get codec => LogicValueCodec(
        decode: fromLogicValue,
        encode: (value) {
          requireCompatible(value.field);
          return value.logicValue;
        },
      );

  /// Creates a field element from packed [value].
  GfValue element(BigInt value) => GfValue(this, value);

  /// Creates a field element from a packed integer [value].
  GfValue elementFromInt(int value) => element(BigInt.from(value));

  /// Creates a field element from a two-state [value].
  GfValue fromLogicValue(LogicValue value) {
    if (value.width != degree) {
      throw RohdHclException(
          'GF(2^$degree) values must have width $degree, not ${value.width}.');
    }
    if (!value.isValid) {
      throw RohdHclException('Finite-field values cannot contain x or z.');
    }
    return element(value.toBigInt());
  }

  /// Reduces [polynomial] modulo this field's defining polynomial.
  GfValue fromPolynomial(BinaryPolynomial polynomial) =>
      element((polynomial % modulus).coefficients);

  /// Whether [other] describes this same field and basis.
  bool isCompatibleWith(BinaryExtensionField other) => this == other;

  /// Throws if [other] does not describe this same field and basis.
  void requireCompatible(BinaryExtensionField other) {
    if (!isCompatibleWith(other)) {
      throw RohdHclException(
          'Finite-field operations require matching field descriptors.');
    }
  }

  /// Whether `x` generates every non-zero element of this field.
  ///
  /// [maximumOrder] bounds trial factorization for unexpectedly large fields.
  bool isPrimitivePolynomial({int maximumOrder = 1048575}) {
    final order = _checkedTableOrder(maximumOrder);
    for (final factor in _distinctPrimeFactors(order)) {
      if (x.pow(BigInt.from(order ~/ factor)) == one) {
        return false;
      }
    }
    return x.pow(BigInt.from(order)) == one;
  }

  /// Generates `x^0` through `x^(2^m - 2)` for reference-model use.
  ///
  /// The modulus must be primitive so that each non-zero element occurs once.
  /// [maximumElements] prevents accidental exponential-size allocations.
  List<GfValue> generateExponentTable({int maximumElements = 1048575}) {
    final order = _checkedTableOrder(maximumElements);
    if (!isPrimitivePolynomial(maximumOrder: maximumElements)) {
      throw RohdHclException(
          'Exponent tables require a primitive defining polynomial.');
    }

    final table = <GfValue>[];
    var value = one;
    for (var exponent = 0; exponent < order; exponent++) {
      table.add(value);
      value *= x;
    }
    return List<GfValue>.unmodifiable(table);
  }

  /// Generates packed-element logarithms to base `x`.
  ///
  /// The zero element has logarithm `-1`. The modulus must be primitive.
  List<int> generateLogTable({int maximumElements = 1048575}) {
    final exponentTable =
        generateExponentTable(maximumElements: maximumElements);
    final table = List<int>.filled(exponentTable.length + 1, -1);
    for (var exponent = 0; exponent < exponentTable.length; exponent++) {
      table[exponentTable[exponent].value.toInt()] = exponent;
    }
    return List<int>.unmodifiable(table);
  }

  int _checkedTableOrder(int maximumElements) {
    if (maximumElements <= 0) {
      throw RohdHclException('Maximum table size must be positive.');
    }
    if (multiplicativeOrder > BigInt.from(maximumElements)) {
      throw RohdHclException(
          'GF(2^$degree) requires $multiplicativeOrder table elements, '
          'exceeding the configured maximum of $maximumElements.');
    }
    return multiplicativeOrder.toInt();
  }

  static Set<int> _distinctPrimeFactors(int value) {
    var remaining = value;
    final factors = <int>{};
    for (var candidate = 2; candidate * candidate <= remaining; candidate++) {
      if (remaining % candidate != 0) {
        continue;
      }
      factors.add(candidate);
      while (remaining % candidate == 0) {
        remaining ~/= candidate;
      }
    }
    if (remaining > 1) {
      factors.add(remaining);
    }
    return factors;
  }

  @override
  bool operator ==(Object other) =>
      other is BinaryExtensionField &&
      modulus == other.modulus &&
      basis == other.basis;

  @override
  int get hashCode => Object.hash(modulus, basis);

  @override
  String toString() => 'GF(2^$degree, modulus: $modulus, basis: ${basis.name})';
}
