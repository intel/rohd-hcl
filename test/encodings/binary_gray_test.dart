// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_gray_test.dart
// Tests for binary to gray and gray to binary conversion.
//
// 2023 October 5
// Author: Yao Jing Quek <yao.jing.quek@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

Future<void> main() async {
  group('binary to gray code', () {
    test('should return 100 if binary is 111 and width is 3.', () async {
      final binaryInput = Logic(name: 'binaryInput', width: 3)..put(bin('111'));
      final binToGray = BinaryToGrayConverter(binaryInput);
      await binToGray.build();

      expect(binToGray.gray.value.toString(includeWidth: false), '100');
    });

    test('should return 0 if binary is 0 and width is 1.', () async {
      final binaryInput = Logic(name: 'binaryInput')..put(bin('0'));
      final binToGray = BinaryToGrayConverter(binaryInput);
      await binToGray.build();

      expect(binToGray.gray.value.toInt(), 0);
    });

    test('should return 1 if binary is 1 and width is 1.', () async {
      final binaryInput = Logic(name: 'binaryInput')..put(bin('1'));
      final binToGray = BinaryToGrayConverter(binaryInput);
      await binToGray.build();

      expect(binToGray.gray.value.toInt(), 1);
    });

    test('should return 111110 if binary is 101011 and width is 6.', () async {
      final binaryInput = Logic(name: 'binaryInput', width: 6)
        ..put(bin('101011'));
      final binToGray = BinaryToGrayConverter(binaryInput);
      await binToGray.build();

      expect(binToGray.gray.value.toString(includeWidth: false), '111110');
    });
  });

  group('gray code to binary', () {
    test('should return 101 if gray code is 111 and width is 3.', () async {
      final graycode = Logic(name: 'grayCode', width: 3)..put(bin('111'));
      final grayToBin = GrayToBinaryConverter(graycode);
      await grayToBin.build();

      expect(grayToBin.binary.value.toString(includeWidth: false), '101');
    });

    test('should return 0 if gray code is 0 and width is 1.', () async {
      final grayCode = Logic(name: 'grayCode')..put(bin('0'));
      final grayToBin = GrayToBinaryConverter(grayCode);
      await grayToBin.build();

      expect(grayToBin.binary.value.toInt(), 0);
    });

    test('should return 1 if gray code is 1 and width is 1.', () async {
      final grayCode = Logic(name: 'grayCode')..put(bin('1'));
      final grayToBin = GrayToBinaryConverter(grayCode);
      await grayToBin.build();

      expect(grayToBin.binary.value.toInt(), 1);
    });

    test('should return 101011 if gray code is 111110 and width is 6.',
        () async {
      final grayCode = Logic(name: 'grayCode', width: 6)..put(bin('111110'));
      final grayToBin = GrayToBinaryConverter(grayCode);
      await grayToBin.build();

      expect(grayToBin.binary.value.toString(includeWidth: false), '101011');
    });

    test('sampled sequential values differ in one bit at large widths',
        () async {
      Future<void> checkBitDiff({required int width}) async {
        final binaryInput = Logic(name: 'binaryInputSeq', width: width);
        final grayInput = Logic(name: 'grayInputSeq', width: width);
        final binToGray = BinaryToGrayConverter(binaryInput);
        final grayToBin = GrayToBinaryConverter(grayInput);
        await binToGray.build();
        await grayToBin.build();

        final midpoint = BigInt.one << (width - 1);
        final maximum = (BigInt.one << width) - BigInt.one;
        final samples = <BigInt>{
          BigInt.zero,
          BigInt.one,
          BigInt.two,
          midpoint - BigInt.one,
          midpoint,
          maximum - BigInt.one,
        };

        for (final current in samples) {
          binaryInput.put(LogicValue.ofBigInt(current, width));
          final gray = binToGray.gray.value;
          grayInput.put(gray);
          expect(grayToBin.binary.value.toBigInt(), current);

          binaryInput.put(LogicValue.ofBigInt(current + BigInt.one, width));
          var difference = (gray ^ binToGray.gray.value).toBigInt();
          var setBits = 0;
          while (difference != BigInt.zero) {
            setBits++;
            difference &= difference - BigInt.one;
          }
          expect(setBits, 1);
        }

        expect(binToGray.generateSynth(), isNot(contains('case (')));
        expect(grayToBin.generateSynth(), isNot(contains('case (')));
      }

      await checkBitDiff(width: 64);
      await checkBitDiff(width: 100);
    });

    // Sweep every input at small widths and compare both hardware converters
    // with the software reference functions.
    test('linear converters match software reference exhaustively', () async {
      for (var width = 1; width <= 6; width++) {
        final binaryInput = Logic(name: 'binaryInput', width: width);
        final grayInput = Logic(name: 'grayInput', width: width);
        final binToGray = BinaryToGrayConverter(binaryInput);
        final grayToBin = GrayToBinaryConverter(grayInput);
        await binToGray.build();
        await grayToBin.build();

        for (var i = 0; i < (1 << width); i++) {
          final value = LogicValue.ofInt(i, width);
          binaryInput.put(value);
          grayInput.put(value);
          expect(binToGray.gray.value.toInt(),
              BinaryToGrayConverter.binaryToGray(value).toInt(),
              reason: 'binaryToGray width=$width value=$i');
          expect(grayToBin.binary.value.toInt(),
              GrayToBinaryConverter.grayToBinary(value).toInt(),
              reason: 'grayToBinary width=$width value=$i');
        }
      }
    });
  });
}
