// Copxorright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// booth_test.dart
// Tests for Booth encoding
//
// 2024 May 21
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/booth.dart';
import 'package:rohd_hcl/src/utils.dart';
import 'package:test/test.dart';

enum SignExtension { brute, stop, compact, compactRect }

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
      // print('$X * $Y');
      expect(pp.evaluate(), equals(X * Y));
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
    // print('$X * $Y');
    expect(pp.evaluate(), equals(X * Y));
  }
}

void main() {
  test('single MAC partial product test', () async {
    // stdout.write('\n');

    final encoder = RadixEncoder(4);
    const widthX = 4;
    const widthY = 4;

    const i = 8;
    var j = pow(2, widthY - 1).toInt();
    j = 2;
    const k = 128;

    final X = BigInt.from(i).toSigned(widthX);
    final Y = BigInt.from(j).toSigned(widthY);
    final Z = BigInt.from(k).toSigned(widthX + widthY);
    final product = X * Y + Z;

    final logicX = Logic(name: 'X', width: widthX);
    final logicY = Logic(name: 'Y', width: widthY);
    final logicZ = Logic(name: 'Z', width: widthX + widthY);
    logicX.put(X);
    logicY.put(Y);
    logicZ.put(Z);
    final pp = PartialProductGenerator(logicX, logicY, encoder);
    // ignore: cascade_invocations
    pp.signExtendCompact();
    // stdout.write(pp);
    // Add a row for addend
    final l = [for (var i = 0; i < logicZ.width; i++) logicZ[i]];
    // ignore: cascade_invocations
    l
      ..add(Const(0)) // ~Sign in our sign extension form
      ..add(Const(1));
    pp.partialProducts.add(l);
    pp.rowShift.add(0);

    // stdout.write('Test: $i($X) * $j($Y) + $k($Z)= $product vs '
    //     '${pp.evaluate(signed: true)}\n');
    if (pp.evaluate() != product) {
      stdout.write('Fail: $X * $Y: ${pp.evaluate()} vs expected $product\n');
      // ignore: cascade_invocations
      // stdout.write(pp);
    }
    // expect(pp.evaluate(signed: true), equals(product));
  });

  // TODO(dakdesmond): Figure out minimum widths!

  // This is a two-minute exhaustive but quick test
  test('exhaustive partial product evaluate: square radix-4, all extension',
      () async {
    stdout.write('\n');
    for (final signed in [false, true]) {
      for (var radix = 4; radix < 8; radix *= 2) {
        final encoder = RadixEncoder(radix);
        // stdout.write('encoding with radix=$radix\n');
        final shift = log2Ceil(encoder.radix);
        for (var width = shift + 1; width < shift * 2 + 1; width++) {
          for (final signExtension in SignExtension.values) {
            final pp = PartialProductGenerator(Logic(name: 'X', width: width),
                Logic(name: 'Y', width: width), encoder,
                signed: signed);
            switch (signExtension) {
              case SignExtension.brute:
                pp.bruteForceSignExtend();
              case SignExtension.stop:
                pp.signExtendWithStopBitsRect();
              case SignExtension.compact:
                pp.signExtendCompact();
              case SignExtension.compactRect:
                pp.signExtendCompactRect();
            }
            // testPartialProductExhaustive(pp);
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
            for (final signExtension in [
              // SignExtension.brute,
              // SignExtension.stop,
              SignExtension.compactRect
            ]) {
              final pp = PartialProductGenerator(Logic(name: 'X', width: width),
                  Logic(name: 'Y', width: width + skew), encoder,
                  signed: signed);

              switch (signExtension) {
                case SignExtension.brute:
                  pp.bruteForceSignExtend();
                case SignExtension.stop:
                  pp.signExtendWithStopBitsRect();
                case SignExtension.compact:
                  pp.signExtendCompact();
                case SignExtension.compactRect:
                  pp.signExtendCompactRect();
              }
              checkEvaluateRandom(pp, 100);
            }
          }
        }
      }
    }
  });

  test('Rectangle Q collision tests,', () async {
    final alignTest = <List<(int, int, int)>>[];

    // These collide with the normal q extension bits
    // These are unsigned tests
    // ignore: cascade_invocations
    alignTest
          ..insert(0, [(2, 5, 0), (4, 7, 1), (8, 7, 2), (16, 9, 3)])
          ..insert(1, [(2, 5, 1), (4, 6, 2), (8, 9, 3), (16, 8, 4)])
          ..insert(2, [(2, 5, 2), (4, 7, 3), (8, 8, 4), (16, 11, 5)])
          ..insert(3, [(4, 6, 4), (8, 7, 5), (16, 10, 6)])
          ..insert(4, [(8, 9, 6), (16, 9, 7)])
          ..insert(5, [(16, 8, 8)])
        //
        ;

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
        pp.signExtendCompactRect();
        expect(pp.evaluate(), equals(product));
        checkEvaluateRandom(pp, 100);
      }
    }
  });
}
