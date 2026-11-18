// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// numeric_narrowing_test.dart
// Reference-model tests for explicit rounding and narrowing.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Map<String, int> _reference(int bits, bool signed, int outputWidth, int shift,
    NumericRoundingMode rounding, NumericOverflowMode overflow) {
  final value = signed && bits >= 16 ? bits - 32 : bits;
  final negative = value < 0;
  final magnitude = value.abs();
  final divisor = 1 << shift;
  final remainder = magnitude % divisor;
  var rounded = magnitude ~/ divisor;
  final increment = switch (rounding) {
    NumericRoundingMode.truncate || NumericRoundingMode.towardZero => false,
    NumericRoundingMode.nearestEven =>
      remainder * 2 > divisor || (remainder * 2 == divisor && rounded.isOdd),
    NumericRoundingMode.nearestTiesAway => remainder * 2 >= divisor,
    NumericRoundingMode.towardPositiveInfinity => !negative && remainder != 0,
    NumericRoundingMode.towardNegativeInfinity => negative && remainder != 0,
  };
  if (increment) {
    rounded++;
  }
  var result = negative ? -rounded : rounded;
  final minimum = signed ? -(1 << (outputWidth - 1)) : 0;
  final maximum =
      signed ? (1 << (outputWidth - 1)) - 1 : (1 << outputWidth) - 1;
  final overflowed = result > maximum;
  final underflowed = result < minimum;
  if (overflow == NumericOverflowMode.saturate) {
    result = result.clamp(minimum, maximum);
  }
  return {
    'result': result & ((1 << outputWidth) - 1),
    'overflowed': overflowed ? 1 : 0,
    'underflowed': underflowed ? 1 : 0,
    'inexact': remainder == 0 ? 0 : 1,
  };
}

void main() {
  tearDown(Simulator.reset);

  test('matches integer reference across rounding and range policies',
      () async {
    for (final signed in [false, true]) {
      for (final rounding in NumericRoundingMode.values) {
        for (final overflow in NumericOverflowMode.values) {
          for (final shift in [0, 1, 2, 5]) {
            for (final outputWidth in [2, 3, 6]) {
              final dut = NumericNarrowing(
                Logic(width: 5),
                outputWidth: outputWidth,
                signed: signed,
                shiftRight: shift,
                roundingMode: rounding,
                overflowMode: overflow,
              );
              await dut.build();
              final vectors = [
                for (var input = 0; input < 32; input++)
                  Vector(
                      {'value': input},
                      _reference(input, signed, outputWidth, shift, rounding,
                          overflow)),
              ];
              await SimCompare.checkFunctionalVector(dut, vectors);
              if (shift == 2 && outputWidth == 3) {
                SimCompare.checkIverilogVector(dut, vectors);
              }
              await Simulator.reset();
            }
          }
        }
      }
    }
  });
}
