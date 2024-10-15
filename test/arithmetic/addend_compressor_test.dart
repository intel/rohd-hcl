// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// addend_compressor_test.dart
// Tests for the select interface of Booth encoding
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/evaluate_compressor.dart';
import 'package:rohd_hcl/src/arithmetic/evaluate_partial_product.dart';
import 'package:rohd_hcl/src/arithmetic/partial_product_sign_extend.dart';
import 'package:test/test.dart';

void testCompressionExhaustive(PartialProductGenerator pp) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  final compressor = ColumnCompressor(pp);

  final limitX = pow(2, widthX);
  final limitY = pow(2, widthY);
  for (var i = 0; i < limitX; i++) {
    for (var j = 0; j < limitY; j++) {
      final X = pp.signed
          ? BigInt.from(i).toSigned(widthX)
          : BigInt.from(i).toUnsigned(widthX);
      final Y = pp.signed
          ? BigInt.from(j).toSigned(widthY)
          : BigInt.from(j).toUnsigned(widthY);
      final product = X * Y;

      pp.multiplicand.put(X);
      pp.multiplier.put(Y);
      final value = pp.evaluate();
      expect(value, equals(product),
          reason: 'Fail: $i($X) * $j($Y): $value '
              'vs expected $product'
              '\n$pp');
      final evaluateValue = compressor.evaluate();
      if (evaluateValue.$1 != product) {
        stdout
          ..write('Fail:  $i($X)[$widthX] * $j($Y)[$widthY]: $evaluateValue '
              'vs expected $product\n')
          ..write(pp);
      }
      compressor.compress();
      final compressedValue = compressor.evaluate().$1;
      expect(compressedValue, equals(product),
          reason: 'Fail:  $i($X)[$widthX] * $j($Y)[$widthY]: $compressedValue '
              'vs expected $product'
              '\n$pp');
      final compressedLogicValue = compressor.evaluate(logic: true).$1;
      expect(compressedLogicValue, equals(product),
          reason:
              'Fail:  $i($X)[$widthX] * $j($Y)[$widthY]: $compressedLogicValue '
              'vs expected $product'
              '\n$pp');

      final a = compressor.extractRow(0);
      final b = compressor.extractRow(1);

      final adder = ParallelPrefixAdder(a, b);
      final adderValue =
          adder.sum.value.toBigInt().toSigned(compressor.columns.length);
      expect(adderValue, equals(product),
          reason: 'Fail:  $i($X)[$widthX] * $j($Y)[$widthY]: '
              '$adderValue vs expected $product'
              '\n$pp');
    }
  }
}

void main() {
  test('exhaustive compression evaluate: square radix-4, just CompactRect',
      () async {
    stdout.write('\n');

    for (final signed in [false, true]) {
      for (var radix = 4; radix < 8; radix *= 2) {
        final encoder = RadixEncoder(radix);
        // stdout.write('encoding with radix=$radix\n');
        final shift = log2Ceil(encoder.radix);
        for (var width = shift + 1; width < 2 * shift + 1; width++) {
          for (final signExtension in SignExtension.values) {
            if (signExtension != SignExtension.compactRect) {
              continue;
            }
            final ppg = curryPartialProductGenerator(signExtension);
            final pp = ppg(Logic(name: 'X', width: width),
                Logic(name: 'Y', width: width), encoder,
                signed: signed);

            testCompressionExhaustive(pp);
          }
        }
      }
    }
  });
  test('single compressor evaluate multiply', () async {
    const widthX = 6;
    const widthY = 9;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    const av = 4;
    const bv = 14;
    for (final signed in [true, false]) {
      final bA = signed
          ? BigInt.from(av).toSigned(widthX)
          : BigInt.from(av).toUnsigned(widthX);
      final bB = signed
          ? BigInt.from(bv).toSigned(widthY)
          : BigInt.from(bv).toUnsigned(widthY);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      const radix = 2;
      final encoder = RadixEncoder(radix);
      final pp = PartialProductGeneratorCompactRectSignExtension(a, b, encoder,
          signed: signed);
      expect(pp.evaluate(), equals(BigInt.from(av * bv)));
      final compressor = ColumnCompressor(pp);
      expect(compressor.evaluate().$1, equals(BigInt.from(av * bv)));
      compressor.compress();
      expect(compressor.evaluate().$1, equals(BigInt.from(av * bv)));
    }
  });
  test('single compressor evaluate', () async {
    const widthX = 6;
    const widthY = 6;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    const av = 3;
    const bv = 6;
    for (final signed in [true]) {
      final bA = signed
          ? BigInt.from(av).toSigned(widthX)
          : BigInt.from(av).toUnsigned(widthX);
      final bB = signed
          ? BigInt.from(bv).toSigned(widthY)
          : BigInt.from(bv).toUnsigned(widthY);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      const radix = 2;
      final encoder = RadixEncoder(radix);

      final pp = PartialProductGeneratorCompactRectSignExtension(a, b, encoder,
          signed: signed);
      expect(pp.evaluate(), equals(BigInt.from(av * bv)));
      final compressor = ColumnCompressor(pp);
      expect(compressor.evaluate().$1, equals(BigInt.from(av * bv)));
      compressor.compress();
      expect(compressor.evaluate().$1, equals(BigInt.from(av * bv)));
    }
  });

  test('example multiplier', () async {
    const widthX = 10;
    const widthY = 10;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    const av = 37;
    const bv = 6;
    for (final signed in [true]) {
      final bA = signed
          ? BigInt.from(av).toSigned(widthX)
          : BigInt.from(av).toUnsigned(widthX);
      final bB = signed
          ? BigInt.from(bv).toSigned(widthY)
          : BigInt.from(bv).toUnsigned(widthY);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      const radix = 8;
      final encoder = RadixEncoder(radix);

      final pp = PartialProductGeneratorCompactRectSignExtension(a, b, encoder,
          signed: signed);
      expect(pp.evaluate(), equals(BigInt.from(av * bv)));
      final compressor = ColumnCompressor(pp)..compress();
      expect(compressor.evaluate().$1, equals(BigInt.from(av * bv)));
    }
  });
}
