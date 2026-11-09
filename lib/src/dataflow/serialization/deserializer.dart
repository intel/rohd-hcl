// Copyright (C) 2024-2026 Intel Corporation
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
class Deserializer<T extends Logic, V> extends Module {
  /// Aggregated data output.
  late final TypedLogicArray<T, V> deserialized;

  /// Length of aggregate to deserialize.
  final int length;

  /// [done] emitted when the last element is committed to [deserialized].
  /// The timing is that you can latch [deserialized] when [done] is high.
  Logic get done => output('done');

  /// Return the current count of elements that have been serialized out.
  Logic get count => output('count');

  /// Build a [Deserializer] that takes serialized input [serialized]
  /// and aggregates it into one wide output [deserialized] of length [length].
  ///
  /// Updates one element per clock while [enable] (if connected) is high,
  /// emitting [done] when completing the filling of wide output
  /// [TypedLogicArray] [deserialized].
  ///
  /// A [TypedLogicArray<T, V>] input gains an outer dimension of [length].
  /// A scalar or structured [T] input produces a one-dimensional array.
  /// [valueCodec] describes the semantic value of each leaf [T], not a whole
  /// array slice. Use [LogicValueCodec.logicValue] for packed values.
  ///
  /// If [last] is connected, it is used as a potential early indicator for
  /// completion of the deserialization.
  Deserializer(Logic serialized, this.length,
      {required Logic clk,
      required Logic reset,
      required LogicValueCodec<V> valueCodec,
      Logic? enable,
      Logic? last,
      super.name = 'deserializer',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName: definitionName ??
                'Deserializer_W${serialized.width}_L$length') {
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'Must be positive.');
    }
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    if (enable != null) {
      enable = addInput('enable', enable);
    }
    Logic? floppedLast;
    if (last != null) {
      last = addInput('last', last);
      floppedLast = Logic(name: 'floppedLast')
        ..gets(flop(clk, reset: reset, en: (enable ?? Const(1)), last));
    }
    serialized = addTypedInput('serialized', serialized);
    final List<int> dimensions;
    final int numUnpackedDimensions;
    final T prototype;
    if (serialized is TypedLogicArray<T, V>) {
      if (serialized.dimensions.any((dimension) => dimension <= 0)) {
        throw ArgumentError.value(serialized.dimensions, 'serialized',
            'Deserialization requires non-empty dimensions.');
      }
      dimensions = [length, ...serialized.dimensions];
      numUnpackedDimensions = serialized.numUnpackedDimensions == 0
          ? 0
          : serialized.numUnpackedDimensions + 1;
      prototype = serialized.arrayElements.first;
    } else if (serialized is T && serialized is! TypedLogicArray) {
      dimensions = [length];
      numUnpackedDimensions = 0;
      prototype = serialized;
    } else {
      throw ArgumentError.value(serialized, 'serialized',
          'Expected a $T or TypedLogicArray<$T, $V>.');
    }
    final cnt = Counter.simple(
        clk: clk,
        reset: reset,
        enable: enable,
        maxValue: length - 1,
        restart: (last ?? Const(0)) & (enable ?? Const(1)));
    final overflowed = cnt.overflowed;
    if (overflowed == null) {
      throw StateError('Deserializer requires Counter overflow tracking.');
    }
    addOutput('count', width: cnt.width) <= cnt.count;
    addOutput('done') <=
        overflowed | ((floppedLast ?? Const(0)) & (enable ?? Const(1)));
    deserialized = addTypedOutput(
        'deserialized',
        ({name = 'deserialized'}) => TypedLogicArray<T, V>(
              dimensions,
              prototype.cloneTyped,
              valueCodec: valueCodec,
              name: name,
              numUnpackedDimensions: numUnpackedDimensions,
            ));
    deserialized.elements.forEachIndexed((i, d) =>
        d <=
        flop(
            clk,
            reset: reset,
            en: (enable ?? Const(1)) & count.eq(i),
            serialized,
            outputGenerator: serialized.clone));
  }
}
