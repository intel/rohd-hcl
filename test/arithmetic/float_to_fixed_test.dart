// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// float_to_fixed_test.dart
// Test floating point to fixed point conversion.
//
// 2024 November 1
// Author: Soner Yaldiz <soner.yaldiz@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() async {
  test('E5M2 to Q16.16 exhaustive', () async {
    final float = FloatingPoint(exponentWidth: 5, mantissaWidth: 2);
    final dut = FloatToFixed(float);
    await dut.build();
    for (var val = 0; val < pow(2, 8); val++) {
      final fpv = FloatingPointValue.ofLogicValue(
          5, 2, LogicValue.ofInt(val, float.width));
      if (!fpv.isAnInfinity & !fpv.isNaN) {
        float.put(fpv);
        final fxp = dut.fixed;
        final fxpExp = FixedPointValue.ofDouble(fpv.toDouble(),
            signed: true, m: dut.m, n: dut.n);
        expect(fxp.value.bitString, fxpExp.value.bitString);
      }
    }
  });

  test('FloatToFixed: exhaustive lossless round-trip fp-fx-fp', () {
    for (var sEW = 2; sEW < 6; sEW++) {
      for (var sMW = 2; sMW < 7; sMW++) {
        final fp1 = FloatingPoint(exponentWidth: sEW, mantissaWidth: sMW)
          ..put(0);
        final convert = FloatToFixed(fp1);
        for (final negate in [false, true]) {
          for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
            for (var m1 = 0; m1 < pow(2, sMW); m1++) {
              final fv1 = FloatingPointValue.ofInts(e1, m1,
                  exponentWidth: sEW, mantissaWidth: sMW, sign: negate);
              fp1.put(fv1.value);
              final fx2 = convert.fixed;
              final dbl = fx2.fixedPointValue.toDouble();
              final dbl2 = fv1.toDouble();
              expect(dbl, equals(dbl2));
            }
          }
        }
      }
    }
  });

  // TODO(desmonddak): float-to-fixed is limited by e=6 by toDouble()
  test('FloatToFixed: exhaustive round-trip fp->smallerfx fpv->xpv', () {
    for (var sEW = 2; sEW < 5; sEW++) {
      print('sEW=$sEW');
      for (var sMW = 2; sMW < 5; sMW++) {
        final fp1 = FloatingPoint(exponentWidth: sEW, mantissaWidth: sMW)
          ..put(0);
        final nominal = FloatToFixed(fp1);
        for (var i = 0; i < nominal.n - 2; i++) {
          final tN = nominal.n - i;
          for (var j = 0; j < nominal.m - 2; j++) {
            final tM = nominal.m - j;
            final convert = FloatToFixed(fp1, m: tM, n: tN);
            final fxc = convert.fixed;
            for (final negate in [false, true]) {
              for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
                for (var m1 = 0; m1 < pow(2, sMW); m1++) {
                  final fv1 = FloatingPointValue.ofInts(e1, m1,
                      exponentWidth: sEW, mantissaWidth: sMW, sign: negate);
                  fp1.put(fv1.value);
                  final fx = FixedPointValue.ofDouble(fv1.toDouble(),
                      signed: true, m: tM, n: tN);
                  expect(fxc.fixedPointValue, equals(fx), reason: '''
                    $fx (${fx.toDouble()})
                    ${fxc.fixedPointValue} (${fxc.fixedPointValue.toDouble()})
                    $fv1 (${fv1.toDouble()})
                    sEW=$sEW
                    sMW=$sMW
                    e1=$e1
                    m1=$m1
                    m=$tM
                    n=$tN
                    negate=$negate
''');
                }
              }
            }
          }
        }
      }
    }
  });
  // TODO(desmonddak): we use rounding to avoid problems with negative
  // numbers, but we don't have any rounding code so this may end up
  // with some problems in other corner cases.
  test('FloatToFixed: exhaustive round-trip fp->smaller_n fpv->xpv', () {
    for (var sEW = 2; sEW < 5; sEW++) {
      for (var sMW = 2; sMW < 6; sMW++) {
        final fp1 = FloatingPoint(exponentWidth: sEW, mantissaWidth: sMW)
          ..put(0);
        final nominal = FloatToFixed(fp1);
        for (var i = 0; i < nominal.n - 2; i++) {
          final tN = nominal.n - i;
          final tM = nominal.m;
          final convert = FloatToFixed(fp1, m: tM, n: tN);
          for (final negate in [false, true]) {
            for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
              for (var m1 = 0; m1 < pow(2, sMW); m1++) {
                final fv1 = FloatingPointValue.ofInts(e1, m1,
                    exponentWidth: sEW, mantissaWidth: sMW, sign: negate);
                fp1.put(fv1.value);
                final fxc = convert.fixed;

                final fx = FixedPointValue.ofDouble(fv1.toDouble(),
                    signed: true, m: tM, n: tN);

                expect(fxc.fixedPointValue, equals(fx), reason: '''
                    $fx (${fx.toDouble()})
                    ${fxc.fixedPointValue} (${fxc.fixedPointValue.toDouble()})
                    $fv1 (${fv1.toDouble()})
                    sEW=$sEW
                    sMW=$sMW
                    e1=$e1
                    m1=$m1
                    m=$tM
                    n=$tN
                    negate=$negate
''');
              }
            }
          }
        }
      }
    }
  });

  test('FloatToFixed: exhaustive round-trip fp->smaller_m->fp', () {
    for (var sEW = 2; sEW < 5; sEW++) {
      for (var sMW = 2; sMW < 5; sMW++) {
        final fp1 = FloatingPoint(exponentWidth: sEW, mantissaWidth: sMW)
          ..put(0);
        final nominal = FloatToFixed(fp1);
        for (var i = 0; i < nominal.m - 2; i++) {
          final tM = nominal.m - i;
          final convert =
              FloatToFixed(fp1, m: tM, n: nominal.n, checkOverflow: true);
          for (final negate in [false, true]) {
            for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
              for (var m1 = 0; m1 < pow(2, sMW); m1++) {
                final fv1 = FloatingPointValue.ofInts(e1, m1,
                    exponentWidth: sEW, mantissaWidth: sMW, sign: negate);
                fp1.put(fv1.value);
                final fx2 = convert.fixed;
                final dbl = fx2.fixedPointValue.toDouble();
                final dbl2 = fv1.toDouble();
                if (convert.overflow != null) {
                  if (!convert.overflow!.value.toBool()) {
                    expect(dbl, equals(dbl2));
                  }
                }
              }
            }
          }
        }
      }
    }
  });
  test('FloatToFixed: exhaustive round-trip fp->larger_fx->fp', () {
    for (var sEW = 2; sEW < 6; sEW++) {
      for (var sMW = 2; sMW < 7; sMW++) {
        final fp1 = FloatingPoint(exponentWidth: sEW, mantissaWidth: sMW)
          ..put(0);
        final nominal = FloatToFixed(fp1);
        final convert = FloatToFixed(fp1, m: nominal.m + 4, n: nominal.n + 2);
        for (final negate in [false, true]) {
          for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
            for (var m1 = 0; m1 < pow(2, sMW); m1++) {
              final fv1 = FloatingPointValue.ofInts(e1, m1,
                  exponentWidth: sEW, mantissaWidth: sMW, sign: negate);
              fp1.put(fv1.value);
              final fx2 = convert.fixed;
              final dbl = fx2.fixedPointValue.toDouble();
              final dbl2 = fv1.toDouble();
              expect(dbl, equals(dbl2));
            }
          }
        }
      }
    }
  });

  test('FP8toINT: exhaustive', () async {
    final float = Logic(width: 8);
    final mode = Logic();
    final dut = Float8ToFixed(float, mode);
    await dut.build();

    // E4M3
    mode.put(1);
    for (var val = 0; val < pow(2, 8); val++) {
      final fp8 = FloatingPointValue.ofLogicValue(
          4, 3, LogicValue.ofInt(val, float.width));
      if (!fp8.isNaN & !fp8.isAnInfinity) {
        float.put(fp8.value);
        final fx8 =
            FixedPointValue.ofDouble(fp8.toDouble(), signed: true, m: 23, n: 9);
        expect(dut.fixed.value.bitString, fx8.value.bitString);
        expect(dut.q23p9.value, fx8.value);
      }
    }

    // E5M2
    mode.put(0);
    for (var val = 0; val < pow(2, 8); val++) {
      final fp8 = FloatingPointValue.ofLogicValue(
          5, 2, LogicValue.ofInt(val, float.width));
      if (!fp8.isNaN & !fp8.isAnInfinity) {
        float.put(fp8.value);
        final fx8 = FixedPointValue.ofDouble(fp8.toDouble(),
            signed: true, m: 16, n: 16);
        expect(dut.fixed.value.bitString, fx8.value.bitString);
        expect(dut.q16p16.value, fx8.value);
      }
    }
  });
}

// Idea for testing lossy conversion:  float to fixed:
// Converting a fixed to a larger float, then back to the fixed should result
// in no loss. While there is loss, it should not be seen in representable
// numbers.

// TODO(desmonddak): write this test first and drive the lossy conversion.
// Should we test this first on the Value side?

// Alternatively:  fixed to float:
//  if we use a larger than needed float and convert back to fixed, there
// should be no loss.
// TODO(desmonddak): Value first, then logic
