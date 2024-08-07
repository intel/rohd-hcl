// Copxorright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compressor_test.dart
// Tests for the select interface of Booth encoding
//
// 2024 June 04
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/booth.dart';
import 'package:rohd_hcl/src/arithmetic/compressor.dart';
import 'package:rohd_hcl/src/arithmetic/parallel_prefix_operations.dart';
import 'package:rohd_hcl/src/utils.dart';
import 'package:test/test.dart';

enum SignExtension { brute, stop, compact }

void testCompressionExhaustive(PartialProductGenerator pp) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  final compressor = ColumnCompressor(pp);

  final limitX = pow(2, widthX);
  final limitY = pow(2, widthY);
  for (var i = 0; i < limitX; i++) {
    for (var j = 0; j < limitY; j++) {
      final X = BigInt.from(i).toSigned(widthX);
      final Y = BigInt.from(j).toSigned(widthY);
      final product = X * Y;

      pp.multiplicand.put(X);
      pp.multiplier.put(Y);
      // stdout.write('$i($X) * $j($Y): should be $product\n');
      if (pp.evaluate() != product) {
        stdout
          ..write('Fail: $i($X) * $j($Y): ${pp.evaluate()} '
              'vs expected $product\n')
          ..write(pp);
      }
      expect(pp.evaluate(), equals(product));
      final evaluateValue = compressor.evaluate();
      if (evaluateValue != product) {
        stdout
          ..write('Fail:  $i($X)[$widthX] * $j($Y)[$widthY]: $evaluateValue '
              'vs expected $product\n')
          ..write(pp);
      }
      compressor.compress();
      final compressedValue = compressor.evaluate();
      if (compressedValue != product) {
        stdout
          ..write('Fail:  $i($X)[$widthX] * $j($Y)[$widthY]: $compressedValue '
              'vs expected $product\n')
          ..write(pp);
      }
      expect(compressedValue, equals(product));
      final compressedLogicValue = compressor.evaluate(logic: true);
      if (compressedLogicValue != product) {
        stdout
          ..write(
              'Fail:  $i($X)[$widthX] * $j($Y)[$widthY]: $compressedLogicValue '
              'vs expected $product\n')
          ..write(pp);
      }
      expect(compressedLogicValue, equals(product));

      final a = compressor.extractRow(0);
      final b = compressor.extractRow(1);
      final adder = ParallelPrefixAdder(a, b, KoggeStone.new);
      final adderValue =
          adder.out.value.toBigInt().toSigned(compressor.columns.length);
      if (adderValue != product) {
        stdout
          ..write('Fail:  $i($X)[$widthX] * $j($Y)[$widthY]: $adderValue '
              'vs expected $product\n')
          ..write(pp);
      }
      expect(adderValue, equals(product));
    }
  }
}

void main() {
  test('exhaustive compression evaluate: square radix-4, all SignExtension',
      () async {
    stdout.write('\n');

    for (var radix = 4; radix < 8; radix *= 2) {
      final encoder = RadixEncoder(2);
      // stdout.write('encoding with radix=$radix\n');
      final shift = log2Ceil(encoder.radix);
      for (var width = shift + 1; width < shift + 2; width++) {
        // stdout.write('\tTesting width=$width\n');
        for (final signExtension in SignExtension.values) {
          final pp = PartialProductGenerator(Logic(name: 'X', width: width),
              Logic(name: 'Y', width: width), encoder);
          switch (signExtension) {
            case SignExtension.brute:
              pp.bruteForceSignExtend();
            case SignExtension.stop:
            // pp.signExtendWithStopBitsRect();
            case SignExtension.compact:
              pp.signExtendCompact();
          }
          // stdout.write('\tTesting extension=$signExtension\n');
          testCompressionExhaustive(pp);
        }
      }
    }
  });
}
