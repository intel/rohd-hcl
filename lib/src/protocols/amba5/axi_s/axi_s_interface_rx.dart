// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi_s_interface_rx.dart
// HW to receive arbitrary messages over AXI-S.
//
// 2025 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A generic module to receive messages over AXI-S.
class AxiStreamInterfaceRx extends Module {
  /// Clock and reset.
  late final Axi5SystemInterface sys;

  /// Inbound messages.
  late final Axi5StreamInterface stream;

  /// The maximum size of any message we expect
  /// to receive over the AXI-S interface.
  late final int maxMsgRxSize;

  /// Can we accept a new message.
  ///
  /// This effectively drives TREADY.
  late final Logic canAcceptMsg;

  /// Fixed source ID for this module.
  ///
  /// Received in TDEST signal.
  /// Drop if doesn't match.
  late final Logic? srcId;

  /// New message received indicator.
  Logic get msgValid => output('msgValid');

  /// New message received.
  Logic get msg => output('msg');

  /// New message's source over AXI.
  Logic? get msgSrc => output('msgSrc');

  /// New message's user field over AXI.
  Logic? get msgUser => output('msgUser');

  /// New message's strobe field over AXI.
  Logic? get msgStrb => output('msgStrb');

  /// New message's kep field over AXI.
  Logic? get msgKeep => output('msgKeep');

  /// Constructor.
  AxiStreamInterfaceRx({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface stream,
    required Logic canAcceptMsg,
    required this.maxMsgRxSize,
    Logic? srcId,
    super.name = 'axiStreamInterfaceRx',
  }) {
    this.sys = addPairInterfacePorts(sys, PairRole.consumer);
    this.stream = addPairInterfacePorts(
      stream,
      PairRole.consumer,
      uniquify: (original) => '${name}_stream_$original',
    );
    this.canAcceptMsg =
        addInput('canAcceptMsg', canAcceptMsg, width: canAcceptMsg.width);
    if (srcId != null) {
      this.srcId = addInput('srcId', srcId, width: srcId.width);
    } else {
      this.srcId = null;
    }

    addOutput('msgValid');
    addOutput('msg', width: maxMsgRxSize);
    if (stream.idWidth > 0) {
      addOutput('msgSrc', width: stream.idWidth);
    }
    if (stream.userWidth > 0) {
      addOutput('msgUser', width: stream.userWidth);
    }
    if (stream.useStrb) {
      addOutput('msgStrb', width: maxMsgRxSize ~/ 8);
    }
    if (stream.useKeep) {
      addOutput('msgKeep', width: maxMsgRxSize ~/ 8);
    }

    _build();
  }

  void _build() {
    // max # of beats we could possibly expect for a single message
    final numBeats = (maxMsgRxSize / stream.dataWidth).ceil();

    // conditions under which we should capture/forward flits
    final idHit = (stream.destWidth > 0
        ? (srcId?.eq(stream.dest) ?? Const(1))
        : Const(1));
    final inAccept = stream.valid & (stream.ready ?? Const(1)) & idHit;
    final inLast = inAccept & idHit & (stream.last ?? Const(1));

    // handle TWAKEUP if present
    final isAwake = Logic(name: 'isAwake');
    if (stream.useWakeup) {
      isAwake <= flop(sys.clk, stream.wakeup ?? Const(1), reset: ~sys.resetN);
    } else {
      isAwake <= Const(1); // always awake
    }

    // case 1: every message can be captured in a single beat
    // simplify the HW
    if (numBeats == 1) {
      msgValid <= inLast & isAwake;
      msg <= stream.data!.getRange(0, maxMsgRxSize);
      if (stream.useStrb) {
        msgStrb?.gets(stream.strb?.getRange(0, maxMsgRxSize ~/ 8) ??
            ~Const(0, width: maxMsgRxSize ~/ 8));
      }
      if (stream.useKeep) {
        msgKeep?.gets(stream.keep?.getRange(0, maxMsgRxSize ~/ 8) ??
            ~Const(0, width: maxMsgRxSize ~/ 8));
      }
    }
    // case 2: message might come in over multiple beats
    else {
      // count the number of beats in a given message
      // restart whenever we see a TLAST
      final beatCounter = Counter.simple(
          clk: sys.clk,
          reset: ~sys.resetN,
          enable: inAccept,
          restart: inLast,
          width: numBeats.bitLength);

      // capture the individual beats of the message
      // and store them for assembly later
      final msgFlits = <Logic>[];
      for (var i = 0; i < numBeats - 1; i++) {
        msgFlits.add(Logic(name: 'inBeats$i', width: stream.dataWidth));
        Sequential(sys.clk, reset: ~sys.resetN, [
          msgFlits[i] <
              mux(inAccept & beatCounter.count.eq(i), stream.data!, msgFlits[i])
        ]);
      }

      // must select the correct arrangement of flits
      final priorFlitsCases = <Logic, Logic>{};
      for (var i = 0; i < numBeats; i++) {
        priorFlitsCases[Const(i, width: beatCounter.count.width)] = [
          ...msgFlits.sublist(0, i),
          stream.data!,
          ...msgFlits.sublist(i),
        ].rswizzle();
      }
      final priorFlits = cases(
        beatCounter.count,
        conditionalType: ConditionalType.unique,
        priorFlitsCases,
        defaultValue: Const(0, width: numBeats * stream.dataWidth),
      );

      // handle strobes
      if (stream.useStrb) {
        final msgStrbs = <Logic>[];
        for (var i = 0; i < numBeats - 1; i++) {
          msgStrbs.add(Logic(name: 'inStrbs$i', width: stream.strbWidth));
          Sequential(sys.clk, reset: ~sys.resetN, [
            msgStrbs[i] <
                mux(inAccept & beatCounter.count.eq(i), stream.strb!,
                    msgStrbs[i])
          ]);
        }
        final priorStrbsCases = <Logic, Logic>{};
        for (var i = 0; i < numBeats; i++) {
          priorStrbsCases[Const(i, width: beatCounter.count.width)] = [
            ...msgStrbs.sublist(0, i),
            stream.strb!,
            ...msgStrbs.sublist(i),
          ].rswizzle();
        }
        final priorStrbs = cases(
          beatCounter.count,
          conditionalType: ConditionalType.unique,
          priorStrbsCases,
          defaultValue: ~Const(0, width: numBeats * stream.strbWidth),
        );
        msgStrb?.gets(priorStrbs.getRange(0, maxMsgRxSize ~/ 8));
      }

      // handle keeps
      if (stream.useKeep) {
        final msgKeeps = <Logic>[];
        for (var i = 0; i < numBeats - 1; i++) {
          msgKeeps.add(Logic(name: 'inKeeps$i', width: stream.strbWidth));
          Sequential(sys.clk, reset: ~sys.resetN, [
            msgKeeps[i] <
                mux(inAccept & beatCounter.count.eq(i), stream.keep!,
                    msgKeeps[i])
          ]);
        }
        final priorKeepsCases = <Logic, Logic>{};
        for (var i = 0; i < numBeats; i++) {
          priorKeepsCases[Const(i, width: beatCounter.count.width)] = [
            ...msgKeeps.sublist(0, i),
            stream.keep!,
            ...msgKeeps.sublist(i),
          ].rswizzle();
        }
        final priorKeeps = cases(
          beatCounter.count,
          conditionalType: ConditionalType.unique,
          priorKeepsCases,
          defaultValue: ~Const(0, width: numBeats * stream.strbWidth),
        );
        msgKeep?.gets(priorKeeps.getRange(0, maxMsgRxSize ~/ 8));
      }

      // the last flit comes straight from the interface
      // for performance
      msgValid <= inLast & isAwake;
      msg <= priorFlits.getRange(0, maxMsgRxSize);
    }

    // drive TREADY
    if (stream.ready != null) {
      stream.ready! <= canAcceptMsg;
    }

    // TID and TUSER must hold constant for a single stream message
    // and message beats cannot be interleaved
    // so it is safe to just grab the source directly from the interface
    msgSrc?.gets(stream.id ?? Const(0, width: stream.idWidth));
    if (stream.userWidth > 0) {
      msgUser?.gets(stream.user ?? Const(0, width: stream.userWidth));
    }
  }
}
