// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi_s_interface_tx.dart
// HW to send arbitrary messages over AXI-S.
//
// 2025 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A generic module to send messages over AXI-S.
class AxiStreamInterfaceTx extends Module {
  /// Clock and reset.
  @protected
  late final Axi5SystemInterface sys;

  /// Outbound messages.
  @protected
  late final Axi5StreamInterface stream;

  /// Is the provided [msgToSend] valid.
  ///
  /// Only drive on the interface if so.
  @protected
  late final Logic msgToSendValid;

  /// Message to transmit on the interface.
  @protected
  late final Logic msgToSend;

  /// AXI-S Destination ID for this message.
  ///
  /// Placed into TDEST signal when sending.
  @protected
  late final Logic? msgDestId;

  /// AXI-S User field for this message.
  ///
  /// Placed into TUSER signal when sending.
  @protected
  late final Logic? msgUser;

  /// AXI-S strobe field for this message.
  ///
  /// Placed into TSTRB signal when sending.
  @protected
  late final Logic? msgStrb;

  /// AXI-S keep field for this message.
  ///
  /// Placed into TKEEP signal when sending.
  @protected
  late final Logic? msgKeep;

  /// Fixed source ID for this module.
  ///
  /// Placed into TID signal when sending.
  /// Expected to be in TDEST signal when receiving.
  @protected
  late final Logic? srcId;

  /// Fixed wakeup for this module.
  ///
  /// Placed into TWAKEUP signal when sending.
  /// Power management functionality.
  @protected
  late final Logic? wakeup;

  /// Backpressure indicator.
  Logic get canAcceptMsg => output('canAcceptMsg');

  /// Constructor.
  AxiStreamInterfaceTx({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface stream,
    required Logic msgToSendValid,
    required Logic msgToSend,
    Logic? srcId,
    Logic? wakeup,
    Logic? msgDestId,
    Logic? msgUser,
    Logic? msgStrb,
    Logic? msgKeep,
    super.name = 'axiStreamInterfaceTx',
  }) {
    this.sys = addPairInterfacePorts(sys, PairRole.consumer);
    this.stream = addPairInterfacePorts(
      stream,
      PairRole.provider,
      uniquify: (original) => '${name}_stream_$original',
    );
    this.msgToSendValid =
        addInput('msgToSendValid', msgToSendValid, width: msgToSendValid.width);
    this.msgToSend = addInput('msgToSend', msgToSend, width: msgToSend.width);

    // global drivers
    if (stream.idWidth > 0 && srcId != null) {
      this.srcId = addInput('srcId', srcId, width: srcId.width);
    } else {
      this.srcId = null;
    }
    if (stream.useWakeup && wakeup != null) {
      this.wakeup = addInput('wakeup', wakeup);
    } else {
      this.wakeup = null;
    }

    // per message drivers
    if (stream.destWidth > 0 && msgDestId != null) {
      this.msgDestId = addInput('destId', msgDestId, width: msgDestId.width);
    } else {
      this.msgDestId = null;
    }
    if (stream.userWidth > 0 && msgUser != null) {
      this.msgUser = addInput('user', msgUser, width: msgUser.width);
    } else {
      this.msgUser = null;
    }
    if (stream.useStrb && msgStrb != null) {
      this.msgStrb = addInput('strb', msgStrb, width: msgStrb.width);
    } else {
      this.msgStrb = null;
    }
    if (stream.useKeep && msgKeep != null) {
      this.msgKeep = addInput('keep', msgKeep, width: msgKeep.width);
    } else {
      this.msgKeep = null;
    }

    addOutput('canAcceptMsg');

    _build();
  }

  void _build() {
    // case (1): must break the message up over multiple beats
    if (msgToSend.width > stream.dataWidth) {
      // determine how many beats we need
      final numBeats = (msgToSend.width / stream.dataWidth).ceil();
      final sendIdle = Logic(name: 'sendIdle');

      // must count as we're sending the message across multiple beats
      // but restart the count once we're done sending
      final countEnable = stream.valid & (stream.ready ?? Const(1));
      final acceptNextSend =
          sendIdle | (countEnable & (stream.last ?? Const(1)));
      final beatCounter = Counter.simple(
          clk: sys.clk,
          reset: ~sys.resetN,
          enable: countEnable,
          restart: acceptNextSend,
          width: numBeats.bitLength);

      // capture the next message to send
      final nextOutDataEn =
          flop(sys.clk, msgToSendValid, en: acceptNextSend, reset: ~sys.resetN)
              .named('nextOutDataEn');
      final nextOutData =
          flop(sys.clk, msgToSend, en: acceptNextSend, reset: ~sys.resetN)
              .named('nextOutData');

      // FSM to track the sending progress
      final sendState = FiniteStateMachine<AxiStreamBeatState>(
        sys.clk,
        ~sys.resetN,
        AxiStreamBeatState.idle,
        [
          // IDLE: move to WORKING when something new to send comes in
          State(
            AxiStreamBeatState.idle,
            events: {
              msgToSendValid & acceptNextSend: AxiStreamBeatState.working,
            },
            actions: [],
          ),
          // WORKING: move to IDLE when we are done sending.
          // but only if there isn't another send immediately following
          State(AxiStreamBeatState.working, events: {
            acceptNextSend & ~msgToSendValid: AxiStreamBeatState.idle,
          }, actions: []),
        ],
      );
      sendIdle <= sendState.currentState.eq(AxiStreamBeatState.idle.index);

      // pick the appropriate slice of the message bits to send
      // based on the current beat count
      final nextDataToSendCases = <Logic, Logic>{};
      for (var i = 0; i < numBeats; i++) {
        final start = stream.dataWidth * i;
        final end = min(stream.dataWidth * (i + 1), msgToSend.width);
        nextDataToSendCases[Const(i, width: beatCounter.count.width)] =
            nextOutData.getRange(start, end).zeroExtend(stream.dataWidth);
      }
      final slicedNextDataToSend = cases(
          beatCounter.count,
          conditionalType: ConditionalType.unique,
          nextDataToSendCases,
          defaultValue: Const(0, width: stream.dataWidth));

      // drive the interface
      stream.valid <= nextOutDataEn & ~sendIdle;
      stream.data! <= slicedNextDataToSend;
      if (stream.useLast) {
        stream.last! <= beatCounter.count.eq(numBeats - 1);
      }

      if (stream.destWidth > 0) {
        final nextOutDest = flop(
                sys.clk,
                (msgDestId ?? Const(0, width: stream.destWidth))
                    .zeroExtend(stream.destWidth),
                en: acceptNextSend,
                reset: ~sys.resetN)
            .named('nextOutDest');
        stream.dest! <= nextOutDest;
      }
      if (stream.userWidth > 0) {
        final nextOutUser = flop(
                sys.clk,
                (msgUser ?? Const(0, width: stream.userWidth))
                    .zeroExtend(stream.userWidth),
                en: acceptNextSend,
                reset: ~sys.resetN)
            .named('nextOutUser');
        stream.user! <= nextOutUser;
      }

      if (stream.useStrb && msgStrb != null) {
        final nextOutStrb =
            flop(sys.clk, msgStrb!, en: acceptNextSend, reset: ~sys.resetN)
                .named('nextOutStrb');
        final nextStrbToSendCases = <Logic, Logic>{};
        for (var i = 0; i < numBeats; i++) {
          final start = stream.strbWidth * i;
          final end = min(stream.strbWidth * (i + 1), msgStrb!.width);
          nextStrbToSendCases[Const(i, width: beatCounter.count.width)] =
              nextOutStrb.getRange(start, end).zeroExtend(stream.strbWidth);
        }
        final slicedNextStrbToSend = cases(
            beatCounter.count,
            conditionalType: ConditionalType.unique,
            nextStrbToSendCases,
            defaultValue: ~Const(0, width: stream.strbWidth));
        stream.strb! <= slicedNextStrbToSend;
      } else {
        stream.strb?.gets(~Const(0, width: stream.strbWidth));
      }

      if (stream.useKeep && msgKeep != null) {
        final nextOutKeep =
            flop(sys.clk, msgKeep!, en: acceptNextSend, reset: ~sys.resetN)
                .named('nextOutKeep');
        final nextKeepToSendCases = <Logic, Logic>{};
        for (var i = 0; i < numBeats; i++) {
          final start = stream.strbWidth * i;
          final end = min(stream.strbWidth * (i + 1), msgKeep!.width);
          nextKeepToSendCases[Const(i, width: beatCounter.count.width)] =
              nextOutKeep.getRange(start, end).zeroExtend(stream.strbWidth);
        }
        final slicedNextKeepToSend = cases(
            beatCounter.count,
            conditionalType: ConditionalType.unique,
            nextKeepToSendCases,
            defaultValue: ~Const(0, width: stream.strbWidth));
        stream.keep! <= slicedNextKeepToSend;
      } else {
        stream.keep?.gets(~Const(0, width: stream.strbWidth));
      }

      canAcceptMsg <= acceptNextSend;
    }
    // case (2): single beat will suffice to send the message
    else {
      final sendIdle = Logic(name: 'sendIdle');
      final acceptNextSend = sendIdle | (stream.ready ?? Const(1));
      final nextOutDataEn =
          flop(sys.clk, msgToSendValid, en: acceptNextSend, reset: ~sys.resetN)
              .named('nextOutDataEn');
      final nextOutData = flop(sys.clk, msgToSend.zeroExtend(stream.dataWidth),
              en: acceptNextSend, reset: ~sys.resetN)
          .named('nextOutData');
      sendIdle <= ~nextOutDataEn;

      stream.valid <= nextOutDataEn;
      stream.data! <= nextOutData;
      if (stream.useLast) {
        stream.last! <= Const(1);
      }
      if (stream.destWidth > 0) {
        final nextOutDest = flop(
                sys.clk,
                (msgDestId ?? Const(0, width: stream.destWidth))
                    .zeroExtend(stream.destWidth),
                en: acceptNextSend,
                reset: ~sys.resetN)
            .named('nextOutDest');
        stream.dest! <= nextOutDest;
      }
      if (stream.userWidth > 0) {
        final nextOutUser = flop(
                sys.clk,
                (msgUser ?? Const(0, width: stream.userWidth))
                    .zeroExtend(stream.userWidth),
                en: acceptNextSend,
                reset: ~sys.resetN)
            .named('nextOutUser');
        stream.user! <= nextOutUser;
      }
      if (stream.useStrb) {
        final nextOutStrb = flop(
                sys.clk,
                (msgStrb ?? ~Const(0, width: stream.strbWidth))
                    .zeroExtend(stream.strbWidth),
                en: acceptNextSend,
                reset: ~sys.resetN)
            .named('nextOutStrb');
        stream.strb! <= nextOutStrb;
      }
      if (stream.useKeep) {
        final nextOutKeep = flop(
                sys.clk,
                (msgKeep ?? ~Const(0, width: stream.strbWidth))
                    .zeroExtend(stream.strbWidth),
                en: acceptNextSend,
                reset: ~sys.resetN)
            .named('nextOutKeep');
        stream.keep! <= nextOutKeep;
      }

      canAcceptMsg <= acceptNextSend;
    }

    // unconditionally driven signals on the outbound stream
    if (stream.idWidth > 0) {
      stream.id! <= (srcId ?? Const(0, width: stream.idWidth));
    }
    if (stream.useWakeup) {
      stream.wakeup! <= (wakeup ?? Const(1));
    }
  }
}
