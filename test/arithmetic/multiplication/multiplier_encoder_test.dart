// Copyright (C) 2023-2026 Intel Corporation
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

const _randomIterations = 4;

// Here are the variations needed testing:
// - Sign variants
//   - Multiplicand:  [unsigned, signed], [selectedUnsigned, selectedSigned]
//   - Multiplier:  [unsigned, signed], [selectedUnsigned, selectedSigned]
// - Radix Encodings:  [2,4,8,16]
// - Widths:
//   - Cross the shift intervals for each radix
//   - Rectangular: again, need to cross a shift interval
// - Sign Extension: [brute, stop, compact, compactRect]

typedef PartialProductFactory = PartialProductGeneratorBase Function();

void testPartialProductExhaustive(
  String description,
  PartialProductFactory create,
) {
  test('exhaustive: $description', () {
    final pp = create();
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

void testPartialProductRandom(
  String description,
  int iterations,
  PartialProductFactory create,
) {
  test('random: $description', () {
    final pp = create();
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
    final rand = Random(47);
    for (var i = 0; i < iterations; i++) {
      for (final multiplicandSign in multiplicandSigns) {
        final X = rand
            .nextLogicValue(width: widthX)
            .toBigInt()
            .toCondSigned(widthX, signed: multiplicandSign);
        if (pp.selectSignedMultiplicand != null) {
          pp.selectSignedMultiplicand!.put(multiplicandSign ? 1 : 0);
        }
        for (final multiplierSign in multiplierSigns) {
          final Y = rand
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

void testPartialProductSingle(
  String description,
  PartialProductFactory create,
  BigInt X,
  BigInt Y,
) {
  test('single: $description', () {
    final pp = create();
    if (pp.selectSignedMultiplicand != null) {
      pp.selectSignedMultiplicand!.put(X.isNegative ? 1 : 0);
    }
    if (pp.selectSignedMultiplier != null) {
      pp.selectSignedMultiplier!.put(Y.isNegative ? 1 : 0);
    }
    checkPartialProduct(pp, X, Y);
  });
}

void checkPartialProduct(PartialProductGeneratorBase pp, BigInt iX, BigInt iY) {
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
  group('PartialProduct: fixed sign variants', () {
    for (final signedMultiplicand in [false, true]) {
      for (final signedMultiplier in [false, true]) {
        for (final radix in [2, 4]) {
          final width = log2Ceil(radix) + (signedMultiplier ? 1 : 0);
          for (final signExtension
              in SignExtension.values.where((e) => e != SignExtension.none)) {
            testPartialProductExhaustive(
              'fixed_R${radix}_W$width'
              '_SD${signedMultiplicand ? 1 : 0}'
              '_SM${signedMultiplier ? 1 : 0}_${signExtension.name}',
              () {
                final pp = PartialProductGenerator(
                  Logic(name: 'X', width: width),
                  Logic(name: 'Y', width: width),
                  RadixEncoder(radix),
                  signedMultiplicand: signedMultiplicand,
                  signedMultiplier: signedMultiplier,
                );
                currySignExtensionFunction(signExtension)(pp).signExtend();
                return pp;
              },
            );
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
        testPartialProductSingle(
          'singleton_R${radix}_W$width'
          '_SD${signedMultiplicand ? 1 : 0}'
          '_SM${signedMultiplier ? 1 : 0}',
          () {
            final pp = PartialProductGenerator(
              Logic(name: 'X', width: width),
              Logic(name: 'Y', width: width),
              encoder,
              signedMultiplicand: signedMultiplicand,
              signedMultiplier: signedMultiplier,
            );
            StopBitsSignExtension(pp).signExtend();
            return pp;
          },
          BigInt.zero,
          BigInt.zero,
        );
      }
    }
  });

  group('PartialProduct: fixed/select sign variants', () {
    for (final radix in [2, 4]) {
      for (final selectMultiplicand in [false, true]) {
        for (final signMultiplicand
            in (!selectMultiplicand ? [false, true] : [false])) {
          for (final selectMultiplier in [false, true]) {
            for (final signMultiplier
                in (!selectMultiplier ? [false, true] : [false])) {
              for (final signExtension in SignExtension.values
                  .where((e) => e != SignExtension.none)) {
                final width = log2Ceil(radix) + (signMultiplier ? 1 : 0);
                testPartialProductExhaustive(
                  'select_R${radix}_W$width'
                  '_SD${signMultiplicand ? 1 : 0}'
                  '_SM${signMultiplier ? 1 : 0}'
                  '_SelD${selectMultiplicand ? 1 : 0}'
                  '_SelM${selectMultiplier ? 1 : 0}_${signExtension.name}',
                  () {
                    final selectSignMultiplicand = Logic();
                    final selectSignMultiplier = Logic();
                    final pp = PartialProductGenerator(
                      Logic(name: 'X', width: width),
                      Logic(name: 'Y', width: width),
                      RadixEncoder(radix),
                      signedMultiplicand: signMultiplicand,
                      signedMultiplier: signMultiplier,
                      selectSignedMultiplicand:
                          selectMultiplicand ? selectSignMultiplicand : null,
                      selectSignedMultiplier:
                          selectMultiplier ? selectSignMultiplier : null,
                    );
                    currySignExtensionFunction(signExtension)(pp).signExtend();
                    return pp;
                  },
                );
              }
            }
          }
        }
      }
    }
  });

  group('PartialProduct: singleton fixed/select sign variants', () {
    const radix = 4;
    const width = 4;

    for (final selectMultiplicand in [false, true]) {
      for (final selectMultiplier in [false, true]) {
        testPartialProductSingle(
          'singleton_select_R${radix}_W$width'
          '_SelD${selectMultiplicand ? 1 : 0}'
          '_SelM${selectMultiplier ? 1 : 0}',
          () {
            final selectSignMultiplicand = Logic();
            final selectSignMultiplier = Logic();
            final pp = PartialProductGenerator(
              Logic(name: 'X', width: width),
              Logic(name: 'Y', width: width),
              RadixEncoder(radix),
              signedMultiplicand: !selectMultiplicand,
              signedMultiplier: !selectMultiplier,
              selectSignedMultiplicand:
                  selectMultiplicand ? selectSignMultiplicand : null,
              selectSignedMultiplier:
                  selectMultiplier ? selectSignMultiplier : null,
            );
            CompactRectSignExtension(pp).signExtend();
            return pp;
          },
          BigInt.from(6),
          BigInt.from(-6),
        );
      }
    }
  });

  group('PartialProduct: width/radix/extension sweep', () {
    for (var radix = 2; radix < 16; radix *= 2) {
      final shift = log2Ceil(radix);
      for (var width = shift; width < min(5, 2 * shift); width++) {
        for (final signExtension
            in SignExtension.values.where((e) => e != SignExtension.none)) {
          testPartialProductExhaustive(
            'width_R${radix}_W${width}_${signExtension.name}',
            () {
              final pp = PartialProductGenerator(
                Logic(name: 'X', width: width),
                Logic(name: 'Y', width: width),
                RadixEncoder(radix),
              );
              currySignExtensionFunction(signExtension)(pp).signExtend();
              return pp;
            },
          );
        }
      }
    }
  });
  group('PartialProduct: rectangle/radix/extension sweep', () {
    for (var radix = 2; radix < 8; radix *= 2) {
      final shift = log2Ceil(radix);
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
              testPartialProductExhaustive(
                'rectangle_R${radix}_W${widthX}x$widthY'
                '_SD${signedMultiplicand ? 1 : 0}'
                '_SM${signedMultiplier ? 1 : 0}_${signExtension.name}',
                () {
                  final pp = PartialProductGenerator(
                    Logic(name: 'X', width: widthX),
                    Logic(name: 'Y', width: widthY),
                    RadixEncoder(radix),
                    signedMultiplicand: signedMultiplicand,
                    signedMultiplier: signedMultiplier,
                  );
                  currySignExtensionFunction(signExtension)(pp).signExtend();
                  return pp;
                },
              );
            }
          }
        }
      }
    }
  });

  group('PartialProduct: minimum width', () {
    for (var radix = 2; radix < 32; radix *= 2) {
      final shift = log2Ceil(radix);
      for (var width = shift; width < min(5, 2 * shift); width++) {
        for (final signExtension
            in SignExtension.values.where((e) => e != SignExtension.none)) {
          testPartialProductExhaustive(
            'minimum_R${radix}_W${width}_${signExtension.name}',
            () {
              final pp = PartialProductGenerator(
                Logic(name: 'X', width: width),
                Logic(name: 'Y', width: width),
                RadixEncoder(radix),
              );
              currySignExtensionFunction(signExtension)(pp).signExtend();
              return pp;
            },
          );
        }
      }
    }
  });

  group('PartialProduct: minimum rectangle', () {
    for (var radix = 2; radix < 32; radix *= 2) {
      final shift = log2Ceil(radix);
      // At high radices, the unsigned and signed extremes cover the
      // rectangular boundary without repeating the mixed-sign cases already
      // exhaustively covered at lower radices.
      final signCombinations = radix < 8
          ? [
              (multiplicand: false, multiplier: false),
              (multiplicand: false, multiplier: true),
              (multiplicand: true, multiplier: false),
              (multiplicand: true, multiplier: true),
            ]
          : [
              (multiplicand: false, multiplier: false),
              (multiplicand: true, multiplier: true),
            ];
      for (final signs in signCombinations) {
        final signedMultiplicand = signs.multiplicand;
        final widthX = shift;
        final signedMultiplier = signs.multiplier;
        final widthY = shift + (signedMultiplier ? 1 : 0);
        for (final signExtension in [
          SignExtension.brute,
          SignExtension.stopBits,
          SignExtension.compactRect
        ]) {
          testPartialProductExhaustive(
            'minimum_rectangle_R${radix}_W${widthX}x$widthY'
            '_SD${signedMultiplicand ? 1 : 0}'
            '_SM${signedMultiplier ? 1 : 0}_${signExtension.name}',
            () {
              final pp = PartialProductGenerator(
                Logic(name: 'X', width: widthX),
                Logic(name: 'Y', width: widthY),
                RadixEncoder(radix),
                signedMultiplicand: signedMultiplicand,
                signedMultiplier: signedMultiplier,
              );
              currySignExtensionFunction(signExtension)(pp).signExtend();
              return pp;
            },
          );
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
        final width = align.$2;

        final skew = align.$3;

        testPartialProductRandom(
          'q_collision_R${radix}_W${width}x${width + skew}',
          _randomIterations,
          () {
            final pp = PartialProductGenerator(
              Logic(name: 'X', width: width),
              Logic(name: 'Y', width: width + skew),
              RadixEncoder(radix),
            );
            CompactRectSignExtension(pp).signExtend();
            return pp;
          },
        );
      }
    }
  });

  test('PartialProduct: flat test', () {
    const radix = 4;
    final radixEncoder = RadixEncoder(radix);
    const widthX = 4;
    const widthY = 3;
    final limitX = pow(2, widthX);
    final limitY = pow(2, widthY);
    final multiplicand = Logic(width: widthX);
    final multiplier = Logic(width: widthY);
    for (final signed in [false, true]) {
      final ppg = PartialProductGenerator(
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

  test('PP Matrix: module test', () async {
    const radix = 4;
    final radixEncoder = RadixEncoder(radix);
    const widthX = 12;
    const widthY = 12;
    final multiplicand = Logic(width: widthX);
    final multiplier = Logic(width: widthY);

    final ppm = PartialProduct(multiplicand, multiplier, radixEncoder);

    final ppmWithOutputs = ppm
      ..generateOutputs(
        beforeGenerateOutputs: (array) =>
            CompactSignExtension(array).signExtend(),
      );
    final compress =
        ColumnCompressor(ppmWithOutputs.rows, ppmWithOutputs.rowShift);
    await ppmWithOutputs.build();
    await compress.build();

    File('ppg.sv').writeAsStringSync(ppmWithOutputs.dumpSystemVerilog());
    File('compress.sv').writeAsStringSync(compress.dumpSystemVerilog());
  });

  test('single MAC partial product test', () {
    final encoder = RadixEncoder(16);
    const widthX = 8;
    const widthY = 10;

    const i = 1478;
    const j = 9;
    const k = 0;

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
    final pp = PartialProductGenerator(logicX, logicY, encoder,
        signedMultiplicand: true, signedMultiplier: true);
    CompactRectSignExtension(pp).signExtend();

    final lastLength =
        pp.partialProducts[pp.rows - 1].length + pp.rowShift[pp.rows - 1];

    final sign = logicZ[logicZ.width - 1];
    // for unsigned versus signed testing
    // final sign = signed ? logicZ[logicZ.width - 1] : Const(0);
    final l = List.generate(logicZ.width, (i) => logicZ[i]);
    while (l.length < lastLength) {
      l.add(sign);
    }
    l
      ..add(~sign)
      ..add(Const(1));

    pp.partialProducts.insert(0, l);
    pp.rowShift.insert(0, 0);

    if (pp.evaluate() != product) {
      stdout.write('Fail: $X * $Y: ${pp.evaluate()} vs expected $product\n');
    }
    expect(pp.evaluate(), equals(product));
  });

  test('single MAC partial product sign extension test', () {
    final encoder = RadixEncoder(16);
    const widthX = 8;
    const widthY = 10;

    const i = 1478;
    const j = 9;
    const k = 0;

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
    final pp = PartialProductGenerator(logicX, logicY, encoder,
        signedMultiplicand: true, signedMultiplier: true);
    CompactRectSignExtension(pp).signExtend();

    final lastLength =
        pp.partialProducts[pp.rows - 1].length + pp.rowShift[pp.rows - 1];

    final sign = logicZ[logicZ.width - 1];
    // for unsigned versus signed testing
    // final sign = signed ? logicZ[logicZ.width - 1] : Const(0);
    final l = List.generate(logicZ.width, (i) => logicZ[i]);
    while (l.length < lastLength) {
      l.add(sign);
    }
    l
      ..add(~sign)
      ..add(Const(1));

    pp.partialProducts.insert(0, l);
    pp.rowShift.insert(0, 0);

    if (pp.evaluate() != product) {
      stdout.write('Fail: $X * $Y: ${pp.evaluate()} vs expected $product\n');
    }
    expect(pp.evaluate(), equals(product));
  });

  test('majority function', () {
    expect(LogicValue.ofBigInt(BigInt.from(7), 5).majority(), true);
    expect(LogicValue.ofBigInt(BigInt.from(7) << 1, 5).majority(), true);
    expect(LogicValue.ofBigInt(BigInt.from(11) << 1, 5).majority(), true);
    expect(LogicValue.ofBigInt(BigInt.from(9) << 1, 5).majority(), false);
    expect(LogicValue.ofBigInt(BigInt.from(7) << 3, 7).majority(), false);
  });
}
