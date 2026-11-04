// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_adder_special_values_test.dart
// Tests for floating-point adder special values.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import '../../verilator_test_utils.dart';

class _SpecialValueHarness extends Module {
  _SpecialValueHarness({required bool pipelined}) {
    final a = FloatingPoint(exponentWidth: 3, mantissaWidth: 3)
      ..gets(addInput('a', Logic(width: 7), width: 7));
    final b =
        FloatingPoint(exponentWidth: 3, mantissaWidth: 3, explicitJBit: true)
          ..gets(addInput('b', Logic(width: 7), width: 7));
    final clk = pipelined ? addInput('clk', Logic()) : null;
    final adder = FloatingPointAdderSinglePath(a, b, clk: clk);
    addOutput('isNaN') <= adder.sum.isNaN;
    addOutput('isInf') <= adder.sum.isAnInfinity;
    addOutput('sign') <= adder.sum.sign;
    addOutput('mantissa', width: 3) <= adder.sum.mantissa;
    addOutput('invalid') <= adder.status.invalid;
  }
}

void main() {
  tearDown(Simulator.reset);

  test('magnitude overflow comparison preserves four-state behavior', () {
    final exponent = Logic(width: 2);
    final mantissa = Logic(width: 3);
    final maxExponent = Const(2, width: 2);
    for (final maxMantissaValue in [6, 7]) {
      final maxMantissa = Const(maxMantissaValue, width: 3);
      final exponentGreater = exponent.gt(maxExponent);
      final exponentEqual = exponent.eq(maxExponent);
      final previous =
          exponentGreater | (exponentEqual & mantissa.gt(maxMantissa));
      final magnitude = [exponent, mantissa].concat();
      final maximum = [maxExponent, maxMantissa].concat();
      final current = exponentGreater | (exponentEqual & magnitude.gt(maximum));
      for (final e0 in '01xz'.split('')) {
        for (final e1 in '01xz'.split('')) {
          exponent.put(LogicValue.ofString('$e0$e1'));
          for (final m0 in '01xz'.split('')) {
            for (final m1 in '01xz'.split('')) {
              for (final m2 in '01xz'.split('')) {
                mantissa.put(LogicValue.ofString('$m0$m1$m2'));
                expect(current.value, previous.value,
                    reason: 'exp=$e0$e1 mantissa=$m0$m1$m2 '
                        'maxMantissa=$maxMantissaValue');
              }
            }
          }
        }
      }
    }
  });

  test('truncation saturates finite overflow but preserves input infinities',
      () {
    final a = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
    final b = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
    final adder = FloatingPointAdderSinglePath(a, b,
        roundingMode: FloatingPointRoundingMode.truncate);
    for (final sign in [1, -1]) {
      a.put(a.valuePopulator().ofDouble(sign * 248.0));
      b.put(b.valuePopulator().ofDouble(sign * 8.0));
      expect(adder.sum.floatingPointValue.toDouble(), sign * 248.0);
      expect(adder.status.overflow.value, LogicValue.one);
      expect(adder.status.inexact.value, LogicValue.one);

      a.put(a
          .valuePopulator()
          .ofDouble(sign > 0 ? double.infinity : double.negativeInfinity));
      expect(adder.sum.floatingPointValue.toDouble(),
          sign > 0 ? double.infinity : double.negativeInfinity);
      expect(adder.status.overflow.value, LogicValue.zero);
    }
  });

  test('mixed J-bit special values preserve operand formats and infinity sign',
      () {
    for (final aExplicit in [false, true]) {
      for (final bExplicit in [false, true]) {
        for (final outExplicit in [false, true]) {
          FloatingPoint makeFp({required bool explicit}) => FloatingPoint(
              exponentWidth: 3, mantissaWidth: 3, explicitJBit: explicit);
          final a = makeFp(explicit: aExplicit);
          final b = makeFp(explicit: bExplicit);
          final out = makeFp(explicit: outExplicit);
          final adder = FloatingPointAdderSinglePath(a, b, outSum: out);
          for (final aInf in [false, true]) {
            for (final negative in [false, true]) {
              final av = a.valuePopulator().ofConstant(aInf
                  ? (negative
                      ? FloatingPointConstants.negativeInfinity
                      : FloatingPointConstants.positiveInfinity)
                  : FloatingPointConstants.positiveZero);
              final bv = b.valuePopulator().ofConstant(aInf
                  ? FloatingPointConstants.positiveZero
                  : (negative
                      ? FloatingPointConstants.negativeInfinity
                      : FloatingPointConstants.positiveInfinity));
              a.put(av);
              b.put(bv);
              expect(adder.sum.floatingPointValue.isAnInfinity, isTrue);
              expect(adder.sum.sign.value.toBool(), negative);
              expect(adder.status.invalid.value, LogicValue.zero);
            }
          }
          a.put(a.valuePopulator().positiveInfinity);
          b.put(b.valuePopulator().negativeInfinity);
          expect(adder.sum.floatingPointValue.isNaN, isTrue);
          expect(adder.status.invalid.value, LogicValue.one);

          FloatingPointValue nan(FloatingPoint fp,
                  {required bool signaling, required bool negative}) =>
              fp.valuePopulator().ofInts(
                  7,
                  (fp.explicitJBit ? 4 : 0) |
                      (signaling ? 1 : (fp.explicitJBit ? 2 : 4)),
                  sign: negative);
          final cases = [
            (
              a.valuePopulator().positiveZero,
              nan(b, signaling: true, negative: true)
            ),
            (
              nan(a, signaling: false, negative: false),
              nan(b, signaling: true, negative: true)
            ),
            (
              nan(a, signaling: true, negative: true),
              nan(b, signaling: false, negative: false)
            ),
            (
              nan(a, signaling: true, negative: true),
              b.valuePopulator().positiveZero
            ),
            (
              a.valuePopulator().positiveZero,
              nan(b, signaling: false, negative: true)
            ),
          ];
          for (final (av, bv) in cases) {
            a.put(av);
            b.put(bv);
            expect(adder.sum.value, out.valuePopulator().add(av, bv).value,
                reason: 'aExplicit=$aExplicit bExplicit=$bExplicit '
                    'outExplicit=$outExplicit a=$av b=$bv');
            expect(adder.status.invalid.value.toBool(),
                av.isSignalingNaN || bv.isSignalingNaN);
          }
        }
      }
    }
  });

  for (final pipelined in [false, true]) {
    test('mixed J-bit special values in HDL, pipelined=$pipelined', () async {
      final dut = _SpecialValueHarness(pipelined: pipelined);
      await dut.build();
      final vectors = <Vector>[];
      void vector(int a, int b, int isNaN, int isInf, int invalid,
          {int? sign, int? mantissa}) {
        final inputs = {'a': a, 'b': b};
        if (pipelined) {
          vectors.add(Vector({...inputs, 'clk': 0}, {}));
        }
        vectors.add(Vector({
          ...inputs,
          if (pipelined) 'clk': 1,
        }, {
          'isNaN': isNaN,
          'isInf': isInf,
          'invalid': invalid,
          if (sign != null) 'sign': sign,
          if (mantissa != null) 'mantissa': mantissa,
        }));
      }

      vector(0, 0x3c, 0, 1, 0, sign: 0);
      vector(0, 0x7c, 0, 1, 0, sign: 1);
      vector(0x78, 0, 0, 1, 0, sign: 1);
      vector(0x38, 0x7c, 1, 0, 1);
      vector(0, 0x3e, 1, 0, 0, sign: 0, mantissa: 4);
      vector(0, 0x7d, 1, 0, 1, sign: 1, mantissa: 5);
      vector(0x3c, 0x7d, 1, 0, 1, sign: 1, mantissa: 5);

      await SimCompare.checkFunctionalVector(dut, vectors);
      SimCompare.checkIverilogVector(dut, vectors);
      expect(SimCompare.checkVerilatorVector(dut, vectors), isTrue);
      expectNoVerilatorWarnings(dut, ['CMPCONST']);
    });
  }
}
