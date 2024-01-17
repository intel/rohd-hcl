import 'dart:io';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/error_checking/ecc.dart';
import 'package:test/test.dart';

void main() {
  test('hamming ecc SEC tx to rx single bit error correction', () async {
    final rand = Random(123);
    for (var dataWidth = 1; dataWidth < 50; dataWidth++) {
      final inputData = Logic(width: dataWidth)
        ..put(rand.nextLogicValue(width: dataWidth));

      final tx = HammingEccTransmitter(inputData);
      final sentTransmission = tx.transmission;

      final errorInjectionVector = Logic(width: sentTransmission.width);
      final receivedTransmission = sentTransmission ^ errorInjectionVector;

      final rx = HammingEccReceiver(receivedTransmission);

      await rx.build();
      // File('tmp.sv').writeAsStringSync(rx.generateSynth()); //TODO

      // test no error
      errorInjectionVector.put(0);
      expect(rx.uncorrectableError.value.toBool(), isFalse);
      expect(rx.correctableError.value.toBool(), isFalse);
      expect(rx.correctedData.value, inputData.value);
      expect(rx.originalData.value, inputData.value);

      // test every bit flip
      for (var i = 0; i < sentTransmission.width; i++) {
        inputData.put(rand.nextLogicValue(width: dataWidth));
        errorInjectionVector.put(BigInt.one << i);
        expect(rx.uncorrectableError.value.toBool(), isFalse);
        expect(rx.correctableError.value.toBool(), isTrue);
        expect(rx.correctedData.value, inputData.value);
        expect(rx.originalData.value,
            receivedTransmission.value.getRange(0, inputData.width));
      }
    }
  });

  // test('ecc tx', () async {
  //   final mod = HammingEccTransmitter(Logic(width: 15));
  //   await mod.build();

  //   print(mod.generateSynth());
  // });

  // test('ecc rx', () async {
  //   final mod = HammingEccReceiver(Logic(width: 20));
  //   await mod.build();
  //   print(mod.generateSynth());
  //   File('tmp.sv').writeAsStringSync(mod.generateSynth());
  // });
}
