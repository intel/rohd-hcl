// Copyright (C) 2021-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/signals/signals.dart';
import 'package:rohd_hcl/src/arithmetic/values/complex_fixed_point_value.dart';
import 'package:rohd_hcl/src/exceptions.dart';

class ComplexFixedPoint extends Logic {
  final bool signed;

  final int integerBits;

  final int fractionalBits;

  static int _fixedPointWidth(
    bool signed,
    int integerBits,
    int fractionalBits,
  ) =>
      signed ? 1 + integerBits + fractionalBits : integerBits + fractionalBits;

  static int _complexFixedPointWidth(
    bool signed,
    int integerBits,
    int fractionalBits,
  ) =>
      2 * _fixedPointWidth(signed, integerBits, fractionalBits);

  ComplexFixedPoint({
    required this.signed,
    required this.integerBits,
    required this.fractionalBits,
    super.name,
    super.naming,
  })  : assert(integerBits > 0),
        assert(fractionalBits > 0),
        assert(max(integerBits, fractionalBits) > 0),
        super(
          width: _complexFixedPointWidth(signed, integerBits, fractionalBits),
        ) {}

  static ComplexFixedPoint fromPartsUnsafe(Logic realPart, Logic imaginaryPart,
      bool signed, int integerBits, int fractionalBits) {
    final result = ComplexFixedPoint(
        signed: signed,
        integerBits: integerBits,
        fractionalBits: fractionalBits);

    result._realPart() <= realPart;
    result._imaginaryPart() <= imaginaryPart;

    return result;
  }

  static ComplexFixedPoint fromParts(
      FixedPoint realPart, FixedPoint imaginaryPart) {
    assert(realPart.signed == imaginaryPart.signed);
    assert(realPart.m == imaginaryPart.m);
    assert(realPart.n == imaginaryPart.n);

    final result = ComplexFixedPoint(
        signed: realPart.signed,
        integerBits: realPart.m,
        fractionalBits: realPart.n);

    result._realPart() <= realPart;
    result._imaginaryPart() <= imaginaryPart;

    return result;
  }

  void _verifyCompatible(ComplexFixedPoint other) {
    if ((signed != other.signed) |
        (integerBits != other.integerBits) |
        (fractionalBits != other.fractionalBits)) {
      throw RohdHclException('Inputs are not comparable.');
    }
  }

  Logic _realPart() =>
      getRange(0, _fixedPointWidth(signed, integerBits, fractionalBits));

  FixedPoint realPart() => FixedPoint.of(_realPart(),
      signed: signed, m: integerBits, n: fractionalBits);

  Logic _imaginaryPart() =>
      getRange(_fixedPointWidth(signed, integerBits, fractionalBits), width);

  FixedPoint imaginaryPart() => FixedPoint.of(_imaginaryPart(),
      signed: signed, m: integerBits, n: fractionalBits);

  @override
  void put(dynamic val, {bool fill = false}) {
    if (val is ComplexFixedPointValue) {
      if ((signed != val.realPart.signed) |
          (integerBits != val.realPart.m) |
          (fractionalBits != val.realPart.n)) {
        throw RohdHclException('Value is not compatible with signal.');
      }

      _realPart().put(val.realPart);
      _imaginaryPart().put(val.imaginaryPart);
    } else {
      throw RohdHclException('Only ComplexFixedPointValue is allowed');
    }
  }

  @override
  Logic lt(dynamic other) {
    if (other is! ComplexFixedPoint) {
      throw RohdHclException('Input must be complex fixed point signal.');
    }
    _verifyCompatible(other);
    return realPart().lt(other.realPart()) &
        imaginaryPart().lt(other.imaginaryPart());
  }

  @override
  Logic lte(dynamic other) {
    if (other is! ComplexFixedPoint) {
      throw RohdHclException('Input must be complex fixed point signal.');
    }
    _verifyCompatible(other);
    return realPart().lte(other.realPart()) &
        imaginaryPart().lte(other.imaginaryPart());
  }

  @override
  Logic gt(dynamic other) {
    if (other is! ComplexFixedPoint) {
      throw RohdHclException('Input must be complex fixed point signal.');
    }
    _verifyCompatible(other);
    return realPart().gt(other.realPart()) &
        imaginaryPart().gt(other.imaginaryPart());
  }

  @override
  Logic gte(dynamic other) {
    if (other is! ComplexFixedPoint) {
      throw RohdHclException('Input must be complex fixed point signal.');
    }
    _verifyCompatible(other);
    return realPart().gte(other.realPart()) &
        imaginaryPart().gte(other.imaginaryPart());
  }

  Logic _add(dynamic other) {
    if (other is! ComplexFixedPoint) {
      throw RohdHclException('Input must be complex fixed point signal.');
    }
    _verifyCompatible(other);
    return fromPartsUnsafe(
        realPart() + other.realPart(),
        imaginaryPart() + other.imaginaryPart(),
        signed,
        integerBits + 1,
        fractionalBits);
  }

  Logic _multiply(dynamic other) {
    if (other is! ComplexFixedPoint) {
      throw RohdHclException('Input must be complex fixed point signal.');
    }
    _verifyCompatible(other);
    // use only 3 multipliers: https://mathworld.wolfram.com/ComplexMultiplication.html
    final ac = realPart() * other.realPart();
    final bd = imaginaryPart() * other.imaginaryPart();
    final abcd = (realPart() + imaginaryPart()) *
        (other.realPart() + other.imaginaryPart());
    return fromPartsUnsafe(
        ac - bd, abcd - ac - bd, signed, integerBits * 2, fractionalBits * 2);
  }

  @override
  Logic operator >(dynamic other) => gt(other);

  @override
  Logic operator >=(dynamic other) => gte(other);

  @override
  Logic operator +(dynamic other) => _add(other);

  @override
  Logic operator *(dynamic other) => _multiply(other);

  @override
  Logic eq(dynamic other) {
    if (other is! ComplexFixedPoint) {
      throw RohdHclException('Input must be complex fixed point signal.');
    }
    _verifyCompatible(other);
    return super.eq(other);
  }

  @override
  Logic neq(dynamic other) {
    if (other is! ComplexFixedPoint) {
      throw RohdHclException('Input must be complex fixed point signal.');
    }
    _verifyCompatible(other);
    return super.neq(other);
  }
}
