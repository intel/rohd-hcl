// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_floating_point_adder_simple.dart
// Configurator for a simple Floating-Point adder.
//
// 2025 January 9
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FloatingPointAdderSimple]s.
class FloatingPointAdderSimpleConfigurator extends Configurator {
  /// Map from Type to Function for Adder generator
  static Map<Type, Adder Function(Logic, Logic, {Logic? carryIn})>
      adderGeneratorMap = {
    Ripple: (a, b, {carryIn}) => ParallelPrefixAdder(a, b, ppGen: Ripple.new),
    Sklansky: (a, b, {carryIn}) =>
        ParallelPrefixAdder(a, b, ppGen: Sklansky.new),
    KoggeStone: ParallelPrefixAdder.new,
    BrentKung: (a, b, {carryIn}) =>
        ParallelPrefixAdder(a, b, ppGen: BrentKung.new),
    NativeAdder: (a, b, {carryIn}) => NativeAdder(a, b, carryIn: carryIn)
  };

  /// Map from Type to Function for Parallel Prefix generator
  static Map<
          Type,
          ParallelPrefix Function(
              List<Logic> inps, Logic Function(Logic term1, Logic term2) op)>
      treeGeneratorMap = {
    Ripple: Ripple.new,
    Sklansky: Sklansky.new,
    KoggeStone: KoggeStone.new,
    BrentKung: BrentKung.new
  };

  /// Controls the type of [Adder] used for internal adders.
  final adderTypeKnob =
      ChoiceConfigKnob(adderGeneratorMap.keys.toList(), value: NativeAdder);

  /// Controls the type of [ParallelPrefix] tree used in the other functions.
  final prefixTreeKnob =
      ChoiceConfigKnob(treeGeneratorMap.keys.toList(), value: KoggeStone);

  /// Controls the width of the exponent.
  final IntConfigKnob exponentWidthKnob = IntConfigKnob(value: 4);

  /// Controls the width of the mantissa.
  final IntConfigKnob mantissaWidthKnob = IntConfigKnob(value: 5);

  /// Controls whether the adder is pipelined
  final ToggleConfigKnob pipelinedKnob = ToggleConfigKnob(value: false);

  @override
  Module createModule() => FloatingPointAdderSimple(
      clk: pipelinedKnob.value ? Logic() : null,
      FloatingPoint(
        exponentWidth: exponentWidthKnob.value,
        mantissaWidth: mantissaWidthKnob.value,
      ),
      FloatingPoint(
          exponentWidth: exponentWidthKnob.value,
          mantissaWidth: mantissaWidthKnob.value),
      adderGen: adderGeneratorMap[adderTypeKnob.value]!);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Prefix tree type': prefixTreeKnob,
    'Adder tree type': adderTypeKnob,
    'Exponent width': exponentWidthKnob,
    'Mantissa width': mantissaWidthKnob,
    'Pipelined': pipelinedKnob,
  });

  @override
  final String name = 'Floating-Point Simple Adder';
}
