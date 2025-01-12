// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier_encoder_test.dart
// Tests for Booth encoding
//
// 2024 May 21
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/evaluate_partial_product.dart';
import 'package:rohd_hcl/src/arithmetic/partial_product_sign_extend.dart';
import 'package:test/test.dart';

// Here are the variations needed testing:
// - Sign variants
//   - Multiplicand:  [unsigned, signed], [selectedUnsigned, selectedSigned]
//   - Multiplier:  [unsigned, signed], [selectedUnsigned, selectedSigned]
// - Radix Encodings:  [2,4,8,16]
// - Widths:
//   - Cross the shift intervals for each radix
//   - Rectangular: again, need to cross a shift interval
// - Sign Extension: [brute, stop, compact, compactRect]

void testPartialProductExhaustive(PartialProductGenerator pp) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  final limitX = pow(2, widthX);
  final limitY = pow(2, widthY);

  final multiplicandSigns = pp.signedMultiplicand
      ? [true]
      : (pp.selectSignedMultiplicand != null)
          ? [false, true]
          : [false];
  final multiplierSigns = pp.signedMultiplier
      ? [true]
      : (pp.selectSignedMultiplier != null)
          ? [false, true]
          : [false];
  test(
      'exhaustive: ${pp.name} R${pp.selector.radix} '
      'WD=${pp.multiplicand.width} WM=${pp.multiplier.width} '
      'SD=${pp.signedMultiplicand ? 1 : 0} '
      'SM=${pp.signedMultiplier ? 1 : 0} '
      'SelD=${pp.selectSignedMultiplicand != null ? 1 : 0} '
      'SelM=${pp.selectSignedMultiplier != null ? 1 : 0}', () async {
    for (var i = 0; i < limitX; i++) {
      for (var j = 0; j < limitY; j++) {
        for (final multiplicandSign in multiplicandSigns) {
          final X =
              SignedBigInt.fromSignedInt(i, widthX, signed: multiplicandSign);
          if (pp.selectSignedMultiplicand != null) {
            pp.selectSignedMultiplicand!.put(multiplicandSign ? 1 : 0);
          }
          for (final multiplierSign in multiplierSigns) {
            final Y =
                SignedBigInt.fromSignedInt(j, widthY, signed: multiplierSign);
            if (pp.selectSignedMultiplier != null) {
              pp.selectSignedMultiplier!.put(multiplierSign ? 1 : 0);
            }
            checkPartialProduct(pp, X, Y);
          }
        }
      }
    }
  });
}

void testPartialProductRandom(PartialProductGenerator pp, int iterations) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  final multiplicandSigns = pp.signedMultiplicand
      ? [true]
      : (pp.selectSignedMultiplicand != null)
          ? [false, true]
          : [false];
  final multiplierSigns = pp.signedMultiplier
      ? [true]
      : (pp.selectSignedMultiplier != null)
          ? [false, true]
          : [false];

  test(
      'random: ${pp.name} R${pp.selector.radix} '
      'WD=${pp.multiplicand.width} WM=${pp.multiplier.width} '
      'SD=${pp.signedMultiplicand ? 1 : 0} '
      'SM=${pp.signedMultiplier ? 1 : 0} '
      'SelD=${pp.selectSignedMultiplicand != null ? 1 : 0} '
      'SelM=${pp.selectSignedMultiplier != null ? 1 : 0}', () async {
    final value = Random(47);
    for (var i = 0; i < iterations; i++) {
      for (final multiplicandSign in multiplicandSigns) {
        final X = value
            .nextLogicValue(width: widthX)
            .toBigInt()
            .toCondSigned(widthX, signed: multiplicandSign);
        if (pp.selectSignedMultiplicand != null) {
          pp.selectSignedMultiplicand!.put(multiplicandSign ? 1 : 0);
        }
        for (final multiplierSign in multiplierSigns) {
          final Y = value
              .nextLogicValue(width: widthY)
              .toBigInt()
              .toCondSigned(widthY, signed: multiplierSign);
          if (pp.selectSignedMultiplier != null) {
            pp.selectSignedMultiplier!.put(multiplierSign ? 1 : 0);
          }
          checkPartialProduct(pp, X, Y);
        }
      }
    }
  });
}

void testPartialProductSingle(PartialProductGenerator pp, BigInt X, BigInt Y) {
  test(
      'single: ${pp.name} R${pp.selector.radix} '
      'WD=${pp.multiplicand.width} WM=${pp.multiplier.width} '
      'SD=${pp.signedMultiplicand ? 1 : 0} '
      'SM=${pp.signedMultiplier ? 1 : 0} '
      'SelD=${pp.selectSignedMultiplicand != null ? 1 : 0} '
      'SelM=${pp.selectSignedMultiplier != null ? 1 : 0}', () async {
    if (pp.selectSignedMultiplicand != null) {
      pp.selectSignedMultiplicand!.put(X.isNegative ? 1 : 0);
    }
    if (pp.selectSignedMultiplier != null) {
      pp.selectSignedMultiplier!.put(Y.isNegative ? 1 : 0);
    }
    checkPartialProduct(pp, X, Y);
  });
}

void checkPartialProduct(PartialProductGenerator pp, BigInt iX, BigInt iY) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  final X = iX.toCondSigned(widthX, signed: pp.isSignedMultiplicand());
  final Y = iY.toCondSigned(widthY, signed: pp.isSignedMultiplier());

  final product = X * Y;

  pp.multiplicand.put(X);
  pp.multiplier.put(Y);
  final value = pp.evaluate();
  expect(value, equals(product),
      reason: 'Fail1: $X * $Y: $value '
          'vs expected $product'
          '\n$pp');
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  group('PartialProduct: fixed sign variants', () {
    for (final signedMultiplicand in [false, true]) {
      for (final signedMultiplier in [false, true]) {
        for (final radix in [2, 4]) {
          final width = log2Ceil(radix) + (signedMultiplier ? 1 : 0);
          for (final signExtension
              in SignExtension.values.where((e) => e != SignExtension.none)) {
            final pp = PartialProductGeneratorBasic(
                Logic(name: 'X', width: width),
                Logic(name: 'Y', width: width),
                RadixEncoder(radix),
                signedMultiplicand: signedMultiplicand,
                signedMultiplier: signedMultiplier);
            currySignExtensionFunction(signExtension)(pp).signExtend();
            testPartialProductExhaustive(pp);
          }
        }
      }
    }
  });
  group('PartialProduct: singleton fixed sign variants', () {
    const radix = 16;
    final encoder = RadixEncoder(radix);

    for (final signedMultiplicand in [false, true]) {
      for (final signedMultiplier in [false, true]) {
        final width = log2Ceil(radix) + (signedMultiplier ? 1 : 0);
        final a = Logic(name: 'X', width: width);
        final b = Logic(name: 'Y', width: width);

        const i = 0;
        const j = 0;
        final X =
            SignedBigInt.fromSignedInt(i, width, signed: signedMultiplicand);
        final Y =
            SignedBigInt.fromSignedInt(j, width, signed: signedMultiplier);
        a.put(X);
        b.put(Y);
        final PartialProductGenerator pp;
        pp = PartialProductGeneratorBasic(a, b, encoder,
            signedMultiplicand: signedMultiplicand,
            signedMultiplier: signedMultiplier);
        StopBitsSignExtension(pp).signExtend();
        testPartialProductSingle(pp, X, Y);
      }
    }
  });

  group('PartialProduct: fixed/select sign variants', () {
    final selectSignMultiplicand = Logic();
    final selectSignMultiplier = Logic();
    for (final radix in [2, 4]) {
      final encoder = RadixEncoder(radix);
      for (final selectMultiplicand in [false, true]) {
        for (final signMultiplicand
            in (!selectMultiplicand ? [false, true] : [false])) {
          for (final selectMultiplier in [false, true]) {
            for (final signMultiplier
                in (!selectMultiplier ? [false, true] : [false])) {
              selectSignMultiplicand.put(selectMultiplicand ? 1 : 0);
              selectSignMultiplier.put(selectMultiplier ? 1 : 0);
              for (final signExtension in SignExtension.values
                  .where((e) => e != SignExtension.none)) {
                final width = log2Ceil(radix) + (signMultiplier ? 1 : 0);
                final PartialProductGenerator pp;
                pp = PartialProductGeneratorBasic(
                    Logic(name: 'X', width: width),
                    Logic(name: 'Y', width: width),
                    encoder,
                    signedMultiplicand: signMultiplicand,
                    signedMultiplier: signMultiplier,
                    selectSignedMultiplicand:
                        selectMultiplicand ? selectSignMultiplicand : null,
                    selectSignedMultiplier:
                        selectMultiplier ? selectSignMultiplier : null);
                currySignExtensionFunction(signExtension)(pp).signExtend();

                testPartialProductExhaustive(pp);
              }
            }
          }
        }
      }
    }
  });

  group('PartialProduct: singleton fixed/select sign variants', () {
    const radix = 4;
    final encoder = RadixEncoder(radix);
    const width = 4;

    final selectSignMultiplicand = Logic();
    final selectSignMultiplier = Logic();

    for (final selectMultiplicand in [false, true]) {
      for (final selectMultiplier in [false, true]) {
        selectSignMultiplicand.put(selectMultiplicand ? 1 : 0);
        selectSignMultiplier.put(selectMultiplier ? 1 : 0);
        final PartialProductGenerator pp;
        pp = PartialProductGeneratorStopBitsSignExtension(
            Logic(name: 'X', width: width),
            Logic(name: 'Y', width: width),
            encoder,
            signedMultiplicand: !selectMultiplicand,
            signedMultiplier: !selectMultiplier,
            selectSignedMultiplicand:
                selectMultiplicand ? selectSignMultiplicand : null,
            selectSignedMultiplier:
                selectMultiplier ? selectSignMultiplier : null);

        const i = 6;
        const j = -6;
        final X = SignedBigInt.fromSignedInt(i, width,
            signed: pp.isSignedMultiplicand());
        final Y = SignedBigInt.fromSignedInt(j, width,
            signed: pp.isSignedMultiplier());

        testPartialProductSingle(pp, X, Y);
      }
    }
  });

  group('PartialProduct: width/radix/extension sweep', () {
    for (var radix = 2; radix < 16; radix *= 2) {
      final encoder = RadixEncoder(radix);
      final shift = log2Ceil(encoder.radix);
      for (var width = shift; width < min(5, 2 * shift); width++) {
        for (final signExtension
            in SignExtension.values.where((e) => e != SignExtension.none)) {
          // final ppg = curryPartialProductGenerator(signExtension);
          final pp = PartialProductGeneratorBasic(
              Logic(name: 'X', width: width),
              Logic(name: 'Y', width: width),
              encoder);
          currySignExtensionFunction(signExtension)(pp).signExtend();

          testPartialProductExhaustive(pp);
        }
      }
    }
  });
  group('PartialProduct: rectangle/radix/extension sweep', () {
    for (var radix = 2; radix < 8; radix *= 2) {
      final encoder = RadixEncoder(radix);
      final shift = log2Ceil(encoder.radix);
      for (final signedMultiplicand in [false, true]) {
        final widthX = shift + 2;
        for (final signedMultiplier in [false, true]) {
          for (var widthY = shift + (signedMultiplier ? 1 : 0);
              widthY < shift + 3 + (signedMultiplier ? 1 : 0);
              widthY++) {
            for (final signExtension in [
              SignExtension.stopBits,
              SignExtension.compactRect
            ]) {
              final pp = PartialProductGeneratorBasic(
                  Logic(name: 'X', width: widthX),
                  Logic(name: 'Y', width: widthY),
                  encoder,
                  signedMultiplicand: signedMultiplicand,
                  signedMultiplier: signedMultiplier);
              currySignExtensionFunction(signExtension)(pp).signExtend();

              testPartialProductExhaustive(pp);
            }
          }
        }
      }
    }
  });

  group('PartialProduct: minimum width', () {
    for (var radix = 2; radix < 32; radix *= 2) {
      final encoder = RadixEncoder(radix);
      final shift = log2Ceil(encoder.radix);
      for (var width = shift; width < min(5, 2 * shift); width++) {
        for (final signExtension
            in SignExtension.values.where((e) => e != SignExtension.none)) {
          final pp = PartialProductGeneratorBasic(
              Logic(name: 'X', width: width),
              Logic(name: 'Y', width: width),
              encoder);
          currySignExtensionFunction(signExtension)(pp).signExtend();

          testPartialProductExhaustive(pp);
        }
      }
    }
  });

  group('PartialProduct: minimum rectangle', () {
    for (var radix = 2; radix < 32; radix *= 2) {
      final encoder = RadixEncoder(radix);
      final shift = log2Ceil(encoder.radix);
      for (final signedMultiplicand in [false, true]) {
        final widthX = shift;
        for (final signedMultiplier in [false, true]) {
          for (var widthY = shift + (signedMultiplier ? 1 : 0);
              widthY < shift + 1 + (signedMultiplier ? 1 : 0);
              widthY++) {
            for (final signExtension in [
              SignExtension.brute,
              SignExtension.stopBits,
              SignExtension.compactRect
            ]) {
              final pp = PartialProductGeneratorBasic(
                  Logic(name: 'X', width: widthX),
                  Logic(name: 'Y', width: widthY),
                  encoder,
                  signedMultiplicand: signedMultiplicand,
                  signedMultiplier: signedMultiplier);
              currySignExtensionFunction(signExtension)(pp).signExtend();

              testPartialProductExhaustive(pp);
            }
          }
        }
      }
    }
  });

  group('Rectangle Q collision tests New,', () {
    // These collide with the normal q extension bits
    // These are unsigned tests

    final alignTest = [
      [(2, 5, 0), (4, 7, 1), (8, 7, 2), (16, 9, 3)],
      [(2, 5, 1), (4, 6, 2), (8, 9, 3), (16, 8, 4)],
      [(2, 5, 2), (4, 7, 3), (8, 8, 4), (16, 11, 5)],
      [(4, 6, 4), (8, 7, 5), (16, 10, 6)],
      [(8, 9, 6), (16, 9, 7)],
      [(16, 8, 8)],
    ];
    for (final alignList in alignTest) {
      for (final align in alignList) {
        final radix = align.$1;
        final encoder = RadixEncoder(radix);
        final width = align.$2;

        final skew = align.$3;

        final pp = PartialProductGeneratorBasic(Logic(name: 'X', width: width),
            Logic(name: 'Y', width: width + skew), encoder);
        CompactRectSignExtension(pp).signExtend();

        testPartialProductRandom(pp, 10);
      }
    }
  });

  test('PartialProduct: flat test', () {
    const radix = 4;
    final radixEncoder = RadixEncoder(radix);
    const widthX = 6;
    const widthY = 3;
    final limitX = pow(2, widthX);
    final limitY = pow(2, widthY);
    final multiplicand = Logic(width: widthX);
    final multiplier = Logic(width: widthY);
    for (final signed in [false, true]) {
      final ppg = PartialProductGeneratorBasic(
          multiplicand, multiplier, radixEncoder,
          signedMultiplicand: signed, signedMultiplier: signed);
      CompactSignExtension(ppg).signExtend();
      for (var i = BigInt.zero; i < BigInt.from(limitX); i += BigInt.one) {
        for (var j = BigInt.zero; j < BigInt.from(limitY); j += BigInt.one) {
          final X = signed ? i.toSigned(widthX) : i.toUnsigned(widthX);
          final Y = signed ? j.toSigned(widthY) : j.toUnsigned(widthY);
          multiplicand.put(X);
          multiplier.put(Y);
          final value = ppg.evaluate();
          expect(value, equals(X * Y),
              reason: '$X * $Y = $value should be ${X * Y}');
        }
      }
    }
  });

  test('single MAC partial product test', () async {
    final encoder = RadixEncoder(16);
    const widthX = 8;
    const widthY = 18;

    const i = 1478;
    const j = 9;
    const k = 0;

    final X = BigInt.from(i).toSigned(widthX);
    final Y = BigInt.from(j).toSigned(widthY);
    final Z = BigInt.from(k).toSigned(widthX + widthY);
    // print('X=$X Y=$Y, Z=$Z');
    final product = X * Y + Z;

    final logicX = Logic(name: 'X', width: widthX);
    final logicY = Logic(name: 'Y', width: widthY);
    final logicZ = Logic(name: 'Z', width: widthX + widthY);
    logicX.put(X);
    logicY.put(Y);
    logicZ.put(Z);
    final pp = PartialProductGeneratorBasic(logicX, logicY, encoder,
        signedMultiplicand: true, signedMultiplier: true);
    CompactRectSignExtension(pp).signExtend();

    final lastLength =
        pp.partialProducts[pp.rows - 1].length + pp.rowShift[pp.rows - 1];

    final sign = logicZ[logicZ.width - 1];
    // for unsigned versus signed testing
    // final sign = signed ? logicZ[logicZ.width - 1] : Const(0);
    final l = [for (var i = 0; i < logicZ.width; i++) logicZ[i]];
    while (l.length < lastLength) {
      l.add(sign);
    }
    l
      ..add(~sign)
      ..add(Const(1));
    // print(pp.representation());

    pp.partialProducts.insert(0, l);
    pp.rowShift.insert(0, 0);
    // print(pp.representation());

    if (pp.evaluate() != product) {
      stdout.write('Fail: $X * $Y: ${pp.evaluate()} vs expected $product\n');
    }
    expect(pp.evaluate(), equals(product));
  });

  test('single MAC partial product sign extension test', () async {
    final encoder = RadixEncoder(16);
    const widthX = 8;
    const widthY = 18;

    const i = 1478;
    const j = 9;
    const k = 0;

    final X = BigInt.from(i).toSigned(widthX);
    final Y = BigInt.from(j).toSigned(widthY);
    final Z = BigInt.from(k).toSigned(widthX + widthY);
    // print('X=$X Y=$Y, Z=$Z');
    final product = X * Y + Z;

    final logicX = Logic(name: 'X', width: widthX);
    final logicY = Logic(name: 'Y', width: widthY);
    final logicZ = Logic(name: 'Z', width: widthX + widthY);
    logicX.put(X);
    logicY.put(Y);
    logicZ.put(Z);
    final pp = PartialProductGeneratorBasic(logicX, logicY, encoder,
        signedMultiplicand: true, signedMultiplier: true);
    CompactRectSignExtension(pp).signExtend();

    final lastLength =
        pp.partialProducts[pp.rows - 1].length + pp.rowShift[pp.rows - 1];

    final sign = logicZ[logicZ.width - 1];
    // for unsigned versus signed testing
    // final sign = signed ? logicZ[logicZ.width - 1] : Const(0);
    final l = [for (var i = 0; i < logicZ.width; i++) logicZ[i]];
    while (l.length < lastLength) {
      l.add(sign);
    }
    l
      ..add(~sign)
      ..add(Const(1));
    // print(pp.representation());

    pp.partialProducts.insert(0, l);
    pp.rowShift.insert(0, 0);
    // print(pp.representation());

    if (pp.evaluate() != product) {
      stdout.write('Fail: $X * $Y: ${pp.evaluate()} vs expected $product\n');
    }
    expect(pp.evaluate(), equals(product));
  });

  test('majority function', () async {
    expect(LogicValue.ofBigInt(BigInt.from(7), 5).majority(), true);
    expect(LogicValue.ofBigInt(BigInt.from(7) << 1, 5).majority(), true);
    expect(LogicValue.ofBigInt(BigInt.from(11) << 1, 5).majority(), true);
    expect(LogicValue.ofBigInt(BigInt.from(9) << 1, 5).majority(), false);
    expect(LogicValue.ofBigInt(BigInt.from(7) << 3, 7).majority(), false);
  });
}
