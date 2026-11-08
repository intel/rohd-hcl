// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// count.dart
// Implementation of Count Functionality.
//
// 2023 July 11
// Author: Rahul Gautham Putcha <rahul.gautham.putcha@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/dataflow/reduction/reduction_tree_generator.dart';
import 'package:rohd_hcl/src/utils.dart';

/// [Count] `1` or `0`.
class Count extends Module {
  /// [_output] is output of [Count] (use index for accessing from outside
  /// Module).
  late Logic _output;

  /// The resulting count.
  Logic get count => _output;

  /// The combinational depth of the balanced population-count tree.
  late final int treeDepth;

  /// [Count] `1` or `0`.
  ///
  /// Takes in [bus] of type [Logic]. by default performs [countOne] (`1`)
  /// if [countOne] is `false` will count `0`. [radix] controls the maximum
  /// number of operands combined by each balanced reduction node.
  Count(Logic bus,
      {bool countOne = true,
      int radix = 2,
      super.name = 'count',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'Count_W${bus.width}_'
                    '${countOne ? "One" : "Zero"}_R$radix') {
    bus = addInput('bus', bus, width: bus.width);
    final countWidth = widthFor(bus.width + 1);
    final tree = ReductionTreeGenerator(
      [
        for (var i = 0; i < bus.width; i++)
          (countOne ? bus[i] : ~bus[i]).zeroExtend(countWidth),
      ],
      (inputs, {depth = 0, control, name = 'add'}) =>
          inputs.reduce((left, right) => left + right),
      radix: radix,
    );
    treeDepth = tree.depth;
    _output = addOutput('count${countOne ? "One" : "Zero"}', width: countWidth);

    _output <= tree.out;
  }
}
