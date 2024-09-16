// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serializer.dart
// A serialization block, serializing wide input data onto a narrower channel.
//
// 2024 August 27
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Serializes wide aggregated data onto a narrower serialization stream
class Serializer extends Module {
  /// Clk input
  @protected
  Logic get clk => input('clk');

  /// Reset input
  @protected
  Logic get reset => input('reset');

  /// Allow serialization onto the output stream when [enable] is true
  @protected
  Logic? get enable => input('enable');

  /// Return the count as an output
  Logic get count => output('count');

  /// Return [done] = true when we have processed [deserialized] completely
  Logic get done => output('done');

  /// Aggregated data to serialize out
  LogicArray get deserialized => input('deserialized') as LogicArray;

  /// Serialized output, one data item per clock
  Logic get serialized => output('serialized');

  /// Build a Serializer that takes the array [deserialized] and sequences it
  /// onto the [serialized] output, one element per clock while [enable]
  /// is high (if connected). If [flopInput] is true, the
  /// [Serializer] is configured to latch the input data and hold it until
  /// [done] is asserted after the full [deserialized] is transferred.
  Serializer(LogicArray deserialized,
      {required Logic clk,
      required Logic reset,
      Logic? enable,
      bool flopInput = false,
      super.name = 'Serializer'}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    if (enable != null) {
      enable = addInput('enable', enable);
    } else {
      enable = Const(1);
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

    final latchInput = enable & ~done;
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
