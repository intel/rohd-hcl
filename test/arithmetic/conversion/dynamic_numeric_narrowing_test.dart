// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Map<String, int> _reference(int bits, int shift,
    {required bool signed,
    required int outputWidth,
    required NumericRoundingMode rounding,
    required NumericOverflowMode overflow}) {
  final value = signed ? bits.toSigned(4) : bits;
  final negative = value < 0;
  final magnitude = value.abs();
  final quotient = magnitude >> shift;
  final remainder = magnitude & ((1 << shift) - 1);
  final half = shift == 0 ? 0 : 1 << (shift - 1);
  final increment = switch (rounding) {
    NumericRoundingMode.truncate || NumericRoundingMode.towardZero => false,
    NumericRoundingMode.nearestEven =>
      shift != 0 && (remainder > half || (remainder == half && quotient.isOdd)),
    NumericRoundingMode.nearestTiesAway => shift != 0 && remainder >= half,
    NumericRoundingMode.towardPositiveInfinity => !negative && remainder != 0,
    NumericRoundingMode.towardNegativeInfinity => negative && remainder != 0,
  };
  final rounded = (negative ? -1 : 1) * (quotient + (increment ? 1 : 0));
  final minimum = signed ? -(1 << (outputWidth - 1)) : 0;
  final maximum =
      signed ? (1 << (outputWidth - 1)) - 1 : (1 << outputWidth) - 1;
  final result = overflow == NumericOverflowMode.saturate
      ? rounded.clamp(minimum, maximum)
      : rounded;
  return {
    'result': result & ((1 << outputWidth) - 1),
    'overflowed': rounded > maximum ? 1 : 0,
    'underflowed': rounded < minimum ? 1 : 0,
    'inexact': remainder == 0 ? 0 : 1,
  };
}

void main() {
  tearDown(Simulator.reset);

  test('runtime narrowing handles every shift, sign and rounding mode',
      () async {
    for (final signed in [false, true]) {
      for (final width in [3, 6]) {
        for (final rounding in NumericRoundingMode.values) {
          for (final overflow in NumericOverflowMode.values) {
            for (final shiftWidth in [1, 3]) {
              final dut = DynamicNumericNarrowing(
                Logic(width: 4),
                Logic(width: shiftWidth),
                outputWidth: width,
                signed: signed,
                roundingMode: rounding,
                overflowMode: overflow,
              );
              await dut.build();
              final vectors = [
                for (var value = 0; value < 16; value++)
                  for (var shift = 0; shift < 1 << shiftWidth; shift++)
                    Vector(
                      {'value': value, 'shift': shift},
                      _reference(value, shift,
                          signed: signed,
                          outputWidth: width,
                          rounding: rounding,
                          overflow: overflow),
                    ),
              ];
              await SimCompare.checkFunctionalVector(dut, vectors);
              SimCompare.checkIverilogVector(dut, vectors);
              await Simulator.reset();
            }
          }
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
