// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dotproduct_test.dart
// An integer dot-product set of unit tests..
//
// 2025 July 23
// Author: Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  final dotProductModules = [
    CompressionTreeDotProduct.new,
    GeneralDotProduct.new
  ];

  test('dotproduct width mismatch test', () async {
    final multiplicands = [
      Logic(width: 3, name: 'a_0'),
      Logic(width: 4, name: 'a_1'),
      Logic(width: 3, name: 'a_2'),
      Logic(width: 3, name: 'a_3')
    ];
    final multipliers = [
      Logic(width: 3, name: 'b_0'),
      Logic(width: 3, name: 'b_1'),
      Logic(width: 3, name: 'b_2'),
      Logic(width: 3, name: 'b_3')
    ];
    final multiplicands2 = [
      Logic(width: 4, name: 'b_0'),
      Logic(width: 4, name: 'b_1'),
      Logic(width: 4, name: 'b_2'),
      Logic(width: 4, name: 'b_3')
    ];

    CompressionTreeDotProduct(multipliers, multipliers);
    try {
      CompressionTreeDotProduct(multiplicands, multipliers);
      fail('Should throw on a multiplicand width mismatch');
    } on RohdHclException catch (e) {
      expect(e.message, contains('Multiplicands must all have the same width'));
    }

    try {
      CompressionTreeDotProduct(multiplicands2, multipliers);
      fail('Should throw on a multiplicand vs multiplier width mismatch');
    } on RohdHclException catch (e) {
      expect(e.message,
          contains('Multiplier and multiplicand have 4 width mismatches.'));
    }
  });

  test('dotproduct signed-variants exhaustive', () async {
    const widths = [3, 3];
    final depth = widths.length;
    final candValues = [for (var i = 0; i < depth; i++) BigInt.zero];
    final multValues = [for (var i = 0; i < depth; i++) BigInt.zero];
    final multiplicands = [
      for (var i = 0; i < depth; i++) Logic(width: widths[i])..put(0)
    ];
    final multipliers = [
      for (var i = 0; i < depth; i++) Logic(width: widths[i])..put(0)
    ];

    final fullWidth = widths.reduce((a, b) => a + b);
    final limit = BigInt.from(1 << fullWidth);
    final masks = [
      for (var i = 0; i < depth; i++) BigInt.from((1 << widths[i]) - 1)
    ];

    for (final signedMultiplicand in [false, true]) {
      for (final signedMultiplier in [false, true]) {
        for (final dotProductModule in dotProductModules) {
          // Create the dot product module with the current parameters.
          // Note that the `dotProduct` function is a constructor for the
          // respective dot product module.
          final dotProduct = dotProductModule(multiplicands, multipliers,
              signedMultiplicand: signedMultiplicand,
              signedMultiplier: signedMultiplier);

          for (var candFv = BigInt.zero; candFv < limit; candFv += BigInt.one) {
            var remCandValue = candFv;

            for (var i = 0; i < depth; i++) {
              candValues[i] = remCandValue & masks[i];
              remCandValue >>= widths[i];
            }
            for (var mulFv = BigInt.zero; mulFv < limit; mulFv += BigInt.one) {
              var remMulValue = mulFv;

              for (var i = 0; i < depth; i++) {
                multValues[i] = remMulValue & masks[i];
                remMulValue >>= widths[i];
              }

              for (var m = 0; m < multiplicands.length; m++) {
                multiplicands[m].put(candValues[m]);
                multipliers[m].put(multValues[m]);
              }
              final expected = List.generate(
                      candValues.length,
                      (i) =>
                          candValues[i].toCondSigned(widths[i],
                              signed: signedMultiplicand) *
                          multValues[i].toCondSigned(widths[i],
                              signed: signedMultiplier))
                  .reduce((sum, product) => sum + product)
                  .toCondSigned(dotProduct.product.width,
                      signed: signedMultiplier | signedMultiplicand);
              final computedLogic = dotProduct.product;
              final computed = computedLogic.value.toBigInt().toCondSigned(
                  computedLogic.width,
                  signed: signedMultiplier | signedMultiplicand);

              expect(computed, equals(expected), reason: '''
          multiplicands=$candValues
          multipliers=$multValues
          computed=$computed, expected=$expected
          computedBits=${dotProduct.product.value.bitString}
          expectedBits=${expected.toRadixString(2)}
  ''');
            }
          }
        }
      }
    }
  });

  test('dotproduct signed-variants random', () async {
    const iterations = 100;

    const widths = [4, 4, 4, 4, 4];
    final depth = widths.length;

    final multiplicands = [
      for (var i = 0; i < depth; i++) Logic(width: widths[i])..put(0)
    ];
    final multipliers = [
      for (var i = 0; i < depth; i++) Logic(width: widths[i])..put(0)
    ];

    for (final signedMultiplicand in [false, true]) {
      for (final signedMultiplier in [false, true]) {
        for (final dotProductModule in dotProductModules) {
          final dotProduct = dotProductModule(multiplicands, multipliers,
              signedMultiplicand: signedMultiplicand,
              signedMultiplier: signedMultiplier);

          final rv = Random(57);
          for (var iteration = 0; iteration < iterations; iteration++) {
            final candValues = [
              for (var i = 0; i < depth; i++)
                rv.nextLogicValue(width: widths[i])
            ];
            final multValues = [
              for (var i = 0; i < depth; i++)
                rv.nextLogicValue(width: widths[i])
            ];

            for (var i = 0; i < iterations; i++) {
              for (var m = 0; m < multiplicands.length; m++) {
                multiplicands[m].put(candValues[m]);
                multipliers[m].put(multValues[m]);
              }
            }

            final productWidth = dotProduct.product.width;

            final expected = List.generate(
                    candValues.length,
                    (i) =>
                        candValues[i].toBigInt().toCondSigned(widths[i],
                            signed: signedMultiplicand) *
                        multValues[i]
                            .toBigInt()
                            .toCondSigned(widths[i], signed: signedMultiplier))
                .reduce((sum, product) => sum + product)
                .toCondSigned(productWidth,
                    signed: signedMultiplier | signedMultiplicand);
            final computedLogic = dotProduct.product;
            final computed = computedLogic.value.toBigInt().toCondSigned(
                computedLogic.width,
                signed: signedMultiplier | signedMultiplicand);
            expect(computed, equals(expected), reason: '''
          multiplicands=${candValues.map((m) => m.toBigInt())}
          multipliers=${multValues.map((m) => m.toBigInt())}
          computed=$computed, expected=$expected
          computedBits=${dotProduct.product.value.bitString}
          expectedBits=${expected.toCondSigned(productWidth).toRadixString(2)}
  ''');
          }
        }
      }
    }
  });

  test('dotproduct singleton', () async {
    const widths = [3, 3];
    final depth = widths.length;
    const signedMultiplicand = true;
    const signedMultiplier = true;

    final multiplicands = [
      for (var i = 0; i < depth; i++) Logic(width: widths[i])
    ];
    final multipliers = [
      for (var i = 0; i < depth; i++) Logic(width: widths[i])
    ];

    final candValues = [4, 6];
    final multValues = [7, 4];
    final signedCandValues = [
      for (var i = 0; i < depth; i++)
        BigInt.from(candValues[i])
            .toCondSigned(widths[i], signed: signedMultiplicand)
    ];
    final signedMultValues = [
      for (var i = 0; i < depth; i++)
        BigInt.from(multValues[i])
            .toCondSigned(widths[i], signed: signedMultiplier)
    ];
    for (var m = 0; m < multiplicands.length; m++) {
      multiplicands[m].put(BigInt.from(candValues[m])
          .toCondSigned(widths[m], signed: signedMultiplicand));
      multipliers[m].put(BigInt.from(multValues[m])
          .toCondSigned(widths[m], signed: signedMultiplier));
    }
    final dotProduct = CompressionTreeDotProduct(multiplicands, multipliers,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier);

    final expected = List.generate(
            candValues.length, (i) => signedCandValues[i] * signedMultValues[i])
        .reduce((sum, product) => sum + product)
        .toCondSigned(dotProduct.product.width,
            signed: signedMultiplier | signedMultiplicand);
    final computedLogic = dotProduct.product;
    final computed = computedLogic.value.toBigInt();
    expect(computed, equals(expected), reason: '''
          multiplicands=$candValues
          multipliers=$multValues
          computed=$computed, expected=$expected
          computedBits=${dotProduct.product.value.toRadixString()}
          expectedBits=${expected.toRadixString(2)}
  ''');
  });

  test('dotproduct trival case', () async {
    const width = 4;
    final multiplicands = [Logic(width: width), Logic(width: width)];
    final multipliers = [Logic(width: width), Logic(width: width)];

    final multiplicandValues = [4, 8];
    final multiplierValues = [2, 3];

    for (var i = 0; i < multiplicands.length; i++) {
      multiplicands[i].put(multiplicandValues[i]);
      multipliers[i].put(multiplierValues[i]);
    }
    final dotProduct = GeneralDotProduct(multiplicands, multipliers);

    final expected = List.generate(multiplicands.length,
            (i) => multiplicandValues[i] * multiplierValues[i])
        .reduce((sum, product) => sum + product);
    final computedLogic = dotProduct.product;
    final computed = computedLogic.value.toInt();
    expect(computed, equals(expected), reason: '''
          multiplicands=$multiplicandValues
          multipliers=$multiplierValues
          computed=$computed, expected=$expected
          computedBits=${dotProduct.product.value.toRadixString()}
          expectedBits=${expected.toRadixString(2)}
          ''');
  });

  test('dotproduct synthesis', () async {
    final multiplicands = <Logic>[];
    final multipliers = <Logic>[];
    for (var i = 0; i < 4; i++) {
      multiplicands.add(Logic(width: 32, name: 'a_$i'));
      multipliers.add(Logic(width: 32, name: 'b_$i'));
    }
    final dotProduct = CompressionTreeDotProduct(multiplicands, multipliers,
        productRadix: 8, definitionName: 'DotProduct');
    await dotProduct.build();
    expect(dotProduct.generateSynth(), isNotEmpty);
  });
}
