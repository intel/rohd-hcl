// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// deserializer.dart
// A deserialization block, deserializing narrow input data onto a wide channel.
//
// 2024 August 27
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:collection/collection.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// [Deserializer] aggregates data from a serialized stream.
class Deserializer extends Module {
  /// Aggregated data output.
  LogicArray get deserialized => output('deserialized') as LogicArray;

  /// Length of aggregate to deserialize.
  final int length;

  /// [done] emitted when the last element is committed to [deserialized].
  /// The timing is that you can latch [deserialized] when [done] is high.
  Logic get done => output('done');

  /// Return the current count of elements that have been serialized out.
  Logic get count => output('count');

  /// Build a Deserializer that takes serialized input [serialized]
  /// and aggregates it into one wide output [deserialized] of length [length].
  ///
  /// Updates one element per clock while [enable] (if connected) is high,
  /// emitting [done] when completing the filling of wide output `LogicArray`
  /// [deserialized].
  Deserializer(Logic serialized, this.length,
      {required Logic clk,
      required Logic reset,
      Logic? enable,
      super.name = 'deserializer'}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    serialized = addInput('serialized', serialized, width: serialized.width);
    final cnt = Counter.simple(
        clk: clk, reset: reset, enable: enable, maxValue: length - 1);
    addOutput('count', width: cnt.width) <= cnt.count;
    addOutput('done') <= cnt.overflowed;
    addOutputArray('deserialized',
            dimensions: [length], elementWidth: serialized.width)
        .elements
        .forEachIndexed((i, d) =>
            d <=
            flop(
                clk,
                reset: reset,
                en: (enable ?? Const(1)) & count.eq(i),
                serialized));
  }
}
