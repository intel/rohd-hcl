// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_depacketizer.dart
// Aggregates a delimited ready/valid frame stream into typed packets.
//
// 2026 August 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// A collected packet and its framing result.
///
/// [validElements] identifies the number of leading [data] elements belonging
/// to this packet. [framingError] is high when configured capacity was reached
/// before the input asserted its frame marker.
/// {@category Dataflow}
class CollectedPacket<LogicType extends Logic> extends LogicStructure {
  /// Collected packet storage.
  TypedLogicArray<LogicType, LogicValue> get data =>
      elements[0] as TypedLogicArray<LogicType, LogicValue>;

  /// Number of valid leading elements in [data].
  Logic get validElements => elements[1];

  /// High when the packet ended at capacity without a frame marker.
  Logic get framingError => elements[2];

  /// Creates a packet result around [data].
  CollectedPacket(TypedLogicArray<LogicType, LogicValue> data, {String? name})
      : super([
          data,
          Logic(
              name: 'validElements',
              width: widthFor((data.dimensions.single) + 1)),
          Logic(name: 'framingError'),
        ], name: name ?? '${data.name}_packet');

  CollectedPacket._clone(LogicStructure original, {String? name})
      : super(original.elements.map((element) => element.cloneTyped()).toList(),
            name: name ?? original.name);

  @override
  CollectedPacket<LogicType> clone({String? name}) =>
      CollectedPacket<LogicType>._clone(this, name: name);
}

/// Aggregates a delimited frame stream into bounded typed packets.
///
/// An asserted input frame marker emits a packet immediately, including partial
/// packets. If the marker has not arrived when packet capacity is reached, the
/// full packet is emitted with [CollectedPacket.framingError]
/// asserted. The completed packet is irrevocable until its consumer accepts it,
/// which may hand off to the first beat of the next packet.
/// {@category Dataflow}
class ReadyValidDepacketizer<LogicType extends Logic> extends Module {
  late final ReadyValidInterface<Frame<LogicType>> _upstream;
  late final IrrevocableReadyValidInterface<CollectedPacket<LogicType>>
      _downstream;

  /// Storage index receiving the next accepted input frame.
  Logic get index => output('index');

  /// Whether a completed packet awaits downstream acceptance.
  Logic get outputOccupied => output('outputOccupied');

  /// Packet capacity in elements.
  final int capacity;

  /// Module clock.
  @protected
  late final Logic clk;

  /// Module reset.
  @protected
  late final Logic reset;

  /// Creates a bounded depacketizer.
  ReadyValidDepacketizer(
      {required Logic clk,
      required Logic reset,
      required ReadyValidInterface<Frame<LogicType>> upstream,
      required ReadyValidInterface<CollectedPacket<LogicType>> downstream,
      String name = 'ready_valid_depacketizer'})
      : capacity = downstream.data.data.dimensions.single,
        super(
            definitionName: 'ReadyValidDepacketizer_L'
                '${downstream.data.data.dimensions.single}'
                '_W${upstream.data.data.width}_'
                '${payloadShapesIdentity([upstream.data, downstream.data])}',
            name: name) {
    if (downstream.data.data.dimensions.length != 1 ||
        downstream.data.data.elementWidth != upstream.data.data.width) {
      throw ArgumentError('Packet data must be a one-dimensional array of '
          '${upstream.data.data.width}-bit values.');
    }
    if (downstream.data.data.arrayElements.any((element) =>
        !rohdPayloadsCompatible([upstream.data.data, element],
            ignoreConstantNames: true))) {
      throw ArgumentError('Input and packet element payloads must match.');
    }
    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    addOutput('index', width: widthFor(capacity));
    addOutput('outputOccupied');
    _upstream = addPairInterface(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    _downstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface<CollectedPacket<LogicType>>(
          downstream.data.cloneTyped()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );

    final inputAccepted = Logic(name: '${name}_input_accepted');
    final outputAccepted = Logic(name: '${name}_output_accepted');
    final isFull = Logic(name: '${name}_is_full');
    final completesPacket = Logic(name: '${name}_completes_packet');
    final validElements = Logic(
      name: '${name}_valid_elements',
      width: _downstream.data.validElements.width,
    );
    final framingError = Logic(name: '${name}_framing_error');
    final engine = ScheduledDeserializerEngine<LogicType>(
      clk: this.clk,
      reset: this.reset,
      element: _upstream.data.data,
      write: inputAccepted,
      last: _upstream.data.last,
      clear: Const(0),
      length: capacity,
      name: '${name}_engine',
    );

    _upstream.ready <= ~outputOccupied | outputAccepted;
    inputAccepted <= _upstream.valid & _upstream.ready;
    outputAccepted <= outputOccupied & _downstream.ready;
    isFull <= engine.index.eq(capacity - 1);
    completesPacket <= _upstream.data.last | isFull;
    _downstream.valid <= outputOccupied;
    _downstream.data.data <= engine.data;
    _downstream.data.validElements <= validElements;
    _downstream.data.framingError <= framingError;
    index <= engine.index;

    Sequential(this.clk, reset: this.reset, resetValues: {
      outputOccupied: 0,
      validElements: 0,
      framingError: 0,
    }, [
      If(inputAccepted, then: [
        If(completesPacket, then: [
          outputOccupied < 1,
          validElements <
              engine.index.zeroExtend(validElements.width) +
                  Const(1, width: validElements.width),
          framingError < isFull & ~_upstream.data.last,
        ]),
      ]),
      If(outputAccepted & ~(inputAccepted & completesPacket), then: [
        outputOccupied < 0,
      ]),
    ]);
  }
}
