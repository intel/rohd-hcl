// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// configurator_test.dart
// Tests for configurators.
//
// 2023 December 6

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';
import 'package:test/test.dart';

import '../confapp/test/example_component.dart';

/// A module that just wraps a hierarchy around a given module.
class Wrapper extends Module {
  Wrapper(Module m) {
    final mOut = m.outputs.values.first;
    addOutput('dummy', width: mOut.width) <= mOut;
  }
}

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
      multiplierCustom.knobs.values.toList()[0].value = 4;

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
      expect(multiplier.knobs.values.whereType<IntConfigKnob>().length, 1);
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

  group('multiplier', () {
    test('should return Compression Tree Multiplier for component name', () {
      final multiplier = MultiplierConfigurator();
      expect(multiplier.name, 'Multiplier');
      multiplier.createModule();
    });

    test(
        'should return correct rtl code when invoking generate() with '
        'different multiplier selections', () async {
      final cfg = MultiplierConfigurator();
      final svDefault = await cfg.generateSV();
      expect(svDefault, contains('Multiplier'));
      cfg.multiplierSelectKnob.compressionTreeMultiplierKnob.value = true;

      var sv = await cfg.generateSV();
      expect(sv, contains('compressor'));
      cfg.multiplierSelectKnob.adderSelectionKnob.parallelPrefixAdderKnob
          .value = true;
      sv = await cfg.generateSV();
      expect(sv, contains('ParallelPrefix'));
      cfg.multiplierSelectKnob.adderSelectionKnob.parallelPrefixTypeKnob.value =
          KoggeStone;
      sv = await cfg.generateSV();
      expect(sv, contains('kogge_stone'));
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

  group('fixed-point sqrt configurator', () {
    test('fixed-point sqrt', () async {
      final cfg = FixedPointSqrtConfigurator();

      final sv = await cfg.generateSV();

      expect(sv, contains('FixedPointSquareRoot'));
    });
  });

  group('floating-point sqrt configurator', () {
    test('floating-point sqrt', () async {
      final cfg = FloatingPointSqrtConfigurator();

      final sv = await cfg.generateSV();

      expect(sv, contains('FloatingPointSqrtSimple'));
    });
  });

  group('leading-digit-anticipate configurator', () {
    test('leading-digit-anticipate', () async {
      final cfg = LeadingDigitAnticipateConfigurator()
        ..anticipator.value = LeadingDigitAnticipate;

      final sv = await cfg.generateSV();

      expect(sv, contains('LeadingDigitAnticipate'));
    });

    test('leading-zero-anticipate', () async {
      final cfg = LeadingDigitAnticipateConfigurator()
        ..anticipator.value = LeadingZeroAnticipate;

      final sv = await cfg.generateSV();

      expect(sv, contains('LeadingZeroAnticipate'));
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
      expect(sv, contains('BitonicSort_W2'));
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
      expect(sv, contains('BitonicSort_W2'));
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

  test('cache configurator multi-port build', () async {
    final cfg = CacheConfigurator();

    // Configure two fill ports; number of read ports is derived from this
    // (each invalidate maps to a read port with an invalidate toggle).
    cfg.numFillPorts.value = 2;

    // Ensure the per-read-port knobs exist and set them differently
    cfg.readWithInvalidateKnobs.count = 2;
    // First read port: no invalidate
    (cfg.readWithInvalidateKnobs.knobs[0] as GroupOfKnobs)
        .subKnobs['Read with invalidate']!
        .value = false;
    // Second read port: invalidate on read
    (cfg.readWithInvalidateKnobs.knobs[1] as GroupOfKnobs)
        .subKnobs['Read with invalidate']!
        .value = true;

    final mod = cfg.createModule();

    // The created module must be a Cache subclass (Cache is abstract but
    // specific implementations are returned by the configurator). Check for
    // the expected number of read/fill ports by inspecting the module name
    // and/or casting to Cache where possible.
    expect(mod, isNotNull);

    // If the returned module is a Cache, check reads/fills lengths. Use
    // a defensive cast because not all implementations publicly expose the
    // lists; we check by name as fallback.
    // Confirm definitionName includes port counts (as configured by the
    // Cache constructor naming scheme). The test avoids accessing protected
    // members directly.
    final def = mod.definitionName;
    expect(def, contains('WP2'));
    expect(def, contains('RP2'));
  });

  test('prefix tree adder configurator', () async {
    final cfg = ParallelPrefixAdderConfigurator();

    final sv = await cfg.generateSV();
    expect(sv, contains('swizzle'));
  });

  test('compound adder configurator', () async {
    final cfg = CompoundAdderConfigurator();
    final svDefault = await cfg.generateSV();
    expect(svDefault, contains('swizzle'));

    cfg.adderSelectionKnob.parallelPrefixAdderKnob.value = true;
    final sv = await cfg.generateSV();
    expect(sv, contains('swizzle'));
  });

  test('floating point simple adder configurator', () async {
    final cfg = FloatingPointAdderConfigurator();

    final svDefault = await cfg.generateSV();
    expect(svDefault, contains('swizzle'));

    cfg.adderSelectionKnob.parallelPrefixAdderKnob.value = true;

    var sv = await cfg.generateSV();
    expect(sv, contains('swizzle'));

    cfg.adderSelectionKnob.parallelPrefixTypeKnob.value = Sklansky;
    sv = await cfg.generateSV();
    expect(sv, contains('swizzle'));

    cfg.pipelinedKnob.value = true;
    sv = await cfg.generateSV();
    expect(sv, contains('swizzle'));
  });

  test('floating point multiplier configurator', () async {
    final cfg = FloatingPointMultiplierSimpleConfigurator();
    cfg.multiplierSelectKnob.adderSelectionKnob.parallelPrefixAdderKnob.value =
        true;

    final sv = await cfg.generateSV();
    expect(sv, contains('swizzle'));
  });

  test('sum configurator', () async {
    final cfg = SumConfigurator();
    cfg.initialValueKnob.value = 6;
    cfg.widthKnob.value = 10;
    cfg.minValueKnob.value = 5;
    cfg.maxValueKnob.value = 25;
    cfg.saturatesKnob.value = true;

    final mod = cfg.createModule() as Sum;

    // ignore: invalid_use_of_protected_member
    expect(mod.initialValueLogic.value.toInt(), 6);
    expect(mod.width, 10);
    // ignore: invalid_use_of_protected_member
    expect(mod.minValueLogic.value.toInt(), 5);
    // ignore: invalid_use_of_protected_member
    expect(mod.maxValueLogic.value.toInt(), 25);
    expect(mod.saturates, true);
  });

  test('gated counter configurator', () async {
    final cfg = CounterConfigurator();
    cfg.clockGatingKnob.value = true;

    final mod = cfg.createModule() as GatedCounter;
    await mod.build();
  });

  test('serialization configurator', () async {
    final cfg = SerializationConfigurator();
    final svDefault = await cfg.generateSV();
    expect(svDefault, contains('Serializer'));

    cfg.directionKnob.value = Deserializer;
    final sv = await cfg.generateSV();
    expect(sv, contains('Deserializer'));
  });

  group('configurator builds', () {
    for (final componentConfigurator in componentRegistry) {
      test(componentConfigurator.name, () async {
        // generates verilog stand-alone
        await componentConfigurator.generateSV();

        // generates within a wrapping module (check for input/output rules)
        final mod = Wrapper(componentConfigurator.createModule());
        await mod.build();
        mod.generateSynth();
      });
    }
  });
}
