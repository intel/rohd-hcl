// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter.dart
// A flexible counter implementation.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/aggregator.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/parallel_prefix_operations.dart';

class Counter extends Module with DynamicInputToLogic {
  final int width;

  /// If `true`, the counter will saturate at the `maxValue` and `minValue`. If
  /// `false`, the counter will wrap around (overflow/underflow) at the
  /// `maxValue` and `minValue`.
  final bool saturates;

  Logic get value => output('value');

  /// TODO
  ///
  /// The [width] can be either explicitly provided or inferred from other
  /// values such as a [maxValue], [minValue], or [resetValue] that contain
  /// width information (e.g. a [LogicValue]), or by making it large enough to
  /// fit [maxValue], or by inspecting widths of [interfaces]. There must be
  /// enough information provided to determine the [width].
  ///
  /// If no [maxValue] is provided, one will be inferred by the maximum that can
  /// fit inside of the [width].
  Counter(
    List<AggregatorInterface> interfaces, {
    required Logic clk,
    required Logic reset,
    dynamic resetValue = 0,
    dynamic maxValue,
    dynamic minValue = 0,
    int? width,
    this.saturates = false,
    super.name = 'counter',
  }) : width = inferWidth([resetValue, maxValue, minValue], width, interfaces) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    addOutput('value', width: this.width);

    interfaces = interfaces
        .map((e) => AggregatorInterface.clone(e)..connectIO(this, e))
        .toList();

    final agg = Aggregator(
      interfaces,
      initialValue: value,
      maxValue: maxValue,
      minValue: minValue,
      width: this.width,
      saturates: saturates,
    );

    final resetValueLogic = dynamicInputToLogic(
      'resetValue',
      resetValue,
    );

    value <=
        flop(
          clk,
          agg.value,
          reset: reset,
          resetValue: resetValueLogic,
        );
  }
}

//TODO doc
//TODO: is this ok? move it somewhere else?
mixin DynamicInputToLogic on Module {
  int get width;

  @protected
  Logic dynamicInputToLogic(String name, dynamic value) {
    if (value is Logic) {
      return addInput(name, value.zeroExtend(width), width: width);
    } else {
      return Const(value, width: width);
    }
  }
}
