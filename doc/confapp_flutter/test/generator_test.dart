import 'package:confapp_flutter/components/pipelined_integer_multiplier_generator.dart';
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
      expect(await multiplier.generate(), contains('RippleCarryAdder'));
    });
  });
}
