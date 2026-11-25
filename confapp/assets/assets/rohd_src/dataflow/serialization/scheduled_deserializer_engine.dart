// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// scheduled_deserializer_engine.dart
// Protocol-neutral scheduled engine for collecting typed elements.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/utils.dart';

/// Collects typed elements into a fixed-length array under explicit scheduling.
///
/// A high `write` stores `element` at `index`. The engine pulses `complete`
/// after the final configured element or an asserted `last` is written. The
/// next index then returns to zero. `clear` discards the partial collection.
/// This engine has no ready/valid ownership semantics.
/// {@category Dataflow}
class ScheduledDeserializerEngine<LogicType extends Logic> extends Module {
  /// Collected typed-array contents.
  late final TypedLogicArray<LogicType, LogicValue> data;

  /// Index at which the next written element will be stored.
  Logic get index => output('index');

  /// Pulses after a write completes the current array.
  Logic get complete => output('complete');

  /// Number of elements in each collection.
  final int length;

  /// Module clock.
  @protected
  late final Logic clk;

  /// Module reset.
  @protected
  late final Logic reset;

  /// Creates a scheduled typed-array collector.
  ScheduledDeserializerEngine({
    required Logic clk,
    required Logic reset,
    required LogicType element,
    required Logic write,
    required Logic last,
    required Logic clear,
    required this.length,
    String name = 'scheduled_deserializer_engine',
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              'ScheduledDeserializerEngine_L${length}_W${element.width}_'
                  '${payloadShapeIdentity(element)}',
          name: name,
        ) {
    if (length < 1) {
      throw ArgumentError.value(length, 'length', 'Must be at least one.');
    }
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    element = addTypedInput<LogicType>('element', element);
    write = addInput('write', write);
    last = addInput('last', last);
    clear = addInput('clear', clear);

    final localIndex = Logic(
      name: '${name}_index',
      width: widthFor(length),
    );
    final localComplete = Logic(name: '${name}_complete');
    LogicType elementClone({String? name}) => element.cloneTyped(name: name);
    TypedLogicArray<LogicType, LogicValue> dataClone({String? name}) =>
        TypedLogicArray<LogicType, LogicValue>(
          [length],
          elementClone,
          name: name ?? '${this.name}_data',
        );
    data = addTypedOutput<TypedLogicArray<LogicType, LogicValue>>(
      'data',
      dataClone,
    );

    addOutput('index', width: localIndex.width) <= localIndex;
    addOutput('complete') <= localComplete;

    Sequential(this.clk, reset: this.reset, resetValues: {
      localIndex: 0,
      localComplete: 0,
    }, [
      localComplete < 0,
      If(clear, then: [
        localIndex < 0,
      ], orElse: [
        If(write, then: [
          for (var slot = 0; slot < length; slot++)
            If(localIndex.eq(slot), then: [
              data.arrayElements[slot] < element,
            ]),
          If(last | localIndex.eq(length - 1), then: [
            localIndex < 0,
            localComplete < 1,
          ], orElse: [
            localIndex < localIndex + 1,
          ]),
        ]),
      ]),
    ]);
  }
}
