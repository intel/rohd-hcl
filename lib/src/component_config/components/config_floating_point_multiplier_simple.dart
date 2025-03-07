// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_floating_point_multiplier_simple.dart
// Configurator for a simple Floating-Point multiplier.
//
// 2025 January 6
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FloatingPointMultiplierSimple]s.
class FloatingPointMultiplierSimpleConfigurator extends Configurator {
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

  /// Map from Type to Function for Mantissa Multiplier
  static Map<
      Type,
      Multiplier Function(Logic term1, Logic term2,
          {Logic? clk,
          Logic? reset,
          Logic? enable,
          String name})> multGeneratorMap = {
    NativeMultiplier: NativeMultiplier.new,
    CompressionTreeMultiplier: (term1, term2,
            {Logic? clk, Logic? reset, Logic? enable, String? name}) =>
        CompressionTreeMultiplier(term1, term2, 4, name: name!)
    // TODO(desmonddak): put tree type, adder type, and radix options here
  };

  /// Controls the type of [Adder] used for internal adders.
  final adderTypeKnob =
      ChoiceConfigKnob(adderGeneratorMap.keys.toList(), value: NativeAdder);

  /// Controls the type of [Multiplier] used for mantissa multiplication.
  final multTypeKnob =
      ChoiceConfigKnob(multGeneratorMap.keys.toList(), value: NativeMultiplier);

  /// Controls the width of the exponent.
  final IntConfigKnob exponentWidthKnob = IntConfigKnob(value: 4);

  /// Controls the width of the mantissa.
  final IntConfigKnob mantissaWidthKnob = IntConfigKnob(value: 5);

  /// Controls whether the multiplier is pipelined
  final ToggleConfigKnob pipelinedKnob = ToggleConfigKnob(value: false);

  @override
  Module createModule() => FloatingPointMultiplierSimple(
      clk: pipelinedKnob.value ? Logic() : null,
      FloatingPoint(
        exponentWidth: exponentWidthKnob.value,
        mantissaWidth: mantissaWidthKnob.value,
      ),
      FloatingPoint(
          exponentWidth: exponentWidthKnob.value,
          mantissaWidth: mantissaWidthKnob.value),
      multGen: multGeneratorMap[multTypeKnob.value]!);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Exponent width': exponentWidthKnob,
    'Mantissa width': mantissaWidthKnob,
    'Pipelined': pipelinedKnob,
  });

  @override
  final String name = 'Floating-Point Simple Multiplier';
}
