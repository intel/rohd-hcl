// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// one_hot_test.dart
// Test of one_hot codec.
//
// 2023 February 24
// Author: Desmond Kirkpatrick

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class _OneHotExtensions extends Module {
  _OneHotExtensions(int width) {
    final onehot = addInput('onehot', Logic(width: width), width: width);
    final binary = addInput('binary', Logic(width: 3), width: 3);
    final decoded = onehot.oneHotToBinary();
    addOutput('decoded', width: decoded.width) <= decoded;
    addOutput('encoded', width: 8) <= binary.binaryToOneHot();
  }
}

void main() {
  group('conversion extensions', () {
    tearDown(() async {
      await Simulator.reset();
    });

    test('valid conversions and output widths', () {
      for (final width in [1, 2, 3, 5]) {
        final binary = Logic(width: width);
        final encoded = binary.binaryToOneHot();
        for (var index = 0; index < 1 << width; index++) {
          final value = LogicValue.ofInt(index, width);
          final expected = LogicValue.ofBigInt(BigInt.one << index, 1 << width);
          binary.put(value);
          expect(encoded.value, expected);
          expect(value.binaryToOneHot(), expected);
          expect(encoded.oneHotToBinary().value,
              LogicValue.ofInt(index, widthFor(1 << width)));
          expect(expected.oneHotToBinary(),
              LogicValue.ofInt(index, widthFor(1 << width)));
        }
      }
    });

    test('value and signal decoders agree for invalid and unknown inputs', () {
      for (final width in [1, 3, 8, 9, 13]) {
        final signal = Logic(width: width);
        final decoded = signal.oneHotToBinary();
        final values = [
          LogicValue.filled(width, LogicValue.zero),
          LogicValue.filled(width, LogicValue.one),
          LogicValue.filled(width, LogicValue.x),
          LogicValue.filled(width, LogicValue.z),
          if (width > 1) LogicValue.ofString('${'0' * (width - 2)}xz'),
        ];
        for (final value in values) {
          signal.put(value);
          expect(value.oneHotToBinary(), decoded.value,
              reason: 'width=$width value=$value');
        }
      }
    });

    test('value and signal encoders agree for unknown inputs', () {
      final signal = Logic(width: 3);
      final encoded = signal.binaryToOneHot();
      for (final input in ['x00', '0z1', 'xxx', 'zzz']) {
        final value = LogicValue.ofString(input);
        signal.put(value);
        expect(value.binaryToOneHot(), encoded.value, reason: input);
      }
    });

    test('value conversions work during simulation', () async {
      Simulator.registerAction(10, () {
        expect(LogicValue.ofInt(3, 3).binaryToOneHot(), LogicValue.ofInt(8, 8));
        expect(LogicValue.ofInt(8, 8).oneHotToBinary(), LogicValue.ofInt(3, 3));
        expect(
            LogicValue.ofInt(256, 9).oneHotToBinary(), LogicValue.ofInt(8, 4));
      });
      Simulator.setMaxSimTime(10);
      await Simulator.run();
    });

    for (final width in [4, 9]) {
      test('signal extensions synthesize for width $width', () async {
        final dut = _OneHotExtensions(width);
        await dut.build();
        final unknownOneHot = LogicValue.ofString('${'0' * (width - 2)}xz');
        final unknownBinary = LogicValue.ofString('0z1');
        final commonVectors = [
          Vector({'onehot': 1, 'binary': 0}, {'decoded': 0, 'encoded': 1}),
          Vector({'onehot': 4, 'binary': 3}, {'decoded': 2, 'encoded': 8}),
          Vector({'onehot': 0, 'binary': 7}, {'decoded': 0, 'encoded': 128}),
        ];
        final unknownInputs = {
          'onehot': unknownOneHot,
          'binary': unknownBinary,
        };
        final simulatedDecode = unknownOneHot.oneHotToBinary();
        final simulatedEncode = unknownBinary.binaryToOneHot();
        await SimCompare.checkFunctionalVector(dut, [
          ...commonVectors,
          Vector(unknownInputs,
              {'decoded': simulatedDecode, 'encoded': simulatedEncode}),
        ]);
        SimCompare.checkIverilogVector(dut, [
          ...commonVectors,
          Vector(unknownInputs, {
            // The case codec's RTL takes its default branch for this input.
            'decoded': width <= 8 ? 0 : simulatedDecode,
            'encoded': simulatedEncode,
          }),
        ]);
      });
    }
  });

  group('binary to one-hot', () {
    test('simple_encode', () {
      // Compute the binary value for a 1hot at position 'pos'
      for (var pos = 0; pos < 1000; pos++) {
        final w = (pos + 1).log2Ceil;
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
      test('simple_decode ${ohToBType.name}', () {
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
            if (i == 0 || !i.isPowerOfTwo) {
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
