// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_bitwise_popcount.dart
// Configurator for bitwise population counting.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Comparison used by the bitwise population counter.
enum BitwisePopcountOperation {
  /// Count unequal corresponding bits.
  xor,

  /// Count equal corresponding bits.
  xnor,
}

/// Configures a bitwise comparison and population count.
class BitwisePopcountConfigurator extends Configurator {
  /// Comparison operation.
  final ChoiceConfigKnob<BitwisePopcountOperation> operationKnob =
      ChoiceConfigKnob(
    BitwisePopcountOperation.values,
    value: BitwisePopcountOperation.xor,
    choiceLabels: const {
      BitwisePopcountOperation.xor: 'XOR',
      BitwisePopcountOperation.xnor: 'XNOR',
    },
  );

  /// Width of each input.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  /// Maximum operands per reduction node.
  final IntConfigKnob radixKnob = IntConfigKnob(value: 2, minValue: 2);

  @override
  ComponentCategory get category => ComponentCategory.bitOperations;
  @override
  String get subcategory => 'population-count';
  @override
  String get name => 'Bitwise Popcount';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Operation': operationKnob,
        'Width': widthKnob,
        'Radix': radixKnob,
      };
  @override
  Module createModule() {
    final a = Logic(name: 'a', width: widthKnob.value);
    final b = Logic(name: 'b', width: widthKnob.value);
    return switch (operationKnob.value) {
      BitwisePopcountOperation.xor => XorPopcount(a, b, radix: radixKnob.value),
      BitwisePopcountOperation.xnor =>
        XnorPopcount(a, b, radix: radixKnob.value),
    };
  }
}
