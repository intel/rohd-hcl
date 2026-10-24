// Copyright (C) 2024-2026 Intel Corporation
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
class Serializer<T extends Logic, V> extends Module {
  /// Serialized output, one outermost array element per clock.
  ///
  /// Has one fewer dimension than the input. For a one-dimensional input,
  /// the output is rank zero and its typed leaf is available via
  /// [TypedLogicArray.scalar].
  late final TypedLogicArray<T, V> serialized;

  /// Return [done] = `true` when we have processed `deserialized`completely.
  /// [done] is asserted with the final element being serialized so that
  /// at the next clock edge, you have [done] with the last element latched at
  /// the same time.
  Logic get done => output('done');

  /// The number of current serialization steps completed in the
  /// transfer is [count].
  Logic get count => output('count');

  /// Build a [Serializer] that takes the array [deserialized] and sequences it
  /// onto the [serialized] output.
  ///
  /// Delivers one element per clock while [enable]
  /// is high (if connected). If [flopInput] is `true`, the
  /// [Serializer] is configured to latch the input data and hold it until
  /// [done] is asserted after the full [TypedLogicArray] [deserialized] is
  /// transferred. This will delay the serialized output by one cycle.
  ///
  /// If [endCount] is connected, it is used as a potential early indicator for
  /// completion of the serialization.
  Serializer(TypedLogicArray<T, V> deserialized,
      {required Logic clk,
      required Logic reset,
      Logic? enable,
      Logic? endCount,
      bool flopInput = false,
      super.name = 'serializer',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'Serializer_W${deserialized.width}_'
                    '${deserialized.elementWidth}') {
    if (deserialized.dimensions.isEmpty ||
        deserialized.dimensions.any((dimension) => dimension <= 0)) {
      throw ArgumentError.value(deserialized.dimensions, 'deserialized',
          'Serialization requires non-empty dimensions.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    if (endCount != null) {
      endCount = addInput('endCount', endCount,
          width: deserialized.dimensions[0].bitLength);
    }
    deserialized = addTypedInput('deserialized', deserialized);

    addOutput('count', width: widthFor(deserialized.dimensions[0]));
    addOutput('done');

    serialized = deserialized.dimensions.length == 1
        ? addTypedOutput(
            'serialized',
            ({name = 'serialized'}) => TypedLogicArray<T, V>(
                  const [],
                  deserialized.arrayElements.first.cloneTyped,
                  valueCodec: deserialized.valueCodec,
                  name: name,
                ))
        : addTypedOutput('serialized', deserialized.majorSlices.first.clone);

    Logic? earlyEnd;
    final cnt = Counter.simple(
        clk: clk,
        reset: reset,
        enable: enable,
        maxValue: deserialized.elements.length - 1,
        restart: earlyEnd);

    if (endCount != null) {
      earlyEnd = Logic(name: 'earlyEnd')..gets(cnt.count.eq(endCount));
    } else {
      earlyEnd = null;
    }

    final latchTheInput =
        ((enable ?? Const(1)) & ~cnt.count.or()).named('latchTheInput');
    count <=
        (flopInput
            ? flop(clk, reset: reset, en: enable, cnt.count)
            : cnt.count);

    final dataOutput = deserialized.clone(name: 'dataOutput');
    for (var i = 0; i < deserialized.elements.length; i++) {
      dataOutput.elements[i] <=
          (flopInput
              ? flop(
                  clk,
                  reset: reset,
                  en: latchTheInput,
                  deserialized.elements[i],
                  outputGenerator: deserialized.elements[i].clone)
              : deserialized.elements[i]);
    }
    serialized <=
        dataOutput.elements.selectIndex(count,
            outputGenerator: dataOutput.elements.first.clone);
    done <=
        (flopInput
            ? flop(
                clk,
                reset: reset,
                en: enable,
                cnt.equalsMax | (earlyEnd ?? Const(0)))
            : cnt.equalsMax | (earlyEnd ?? Const(0)));
  }
}
