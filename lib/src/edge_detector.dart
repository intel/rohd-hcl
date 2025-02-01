// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// edge_detector.dart
// Implementation of edge detectors.
//
// 2024 January 29
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// An edge detector for positive, negative, or any edge on a signal relative to
/// the previous clock cycle.
class EdgeDetector extends Module {
  /// The type of edge(s) to detect.
  final Edge edgeType;

  /// The name of the [edge] output.
  String get _edgeName => '${edgeType.name}_edge';

  /// High for one cycle when the input signal has an [edgeType] transition.
  Logic get edge => output(_edgeName);

  /// Creates an edge detector which flags an [edge] when [signal] changes
  /// relative to its value in the previous cycle.
  ///
  /// [signal] must be 1-bit.
  ///
  /// If a [reset] is provided, then the first cycle after [reset] is
  /// deasserted, [signal] will be compared to [resetValue] (or 0, if not
  /// provided).
  EdgeDetector(
    Logic signal, {
    required Logic clk,
    Logic? reset,
    dynamic resetValue,
    this.edgeType = Edge.pos,
    String? name,
  }) : super(
            name: name ?? '${edgeType.name}_edge_detector',
            definitionName: 'EdgeDetector_T${edgeType.name}') {
    if (signal.width != 1 ||
        (resetValue is Logic && resetValue.width != 1) ||
        (resetValue is LogicValue && resetValue.width != 1)) {
      throw RohdHclException('Can only detect edges on 1-bit signals.');
    }

    if (reset == null && resetValue != null) {
      throw RohdHclException(
          'If no reset is provided, then a resetValue cannot be provided.');
    }

    clk = addInput('clk', clk);
    signal = addInput('signal', signal);

    if (reset != null) {
      reset = addInput('reset', reset);
    }

    if (resetValue != null && resetValue is Logic) {
      resetValue = addInput('resetValue', resetValue);
    }

    addOutput(_edgeName);

    final previousValue = Logic(name: 'previousValue')
      ..gets(
        flop(clk, reset: reset, resetValue: resetValue, signal),
      );

    edge <=
        [
          if (edgeType case Edge.pos || Edge.any) ~previousValue & signal,
          if (edgeType case Edge.neg || Edge.any) previousValue & ~signal,
        ].swizzle().or();
  }
}
