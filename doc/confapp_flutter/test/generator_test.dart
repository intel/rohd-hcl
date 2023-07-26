import 'package:confapp_flutter/components/components.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';
import 'package:confapp_flutter/components/config.dart';

void main() {
  group('pipelined_integer_multiplier', () {
    test('should return Carry Save Multiplier when access componentName', () {
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

  group('ripple carry adder', () {
    test('should return Ripple Carry Adder when access componentName', () {
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
}
