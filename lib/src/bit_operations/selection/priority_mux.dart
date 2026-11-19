// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// priority_mux.dart
// Module that selects the case for the least significant set selector bit.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// Selects a typed case for the least significant bit set in `selector`.
///
/// Bit 0 of `selector` has the highest priority. When no bit is set,
/// `defaultValue` is produced.
class PriorityMuxImplementation<T extends Logic> extends Module {
  /// The selected [result].
  T get result => output('result') as T;

  /// Constructs a typed priority mux whose cases match [defaultValue]'s layout.
  PriorityMuxImplementation(Logic selector, List<T> cases, T defaultValue,
      {String name = 'priorityMux',
      bool reserveName = false,
      bool reserveDefinitionName = false,
      String? definitionName})
      : this._(selector, cases, defaultValue,
            name: name,
            reserveName: reserveName,
            reserveDefinitionName: reserveDefinitionName,
            definitionName: definitionName,
            flatPorts: false);

  PriorityMuxImplementation._(Logic selector, List<T> cases, T defaultValue,
      {required bool flatPorts,
      required super.name,
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'PriorityMux_N${cases.length}_W${defaultValue.width}'
                    '${flatPorts ? '' : '_'}'
                    '${flatPorts ? '' : payloadShapeIdentity(defaultValue)}') {
    if (cases.isEmpty) {
      throw Exception('At least one case is required.');
    }
    final width = defaultValue.width;
    if (cases.any((c) => c.width != width)) {
      throw Exception('All cases must have the same width as the default.');
    }
    if (!flatPorts &&
        cases.any(
            (c) => !samePayloadShapeAllowingRenamedClone(defaultValue, c))) {
      throw ArgumentError('Cases must match the default payload shape.');
    }
    if (selector.width != cases.length) {
      throw Exception('Selector width must equal the number of cases.');
    }

    selector = addInput('selector', selector, width: selector.width);
    final inputs = [
      for (var i = 0; i < cases.length; i++)
        if (flatPorts)
          addInput('case$i', cases[i], width: width) as T
        else
          addTypedInput<T>('case$i', cases[i])
    ];
    final localDefault = flatPorts
        ? addInput('defaultValue', defaultValue, width: width) as T
        : addTypedInput<T>('defaultValue', defaultValue);
    final result = flatPorts
        ? addOutput('result', width: width) as T
        : addTypedPayloadOutput<T>(this, 'result', localDefault);

    // Build from the most significant selector bit down, so that the lowest
    // set bit is applied last and wins.
    var chosen = localDefault;
    for (var i = inputs.length - 1; i >= 0; i--) {
      chosen = mux<T>(selector[i], inputs[i], chosen);
    }
    result <= chosen;
  }
}

/// Compatibility priority mux with flat case and result ports.
@Deprecated("Use import 'package:rohd_hcl/rohd_hcl.dart' hide PriorityMux; "
    "and import 'package:rohd_hcl/bit_operations/selection/priority_mux.dart';")
class PriorityMux extends PriorityMuxImplementation<Logic> {
  /// Constructs a priority mux with flat ports.
  @Deprecated("Use import 'package:rohd_hcl/rohd_hcl.dart' hide PriorityMux; "
      "and import 'package:rohd_hcl/bit_operations/selection/priority_mux.dart';")
  PriorityMux(super.selector, super.cases, super.defaultValue,
      {super.name = 'priorityMux',
      super.reserveName,
      super.reserveDefinitionName,
      super.definitionName})
      : super._(flatPorts: true);
}
