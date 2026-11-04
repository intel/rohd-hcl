// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// one_hot_mux.dart
// Module that ORs together the cases whose selector bits are set.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Selects the OR of every case whose bit in `selector` is set.
///
/// When `selector` is one-hot, the result is the single selected case. With
/// several bits set, the selected cases are combined bitwise. With no bits
/// set, the result is zero.
class OneHotMux extends Module {
  /// The selected [result].
  Logic get result => output('result');

  /// Constructs a [OneHotMux] over [cases], where bit `i` of [selector]
  /// chooses `cases[i]`.
  OneHotMux(Logic selector, List<Logic> cases,
      {super.name = 'oneHotMux',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'OneHotMux_N${cases.length}_W${cases.first.width}') {
    if (cases.isEmpty) {
      throw Exception('At least one case is required.');
    }
    final width = cases.first.width;
    if (cases.any((c) => c.width != width)) {
      throw Exception('All cases must have the same width.');
    }
    if (selector.width != cases.length) {
      throw Exception('Selector width must equal the number of cases.');
    }

    selector = addInput('selector', selector, width: selector.width);
    final inputs = [
      for (var i = 0; i < cases.length; i++)
        addInput('case$i', cases[i], width: width)
    ];
    final result = addOutput('result', width: width);

    final terms = [
      for (var i = 0; i < inputs.length; i++)
        inputs[i] & selector[i].replicate(width)
    ];
    result <= terms.reduce((a, b) => a | b);
  }
}
