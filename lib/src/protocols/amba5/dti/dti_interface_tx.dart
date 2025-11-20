// two translation interfaces + DTI interface
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A generic module to send DTI messages over AXI-S.
class DtiInterfaceTx extends Module {
  /// Clock and reset.
  late final Axi5SystemInterface sys;

  /// Outbound DTI messages.
  late final Axi5StreamInterface toSub;

  /// Is the provided [msgToSend] valid.
  ///
  /// Only drive on the interface if so.
  late final Logic msgToSendValid;

  /// DTI message to transmit on the interface.
  late final Logic msgToSend;

  /// Fixed source ID for this module.
  ///
  /// Placed into TID signal when sending.
  /// Expected to be in TDEST signal when receiving.
  late final Logic srcId;

  /// Fixed Destination ID for this module.
  ///
  /// Placed into TDEST signal when sending.
  late final Logic destId;

  /// Backpressure indicator.
  Logic get msgAccepted => output('msgAccepted');

  /// Constructor.
  DtiInterfaceTx({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface toSub,
    required Logic msgToSendValid,
    required Logic msgToSend,
    required Logic srcId,
    required Logic destId,
    super.name = 'dtiInterfaceTx',
  }) {
    this.sys = addPairInterfacePorts(sys, PairRole.consumer);
    this.toSub = addPairInterfacePorts(
      toSub,
      PairRole.provider,
      uniquify: (original) => '${name}_toSub_$original',
    );
    this.msgToSendValid =
        addInput('msgToSendValid', msgToSendValid, width: msgToSendValid.width);
    this.msgToSend = addInput('msgToSend', msgToSend, width: msgToSend.width);
    this.srcId = addInput('srcId', srcId, width: srcId.width);
    this.destId = addInput('destId', destId, width: destId.width);

    addOutput('msgAccepted');

    _build();
  }

  void _build() {
    // case (1): must break the message up over multiple beats
    // TODO(kimmeljo): try to make this dynamic over time??
    if (msgToSend.width > toSub.dataWidth) {
      // determine how many beats we need
      final numBeats = (msgToSend.width / toSub.dataWidth).ceil();
      final sendIdle = Logic(name: 'sendIdle');

      // must count as we're sending the message across multiple beats
      // but restart the count once we're done sending
      final countEnable = toSub.valid & (toSub.ready ?? Const(1));
      final acceptNextSend =
          sendIdle | (countEnable & (toSub.last ?? Const(1)));
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
      final sendState = FiniteStateMachine<DtiStreamBeatState>(
        sys.clk,
        ~sys.resetN,
        DtiStreamBeatState.idle,
        [
          // IDLE: move to WORKING when something new to send comes in
          State(
            DtiStreamBeatState.idle,
            events: {
              msgToSendValid & acceptNextSend: DtiStreamBeatState.working,
            },
            actions: [],
          ),
          // WORKING: move to IDLE when we are done sending.
          // but only if there isn't another send immediately following
          State(DtiStreamBeatState.working, events: {
            acceptNextSend & msgToSendValid: DtiStreamBeatState.idle,
          }, actions: []),
        ],
      );
      sendIdle <=
          sendState.currentState.eq(DtiConnectionState.unconnected.index);

      // pick the appropriate slice of the message bits to send
      // based on the current beat count
      final nextDataToSendCases = <Logic, Logic>{};
      for (var i = 0; i < numBeats; i++) {
        final start = toSub.dataWidth * i;
        final end = min(toSub.dataWidth * (i + 1), msgToSend.width);
        nextDataToSendCases[Const(i, width: beatCounter.count.width)] =
            nextOutData.getRange(start, end).zeroExtend(toSub.dataWidth);
      }
      final slicedNextDataToSend = cases(
          beatCounter.count,
          conditionalType: ConditionalType.unique,
          nextDataToSendCases,
          defaultValue: Const(0, width: toSub.dataWidth));

      // drive the interface
      toSub.valid <= nextOutDataEn & ~sendIdle;
      toSub.data! <= slicedNextDataToSend;
      if (toSub.useLast) {
        toSub.last! <= beatCounter.count.eq(numBeats - 1);
      }

      msgAccepted <= acceptNextSend;
    }
    // case (2): single beat will suffice to send the message
    else {
      final sendIdle = Logic(name: 'sendIdle');
      final acceptNextSend = sendIdle | (toSub.ready ?? Const(1));
      final nextOutDataEn =
          flop(sys.clk, msgToSendValid, en: acceptNextSend, reset: ~sys.resetN)
              .named('nextOutDataEn');
      final nextOutData = flop(sys.clk, msgToSend.zeroExtend(toSub.dataWidth),
              en: acceptNextSend, reset: ~sys.resetN)
          .named('nextOutData');
      sendIdle <= ~nextOutDataEn;

      toSub.valid <= nextOutDataEn;
      toSub.data! <= nextOutData;
      if (toSub.useLast) {
        toSub.last! <= Const(1);
      }

      msgAccepted <= acceptNextSend;
    }

    // unconditionally driven signals on the outbound stream
    // TODO(kimmeljo): any use for TSTRB or TKEEP??
    // TODO(kimmeljo): provide a hook into TUSER??
    // TODO(kimmeljo): provide a hook into TWAKEUP??
    if (toSub.idWidth > 0) {
      toSub.id! <= srcId;
    }
    if (toSub.destWidth > 0) {
      toSub.dest! <= destId;
    }
    if (toSub.useKeep) {
      toSub.keep! <= ~Const(0, width: toSub.strbWidth);
    }
    if (toSub.useStrb) {
      toSub.strb! <= ~Const(0, width: toSub.strbWidth);
    }
    if (toSub.userWidth > 0) {
      toSub.user! <= Const(0, width: toSub.userWidth);
    }
    if (toSub.useWakeup) {
      toSub.wakeup! <= Const(1);
    }
  }
}
