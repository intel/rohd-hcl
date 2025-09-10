// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sign_magnitude_value_test.dart
// Populator for sign-magnitude values.
//
// 2025 September 8
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  test('SignMagnitudeValue basic', () {
    final smv = SignMagnitudeValue.populator(width: 4)
        .populate(sign: LogicValue.one, magnitude: LogicValue.ofInt(3, 4));
    expect(smv.sign.toInt(), 1);
    expect(smv.magnitude.toInt(), 3);
    expect(smv.value.toInt(), 19);
    expect(smv.width, 4);
  });

  test('SignMagnitudeValue comparison', () {
    const width = 5;
    SignMagnitudeValuePopulator populator() =>
        SignMagnitudeValue.populator(width: width);

    for (var i = -15; i < 15; i++) {
      for (var j = -15; j < 15; j++) {
        final smv1 = populator().populate(
            sign: LogicValue.ofBool(i < 0),
            magnitude: LogicValue.ofInt(i.abs(), width));
        final smv2 = populator().populate(
            sign: LogicValue.ofBool(j < 0),
            magnitude: LogicValue.ofInt(j.abs(), width));
        expect(smv1.compareTo(smv2), i.compareTo(j));
        expect(smv1 == smv2, i == j);
        expect(smv1 < smv2, i < j);
        expect(smv1 <= smv2, i <= j);
        expect(smv1 > smv2, i > j);
        expect(smv1 >= smv2, i >= j);
      }
    }
  });

  group('SignMagnitude value: constrained random generation', () {
    const width = 4;
    SignMagnitudeValuePopulator populator() =>
        SignMagnitudeValue.populator(width: width);

    test('SignMagnitude value: tight constraint random generation', () {
      const gtInt = 12;
      const ltInt = 12;
      final gt = populator().ofInt(gtInt);
      final lt = populator().ofInt(ltInt);
      final rv = Random(71);
      final out = populator().random(rv, gte: gt, lte: lt);
      expect(out.toInt(), equals(gtInt));
      try {
        populator().random(rv, gt: gt, lt: lt);
        fail('should throw due to too tight a range');
      } on Exception catch (e) {
        expect(e, isA<RohdHclException>());
      }
      try {
        populator().random(rv, gte: gt, lt: lt);
        fail('should throw due to too tight a range');
      } on Exception catch (e) {
        expect(e, isA<RohdHclException>());
      }
      try {
        populator().random(rv, gt: gt, lte: lt);
        fail('should throw due to too tight a range');
      } on Exception catch (e) {
        expect(e, isA<RohdHclException>());
      }
    });

    test('SignMagnitude value: random generation', () {
      final rv = Random(71);
      for (var gtInt = -15; gtInt < 15; gtInt++) {
        for (var ltInt = gtInt; ltInt < 15; ltInt++) {
          final gt = populator().ofInt(gtInt);
          final lt = populator().ofInt(ltInt);
          for (var iter = 0; iter < 1000; iter++) {
            // Single-sided greater-than
            final fpvGtE = populator().random(rv, gte: gt);
            final outGtE = fpvGtE.toInt();
            expect(outGtE < gtInt, isFalse,
                reason: 'Value out of range $gtInt < $outGtE');
            if (gtInt < 15) {
              final fpvGt = populator().random(rv, gt: gt);
              final outGt = fpvGt.toInt();
              expect(outGt <= gtInt, isFalse,
                  reason: 'Value out of range $gtInt < $outGt');
            }
            // Single-sided less-than
            final fvpLtE = populator().random(rv, lte: lt);
            final outLtE = fvpLtE.toInt();
            expect(outLtE > ltInt, isFalse,
                reason: 'Value out of range $ltInt >= $outLtE');
            if (ltInt > -15) {
              final fvpLt = populator().random(rv, lt: lt);
              final outLt = fvpLt.toInt();
              expect(outLt >= ltInt, isFalse,
                  reason: 'Value out of range $ltInt >= $outLt');
            }
            // Double-sided
            final rnd = populator().random(rv, gte: gt, lte: lt);
            final out = rnd.toInt();
            expect(out < gtInt || out > ltInt, isFalse,
                reason: 'Value out of range $gtInt <= $out <= $ltInt');
            if (ltInt - gtInt > 1) {
              final fpvLt = populator().random(rv, gt: gt, lte: lt);
              final outLt = fpvLt.toInt();
              expect(outLt <= gtInt || outLt > ltInt, isFalse,
                  reason: 'Value out of range $gtInt < $out <= $ltInt');
              final fpvGt = populator().random(rv, gte: gt, lt: lt);
              final outGt = fpvGt.toInt();
              expect(outGt < gtInt || outGt >= ltInt, isFalse,
                  reason: 'Value out of range $gtInt <= $out < $ltInt');
              if (ltInt - gtInt > 2) {
                final fpvGt = populator().random(rv, gt: gt, lt: lt);
                final outGt = fpvGt.toInt();
                expect(outGt <= gtInt || outGt >= ltInt, isFalse,
                    reason: 'Value out of range $gtInt < $out < $ltInt');
              }
            }
          }
        }
      }
    });
  });
}
