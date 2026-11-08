// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_reduction_tree.dart
// Configurator for common reduction-tree operations.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Common operations that can be represented in the configuration app.
enum ReductionTreeOperation {
  /// Bitwise AND all inputs.
  and,

  /// Bitwise OR all inputs.
  or,

  /// Bitwise XOR all inputs.
  xor,

  /// Add all inputs.
  sum,
}

/// A [Configurator] for [ReductionTree].
class ReductionTreeConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.dataflow;

  @override
  String get subcategory => 'reduction';

  /// Number of input terms.
  final IntConfigKnob inputCountKnob = PositiveIntConfigKnob(value: 4);

  /// Width of each input term.
  final IntConfigKnob inputWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Number of branches per reduction node.
  final IntConfigKnob radixKnob = IntConfigKnob(value: 2, minValue: 2);

  /// Reduction operation.
  final ChoiceConfigKnob<ReductionTreeOperation> operationKnob =
      ChoiceConfigKnob(
    ReductionTreeOperation.values,
    value: ReductionTreeOperation.and,
    choiceLabels: const {
      ReductionTreeOperation.and: 'AND',
      ReductionTreeOperation.or: 'OR',
      ReductionTreeOperation.xor: 'XOR',
      ReductionTreeOperation.sum: 'Sum',
    },
  );

  /// Sign extension selection for nodes whose results widen.
  final StaticOrRuntimeBoolKnob signExtendKnob = StaticOrRuntimeBoolKnob();

  /// Optional number of node levels between pipeline stages.
  final IntOptionalConfigKnob depthBetweenFlopsKnob =
      IntOptionalConfigKnob(value: null);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Input Count': inputCountKnob,
    'Input Width': inputWidthKnob,
    'Radix': radixKnob,
    'Operation': operationKnob,
    'Sign Extend': signExtendKnob,
    'Depth Between Flops': depthBetweenFlopsKnob,
  });

  @override
  Module createModule() {
    final pipeline = depthBetweenFlopsKnob.value != null;
    return ReductionTree(
      List<Logic>.generate(
          inputCountKnob.value, (_) => Logic(width: inputWidthKnob.value)),
      _operation,
      radix: radixKnob.value,
      signExtend: signExtendKnob.resolve('signExtend'),
      depthBetweenFlops: depthBetweenFlopsKnob.value,
      clk: pipeline ? Logic() : null,
      reset: pipeline ? Logic() : null,
      enable: pipeline ? Logic() : null,
    );
  }

  Logic _operation(List<Logic> inputs,
      {int depth = 0, Logic? control, String name = 'reduction'}) {
    final result = switch (operationKnob.value) {
      ReductionTreeOperation.and => inputs.reduce((lhs, rhs) => lhs & rhs),
      ReductionTreeOperation.or => inputs.reduce((lhs, rhs) => lhs | rhs),
      ReductionTreeOperation.xor => inputs.reduce((lhs, rhs) => lhs ^ rhs),
      ReductionTreeOperation.sum => inputs.reduce((lhs, rhs) => lhs + rhs),
    };
    return result.named(name);
  }

  @override
  String get name => 'Reduction Tree';
}
