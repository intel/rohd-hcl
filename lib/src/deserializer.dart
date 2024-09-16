// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// deserializer.dart
// A deserialization block, deserializing narrow input data onto a wide channel.
//
// 2024 August 27
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Aggregates data from a serialized stream
class Deserializer extends Module {
  /// Clk input
  @protected
  Logic get clk => input('clk');

  /// Reset input
  @protected
  Logic get reset => input('reset');

  /// Run deserialization whenever [enable] is true
  @protected
  Logic? get enable => input('enable');

  /// Serialized input, one data item per clock
  Logic get serialized => input('serialized');

  /// Aggregated data output
  LogicArray get deserialized => output('deserialized') as LogicArray;

  /// Valid out when data is reached
  Logic get done => output('done');

  /// Return the count as an output
  @protected
  Logic get count => output('count');

  /// Build a Deserializer that takes serialized input [serialized]
  /// and aggregates it into one wide output [deserialized], one element per
  /// clock while [enable] (if connected) is high, emitting [done] when
  /// completing the filling of wide output [deserialized].
  Deserializer(Logic serialized, int length,
      {required Logic clk,
      required Logic reset,
      Logic? enable,
      super.name = 'Deserializer'}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    if (enable != null) {
      enable = addInput('enable', enable);
    } else {
      enable = Const(1);
    }
    serialized = addInput('serialized', serialized, width: serialized.width);
    final cnt = Counter.simple(
        clk: clk, reset: reset, enable: enable, maxValue: length - 1);
    addOutput('count', width: cnt.width) <= cnt.count;
    addOutput('done') <= cnt.overflowed;
    addOutputArray('deserialized',
            dimensions: [length], elementWidth: serialized.width) <=
        [
          for (var i = 0; i < length; i++)
            flop(clk, reset: reset, en: enable & count.eq(i), serialized)
        ].swizzle();
  }
}
