// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_mux.dart
// Configurator for multiplexer implementations.
//
// 2026 November 4
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Selection behavior for a configurable multiplexer.
enum MuxImplementation {
  /// Select each bit independently with a vector per input.
  bitwise,

  /// OR the words selected by the selector bits.
  oneHot,

  /// Select the lowest asserted selector bit or a default.
  priority,
}

/// Configures bitwise, one-hot, and priority multiplexers.
class MuxConfigurator extends Configurator {
  /// Multiplexer implementation.
  final ChoiceConfigKnob<MuxImplementation> implementationKnob =
      ChoiceConfigKnob(
    MuxImplementation.values,
    value: MuxImplementation.oneHot,
    choiceLabels: const {
      MuxImplementation.bitwise: 'Bitwise',
      MuxImplementation.oneHot: 'One-hot',
      MuxImplementation.priority: 'Priority',
    },
  );

  /// Width of each data word.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  /// Number of data inputs.
  final IntConfigKnob inputCountKnob = PositiveIntConfigKnob(value: 2);

  @override
  ComponentCategory get category => ComponentCategory.bitOperations;
  @override
  String get subcategory => 'selection';
  @override
  String get name => 'Multiplexer';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Implementation': implementationKnob,
        'Width': widthKnob,
        'Input Count': inputCountKnob,
      };
  @override
  Module createModule() {
    final inputs = List.generate(
      inputCountKnob.value,
      (i) => Logic(name: 'data$i', width: widthKnob.value),
    );
    return switch (implementationKnob.value) {
      MuxImplementation.bitwise => BitwiseMux(
          List.generate(inputCountKnob.value,
              (i) => Logic(name: 'select$i', width: widthKnob.value)),
          inputs,
        ),
      MuxImplementation.oneHot =>
        OneHotMux(Logic(name: 'selector', width: inputCountKnob.value), inputs),
      MuxImplementation.priority => PriorityMux(
          Logic(name: 'selector', width: inputCountKnob.value),
          inputs,
          Logic(name: 'defaultValue', width: widthKnob.value),
        ),
    };
  }
}
