// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// scheduled_serializer_engine.dart
// Protocol-neutral scheduled engine for one-dimensional typed arrays.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';
import 'package:rohd_hcl/src/utils.dart';

/// Captures and emits a typed array one element per scheduled advance.
///
/// `load` starts a serialization by capturing `loadData`. `advance` consumes
/// the currently presented `data`. `clear` discards the captured array and any
/// in-flight element. If `load` and `advance` are both high, `load` takes
/// precedence so a completed array may be replaced without an idle cycle.
///
/// This engine has no ownership-transfer protocol. A direct scheduler, a
/// valid-only channel, or a ready/valid shell supplies its schedule actions.
/// {@category Dataflow}
class ScheduledSerializerEngine<LogicType extends Logic> extends Module {
  /// Element currently selected from the captured array.
  late final LogicType data;

  /// Zero-based index of [data] within the captured array.
  Logic get index => output('index');

  /// Whether an array is currently being serialized.
  Logic get active => output('active');

  /// Whether [data] is the final element of the captured array.
  Logic get last => output('last');

  /// Number of elements captured by each load.
  final int length;

  /// Module clock.
  @protected
  late final Logic clk;

  /// Module reset.
  @protected
  late final Logic reset;

  /// Creates a one-dimensional scheduled serializer engine.
  ScheduledSerializerEngine({
    required Logic clk,
    required Logic reset,
    required TypedLogicArray<LogicType, LogicValue> loadData,
    required Logic load,
    required Logic advance,
    required Logic clear,
    String name = 'scheduled_serializer_engine',
    String? definitionName,
  })  : length = _scheduledSerializerLength(loadData),
        super(
          definitionName: definitionName ??
              'ScheduledSerializerEngine_L'
                  '${_scheduledSerializerLength(loadData)}_W'
                  '${loadData.elementWidth}_${payloadShapeIdentity(loadData)}',
          name: name,
        ) {
    if (!rohdPayloadsCompatible(loadData.arrayElements,
        ignoreConstantNames: true)) {
      throw ArgumentError('Serialized elements must have compatible payloads.');
    }
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    load = addInput('load', load);
    advance = addInput('advance', advance);
    clear = addInput('clear', clear);
    loadData = addTypedInput<TypedLogicArray<LogicType, LogicValue>>(
      'loadData',
      loadData,
    );

    final storedData = loadData.cloneTyped(name: '${name}_stored_data');
    final localIndex = Logic(
      name: '${name}_index',
      width: widthFor(length),
    );
    final localActive = Logic(name: '${name}_active');
    final localLast = Logic(name: '${name}_last');
    data = addTypedPayloadOutput(this, 'data', loadData.arrayElements.first);

    addOutput('index', width: localIndex.width) <= localIndex;
    addOutput('active') <= localActive;
    addOutput('last') <= localLast;
    data <= storedData.arrayElements.selectIndex(localIndex);
    localLast <= localActive & localIndex.eq(length - 1);

    Sequential(this.clk, reset: this.reset, resetValues: {
      localIndex: 0,
      localActive: 0,
    }, [
      If(clear, then: [
        localIndex < 0,
        localActive < 0,
      ], orElse: [
        If(load, then: [
          storedData < loadData,
          localIndex < 0,
          localActive < 1,
        ], orElse: [
          If(advance & localActive, then: [
            If(localLast, then: [
              localIndex < 0,
              localActive < 0,
            ], orElse: [
              localIndex < localIndex + 1,
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}

int _scheduledSerializerLength<LogicType extends Logic, TValue>(
  TypedLogicArray<LogicType, TValue> array,
) {
  if (array.dimensions.length != 1 || array.dimensions.single < 1) {
    throw ArgumentError.value(
      array.dimensions,
      'loadData.dimensions',
      'Must be a one-dimensional array with a positive length.',
    );
  }
  return array.dimensions.single;
}
