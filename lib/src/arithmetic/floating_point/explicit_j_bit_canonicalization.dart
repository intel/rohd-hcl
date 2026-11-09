// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// explicit_j_bit_canonicalization.dart
// Shared explicit-J-bit canonicalization logic.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Canonicalizes a finite explicit-J-bit value without losing precision.
///
/// Special values retain their classification and NaN payload. Infinities
/// are mapped to the format's canonical infinity encoding.
FloatingPoint canonicalizeExplicitJBit(
  FloatingPoint value, {
  PriorityEncoder Function(Logic bitVector, {bool generateValid, String name})
      priorityGen = RecursiveModulePriorityEncoder.new,
}) {
  if (!value.explicitJBit) {
    throw ArgumentError('Canonicalization requires an explicit J bit.');
  }
  if (value.exponent.width < 2) {
    throw ArgumentError('Explicit-J alignment requires at least two exponent '
        'bits to represent canonical normal values.');
  }
  final encoder = priorityGen(
    value.mantissa.reversed,
    generateValid: true,
    name: 'canonical_leading_one',
  );
  final width = max(value.exponent.width, encoder.out.width);
  final exponent = value.exponent.zeroExtend(width);
  final effectiveExponent = mux(
    exponent.eq(0),
    Const(1, width: width),
    exponent,
  );
  final leadingZeros = encoder.out.zeroExtend(width);
  final maxShift = effectiveExponent - Const(1, width: width);
  final shift = mux(leadingZeros.lt(maxShift), leadingZeros, maxShift);
  final shiftedMantissa = value.mantissa << shift;
  final canonicalExponent = mux(
    encoder.valid! & shiftedMantissa[-1],
    effectiveExponent - shift,
    Const(0, width: width),
  ).getRange(0, value.exponent.width);
  final special = value.isNaN | value.isAnInfinity;
  final result = value.clone(name: 'canonical_explicit_j');
  result.sign <= value.sign;
  result.exponent <= mux(special, value.exponent, canonicalExponent);
  result.mantissa <=
      mux(
        value.isNaN,
        value.mantissa,
        mux(
          value.isAnInfinity,
          Const(value.valuePopulator().positiveInfinity.mantissa),
          shiftedMantissa,
        ),
      );
  return result;
}
