// Copyright (C) 2024-2026 Intel Corporation
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
  FixedPointValue exactFixedValue(
      FloatingPointValue source, FixedPoint destination) {
    final fractionBits = source.mantissaWidth - (source.explicitJBit ? 1 : 0);
    final normal = !source.exponent.isZero;
    final significand = source.mantissa.toBigInt() |
        (normal && !source.explicitJBit
            ? BigInt.one << fractionBits
            : BigInt.zero);
    final unbiasedExponent =
        normal ? source.exponent.toInt() - source.bias : source.minExponent;
    final shift = unbiasedExponent - fractionBits + destination.fractionWidth;
    final magnitude = shift >= 0 ? significand << shift : significand >> -shift;
    final scaled = source.sign.toBool() ? -magnitude : magnitude;
    return destination
        .valuePopulator()
        .ofLogicValue(LogicValue.ofBigInt(scaled, destination.width));
  }

  // Rounds [significand] right-shifted by [-shift] bits (for `shift < 0`)
  // according to [mode], mirroring FloatingPointValuePopulator's internal
  // significand rounding so tests can independently check FloatToFixed's
  // rounding logic.
  BigInt roundedMagnitude(
      BigInt significand, int shift, FloatingPointRoundingMode mode,
      {required bool negative}) {
    if (shift >= 0) {
      return significand << shift;
    }
    final discardedWidth = -shift;
    final quotient = significand >> discardedWidth;
    final remainder =
        significand & ((BigInt.one << discardedWidth) - BigInt.one);
    if (remainder == BigInt.zero) {
      return quotient;
    }
    final half = BigInt.one << (discardedWidth - 1);
    final increment = switch (mode) {
      FloatingPointRoundingMode.truncate ||
      FloatingPointRoundingMode.roundTowardsZero =>
        false,
      FloatingPointRoundingMode.roundTowardsInfinity => !negative,
      FloatingPointRoundingMode.roundTowardsNegativeInfinity => negative,
      FloatingPointRoundingMode.roundNearestTiesAway => remainder >= half,
      FloatingPointRoundingMode.roundNearestEven =>
        remainder > half || (remainder == half && quotient.isOdd),
    };
    return increment ? quotient + BigInt.one : quotient;
  }

  FixedPointValue roundedFixedValue(FloatingPointValue source,
      FixedPoint destination, FloatingPointRoundingMode mode) {
    final fractionBits = source.mantissaWidth - (source.explicitJBit ? 1 : 0);
    final normal = !source.exponent.isZero;
    final significand = source.mantissa.toBigInt() |
        (normal && !source.explicitJBit
            ? BigInt.one << fractionBits
            : BigInt.zero);
    final unbiasedExponent =
        normal ? source.exponent.toInt() - source.bias : source.minExponent;
    final shift = unbiasedExponent - fractionBits + destination.fractionWidth;
    final negative = source.sign.toBool();
    final magnitude =
        roundedMagnitude(significand, shift, mode, negative: negative);
    final scaled = negative ? -magnitude : magnitude;
    return destination.valuePopulator().ofLogicValue(LogicValue.ofBigInt(
        scaled.toUnsigned(destination.width), destination.width));
  }

  test('FloatToFixed: supports every rounding mode', () {
    // Small widths so exhaustive coverage over every raw bit pattern stays
    // fast. mantissaWidth (4) is wider than fractionWidth (2), forcing a
    // right-shift on every conversion so every rounding mode is exercised.
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final float = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
      ..put(0);

    for (final mode in FloatingPointRoundingMode.values) {
      final dut = FloatToFixed(float,
          integerWidth: 4, fractionWidth: 2, roundingMode: mode);
      for (var raw = 0; raw < 1 << float.width; raw++) {
        final source = float
            .valuePopulator()
            .ofLogicValue(LogicValue.ofInt(raw, float.width));
        if (source.isNaN || source.isAnInfinity) {
          continue;
        }
        float.put(source);
        final expected = roundedFixedValue(source, dut.fixed, mode);
        expect(dut.fixed.value.bitString, expected.value.bitString,
            reason: 'mode=$mode raw=0x${raw.toRadixString(16)}');
      }
    }
  });

  test('FloatToFixed: explicit j-bit exhaustive round trip', () {
    // Regression test for the explicit-j-bit handling bug in FloatToFixed:
    // the explicit j-bit stored as the mantissa's top bit was being
    // erroneously duplicated by prepending a second, independently-computed
    // j-bit. Small widths keep this exhaustive over every legal bit pattern
    // while running fast.
    const exponentWidth = 4;
    const mantissaWidth = 4;
    final float = FloatingPoint(
        exponentWidth: exponentWidth,
        mantissaWidth: mantissaWidth,
        explicitJBit: true)
      ..put(0);
    final dut = FloatToFixed(float, integerWidth: 4, fractionWidth: 4);

    for (var raw = 0; raw < 1 << float.width; raw++) {
      final source = float
          .valuePopulator()
          .ofLogicValue(LogicValue.ofInt(raw, float.width));
      if (!source.isLegalValue() || source.isNaN || source.isAnInfinity) {
        continue;
      }
      float.put(source);
      final expected = roundedFixedValue(
          source, dut.fixed, FloatingPointRoundingMode.truncate);
      expect(dut.fixed.value.bitString, expected.value.bitString,
          reason: 'raw=0x${raw.toRadixString(16)}');
    }
  });

  test('FloatToFixed: checkOverflow exhaustive for narrow integerWidth', () {
    // Regression test for two overflow-detection bugs:
    // 1. Overflow was never detected when the destination format was
    //    narrower than the source mantissa's precision (a Dart-int
    //    subtraction inside a comparison could go negative, and unsigned
    //    Logic.gte silently treated that as an enormous positive threshold).
    // 2. At the exact negative-power-of-two boundary (e.g. -4 in a format
    //    whose max positive value is 3.5), overflow was incorrectly flagged
    //    even though two's-complement negative range extends one step
    //    further than positive range.
    //
    // Truncating a value to `fractionWidth` bits (matching the default
    // rounding mode) fits within a signed Qm.n format exactly when its
    // truncated raw integer magnitude is in [-2^(m+n), 2^(m+n) - 1].
    bool expectedNoOverflow(double value, int integerWidth, int fractionWidth) {
      final scaled = value * (1 << fractionWidth);
      final flooredInt = value < 0 ? -(-scaled).floor() : scaled.floor();
      final maxPositiveInt = (1 << integerWidth) * (1 << fractionWidth) - 1;
      final minNegativeInt = -(1 << integerWidth) * (1 << fractionWidth);
      return flooredInt >= minNegativeInt && flooredInt <= maxPositiveInt;
    }

    const exponentWidth = 4;
    const mantissaWidth = 4;
    final float = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
      ..put(0);

    for (final targetSpec in [(2, 1), (1, 2), (3, 0), (0, 3)]) {
      final dut = FloatToFixed(float,
          integerWidth: targetSpec.$1,
          fractionWidth: targetSpec.$2,
          checkOverflow: true);
      for (final signVal in [false, true]) {
        for (var e = 0; e < 15; e++) {
          for (var m = 0; m < 16; m++) {
            final fv = float.valuePopulator().ofInts(e, m, sign: signVal);
            float.put(fv);
            final expectedOverflow = !expectedNoOverflow(
                fv.toDouble(), targetSpec.$1, targetSpec.$2);
            expect(dut.overflow!.value.toBool(), expectedOverflow,
                reason: 'target=$targetSpec fv=$fv (${fv.toDouble()})');
          }
        }
      }
    }
  });

  test(
      'FloatToFixed: exhaustive when fullMantissa is wider than the output '
      'format', () {
    // Regression test for a scenario with no prior coverage: when the
    // source float's mantissa (plus j-bit) is wider than the destination
    // Qm.n format's total width, `shiftRight`'s calculation must subtract
    // off the bits already discarded by pre-truncating to `preNumber`
    // before applying the right shift, or results are silently corrupted
    // (verified by deliberately removing that adjustment: it produced 1470
    // mismatches out of 5292 checks in this exact configuration, including
    // a plain 0.25 collapsing to 0.0).
    const exponentWidth = 5;
    const mantissaWidth = 10; // fullMantissa.width = 11
    const integerWidth = 2;
    const fractionWidth = 2; // outputWidth = 5 (< 11)

    final float = FloatingPoint(
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
      ..put(0);
    final dut = FloatToFixed(float,
        integerWidth: integerWidth, fractionWidth: fractionWidth);

    for (final negate in [false, true]) {
      for (var e = 0; e < pow(2, exponentWidth) - 1; e++) {
        for (var m = 0; m < pow(2, mantissaWidth); m += 7) {
          final fv = float.valuePopulator().ofInts(e, m, sign: negate);
          float.put(fv);
          final val = fv.toDouble();
          if (!FixedPointValuePopulator.canStore(val,
              signed: true,
              integerWidth: integerWidth,
              fractionWidth: fractionWidth)) {
            continue;
          }
          final expected = dut.fixed.valuePopulator().ofDouble(val);
          final computed = dut.fixed.fixedPointValue;
          expect(computed, equals(expected),
              reason: 'fv=$fv (${fv.toDouble()}) computed=$computed '
                  '(${computed.toDouble()}) expected=$expected '
                  '(${expected.toDouble()})');
        }
      }
    }
  });

  test('FloatToFixed: exact exhaustive reduced-width conversion', () {
    final float = FloatingPoint(exponentWidth: 5, mantissaWidth: 4);
    final dut = FloatToFixed(float);

    for (var raw = 0; raw < 1 << float.width; raw++) {
      final source = float
          .valuePopulator()
          .ofLogicValue(LogicValue.ofInt(raw, float.width));
      if (source.isNaN || source.isAnInfinity) {
        continue;
      }
      float.put(source);
      final expected = exactFixedValue(source, dut.fixed);
      expect(dut.fixed.value.bitString, expected.value.bitString,
          reason: 'raw=0x${raw.toRadixString(16)}');
    }
  });

  test('FloatToFixed: exact wide mantissa conversion', () {
    final float = FloatingPoint(exponentWidth: 8, mantissaWidth: 80);
    final dut = FloatToFixed(float);
    final cases = [
      float.valuePopulator().ofBigInts(BigInt.from(127), BigInt.zero),
      float
          .valuePopulator()
          .ofBigInts(BigInt.from(128), BigInt.one << 79, sign: true),
      float.valuePopulator().ofBigInts(BigInt.one, BigInt.one),
      float.valuePopulator().ofBigInts(BigInt.zero, BigInt.one),
    ];

    for (final source in cases) {
      float.put(source);
      final expected = exactFixedValue(source, dut.fixed);
      expect(dut.fixed.value.bitString, expected.value.bitString,
          reason: 'source=$source');
    }
  });

  test('E5M2 to Q16.16 exhaustive', () async {
    final float = FloatingPoint(exponentWidth: 5, mantissaWidth: 2);
    final dut = FloatToFixed(float);
    await dut.build();
    for (var val = 0; val < pow(2, 8); val++) {
      final fpv = float
          .valuePopulator()
          .ofLogicValue(LogicValue.ofInt(val, float.width));
      if (!fpv.isAnInfinity & !fpv.isNaN) {
        float.put(fpv);
        final fxp = dut.fixed;
        final fxpExp = fxp.valuePopulator().ofDouble(fpv.toDouble());
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
              final fv1 = fp1.valuePopulator().ofInts(e1, m1, sign: negate);
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

  // float-to-fixed round-trip testing here is bounded by double precision:
  // toDouble()/ofDouble() only exactly round-trip values that fit within a
  // double's 52-bit mantissa, so this loop keeps source widths well below
  // that limit rather than exhaustively covering every exponent width.
  test('FloatToFixed: exhaustive round-trip fp->smallerfx fpv->xpv', () {
    for (var sEW = 2; sEW < 5; sEW++) {
      for (var sMW = 2; sMW < 6; sMW++) {
        final fp1 = FloatingPoint(exponentWidth: sEW, mantissaWidth: sMW)
          ..put(0);
        final nominal = FloatToFixed(fp1);
        for (var i = 0; i < nominal.fractionWidth - 2; i++) {
          final tN = nominal.fractionWidth - i;
          for (var j = 0; j < nominal.integerWidth - 2; j++) {
            final tM = nominal.integerWidth - j;
            final convert =
                FloatToFixed(fp1, integerWidth: tM, fractionWidth: tN);
            final fxc = convert.fixed;
            for (final negate in [false, true]) {
              for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
                for (var m1 = 0; m1 < pow(2, sMW); m1++) {
                  final fv1 = fp1.valuePopulator().ofInts(e1, m1, sign: negate);
                  fp1.put(fv1.value);
                  final val = fv1.toDouble();
                  if (FixedPointValuePopulator.canStore(val,
                      signed: true, integerWidth: tM, fractionWidth: tN)) {
                    final fx = fxc.valuePopulator().ofDouble(fv1.toDouble());

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
                  } else {
                    continue;
                  }
                }
              }
            }
          }
        }
      }
    }
  });
  // This test exercises the default (truncate) rounding mode, which
  // operates on the magnitude before re-applying sign, so it matches
  // FixedPointValue.ofDouble()'s truncate-towards-zero semantics for
  // negative numbers as well; verified exhaustively above with 0 failures.
  test('FloatToFixed: exhaustive round-trip fp->smaller_n fpv->xpv', () {
    for (var sEW = 2; sEW < 5; sEW++) {
      for (var sMW = 2; sMW < 6; sMW++) {
        final fp1 = FloatingPoint(exponentWidth: sEW, mantissaWidth: sMW)
          ..put(0);
        final nominal = FloatToFixed(fp1);
        for (var i = 0; i < nominal.fractionWidth - 2; i++) {
          final tN = nominal.fractionWidth - i;
          final tM = nominal.integerWidth;
          final convert =
              FloatToFixed(fp1, integerWidth: tM, fractionWidth: tN);
          for (final negate in [false, true]) {
            for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
              for (var m1 = 0; m1 < pow(2, sMW); m1++) {
                final fv1 = fp1.valuePopulator().ofInts(e1, m1, sign: negate);
                fp1.put(fv1.value);
                final fxc = convert.fixed;
                final fx = fxc.valuePopulator().ofDouble(fv1.toDouble());

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
        for (var i = 0; i < nominal.integerWidth - 2; i++) {
          final tM = nominal.integerWidth - i;
          final convert = FloatToFixed(fp1,
              integerWidth: tM,
              fractionWidth: nominal.fractionWidth,
              checkOverflow: true);
          for (final negate in [false, true]) {
            for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
              for (var m1 = 0; m1 < pow(2, sMW); m1++) {
                final fv1 = fp1.valuePopulator().ofInts(e1, m1, sign: negate);
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
        final convert = FloatToFixed(fp1,
            integerWidth: nominal.integerWidth + 4,
            fractionWidth: nominal.fractionWidth + 2);
        for (final negate in [false, true]) {
          for (var e1 = 0; e1 < pow(2, sEW) - 1; e1++) {
            for (var m1 = 0; m1 < pow(2, sMW); m1++) {
              final fv1 = fp1.valuePopulator().ofInts(e1, m1, sign: negate);
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
      final fp8 =
          FloatingPointValue.populator(exponentWidth: 4, mantissaWidth: 3)
              .ofLogicValue(LogicValue.ofInt(val, float.width));
      if (!fp8.isNaN & !fp8.isAnInfinity) {
        float.put(fp8.value);
        final fx8 = dut.q23p9.valuePopulator().ofDouble(fp8.toDouble());
        expect(dut.fixed.value.bitString, fx8.value.bitString);
        expect(dut.q23p9.value, fx8.value);
      }
    }

    // E5M2
    mode.put(0);
    for (var val = 0; val < pow(2, 8); val++) {
      final fp8 =
          FloatingPointValue.populator(exponentWidth: 5, mantissaWidth: 2)
              .ofLogicValue(LogicValue.ofInt(val, float.width));
      if (!fp8.isNaN & !fp8.isAnInfinity) {
        float.put(fp8.value);
        final fx8 = dut.q16p16.valuePopulator().ofDouble(fp8.toDouble());
        expect(dut.fixed.value.bitString, fx8.value.bitString);
        expect(dut.q16p16.value, fx8.value);
      }
    }
  });

  test('FloatToFixed: BF16 singleton', () {
    final bf16 = FloatingPointBF16();
    final bf16Val = FloatingPointBF16Value.populator()
        .ofBinaryStrings('0', '00000000', '0000010');
    bf16.put(bf16Val);
    const m = 18;
    const n = 16;
    final convert = FloatToFixed(bf16, integerWidth: m, fractionWidth: n);
    final expectedDbl = bf16Val.toDouble();

    if (FixedPointValuePopulator.canStore(expectedDbl,
        signed: true,
        integerWidth: convert.integerWidth,
        fractionWidth: convert.fractionWidth)) {
      final fixedVal = convert.fixed;
      final expected = fixedVal.valuePopulator().ofDouble(expectedDbl);
      final computedDbl = fixedVal.fixedPointValue.toDouble();
      final computed = fixedVal.valuePopulator().ofDouble(computedDbl);
      expect(expected, equals(computed), reason: '''
          expected=$expected ($expectedDbl)
          computed=$computed ($computedDbl)
''');
    }
  });

  test('FloatToFixed: BF16', () {
    final bf16 = FloatingPointBF16()..put(0);
    const m = 18;
    const n = 16;
    final convert = FloatToFixed(bf16, integerWidth: m, fractionWidth: n);
    for (var i = 0; i < pow(2, 16); i++) {
      final val = LogicValue.ofInt(i, 16);
      final bf16Val = FloatingPointBF16Value.populator().ofLogicValue(val);
      bf16.put(bf16Val);
      final expectedDbl = bf16Val.toDouble();

      if (FixedPointValuePopulator.canStore(expectedDbl,
          signed: true,
          integerWidth: convert.integerWidth,
          fractionWidth: convert.fractionWidth)) {
        final fixedVal = convert.fixed;
        final expected = fixedVal.valuePopulator().ofDouble(expectedDbl);
        final computedDbl = fixedVal.fixedPointValue.toDouble();
        final computed = fixedVal.valuePopulator().ofDouble(computedDbl);
        expect(expected, equals(computed), reason: '''
          expected=$expected ($expectedDbl)
          computed=$computed ($computedDbl)
''');
      }
    }
  });
}
