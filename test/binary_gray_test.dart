// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_gray_test.dart
// Tests for binary to gray and gray to binary conversion.
//
// 2023 October 5
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Future<void> main() async {
  group('binary to gray code', () {
    test('should return 100 if binary is 111 and width is 3.', () async {
      final binaryInput = Logic(name: 'binaryInput', width: 3)..put(bin('111'));
      final binToGray = BinaryToGrayConverter(binaryInput);
      await binToGray.build();

      expect(binToGray.grayCode.value.toString(includeWidth: false), '100');
    });

    test('should return 0 if binary is 0 and width is 1.', () async {
      final binaryInput = Logic(name: 'binaryInput')..put(bin('0'));
      final binToGray = BinaryToGrayConverter(binaryInput);
      await binToGray.build();

      expect(binToGray.grayCode.value.toInt(), 0);
    });

    test('should return 1 if binary is 1 and width is 1.', () async {
      final binaryInput = Logic(name: 'binaryInput')..put(bin('1'));
      final binToGray = BinaryToGrayConverter(binaryInput);
      await binToGray.build();

      expect(binToGray.grayCode.value.toInt(), 1);
    });

    test('should return 111110 if binary is 101011 and width is 6.', () async {
      final binaryInput = Logic(name: 'binaryInput', width: 6)
        ..put(bin('101011'));
      final binToGray = BinaryToGrayConverter(binaryInput);
      await binToGray.build();

      expect(binToGray.grayCode.value.toString(includeWidth: false), '111110');
    });
  });

  group('gray code to binary', () {
    test('should return 101 if gray code is 111 and width is 3.', () async {
      final graycode = Logic(name: 'grayCode', width: 3)..put(bin('111'));
      final grayToBin = GrayToBinaryConverter(graycode);
      await grayToBin.build();

      expect(grayToBin.binaryVal.value.toString(includeWidth: false), '101');
    });

    test('should return 0 if gray code is 0 and width is 1.', () async {
      final grayCode = Logic(name: 'grayCode')..put(bin('0'));
      final grayToBin = GrayToBinaryConverter(grayCode);
      await grayToBin.build();

      expect(grayToBin.binaryVal.value.toInt(), 0);
    });

    test('should return 1 if gray code is 1 and width is 1.', () async {
      final grayCode = Logic(name: 'grayCode')..put(bin('1'));
      final grayToBin = GrayToBinaryConverter(grayCode);
      await grayToBin.build();

      expect(grayToBin.binaryVal.value.toInt(), 1);
    });

    test('should return 101011 if gray code is 111110 and width is 6.',
        () async {
      final grayCode = Logic(name: 'grayCode', width: 6)..put(bin('111110'));
      final grayToBin = GrayToBinaryConverter(grayCode);
      await grayToBin.build();

      expect(grayToBin.binaryVal.value.toString(includeWidth: false), '101011');
    });

    test(
        'sequential values should differ in just one bit in integer and bigInt'
        ' bit range.', () async {
      Future<void> checkBitDiff({required int width}) async {
        for (var i = 0; i < pow(2, width) - 1; i++) {
          final binaryInput1 = Logic(name: 'binaryInputSeq1', width: width)
            ..put(bin(i.toRadixString(2)));
          final binaryInput2 = Logic(name: 'binaryInputSeq2', width: width)
            ..put(bin((i + 1).toRadixString(2)));

          final binToGray1 = BinaryToGrayConverter(binaryInput1);
          final binToGray2 = BinaryToGrayConverter(binaryInput2);

          await binToGray1.build();
          await binToGray2.build();

          final gray1 = binToGray1.grayCode.value;
          final gray2 = binToGray2.grayCode.value;

          var diff = gray1 ^ gray2;

          var setBits = 0;
          while (diff.toInt() != 0) {
            setBits++;
            diff &= diff - 1;
          }

          expect(setBits, 1);
        }
      }

      await checkBitDiff(width: 64);
      await checkBitDiff(width: 100);
    });
  });
}
