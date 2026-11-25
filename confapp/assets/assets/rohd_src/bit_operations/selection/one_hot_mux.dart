// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// one_hot_mux.dart
// Module that ORs together the cases whose selector bits are set.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// Selects the OR of every case whose bit in `selector` is set.
///
/// When `selector` is one-hot, the result is the single selected case. With
/// several bits set, the selected cases are combined bitwise. With no bits
/// set, the result is zero. Inputs and the result retain their payload types;
/// the bitwise combination does not perform a semantic value conversion.
class OneHotMux<T extends Logic> extends Module {
  /// The selected [result].
  T get result => output('result') as T;

  /// Constructs a [OneHotMux] over [cases], where bit `i` of [selector]
  /// chooses `cases[i]`.
  OneHotMux(Logic selector, List<T> cases,
      {super.name = 'oneHotMux',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
          definitionName: definitionName ??
              'OneHotMux_N${cases.length}'
                  '_W${cases.isEmpty ? 0 : cases.first.width}'
                  '${cases.isEmpty ? '' : '_'}'
                  '${cases.isEmpty ? '' : payloadShapeIdentity(cases.first)}',
        ) {
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
    if (!compatiblePayloadSet(cases, allowRenamedClones: true)) {
      throw ArgumentError('Mux cases must have compatible payload schemas.');
    }

    selector = addInput('selector', selector, width: selector.width);
    final inputs = [
      for (var i = 0; i < cases.length; i++)
        addTypedInput<T>('case$i', cases[i])
    ];
    final result = addTypedPayloadOutput<T>(this, 'result', inputs.first);

    final terms = [
      for (var i = 0; i < inputs.length; i++)
        inputs[i] & selector[i].replicate(width)
    ];
    connectPackedPayload(result, terms.reduce((a, b) => a | b));
  }
}
