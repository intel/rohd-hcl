// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serializer.dart
// A serialization block, serializing wide input data onto a narrower channel.
//
// 2024 August 27
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Serializes wide aggregated data onto a narrower serialization stream.
class Serializer extends Module {
  /// Serialized output, one data item per clock.
  Logic get serialized => output('serialized');

  /// Return [done] = true when we have processed `deserialized`completely.
  /// [done] is asserted with the final element being serialized so that
  /// at the next clock edge, you have [done] with the last element latched at
  /// the same time.
  Logic get done => output('done');

  /// The number of current serialization steps completed in the
  /// transfer is [count].
  Logic get count => output('count');

  /// Build a Serializer that takes the array [deserialized] and sequences it
  /// onto the [serialized] output.
  ///
  /// Delivers one element per clock while [enable]
  /// is high (if connected). If [flopInput] is true, the
  /// [Serializer] is configured to latch the input data and hold it until
  /// [done] is asserted after the full `LogicArray` [deserialized] is
  /// transferred. This will delay the serialized output by one cycle.
  Serializer(LogicArray deserialized,
      {required Logic clk,
      required Logic reset,
      Logic? enable,
      bool flopInput = false,
      super.name = 'Serializer'}) {
    if (deserialized.dimensions.length != 1) {
      throw RohdHclException('deserialized dimension must be of length 1');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    deserialized = addInputArray('deserialized', deserialized,
        dimensions: deserialized.dimensions,
        elementWidth: deserialized.elementWidth);
    addOutput('serialized', width: deserialized.elementWidth);
    addOutput('count', width: log2Ceil(deserialized.dimensions[0]));
    addOutput('done');

    final cnt = Counter.simple(
        clk: clk,
        reset: reset,
        enable: enable,
        maxValue: deserialized.elements.length - 1);

    final latchInput = (enable ?? Const(1)) & ~cnt.count.or();
    count <=
        (flopInput
            ? flop(clk, reset: reset, en: enable, cnt.count)
            : cnt.count);

    final dataOutput =
        LogicArray(deserialized.dimensions, deserialized.elementWidth);
    for (var i = 0; i < deserialized.elements.length; i++) {
      dataOutput.elements[i] <=
          (flopInput
              ? flop(
                  clk, reset: reset, en: latchInput, deserialized.elements[i])
              : deserialized.elements[i]);
    }
    serialized <= dataOutput.elements.selectIndex(count);
    done <=
        (flopInput
            ? flop(clk, reset: reset, en: enable, cnt.equalsMax)
            : cnt.equalsMax);
  }
}
