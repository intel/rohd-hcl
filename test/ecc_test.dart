// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ecc_test.dart
// Tests for error correcting code hardware generators.
//
// 2024 January 18
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/error_checking/ecc.dart';
import 'package:test/test.dart';

void main() {
  for (final hammingType in HammingType.values) {
    test('$hammingType tx to rx', () async {
      final rand = Random(123);

      final canCorrectSingleBit = hammingType.hasCorrection;
      final canDetectDoubleBit = hammingType != HammingType.sec;
      final canDetectTripleBit = hammingType == HammingType.seddedted;

      for (var dataWidth = 1; dataWidth < 20; dataWidth++) {
        final inputData = Logic(width: dataWidth)
          ..put(rand.nextLogicValue(width: dataWidth));

        final tx = HammingEccTransmitter(inputData, hammingType: hammingType);
        final sentTransmission = tx.transmission;

        final errorInjectionVector = Logic(width: sentTransmission.width);
        final receivedTransmission = sentTransmission ^ errorInjectionVector;

        final rx =
            HammingEccReceiver(receivedTransmission, hammingType: hammingType);

        await rx.build();

        // test no error
        errorInjectionVector.put(0);
        expect(rx.uncorrectableError.value.toBool(), isFalse);
        expect(rx.correctableError.value.toBool(), isFalse);
        expect(rx.correctedData?.value,
            canCorrectSingleBit ? inputData.value : null);
        expect(rx.originalData.value, inputData.value);

        // test every 1-bit flip
        for (var i = 0; i < sentTransmission.width; i++) {
          inputData.put(rand.nextLogicValue(width: dataWidth));
          errorInjectionVector.put(BigInt.one << i);

          expect(rx.uncorrectableError.value.toBool(), !canCorrectSingleBit);
          expect(rx.correctableError.value.toBool(), canCorrectSingleBit);
          expect(rx.correctedData?.value,
              canCorrectSingleBit ? inputData.value : null);
          expect(rx.originalData.value,
              receivedTransmission.value.getRange(0, inputData.width));
        }

        if (canDetectDoubleBit) {
          // test every 2-bit flip
          for (var i = 0; i < sentTransmission.width; i++) {
            for (var j = i + 1; j < sentTransmission.width; j++) {
              inputData.put(rand.nextLogicValue(width: dataWidth));
              errorInjectionVector.put((BigInt.one << i) | (BigInt.one << j));

              expect(rx.uncorrectableError.value.toBool(), isTrue);
              expect(rx.correctableError.value.toBool(), isFalse);
              // don't care what corrected data is...
              expect(rx.originalData.value,
                  receivedTransmission.value.getRange(0, inputData.width));
            }
          }
        }

        if (canDetectTripleBit) {
          // test every 3-bit flip
          for (var i = 0; i < sentTransmission.width; i++) {
            for (var j = i + 1; j < sentTransmission.width; j++) {
              for (var k = j + 1; k < sentTransmission.width; k++) {
                inputData.put(rand.nextLogicValue(width: dataWidth));
                errorInjectionVector.put(
                    (BigInt.one << i) | (BigInt.one << j) | (BigInt.one << k));

                expect(rx.uncorrectableError.value.toBool(), isTrue);
                expect(rx.correctableError.value.toBool(), isFalse);
                // don't care what corrected data is...
                expect(rx.originalData.value,
                    receivedTransmission.value.getRange(0, inputData.width));
              }
            }
          }
        }
      }
    });
  }

  test('Hamming(7,4)', () async {
    final tx = HammingEccTransmitter(Logic(width: 4));
    final rx = HammingEccReceiver(tx.transmission);
    expect(tx.transmission.width, 7);
    expect(rx.code.width, 3);
  });
}
