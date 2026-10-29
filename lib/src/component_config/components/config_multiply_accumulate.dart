// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_multiply_accumulate.dart
// Configurator for compression-tree multiply-accumulate units.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [CompressionTreeMultiplyAccumulate].
class MultiplyAccumulateConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'multiply-accumulate';

  /// Width of multiplicand A.
  final IntConfigKnob multiplicandWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of multiplier B.
  final IntConfigKnob multiplierWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of addend C.
  final IntConfigKnob addendWidthKnob = PositiveIntConfigKnob(value: 17);

  /// Optional output width.
  final IntOptionalConfigKnob outputWidthKnob =
      IntOptionalConfigKnob(value: null);

  /// Booth radix used by the compression tree.
  final ChoiceConfigKnob<int> radixKnob = ChoiceConfigKnob(
    [2, 4, 8, 16],
    value: 4,
  );

  /// Whether to generate pipeline clock, reset, and enable inputs.
  final ToggleConfigKnob pipelinedKnob = ToggleConfigKnob(value: false);

  /// Multiplicand signedness selection.
  final StaticOrRuntimeBoolKnob signedMultiplicandKnob =
      StaticOrRuntimeBoolKnob();

  /// Multiplier signedness selection.
  final StaticOrRuntimeBoolKnob signedMultiplierKnob =
      StaticOrRuntimeBoolKnob();

  /// Addend signedness selection.
  final StaticOrRuntimeBoolKnob signedAddendKnob = StaticOrRuntimeBoolKnob();

  /// Adder implementation used after compression.
  final AdderSelectKnob adderSelectKnob = AdderSelectKnob();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Multiplicand Width': multiplicandWidthKnob,
    'Multiplier Width': multiplierWidthKnob,
    'Addend Width': addendWidthKnob,
    'Output Width': outputWidthKnob,
    'Radix': radixKnob,
    'Pipelined': pipelinedKnob,
    'Multiplicand Signedness': signedMultiplicandKnob,
    'Multiplier Signedness': signedMultiplierKnob,
    'Addend Signedness': signedAddendKnob,
    'Final Adder': adderSelectKnob,
  });

  @override
  Module createModule() => CompressionTreeMultiplyAccumulate(
        Logic(width: multiplicandWidthKnob.value),
        Logic(width: multiplierWidthKnob.value),
        Logic(width: addendWidthKnob.value),
        radix: radixKnob.value,
        clk: pipelinedKnob.value ? Logic() : null,
        reset: pipelinedKnob.value ? Logic() : null,
        enable: pipelinedKnob.value ? Logic() : null,
        signedMultiplicand:
            signedMultiplicandKnob.resolve('signedMultiplicand'),
        signedMultiplier: signedMultiplierKnob.resolve('signedMultiplier'),
        signedAddend: signedAddendKnob.resolve('signedAddend'),
        outputWidth: outputWidthKnob.value,
        adderGen: (a, b, {carryIn}) => adderSelectKnob.selectedAdder()(a, b,
            carryIn: carryIn, name: 'mac_add'),
      );

  @override
  String get name => 'Compression Tree Multiply-Accumulate';
}
