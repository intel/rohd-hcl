// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_status_test.dart
// Tests for IEEE 754 floating-point exception status.
//
// 2026 August 25
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  void expectEncoding(FloatingPoint actual, FloatingPointValue expected) {
    expect(actual.value.bitString, expected.value.bitString);
  }

  test('FP: converter reports overflow and underflow status', () {
    final source = FloatingPoint(exponentWidth: 5, mantissaWidth: 6);
    final destination = FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final converter = FloatingPointConverter(source, destination);

    source.put(source
        .valuePopulator()
        .ofConstant(FloatingPointConstants.largestNormal));
    expect(converter.status.overflow.value.toBool(), isTrue);
    expect(converter.status.inexact.value.toBool(), isTrue);

    source.put(source
        .valuePopulator()
        .ofConstant(FloatingPointConstants.smallestPositiveSubnormal));
    expect(converter.status.underflow.value.toBool(), isTrue);
    expect(converter.status.inexact.value.toBool(), isTrue);
  });

  test('FP: adders report invalid and overflow status', () {
    final a = FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final b = FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final single = FloatingPointAdderSinglePath(a, b);
    final dual = FloatingPointAdderDualPath(a, b);

    a.put(a.valuePopulator().positiveInfinity);
    b.put(b.valuePopulator().negativeInfinity);
    expect(single.status.invalid.value.toBool(), isTrue);
    expect(dual.status.invalid.value.toBool(), isTrue);

    a.put(a.valuePopulator().ofConstant(FloatingPointConstants.largestNormal));
    b.put(b.valuePopulator().ofConstant(FloatingPointConstants.largestNormal));
    expect(single.status.overflow.value.toBool(), isTrue);
    expect(single.status.inexact.value.toBool(), isTrue);
    expect(dual.status.overflow.value.toBool(), isTrue);
    expect(dual.status.inexact.value.toBool(), isTrue);
  });

  test('FP: multiplier reports invalid and underflow status', () {
    final a = FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final b = FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final multiplier = FloatingPointMultiplierSimple(a, b,
        roundingMode: FloatingPointRoundingMode.roundNearestEven);

    a.put(a.valuePopulator().positiveInfinity);
    b.put(b.valuePopulator().positiveZero);
    expect(multiplier.status.invalid.value.toBool(), isTrue);

    a.put(a
        .valuePopulator()
        .ofConstant(FloatingPointConstants.smallestPositiveSubnormal));
    b.put(b.valuePopulator().ofDouble(0.5));
    expect(multiplier.status.underflow.value.toBool(), isTrue);
    expect(multiplier.status.inexact.value.toBool(), isTrue);
  });

  test('FP: square root reports invalid and inexact status', () {
    final input = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
    final sqrt = FloatingPointSqrtSimple(input);

    input.put(input.valuePopulator().ofDouble(-1));
    expect(sqrt.status.invalid.value.toBool(), isTrue);

    input.put(input.valuePopulator().ofDouble(2));
    expect(sqrt.status.invalid.value.toBool(), isFalse);
    expect(sqrt.status.inexact.value.toBool(), isTrue);
  });

  test('FP: signaling NaNs are quieted, prioritized, and report invalid', () {
    FloatingPoint operand() =>
        FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final a = operand();
    final b = operand();
    final quietFirst = a.valuePopulator().ofInts(7, 5, sign: false);
    final signalingSecond = a.valuePopulator().ofInts(7, 2, sign: true);
    final expected = a.valuePopulator().ofInts(7, 6, sign: true);
    final single = FloatingPointAdderSinglePath(a, b);
    final dual = FloatingPointAdderDualPath(a, b);
    final multiplier = FloatingPointMultiplierSimple(a, b);

    a.put(quietFirst);
    b.put(signalingSecond);
    expectEncoding(single.sum, expected);
    expectEncoding(dual.sum, expected);
    expectEncoding(multiplier.product, expected);
    expect(single.status.invalid.value.toBool(), isTrue);
    expect(dual.status.invalid.value.toBool(), isTrue);
    expect(multiplier.status.invalid.value.toBool(), isTrue);

    b.put(b.valuePopulator().one);
    expectEncoding(single.sum, quietFirst);
    expect(single.status.invalid.value.toBool(), isFalse);
  });

  test('FP: converter and square root preserve and quiet NaN payloads', () {
    final source = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
    final destination = FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final converter = FloatingPointConverter(source, destination);
    final sqrt = FloatingPointSqrtSimple(source);
    final signaling = source.valuePopulator().ofInts(15, 3, sign: true);
    final converted = destination.valuePopulator().ofInts(7, 7, sign: true);
    final quieted = source.valuePopulator().ofInts(15, 11, sign: true);

    source.put(signaling);
    expectEncoding(converter.destination, converted);
    expectEncoding(sqrt.sqrt, quieted);
    expect(converter.status.invalid.value.toBool(), isTrue);
    expect(sqrt.status.invalid.value.toBool(), isTrue);
  });

  test('FP: invalid arithmetic without a NaN returns a canonical quiet NaN',
      () {
    final a = FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final b = FloatingPoint(exponentWidth: 3, mantissaWidth: 3);
    final adder = FloatingPointAdderSinglePath(a, b);
    final multiplier = FloatingPointMultiplierSimple(a, b);
    final canonical = a.valuePopulator().ofConstant(FloatingPointConstants.nan);

    a.put(a.valuePopulator().positiveInfinity);
    b.put(b.valuePopulator().negativeInfinity);
    expectEncoding(adder.sum, canonical);

    b.put(b.valuePopulator().positiveZero);
    expectEncoding(multiplier.product, canonical);
  });

  test('FP: E4M3 finite all-ones exponents and overflow are format aware', () {
    final a = FloatingPoint8E4M3();
    final b = FloatingPoint8E4M3();
    final single = FloatingPointAdderSinglePath(a, b);
    final dual = FloatingPointAdderDualPath(a, b);
    final multiplier = FloatingPointMultiplierSimple(a, b);
    final finiteWithMaxExponent =
        FloatingPoint8E4M3Value.populator().ofInts(15, 0);
    final largest = FloatingPoint8E4M3Value.populator()
        .ofConstant(FloatingPointConstants.largestNormal);

    a.put(finiteWithMaxExponent);
    b.put(FloatingPoint8E4M3Value.populator().positiveZero);
    expectEncoding(single.sum, finiteWithMaxExponent);
    expectEncoding(dual.sum, finiteWithMaxExponent);

    a.put(largest);
    b.put(largest);
    expectEncoding(single.sum, largest);
    expectEncoding(dual.sum, largest);
    expect(single.status.overflow.value.toBool(), isTrue);
    expect(dual.status.overflow.value.toBool(), isTrue);

    b.put(FloatingPoint8E4M3Value.populator().ofDouble(2));
    expectEncoding(multiplier.product, largest);
    expect(multiplier.status.overflow.value.toBool(), isTrue);
  });

  test('FP: E5M2 special values convert correctly to E4M3', () {
    final source = FloatingPoint(exponentWidth: 5, mantissaWidth: 2);
    final destination = FloatingPoint8E4M3();
    final converter = FloatingPointConverter(source, destination);
    source.put(source.valuePopulator().positiveInfinity);
    expectEncoding(
        converter.destination,
        FloatingPoint8E4M3Value.populator()
            .ofConstant(FloatingPointConstants.largestNormal));

    source.put(source.valuePopulator().ofInts(31, 1, sign: true));
    expectEncoding(converter.destination,
        FloatingPoint8E4M3Value.populator().ofInts(15, 7, sign: true));
    expect(converter.destination.sign.value.toBool(), isTrue);
  });
}
