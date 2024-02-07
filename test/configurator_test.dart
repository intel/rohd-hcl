// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// configurator_test.dart
// Tests for configurators.
//
// 2023 December 6

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import '../confapp/test/example_component.dart';

void main() {
  test('to and from json', () {
    final cfg = ExampleConfigurator();
    cfg.knobs['a']!.value = 'banana';
    cfg.knobs['b']!.value = 42;
    cfg.knobs['c']!.value = false;
    cfg.knobs['d']!.value = ExampleEnum.yes;

    cfg.knobs['e']!.value = 5;
    for (final k in (cfg.knobs['e']! as ListOfKnobsKnob).knobs) {
      // ignore: avoid_dynamic_calls
      k.value += 10;
    }

    (cfg.knobs['f']! as GroupOfKnobs).subKnobs.forEach((key, value) {
      // ignore: avoid_dynamic_calls
      value.value += 'x';
    });

    final json = cfg.toJson(pretty: true);

    // print(json);

    final cfgLoaded = ExampleConfigurator()..loadJson(json);

    expect(cfgLoaded.knobs['a']!.value, 'banana');
    expect(cfgLoaded.knobs['b']!.value, 42);
    expect(cfgLoaded.knobs['c']!.value, false);
    expect(cfgLoaded.knobs['d']!.value, ExampleEnum.yes);

    expect((cfgLoaded.knobs['e']! as ListOfKnobsKnob).knobs[3].value, 13);

    expect((cfg.knobs['f']! as GroupOfKnobs).subKnobs['2']!.value, '2x');
  });

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
      final multiplier = CarrySaveMultiplierConfigurator();
      expect(multiplier.name, 'Carry Save Multiplier');
    });

    test('should return both Int knobs to be configured', () {
      final multiplier = CarrySaveMultiplierConfigurator();
      for (final element in multiplier.knobs.values.toList()) {
        expect(element, isA<IntConfigKnob>());
      }
    });

    test('should return rtl code when invoke generate() with default value',
        () async {
      final multiplier = CarrySaveMultiplierConfigurator();
      expect(await multiplier.generateSV(), contains('CarrySaveMultiplier'));
    });

    test('should return rtl code when invoke generate() with custom value',
        () async {
      final multiplierDefault = CarrySaveMultiplierConfigurator();
      final multiplierCustom = CarrySaveMultiplierConfigurator();
      multiplierCustom.knobs.values.toList()[0].value = 2;

      final multiplierDefaultRTL = await multiplierDefault.generateSV();
      final multiplierCustomRTL = await multiplierCustom.generateSV();

      expect(multiplierDefaultRTL.length > multiplierCustomRTL.length,
          equals(true));
    });
  });

  group('fifo configurator', () {
    test('should generate FIFO', () async {
      final cfg = FifoConfigurator()
        ..dataWidthKnob.value = 6
        ..depthKnob.value = 7
        ..generateBypassKnob.value = true
        ..generateErrorKnob.value = true
        ..generateOccupancyKnob.value = true;

      final sv = await cfg.generateSV();

      expect(sv, contains('bypass'));
      expect(sv, contains('occupancy'));
      expect(sv, contains('error'));
      expect(sv, contains('input logic [5:0] writeData'));
      expect(sv, contains("(wrPointer == 3'h6"));
    });
  });

  group('one-hot configurator', () {
    test('one-hot to binary', () async {
      final cfg = OneHotConfigurator()
        ..directionKnob.value = OneHotToBinary
        ..generateErrorKnob.value = true;

      final sv = await cfg.generateSV();

      expect(sv, contains('OneHotToBinary'));
      expect(sv, contains('error'));
    });

    test('binary to one-hot', () async {
      final cfg = OneHotConfigurator()..directionKnob.value = BinaryToOneHot;

      final sv = await cfg.generateSV();

      expect(sv, contains('BinaryToOneHot'));
    });
  });

  group('rf configurator', () {
    test('should generate rf', () async {
      final cfg = RegisterFileConfigurator()..maskedWritesKnob.value = true;

      final sv = await cfg.generateSV();

      expect(sv, contains('wr_mask_0'));
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

  test('hamming ecc configurator', () async {
    final cfg = EccConfigurator();
    cfg.typeKnob.value = HammingType.secded;
    cfg.dataWidthKnob.value = 11;
    final sv = await cfg.generateSV();
    expect(sv, contains('input logic [15:0] transmission'));
  });

  test('find configurator', () async {
    final cfg = FindConfigurator();
    cfg.includeNKnob.value = true;
    cfg.generateErrorKnob.value = true;
    final sv = await cfg.generateSV();
    expect(sv, contains('module Find'));
  });
}
