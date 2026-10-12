// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_adders.dart
// Configurators for documented adder implementations.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [OnesComplementAdder].
class OnesComplementAdderConfigurator extends Configurator {
  /// Width of each magnitude input.
  final IntConfigKnob widthKnob = IntConfigKnob(value: 8);

  /// Static or runtime subtraction configuration.
  final StaticOrRuntimeBoolKnob subtractKnob = StaticOrRuntimeBoolKnob();

  /// Whether to expose the end-around carry output.
  final ToggleConfigKnob generateEndAroundCarryKnob =
      ToggleConfigKnob(value: false);

  /// Adder implementation used internally.
  final AdderSelectKnob adderSelectKnob = AdderSelectKnob();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': widthKnob,
    'Subtract': subtractKnob,
    'Generate End-Around Carry': generateEndAroundCarryKnob,
    'Internal Adder': adderSelectKnob,
  });

  @override
  Module createModule() => OnesComplementAdder(
        Logic(width: widthKnob.value),
        Logic(width: widthKnob.value),
        subtract: subtractKnob.resolve('subtract'),
        generateEndAroundCarry: generateEndAroundCarryKnob.value,
        adderGen: (a, b, {carryIn}) => adderSelectKnob.selectedAdder()(a, b,
            carryIn: carryIn, name: 'ones_add'),
      );

  @override
  String get name => 'Ones Complement Adder';
}

/// Available sign-magnitude adder implementations.
enum SignMagnitudeAdderImplementation {
  /// Use one ones-complement adder and optional magnitude comparison.
  single,

  /// Use two ones-complement adders to calculate the result directly.
  dual,
}

/// A [Configurator] for sign-magnitude adders.
class SignMagnitudeAdderConfigurator extends Configurator {
  /// Width of each magnitude input.
  final IntConfigKnob widthKnob = IntConfigKnob(value: 8);

  /// Sign-magnitude implementation to instantiate.
  final ChoiceConfigKnob<SignMagnitudeAdderImplementation> implementationKnob =
      ChoiceConfigKnob(
    SignMagnitudeAdderImplementation.values,
    value: SignMagnitudeAdderImplementation.single,
    choiceLabels: const {
      SignMagnitudeAdderImplementation.single: 'Single Adder',
      SignMagnitudeAdderImplementation.dual: 'Dual Adder',
    },
  );

  /// Whether the first magnitude is guaranteed to be larger.
  final ToggleConfigKnob largestMagnitudeFirstKnob =
      ToggleConfigKnob(value: false);

  /// Whether to expose the end-around carry output.
  final ToggleConfigKnob generateEndAroundCarryKnob =
      ToggleConfigKnob(value: false);

  /// Adder implementation used internally.
  final AdderSelectKnob adderSelectKnob = AdderSelectKnob();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': widthKnob,
    'Implementation': implementationKnob,
    if (implementationKnob.value == SignMagnitudeAdderImplementation.single)
      'Largest Magnitude First': largestMagnitudeFirstKnob,
    if (implementationKnob.value == SignMagnitudeAdderImplementation.single)
      'Generate End-Around Carry': generateEndAroundCarryKnob,
    'Internal Adder': adderSelectKnob,
  });

  @override
  Module createModule() {
    final aSign = Logic();
    final bSign = Logic();
    final a = Logic(width: widthKnob.value);
    final b = Logic(width: widthKnob.value);
    Adder adderGen(Logic lhs, Logic rhs, {Logic? carryIn}) => adderSelectKnob
        .selectedAdder()(lhs, rhs, carryIn: carryIn, name: 'sign_add');

    return implementationKnob.value == SignMagnitudeAdderImplementation.single
        ? SignMagnitudeAdder(
            aSign,
            a,
            bSign,
            b,
            largestMagnitudeFirst: largestMagnitudeFirstKnob.value,
            generateEndAroundCarry: generateEndAroundCarryKnob.value,
            adderGen: adderGen,
          )
        : SignMagnitudeDualAdder(aSign, a, bSign, b, adderGen: adderGen);
  }

  @override
  String get name => 'Sign Magnitude Adder';
}

/// A [Configurator] for [CarrySelectOnesComplementCompoundAdder].
class CarrySelectOnesComplementCompoundAdderConfigurator extends Configurator {
  /// Width of each addend.
  final IntConfigKnob widthKnob = IntConfigKnob(value: 8);

  /// Size of each carry-select block.
  final IntConfigKnob blockWidthKnob = IntConfigKnob(value: 4);

  /// Static or runtime subtraction configuration.
  final StaticOrRuntimeBoolKnob subtractKnob = StaticOrRuntimeBoolKnob();

  /// Whether to expose the end-around carry for the sum.
  final ToggleConfigKnob generateCarryOutKnob = ToggleConfigKnob(value: false);

  /// Whether to expose the end-around carry for sum plus one.
  final ToggleConfigKnob generateCarryOutP1Knob =
      ToggleConfigKnob(value: false);

  /// Adder implementation used in each carry-select block.
  final AdderSelectKnob adderSelectKnob = AdderSelectKnob();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': widthKnob,
    'Block Width': blockWidthKnob,
    'Subtract': subtractKnob,
    'Generate Carry Out': generateCarryOutKnob,
    'Generate Carry Out Plus One': generateCarryOutP1Knob,
    'Internal Adder': adderSelectKnob,
  });

  @override
  Module createModule() => CarrySelectOnesComplementCompoundAdder(
        Logic(width: widthKnob.value),
        Logic(width: widthKnob.value),
        subtract: subtractKnob.resolve('subtract'),
        generateCarryOut: generateCarryOutKnob.value,
        generateCarryOutP1: generateCarryOutP1Knob.value,
        widthGen: blockWidthKnob.value > 0
            ? CarrySelectCompoundAdder.splitSelectAdderAlgorithmNBit(
                blockWidthKnob.value)
            : CarrySelectCompoundAdder.splitSelectAdderAlgorithmSingleBlock,
        adderGen: (a, b, {carryIn}) => adderSelectKnob.selectedAdder()(a, b,
            carryIn: carryIn, name: 'compound_add'),
      );

  @override
  String get name => 'Carry-Select Ones Complement Compound Adder';
}
