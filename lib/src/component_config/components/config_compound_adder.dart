// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compound_adder.dart
// Configurator for a CompoundAdder.
//
// 2024 Cotober 1

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [CompoundAdder].
class CompoundAdderConfigurator extends Configurator {
  /// Map from Type to Function for Adder generator
  static Map<
      Type,
      Adder Function(Logic, Logic,
          {Logic? carryIn,
          Logic? subtractIn,
          String? name})> adderGeneratorMap = {
    Ripple: (a, b, {carryIn, subtractIn, name}) =>
        ParallelPrefixAdder(a, b, ppGen: Ripple.new, name: name!),
    Sklansky: (a, b, {carryIn, subtractIn, name}) =>
        ParallelPrefixAdder(a, b, ppGen: Sklansky.new, name: name!),
    KoggeStone: (a, b, {carryIn, subtractIn, name}) =>
        ParallelPrefixAdder(a, b, name: name!),
    BrentKung: (a, b, {carryIn, subtractIn, name}) =>
        ParallelPrefixAdder(a, b, ppGen: BrentKung.new, name: name!),
    NativeAdder: (a, b, {carryIn, subtractIn, name}) =>
        NativeAdder(a, b, carryIn: carryIn, name: name ?? '')
  };

  /// Controls the type of [Adder] used for internal adders.
  static final adderTypeKnob =
      ChoiceConfigKnob(adderGeneratorMap.keys.toList(), value: NativeAdder);

  /// Map from Type to Adder generator
  static Map<Type, CompoundAdder Function(Logic a, Logic b)> generatorMap = {
    TrivialCompoundAdder: TrivialCompoundAdder.new,
    CarrySelectCompoundAdder: (a, b, {Logic? carryIn}) =>
        CarrySelectCompoundAdder(
          a,
          b,
          carryIn: carryIn,
          adderGen: adderGeneratorMap[adderTypeKnob.value]!,
        )
  };

  /// A knob controlling the width of the inputs to the adder.
  final IntConfigKnob logicWidthKnob = IntConfigKnob(value: 16);

  /// Controls the type of [CompoundAdder].
  final moduleTypeKnob = ChoiceConfigKnob(generatorMap.keys.toList(),
      value: CarrySelectCompoundAdder);
  @override
  final String name = 'Compound Adder';

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': logicWidthKnob,
    'Compound Adder Type': moduleTypeKnob,
    'Internal Adder Type': adderTypeKnob,
  });

  @override
  Module createModule() => generatorMap[moduleTypeKnob.value]!(
        Logic(width: logicWidthKnob.value),
        Logic(width: logicWidthKnob.value),
      );
}
