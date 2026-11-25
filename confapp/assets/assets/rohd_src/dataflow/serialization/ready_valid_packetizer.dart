// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_packetizer.dart
// Converts a typed fixed array into a delimited ready/valid frame stream.
//
// 2026 August 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

int _packetLength<T extends Logic, V>(TypedLogicArray<T, V> array) {
  if (array.dimensions.length != 1) {
    throw ArgumentError.value(array.dimensions, 'upstream.data',
        'Only one-dimensional arrays are supported.');
  }
  return array.dimensions.single;
}

/// Converts a fixed one-dimensional array into a delimited frame stream.
///
/// The input array is one complete packet. It is accepted only while idle and
/// retained internally while its leaves are emitted in order. `last` is high
/// only for the final leaf, and the output offer remains irrevocable while
/// stalled. A final accepted leaf may hand off directly to the next packet.
/// {@category Dataflow}
class ReadyValidPacketizer<LogicType extends Logic> extends Module {
  /// Complete input packet.
  late final ReadyValidInterface<TypedLogicArray<LogicType, LogicValue>>
      _upstream;

  /// Framed output stream.
  late final IrrevocableReadyValidInterface<Frame<LogicType>> _downstream;

  /// Index of the frame currently offered downstream.
  Logic get index => output('index');

  /// Whether an input packet is currently being emitted.
  Logic get active => output('active');

  /// Number of leaves in each input packet.
  final int length;

  /// Module clock.
  @protected
  late final Logic clk;

  /// Module reset.
  @protected
  late final Logic reset;

  /// Creates a fixed-array packetizer.
  ReadyValidPacketizer(
      {required Logic clk,
      required Logic reset,
      required ReadyValidInterface<TypedLogicArray<LogicType, LogicValue>>
          upstream,
      required ReadyValidInterface<Frame<LogicType>> downstream,
      String name = 'ready_valid_packetizer'})
      : length = _packetLength(upstream.data),
        super(
            definitionName:
                'ReadyValidPacketizer_L${_packetLength(upstream.data)}'
                '_W${upstream.data.elementWidth}_'
                '${payloadShapesIdentity([upstream.data, downstream.data])}',
            name: name) {
    final elements = upstream.data.arrayElements;
    if (!compatiblePayloadSet(elements, ignoreConstantNames: true) ||
        elements.any((element) => !compatiblePayloadConnection(
            element, downstream.data.data,
            ignoreConstantNames: true))) {
      throw ArgumentError('Packet elements and output payload must match.');
    }
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    addOutput('index', width: widthFor(length));
    addOutput('active');
    _upstream = addPairInterface(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    _downstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface<Frame<LogicType>>(
          downstream.data.cloneTyped()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );

    final inputAccepted = Logic(name: '${name}_input_accepted');
    final outputAccepted = Logic(name: '${name}_output_accepted');
    final engine = ScheduledSerializerEngine<LogicType>(
      clk: this.clk,
      reset: this.reset,
      loadData: _upstream.data,
      load: inputAccepted,
      advance: outputAccepted,
      clear: Const(0),
      name: '${name}_engine',
    );

    _upstream.ready <= ~engine.active | (outputAccepted & engine.last);
    inputAccepted <= _upstream.valid & _upstream.ready;
    outputAccepted <= engine.active & _downstream.ready;
    _downstream.valid <= engine.active;
    _downstream.data.data <= engine.data;
    _downstream.data.last <= engine.active & engine.last;
    index <= engine.index;
    active <= engine.active;
  }
}
