// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point stuff
//
// 2024 September 20
// Authors:
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com
//

import 'dart:math';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('FP: multiplication', () {
    test('exhaustive zero exponent', () {
      const radix = 4;

      final fp1 = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
      final fv1 = FloatingPointValue.ofBinaryStrings('0', '0110', '0000');
      final fp2 = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
      final fv2 = FloatingPointValue.ofBinaryStrings('0', '0110', '0000');
      fp1.put(fv1.value);
      fp2.put(fv2.value);
      final multiply = FloatingPointMultiplier(fp1, fp2, radix, KoggeStone.new);
      final fpOut = multiply.out;

      const widthX = 4;
      const widthY = 4;
      // return;
      final limitX = pow(2, widthX);
      final limitY = pow(2, widthY);
      for (var j = 0; j < limitY; j++) {
        for (var i = 0; i < limitX; i++) {
          final X = BigInt.from(i).toUnsigned(widthX);
          final Y = BigInt.from(j).toUnsigned(widthY);
          final strX = X.toRadixString(2).padLeft(widthX, '0');
          final strY = Y.toRadixString(2).padLeft(widthY, '0');
          final fv1 = FloatingPointValue.ofBinaryStrings('0', '0111', strX);
          final fv2 = FloatingPointValue.ofBinaryStrings('0', '0111', strY);

          final doubleProduct = fv1.toDouble() * fv2.toDouble();
          final partway = FloatingPointValue.fromDoubleIter(doubleProduct,
              exponentWidth: widthX, mantissaWidth: widthY);
          final roundTrip = partway.toDouble();

          fp1.put(fv1.value);
          fp2.put(fv2.value);
          expect(fpOut.floatingPointValue.toDouble(), equals(roundTrip));
        }
      }
    });

    // TODO(desmonddak): This is a failing case for overflow we need
    // to generalize and handle all cases
    // uncomment the fv1 below to expose the failure
    test('FP: single multiply example', () {
      const radix = 4;

      const expWidth = 4;
      const mantWidth = 4;
      final fp1 =
          FloatingPoint(exponentWidth: expWidth, mantissaWidth: mantWidth);
      // final fv1 = FloatingPointValue.ofStrings('0', '1111', '1111');
      final fv1 = FloatingPointValue.ofBinaryStrings('0', '1110', '1111');
      final fp2 = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
      final fv2 = FloatingPointValue.ofBinaryStrings('0', '0111', '0001');
      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final multiply = FloatingPointMultiplier(fp1, fp2, radix, KoggeStone.new);
      final fpOut = multiply.out;

      final doubleProduct = fv1.toDouble() * fv2.toDouble();
      final partWay = FloatingPointValue.fromDouble(doubleProduct,
          exponentWidth: 4, mantissaWidth: 4);
      final roundTrip = partWay.toDouble();

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      expect(fpOut.floatingPointValue.isNaN(), equals(roundTrip.isNaN));
    });

// fails on i, j, k = 1, 0, 1
    test('FP multiply normals', () {
      const radix = 4;

      const expWidth = 4;
      const mantWidth = 4;
      final fp1 =
          FloatingPoint(exponentWidth: expWidth, mantissaWidth: mantWidth);
      final fv1 = FloatingPointValue.ofBinaryStrings('0', '0110', '0000');
      final fp2 = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
      final fv2 = FloatingPointValue.ofBinaryStrings('0', '0110', '0000');
      fp1.put(fv1.value);
      fp2.put(fv2.value);

      const widthX = mantWidth;
      const widthY = mantWidth;
      final expLimit = pow(2, expWidth);
      final limitX = pow(2, widthX);
      final limitY = pow(2, widthY);
      // TODO(desmonddak): Push to the exponent limit: implement
      //   Infinity and NaN properly in both floating_point_value
      //   and the operations
      final multiply = FloatingPointMultiplier(fp1, fp2, radix, KoggeStone.new);
      for (var k = 1; k < expLimit - 1; k++) {
        // stdout.write('k=$k\n');
        for (var j = 0; j < limitY; j++) {
          for (var i = 0; i < limitX; i++) {
            final E = BigInt.from(k).toUnsigned(expWidth);
            final X = BigInt.from(i).toUnsigned(widthX);
            final Y = BigInt.from(j).toUnsigned(widthY);
            final expStr = E.toRadixString(2).padLeft(expWidth, '0');
            // expStr = '0110';  this will pass, but all else fails
            final strX = X.toRadixString(2).padLeft(widthX, '0');
            final strY = Y.toRadixString(2).padLeft(widthY, '0');
            final fv1 = FloatingPointValue.ofBinaryStrings('0', expStr, strX);
            // This will force it to be normal
            final fv2 = FloatingPointValue.ofBinaryStrings('0', '0111', strY);

            final fpOut = multiply.out;
            final doubleProduct = fv1.toDouble() * fv2.toDouble();
            final roundTrip = FloatingPointValue.fromDoubleIter(doubleProduct,
                    exponentWidth: 4, mantissaWidth: 4)
                .toDouble();

            fp1.put(fv1.value);
            fp2.put(fv2.value);

            if (!(fpOut.floatingPointValue.isNaN() | roundTrip.isNaN)) {
              expect(fpOut.floatingPointValue.toDouble(), equals(roundTrip));
            }
          }
        }
      }
    });
  });
}
