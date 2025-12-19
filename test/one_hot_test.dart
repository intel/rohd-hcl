// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// one_hot_test.dart
// Test of one_hot codec.
//
// 2023 February 24
// Author: Desmond Kirkpatrick

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('binary to one-hot', () {
    test('simple_encode', () {
      // Compute the binary value for a 1hot at position 'pos'
      for (var pos = 0; pos < 1000; pos++) {
        final w = log2Ceil(pos + 1);
        final val = BigInt.two.pow(pos);

        expect(BinaryToOneHot(Const(pos, width: w)).encoded.value,
            equals(LogicValue.ofBigInt(val, pow(2, w).toInt())));
      }
    });
  });

  group('one-hot to binary', () {
    test('error on decode', () {
      final onehot = Logic(width: 8);
      final err = OneHotToBinary(onehot, generateError: true).error!;

      onehot.put(1);
      expect(err.value.toBool(), isFalse);

      onehot.put(0);
      expect(err.value.toBool(), isTrue);

      onehot.put(1 << 3);
      expect(err.value.toBool(), isFalse);

      onehot.put(3 << 2);
      expect(err.value.toBool(), isTrue);
    });

    test('tree error on decode', () {
      final onehot = Logic(width: 13);
      final bin = TreeOneHotToBinary(onehot, generateError: true);
      onehot.put(3);
      expect(bin.error!.value.toBool(), isTrue);

      onehot.put(0);
      expect(bin.error!.value.toBool(), isTrue);

      onehot.put(2);
      expect(bin.error!.value.toBool(), isFalse);
    });

    final ohToBTypes = [
      (name: 'case', constructor: CaseOneHotToBinary.new, max: 8),
      (name: 'tree', constructor: TreeOneHotToBinary.new, max: 100),
    ];

    for (final ohToBType in ohToBTypes) {
      test('simple_decode ${ohToBType.name}', () async {
        // Compute the first 1 in a binary value
        for (var pos = 0; pos < ohToBType.max; pos++) {
          final val = BigInt.two.pow(pos);
          final computed =
              ohToBType.constructor(Const(val, width: pos + 1)).binary;
          final expected = LogicValue.ofInt(pos, computed.width);
          expect(computed.value, equals(expected));
        }
      });

      test('error detection ${ohToBType.name}', () {
        for (final width in [7, 8, 9, 10]) {
          final onehot = Logic(width: width);
          final dut = ohToBType.constructor(onehot, generateError: true);

          for (var i = 0; i < 1 << width; i++) {
            onehot.put(i);
            if (i == 0 || !isPowerOfTwo(i)) {
              expect(dut.error!.value.toBool(), isTrue, reason: '$i');
            } else {
              expect(dut.error!.value.toBool(), isFalse, reason: '$i');
            }
          }
        }
      });
    }
  });
}
