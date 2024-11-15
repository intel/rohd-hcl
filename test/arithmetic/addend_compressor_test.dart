// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// addend_compressor_test.dart
// Tests for the select interface of Booth encoding
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/evaluate_compressor.dart';
import 'package:rohd_hcl/src/arithmetic/evaluate_partial_product.dart';
import 'package:rohd_hcl/src/arithmetic/partial_product_sign_extend.dart';
import 'package:test/test.dart';

class CompressorTestMod extends Module {
  late final PartialProductGenerator pp;

  late final ColumnCompressor compressor;

  Logic get r0 => output('r0');

  Logic get r1 => output('r1');

  CompressorTestMod(Logic ia, Logic ib, RadixEncoder encoder, Logic? iclk,
      {bool signed = true})
      : super(name: 'compressor_test_mod') {
    final a = addInput('a', ia, width: ia.width);
    final b = addInput('b', ib, width: ib.width);
    Logic? clk;
    if (iclk != null) {
      clk = addInput('clk', iclk);
    }

    pp = PartialProductGeneratorCompactRectSignExtension(a, b, encoder,
        signed: signed);
    compressor = ColumnCompressor(pp, clk: clk);
    compressor.compress();
    final r0 = addOutput('r0', width: compressor.columns.length);
    final r1 = addOutput('r1', width: compressor.columns.length);

    r0 <= compressor.extractRow(0);
    r1 <= compressor.extractRow(1);
  }
}

void testCompressionExhaustive(PartialProductGenerator pp) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  final signed =
      (pp.selectSigned == null) ? pp.signed : !pp.selectSigned!.value.isZero;

  final limitX = pow(2, widthX);
  final limitY = pow(2, widthY);
  for (var i = 0; i < limitX; i++) {
    for (var j = 0; j < limitY; j++) {
      final X = signed
          ? BigInt.from(i).toSigned(widthX)
          : BigInt.from(i).toUnsigned(widthX);
      final Y = signed
          ? BigInt.from(j).toSigned(widthY)
          : BigInt.from(j).toUnsigned(widthY);

      checkCompressor(pp, X, Y);
    }
  }
}

void testCompressionRandom(PartialProductGenerator pp, int iterations) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  final value = Random(47);
  for (var i = 0; i < iterations; i++) {
    final X = pp.signed
        ? value.nextLogicValue(width: widthX).toBigInt().toSigned(widthX)
        : value.nextLogicValue(width: widthX).toBigInt().toUnsigned(widthX);
    final Y = pp.signed
        ? value.nextLogicValue(width: widthY).toBigInt().toSigned(widthY)
        : value.nextLogicValue(width: widthY).toBigInt().toUnsigned(widthY);

    checkCompressor(pp, X, Y);
  }
}

void checkCompressor(PartialProductGenerator pp, BigInt X, BigInt Y) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;
  final compressor = ColumnCompressor(pp);

  final product = X * Y;

  pp.multiplicand.put(X);
  pp.multiplier.put(Y);
  final value = pp.evaluate();
  expect(value, equals(product),
      reason: 'Fail: $X * $Y: $value '
          'vs expected $product'
          '\n$pp');
  final evaluateValue = compressor.evaluate();
  if (evaluateValue.$1 != product) {
    stdout
      ..write('Fail:  $X)$widthX] * $Y[$widthY]: $evaluateValue '
          'vs expected $product\n')
      ..write(pp);
  }
  compressor.compress();
  final compressedValue = compressor.evaluate().$1;
  expect(compressedValue, equals(product),
      reason: 'Fail:  $X[$widthX] * $Y[$widthY]: $compressedValue '
          'vs expected $product'
          '\n$pp');
  final compressedLogicValue = compressor.evaluate(logic: true).$1;
  expect(compressedLogicValue, equals(product),
      reason: 'Fail:  $X[$widthX] * $Y[$widthY]: $compressedLogicValue '
          'vs expected $product'
          '\n$pp');

  final a = compressor.extractRow(0);
  final b = compressor.extractRow(1);

  final adder = ParallelPrefixAdder(a, b);
  final adderValue =
      adder.sum.value.toBigInt().toSigned(compressor.columns.length);
  expect(adderValue, equals(product),
      reason: 'Fail:  $X[$widthX] * $Y[$widthY]: '
          '$adderValue vs expected $product'
          '\n$pp');
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  test('ColumnCompressor: random evaluate: square radix-4, just CompactRect',
      () async {
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
            for (final useSelect in [false, true]) {
              final PartialProductGenerator pp;
              if (useSelect) {
                final selectSigned = Logic();
                // ignore: cascade_invocations
                selectSigned.put(signed ? 1 : 0);
                pp = ppg(Logic(name: 'X', width: width),
                    Logic(name: 'Y', width: width), encoder,
                    selectSigned: selectSigned);
              } else {
                pp = ppg(Logic(name: 'X', width: width),
                    Logic(name: 'Y', width: width), encoder,
                    signed: signed);
              }
              testCompressionRandom(pp, 10);
            }
          }
        }
      }
    }
  });
  test('Column Compressor: single compressor evaluate', () async {
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

  test('Column Compressor: evaluate flopped', () async {
    final clk = SimpleClockGenerator(10).clk;
    const widthX = 6;
    const widthY = 6;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    var av = 3;
    const bv = 6;
    var bA = BigInt.from(av).toSigned(widthX);
    final bB = BigInt.from(bv).toSigned(widthY);

    // Set these so that printing inside module build will have Logic values
    a.put(bA);
    b.put(bB);
    const radix = 2;
    final encoder = RadixEncoder(radix);

    final compressorTestMod = CompressorTestMod(a, b, encoder, clk);
    await compressorTestMod.build();

    unawaited(Simulator.run());

    await clk.nextNegedge;
    expect(compressorTestMod.compressor.evaluate().$1,
        equals(BigInt.from(av * bv)));
    av = 4;
    bA = BigInt.from(av).toSigned(widthX);
    a.put(bA);
    await clk.nextNegedge;
    expect(compressorTestMod.compressor.evaluate().$1,
        equals(BigInt.from(av * bv)));
    await Simulator.endSimulation();
  });

  test('example multiplier', () async {
    const widthX = 10;
    const widthY = 10;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    const av = 37;
    const bv = 6;
    for (final signed in [false, true]) {
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
      final selectSigned = Logic();
      // ignore: cascade_invocations
      selectSigned.put(signed ? 1 : 0);
      final pp = PartialProductGeneratorStopBitsSignExtension(a, b, encoder,
          // final pp = PartialProductGeneratorCompactRectSignExtension(a, b,
          // encoder,
          // signed: signed);
          selectSigned: selectSigned);

      expect(pp.evaluate(), equals(bA * bB));
      final compressor = ColumnCompressor(pp)..compress();
      expect(compressor.evaluate().$1, equals(bA * bB));
    }
  });

  test('single sign agnostic compressor evaluate', () async {
    const widthX = 3;
    const widthY = 3;
    final a = Logic(name: 'a', width: widthX);
    final b = Logic(name: 'b', width: widthY);

    const av = 1;
    const bv = 4;
    for (final signed in [false, true]) {
      final bA = signed
          ? BigInt.from(av).toSigned(widthX)
          : BigInt.from(av).toUnsigned(widthX);
      final bB = signed
          ? BigInt.from(bv).toSigned(widthY)
          : BigInt.from(bv).toUnsigned(widthY);

      const radix = 4;
      final encoder = RadixEncoder(radix);
      // for (final useSelect in [true]) {
      for (final useSelect in [false, true]) {
        // Set these so that printing inside module build will have Logic values
        a.put(bA);
        b.put(bB);

        final selectSigned = Logic();
        // ignore: cascade_invocations
        selectSigned.put(signed ? 1 : 0);

        final pp = useSelect
            ? PartialProductGeneratorBruteSignExtension(a, b, encoder,
                selectSigned: selectSigned)
            : PartialProductGeneratorBruteSignExtension(a, b, encoder,
                signed: signed);

        // print(pp.representation());

        expect(pp.evaluate(), equals(bA * bB));
        final compressor = ColumnCompressor(pp);
        expect(compressor.evaluate().$1, equals(bA * bB));
        compressor.compress();
        expect(compressor.evaluate().$1, equals(bA * bB));
      }
    }
  });
}
