import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  group('rotate generator', () {
    test('should return Ripple Carry Adder for component name', () {
      final rotate = RotateConfigurator();
      expect(rotate.name, 'Rotate');
    });

    test('should return true if config knob has correct data type', () {
      final rotate = RotateConfigurator();
      expect(rotate.knobs.values.toList()[0],
          isA<ChoiceConfigKnob<RotateDirection>>());
      expect(rotate.knobs.values.toList()[1], isA<IntConfigKnob>());
      expect(rotate.knobs.values.toList()[2], isA<IntConfigKnob>());
    });

    test('should return RotateRight module when generate() with default value',
        () async {
      final rotate = RotateConfigurator();
      expect(await rotate.generateSV(), contains('RotateRight'));
    });

    test('should return RotateLeft when invoke generate() with default value',
        () async {
      final rotate = RotateConfigurator();
      const oriWidth = 10;
      const rotateAmountWidth = 5;

      rotate.directionKnob.value = RotateDirection.left;
      rotate.originalWidthKnob.value = oriWidth;
      rotate.rotateWidthKnob.value = rotateAmountWidth;

      final sv = await rotate.generateSV();
      expect(sv, contains('RotateLeft'));
      expect(sv, contains('input logic [9:0] original'));
      expect(sv, contains('input logic [4:0] rotate_amount'));
    });
  });

  group('ripple carry adder', () {
    test('should return Ripple Carry Adder for component name', () {
      final multiplier = RippleCarryAdderConfigurator();
      expect(multiplier.name, 'Ripple Carry Adder');
    });

    test('should return single Int knobs to be configured', () {
      final multiplier = RippleCarryAdderConfigurator();
      for (final element in multiplier.knobs.values.toList()) {
        expect(element, isA<IntConfigKnob>());
      }
    });

    test('should return rtl code when invoke generate() with default value',
        () async {
      final multiplier = RippleCarryAdderConfigurator();
      expect(await multiplier.generateSV(), contains('RippleCarryAdder'));
    });

    test('should return true when compare lower width with default width',
        () async {
      final multiplierDefault = RippleCarryAdderConfigurator();

      final multiplierCustom = RippleCarryAdderConfigurator();
      multiplierCustom.knobs.values.toList()[0].value = 10;

      final multiplierDefaultRTL = await multiplierDefault.generateSV();
      final multiplierCustomRTL = await multiplierCustom.generateSV();

      expect(multiplierDefaultRTL.length > multiplierCustomRTL.length,
          equals(true));
    });
  });

  group('pipelined_integer_multiplier', () {
    test('should return Carry Save Multiplier for component name', () {
      final multiplier = PipelinedIntegerMultiplierConfigurator();
      expect(multiplier.name, 'Carry Save Multiplier');
    });

    test('should return both Int knobs to be configured', () {
      final multiplier = PipelinedIntegerMultiplierConfigurator();
      for (final element in multiplier.knobs.values.toList()) {
        expect(element, isA<IntConfigKnob>());
      }
    });

    test('should return rtl code when invoke generate() with default value',
        () async {
      final multiplier = PipelinedIntegerMultiplierConfigurator();
      expect(await multiplier.generateSV(), contains('CarrySaveMultiplier'));
    });

    test('should return rtl code when invoke generate() with custom value',
        () async {
      final multiplierDefault = PipelinedIntegerMultiplierConfigurator();
      final multiplierCustom = PipelinedIntegerMultiplierConfigurator();
      multiplierCustom.knobs.values.toList()[0].value = 2;

      final multiplierDefaultRTL = await multiplierDefault.generateSV();
      final multiplierCustomRTL = await multiplierCustom.generateSV();

      expect(multiplierDefaultRTL.length > multiplierCustomRTL.length,
          equals(true));
    });
  });

  group('sort generator.dart', () {
    test('should return Bitonic Sort for module name', () {
      final sortGenerator = BitonicSortConfigurator();
      expect(sortGenerator.name, 'Bitonic Sort');
    });

    test('should return 3 Knobs of correct type to be configured.', () {
      final sortGenerator = BitonicSortConfigurator();
      expect(sortGenerator.knobs.values.whereType<IntConfigKnob>().length, 2);
      expect(
          sortGenerator.knobs.values.whereType<ToggleConfigKnob>().length, 1);
    });

    test('should return sorted module component code in ascending.', () async {
      final bitonicSortGenerator = BitonicSortConfigurator();

      const lengthOfInput = 4;
      const logicWidth = 8;
      const sortDirection = true;

      bitonicSortGenerator.lengthOfListKnob.value = lengthOfInput;
      bitonicSortGenerator.logicWidthKnob.value = logicWidth;
      bitonicSortGenerator.isAscendingKnob.value = sortDirection;

      final sv = await bitonicSortGenerator.generateSV();

      expect(sv, contains('input logic [7:0]'));
      expect(sv, contains('BitonicSort_2'));
      expect(sv, contains('if((toSort1 > toSort3)) begin'));
    });

    test('should return sorted module component code in descending.', () async {
      final bitonicSortGenerator = BitonicSortConfigurator();

      const lengthOfInput = 4;
      const logicWidth = 8;
      const sortDirection = false;

      bitonicSortGenerator.lengthOfListKnob.value = lengthOfInput;
      bitonicSortGenerator.logicWidthKnob.value = logicWidth;
      bitonicSortGenerator.isAscendingKnob.value = sortDirection;

      final sv = await bitonicSortGenerator.generateSV();

      expect(sv, contains('input logic [7:0]'));
      expect(sv, contains('BitonicSort_2'));
      expect(sv, contains('if((toSort1 < toSort3)) begin'));
    });
  });
}
