// Copyright (C) 2023-2024 Intel Corporation
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
import 'package:test/test.dart';

void checkEvaluateExhaustive(PartialProductGenerator pp) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  final limitX = pow(2, widthX);
  final limitY = pow(2, widthY);
  for (var i = BigInt.zero; i < BigInt.from(limitX); i += BigInt.one) {
    for (var j = BigInt.zero; j < BigInt.from(limitY); j += BigInt.one) {
      final X = pp.signed ? i.toSigned(widthX) : i.toUnsigned(widthX);
      final Y = pp.signed ? j.toSigned(widthY) : j.toUnsigned(widthY);
      pp.multiplicand.put(X);
      pp.multiplier.put(Y);
      final value = pp.evaluate();
      expect(value, equals(X * Y),
          reason: '$X * $Y = $value should be ${X * Y}');
    }
  }
}

void checkEvaluateRandom(PartialProductGenerator pp, int nSamples) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  for (var i = 0; i < nSamples; ++i) {
    final rX = Random().nextLogicValue(width: widthX).toBigInt();
    final rY = Random().nextLogicValue(width: widthY).toBigInt();
    final X = pp.signed ? rX.toSigned(widthX) : rX;
    final Y = pp.signed ? rY.toSigned(widthY) : rY;
    pp.multiplicand.put(X);
    pp.multiplier.put(Y);
    final value = pp.evaluate();
    expect(value, equals(X * Y), reason: '$X * $Y = $value should be ${X * Y}');
  }
}

void main() {
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
    final pp = PartialProductGenerator(logicX, logicY, encoder, signed: true);

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

  // This is a two-minute exhaustive but quick test
  test('exhaustive partial product evaluate: square radix-4, all extension',
      () async {
    for (final signed in [false, true]) {
      for (var radix = 4; radix < 8; radix *= 2) {
        const radix = 4;
        final encoder = RadixEncoder(radix);
        final shift = log2Ceil(encoder.radix);
        final minWidth = shift + (signed ? 1 : 0);
        for (var width = minWidth; width < shift * 2 + 1; width++) {
          for (final signExtension in SignExtension.values) {
            if (signExtension == SignExtension.none) {
              continue;
            }
            final pp = PartialProductGenerator(Logic(name: 'X', width: width),
                Logic(name: 'Y', width: width), encoder,
                signed: signed, signExtension: signExtension);

            checkEvaluateExhaustive(pp);
          }
        }
      }
    }
  });

  test('full rectangular test,', () async {
    for (final signed in [false, true]) {
      for (var radix = 2; radix < 32; radix *= 2) {
        final encoder = RadixEncoder(radix);
        final shift = log2Ceil(encoder.radix);
        for (var width = 3 + shift + 1; width < 3 + shift * 2 + 1; width++) {
          for (var skew = -3; skew < shift * 2; skew++) {
            // Only some sign extension routines have rectangular support
            // Commented out rectangular extension routines for speedup
            for (final signExtension in [
              SignExtension.brute,
              SignExtension.stop,
              SignExtension.compactRect
            ]) {
              final pp = PartialProductGenerator(Logic(name: 'X', width: width),
                  Logic(name: 'Y', width: width + skew), encoder,
                  signed: signed, signExtension: signExtension);
              checkEvaluateRandom(pp, 20);
            }
          }
        }
      }
    }
  });

  test('Rectangle Q collision tests,', () async {
    // These collide with the normal q extension bits
    // These are unsigned tests
    final alignTest = <List<(int, int, int)>>[]
      ..insert(0, [(2, 5, 0), (4, 7, 1), (8, 7, 2), (16, 9, 3)])
      ..insert(1, [(2, 5, 1), (4, 6, 2), (8, 9, 3), (16, 8, 4)])
      ..insert(2, [(2, 5, 2), (4, 7, 3), (8, 8, 4), (16, 11, 5)])
      ..insert(3, [(4, 6, 4), (8, 7, 5), (16, 10, 6)])
      ..insert(4, [(8, 9, 6), (16, 9, 7)])
      ..insert(5, [(16, 8, 8)]);

    for (final alignList in alignTest) {
      for (final align in alignList) {
        final radix = align.$1;
        final encoder = RadixEncoder(radix);
        final width = align.$2;

        final skew = align.$3;
        final X = BigInt.from(29).toUnsigned(width);
        final Y = BigInt.from(2060).toUnsigned(width + skew);
        final product = X * Y;

        final pp = PartialProductGenerator(Logic(name: 'X', width: width),
            Logic(name: 'Y', width: width + skew), encoder,
            signed: false);

        pp.multiplicand.put(X);
        pp.multiplier.put(Y);
        expect(pp.evaluate(), equals(product));
        checkEvaluateRandom(pp, 100);
      }
    }
  });

  test('minimum width verification,', () async {
    for (final signed in [false, true]) {
      for (var radix = 2; radix < 32; radix *= 2) {
        final encoder = RadixEncoder(radix);
        final shift = log2Ceil(encoder.radix);
        final width = shift + (signed ? 1 : 0);
        const skew = 0;
        // Only some sign extension routines have rectangular support
        // Commented out rectangular extension routines for speedup
        for (final signExtension in SignExtension.values) {
          if (signExtension == SignExtension.none) {
            continue;
          }
          final pp = PartialProductGenerator(Logic(name: 'X', width: width),
              Logic(name: 'Y', width: width + skew), encoder,
              signed: signed, signExtension: signExtension);
          checkEvaluateRandom(pp, 100);
        }
      }
    }
  });
  test('minimum rectangular width verification,', () async {
    for (final signed in [false, true]) {
      for (var radix = 2; radix < 32; radix *= 2) {
        final encoder = RadixEncoder(radix);
        final shift = log2Ceil(encoder.radix);
        final width = shift;
        final skew = (signed ? 1 : 0);
        // Only some sign extension routines have rectangular support
        // Commented out rectangular extension routines for speedup
        for (final signExtension in [
          SignExtension.brute,
          SignExtension.stop,
          SignExtension.compactRect
        ]) {
          {
            final pp = PartialProductGenerator(Logic(name: 'X', width: width),
                Logic(name: 'Y', width: width + skew), encoder,
                signed: signed, signExtension: signExtension);
            checkEvaluateExhaustive(pp);
          }
        }
      }
    }
  });
}
