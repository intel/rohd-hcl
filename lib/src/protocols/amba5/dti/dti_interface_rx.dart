import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A generic module to send DTI messages over AXI-S.
class DtiInterfaceRx extends Module {
  /// Clock and reset.
  late final Axi5SystemInterface sys;

  /// Inbound DTI messages.
  late final Axi5StreamInterface fromSub;

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
  late final Logic srcId;

  /// New message received indicator.
  Logic get msgValid => output('msgValid');

  /// New message received.
  Logic get msg => output('msg');

  /// Constructor.
  DtiInterfaceRx({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface fromSub,
    required Logic canAcceptMsg,
    required Logic srcId,
    required this.maxMsgRxSize,
    super.name = 'dtiInterfaceRx',
  }) {
    this.sys = addPairInterfacePorts(sys, PairRole.consumer);
    this.fromSub = addPairInterfacePorts(
      fromSub,
      PairRole.consumer,
      uniquify: (original) => '${name}_fromSub_$original',
    );
    this.canAcceptMsg =
        addInput('canAcceptMsg', canAcceptMsg, width: canAcceptMsg.width);
    this.srcId = addInput('srcId', srcId, width: srcId.width);

    addOutput('msgValid');
    addOutput('msg', width: maxMsgRxSize);

    _build();
  }

  void _build() {
    // max # of beats we could possibly expect for a single message
    final numBeats = (maxMsgRxSize / fromSub.dataWidth).ceil();

    // conditions under which we should capture/forward flits
    final idHit = (fromSub.destWidth > 0 ? srcId.eq(fromSub.dest) : Const(1));
    final inAccept = fromSub.valid & (fromSub.ready ?? Const(1)) & idHit;
    final inLast = inAccept & idHit & (fromSub.last ?? Const(1));

    // case 1: every message can be captured in a single beat
    // simplify the HW
    if (numBeats == 1) {
      msgValid <= inLast;
      msg <= fromSub.data!.getRange(0, maxMsgRxSize);
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
        msgFlits.add(Logic(name: 'inBeats$i', width: fromSub.dataWidth));
        Sequential(sys.clk, reset: ~sys.resetN, [
          msgFlits[i] <
              mux(inAccept & beatCounter.count.eq(i), fromSub.data!,
                  msgFlits[i])
        ]);
      }

      // the last flit comes straight from the interface
      // for performance
      msgValid <= inLast;
      msg <= [...msgFlits, fromSub.data!].rswizzle().getRange(0, maxMsgRxSize);
    }

    // drive TREADY
    if (fromSub.ready != null) {
      fromSub.ready! <= canAcceptMsg;
    }
  }
}
