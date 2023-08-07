import 'package:confapp_flutter/components/components.dart';
import 'package:confapp_flutter/components/config.dart';
import 'package:test/test.dart';

void main() {
  group('rotate generator', () {
    test('should return Ripple Carry Adder for component name', () {
      final rotate = RotateGenerator();
      expect(rotate.componentName, 'Rotate');
    });

    test('should return true if config knob has correct data type', () {
      final rotate = RotateGenerator();
      expect(rotate.knobs[0], isA<IntConfigKnob>());
      expect(rotate.knobs[1], isA<IntConfigKnob>());
      expect(rotate.knobs[2], isA<StringConfigKnob>());
    });

    test(
        'should return RotateRight module when invoke generate() with default value',
        () async {
      final rotate = RotateGenerator();
      expect(await rotate.generate(), contains('RotateRight'));
    });

    test('should return RotateLeft when invoke generate() with default value',
        () async {
      final rotate = RotateGenerator();
      const oriWidth = 10;
      const rotateAmountWidth = 5;
      const rotateDir = 'left';

      rotate.knobs[0].value = oriWidth;
      rotate.knobs[1].value = rotateAmountWidth;
      rotate.knobs[2].value = rotateDir;

      final sv = await rotate.generate();
      expect(sv, contains('RotateLeft'));
      expect(sv, contains('input logic [9:0] original'));
      expect(sv, contains('input logic [4:0] rotate_amount'));
    });
  });

  group('ripple carry adder', () {
    test('should return Ripple Carry Adder for component name', () {
      final multiplier = RippleCarryAdderGenerator();
      expect(multiplier.componentName, 'Ripple Carry Adder');
    });

    test('should return single Int knobs to be configured', () {
      final multiplier = RippleCarryAdderGenerator();
      for (var element in multiplier.knobs) {
        expect(element, isA<IntConfigKnob>());
      }
    });

    test('should return rtl code when invoke generate() with default value',
        () async {
      final multiplier = RippleCarryAdderGenerator();
      expect(await multiplier.generate(), contains('RippleCarryAdder'));
    });

    test('should return true when compare lower width with default width',
        () async {
      final multiplierDefault = RippleCarryAdderGenerator();

      final multiplierCustom = RippleCarryAdderGenerator();
      multiplierCustom.knobs[0].value = 10;

      final multiplierDefaultRTL = await multiplierDefault.generate();
      final multiplierCustomRTL = await multiplierCustom.generate();

      expect(multiplierDefaultRTL.length > multiplierCustomRTL.length,
          equals(true));
    });
  });

  group('pipelined_integer_multiplier', () {
    test('should return Carry Save Multiplier for component name', () {
      final multiplier = PipelinedIntegerMultiplierGenerator();
      expect(multiplier.componentName, 'Carry Save Multiplier');
    });

    test('should return both Int knobs to be configured', () {
      final multiplier = PipelinedIntegerMultiplierGenerator();
      for (var element in multiplier.knobs) {
        expect(element, isA<IntConfigKnob>());
      }
    });

    test('should return rtl code when invoke generate() with default value',
        () async {
      final multiplier = PipelinedIntegerMultiplierGenerator();
      expect(await multiplier.generate(), contains('CarrySaveMultiplier'));
    });

    test('should return rtl code when invoke generate() with custom value',
        () async {
      final multiplierDefault = PipelinedIntegerMultiplierGenerator();
      final multiplierCustom = PipelinedIntegerMultiplierGenerator();
      multiplierCustom.knobs[0].value = 2;
      multiplierCustom.knobs[1].value = 10;

      final multiplierDefaultRTL = await multiplierDefault.generate();
      final multiplierCustomRTL = await multiplierCustom.generate();

      expect(multiplierDefaultRTL.length > multiplierCustomRTL.length,
          equals(true));
    });
  });

  group('sort generator.dart', () {
    test('should return Bitonic Sort for module name', () {
      final sortGenerator = BitonicSortGenerator();
      expect(sortGenerator.componentName, 'Bitonic Sort');
    });

    test('should return 3 int Knob to be configured.', () {
      final sortGenerator = BitonicSortGenerator();
      for (var element in sortGenerator.knobs) {
        expect(element, isA<IntConfigKnob>());
      }
    });

    test('should return sorted module component code in ascending.', () async {
      final bitonicSortGenerator = BitonicSortGenerator();

      const lengthOfInput = 4;
      const logicWidth = 8;
      const sortDirection = 1;

      bitonicSortGenerator.knobs[0].value = lengthOfInput;
      bitonicSortGenerator.knobs[1].value = logicWidth;
      bitonicSortGenerator.knobs[2].value = sortDirection;

      final sv = await bitonicSortGenerator.generate();

      expect(sv, contains('input logic [7:0]'));
      expect(sv, contains('BitonicSort_2'));
      expect(sv, contains('if((toSort1 > toSort3)) begin'));
    });

    test('should return sorted module component code in descending.', () async {
      final bitonicSortGenerator = BitonicSortGenerator();

      const lengthOfInput = 4;
      const logicWidth = 8;
      const sortDirection = 0;

      bitonicSortGenerator.knobs[0].value = lengthOfInput;
      bitonicSortGenerator.knobs[1].value = logicWidth;
      bitonicSortGenerator.knobs[2].value = sortDirection;

      final sv = await bitonicSortGenerator.generate();

      expect(sv, contains('input logic [7:0]'));
      expect(sv, contains('BitonicSort_2'));
      expect(sv, contains('if((toSort1 < toSort3)) begin'));
    });
  });
}
