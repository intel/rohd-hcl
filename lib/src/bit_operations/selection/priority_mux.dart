// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// priority_mux.dart
// Module that selects the case for the least significant set selector bit.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Selects the case for the least significant bit set in `selector`.
///
/// Bit 0 of `selector` has the highest priority. When no bit is set,
/// `defaultValue` is produced.
class PriorityMux extends Module {
  /// The selected [result].
  Logic get result => output('result');

  /// Constructs a [PriorityMux] over [cases], where bit `i` of [selector]
  /// chooses `cases[i]` and [defaultValue] is used when [selector] is zero.
  PriorityMux(Logic selector, List<Logic> cases, Logic defaultValue,
      {super.name = 'priorityMux',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'PriorityMux_N${cases.length}_W${defaultValue.width}') {
    if (cases.isEmpty) {
      throw Exception('At least one case is required.');
    }
    final width = defaultValue.width;
    if (cases.any((c) => c.width != width)) {
      throw Exception('All cases must have the same width as the default.');
    }
    if (selector.width != cases.length) {
      throw Exception('Selector width must equal the number of cases.');
    }

    selector = addInput('selector', selector, width: selector.width);
    final inputs = [
      for (var i = 0; i < cases.length; i++)
        addInput('case$i', cases[i], width: width)
    ];
    defaultValue = addInput('defaultValue', defaultValue, width: width);
    final result = addOutput('result', width: width);

    // Build from the most significant selector bit down, so that the lowest
    // set bit is applied last and wins.
    var chosen = defaultValue;
    for (var i = inputs.length - 1; i >= 0; i--) {
      chosen = mux(selector[i], inputs[i], chosen);
    }
    result <= chosen;
  }
}
