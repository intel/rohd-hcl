// two translation interfaces + DTI interface
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// DTI TBU Main controller handles transactions over DTI (AXI-S)
/// in the Main direction.
///
/// Namely, sending TRANS_REQ, INV_ACK, SYNC_ACK, CONDIS_REQ.
/// and receiving TRANS_RESP{EX}, TRANS_FAULT, INV_REQ, SYNC_REQ, CONDIS_ACK.
///
/// TODO(kimmeljo): support a dynamic TDEST for sending...
class DtiTbuMainController extends Module {
  /// Clock and reset.
  late final Axi5SystemInterface sys;

  /// Outbound DTI messages.
  late final Axi5StreamInterface toSub;

  /// Inbound DTI messages.
  late final Axi5StreamInterface fromSub;

  /// Translation requests.
  late final ReadyValidInterface<DtiTbuTransReq>? transReqSend;

  /// Invalidation ACKs.
  late final ReadyValidInterface<DtiTbuInvAck>? invAckSend;

  /// Synchronization ACKs.
  late final ReadyValidInterface<DtiTbuSyncAck>? syncAckSend;

  /// Connect/Disconnect requests.
  late final ReadyValidInterface<DtiTbuCondisReq> condisReqSend;

  // /// Translation responses.
  // /// This covers both RESP and RESPEX
  // late final ReadyValidInterface<DtiTbuTransResp>? transRespOut;

  // /// Translation faults.
  // late final ReadyValidInterface<DtiTbuTransFault>? transFaultOut;

  // /// Invalidation requests.
  // late final ReadyValidInterface<DtiTbuInvReq>? invReqOut;

  // /// Synchronization requests.
  // late final ReadyValidInterface<DtiTbuSyncReq>? syncReqOut;

  // /// Connect/Disconnects ACKs.
  // late final ReadyValidInterface<DtiTbuCondisAck>? condisAckOut;

  /// Arbitration across different message classes for
  /// sending messages out over AXI-S (toSub).
  late final Arbiter? outboundArbiter;
  final _arbiterReqs = <Logic>[];
  late int _transReqArbIdx = 0;
  late int _invSyncAckArbIdx = 0;
  late int _condisReqArbIdx = 0;

  /// Depth of FIFO for pending TRANS_REQs to send.
  late final int transReqSendFifoDepth;

  /// Depth of FIFO for pending INV_ACKs and SYNC_ACKs to send.
  late final int invSyncAckSendFifoDepth;

  /// Depth of FIFO for pending CONDIS_REQs to send.
  late final int condisReqSendFifoDepth;

  /// Fixed source ID for this module.
  ///
  /// Placed into TID signal when sending.
  /// Expected to be in TDEST signal when receiving.
  late final Logic srcId;

  /// Fixed Destination ID for this module.
  ///
  /// Placed into TDEST signal when sending.
  /// TODO(kimmeljo): allow dynamic TDEST per message?
  late final Logic destId;

  // outbound FIFOs
  late final Fifo? _outTransReqs;
  late final Fifo? _outInvSyncAcks;
  late final Fifo? _outCondisReqs;

  // track the number of outstanding translation requests
  late final Logic _transTokensGranted;
  late final Counter _transReqTokens;

  // TODO(kimmeljo): still need to deal with the receiving side...

  // manage the connection state
  late final FiniteStateMachine<DtiConnectionState> _connState;
  late final Logic _isConnected;

  /// Constructor.
  DtiTbuMainController({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface toSub,
    required Axi5StreamInterface fromSub,
    required Logic srcId,
    required Logic destId,
    required ReadyValidInterface<DtiTbuCondisReq> condisReqSend,
    ReadyValidInterface<DtiTbuTransReq>? transReqSend,
    ReadyValidInterface<DtiTbuInvAck>? invAckSend,
    ReadyValidInterface<DtiTbuSyncAck>? syncAckSend,
    this.transReqSendFifoDepth = 1,
    this.invSyncAckSendFifoDepth = 1,
    this.condisReqSendFifoDepth = 1,
    Arbiter? outboundArbiter,
    super.name = 'dtiTbuMainController',
  }) {
    this.sys = addPairInterfacePorts(sys, PairRole.consumer);
    this.toSub = addPairInterfacePorts(
      toSub,
      PairRole.provider,
      uniquify: (original) => '${name}_toSub_$original',
    );
    this.fromSub = addPairInterfacePorts(
      fromSub,
      PairRole.consumer,
      uniquify: (original) => '${name}_fromSub_$original',
    );
    if (transReqSend != null && transReqSendFifoDepth > 0) {
      this.transReqSend = addPairInterfacePorts(transReqSend, PairRole.consumer,
          uniquify: (original) => '${name}_transReqSend_$original');
    } else {
      this.transReqSend = null;
    }
    if (invAckSend != null && invSyncAckSendFifoDepth > 0) {
      this.invAckSend = addPairInterfacePorts(invAckSend, PairRole.consumer,
          uniquify: (original) => '${name}_invAckSend_$original');
    } else {
      this.invAckSend = null;
    }
    if (syncAckSend != null && invSyncAckSendFifoDepth > 0) {
      this.syncAckSend = addPairInterfacePorts(syncAckSend, PairRole.consumer,
          uniquify: (original) => '${name}_syncAckSend_$original');
    } else {
      this.syncAckSend = null;
    }
    this.condisReqSend = addPairInterfacePorts(condisReqSend, PairRole.consumer,
        uniquify: (original) => '${name}_condisReqSend_$original');

    this.srcId = addInput('srcId', srcId, width: srcId.width);
    this.destId = addInput('destId', destId, width: destId.width);

    // capture the request lines into the arbiter
    // dynamically based on which send queues are available
    var transReqArbIdx = 0;
    var invSyncAckArbIdx = 0;
    var condisReqArbIdx = 0;
    if (this.transReqSend != null && transReqSendFifoDepth > 0) {
      _arbiterReqs.add(Logic(name: 'arbiter_req_transReq'));
      transReqArbIdx = _arbiterReqs.length - 1;
    }
    if ((this.invAckSend != null || this.syncAckSend != null) &&
        invSyncAckSendFifoDepth > 0) {
      _arbiterReqs.add(Logic(name: 'arbiter_req_invSyncAck'));
      invSyncAckArbIdx = _arbiterReqs.length - 1;
    }
    _arbiterReqs.add(Logic(name: 'arbiter_req_condisReq'));
    condisReqArbIdx = _arbiterReqs.length - 1;

    if (outboundArbiter != null) {
      this.outboundArbiter = outboundArbiter;
    } else {
      this.outboundArbiter = RoundRobinArbiter(_arbiterReqs,
          clk: this.sys.clk, reset: ~this.sys.resetN);
    }

    _isConnected = Logic(name: 'isConnected');

    // FIFOs
    if (this.transReqSend != null && transReqSendFifoDepth > 0) {
      _outTransReqs = Fifo(
        this.sys.clk,
        ~this.sys.resetN,
        writeEnable: this.transReqSend!.valid,
        writeData: this.transReqSend!.data,
        readEnable: this.outboundArbiter!.grants[transReqArbIdx] &
            (toSub.valid & (toSub.ready ?? Const(1))),
        depth: transReqSendFifoDepth,
        generateOccupancy: true,
        generateError: true,
        name: 'outTransReqsFifo',
      );
      _arbiterReqs[transReqArbIdx] <= ~_outTransReqs!.empty;

      // must have translation tokens to spare
      this.transReqSend!.ready <=
          ~_outTransReqs!.full & _isConnected & _transReqTokens.count.neq(0);
    } else {
      _outTransReqs = null;
      if (transReqSend != null) {
        this.transReqSend!.ready <= Const(0);
      }
    }
    if ((this.invAckSend != null || this.syncAckSend != null) &&
        invSyncAckSendFifoDepth > 0) {
      // if simultaneous inv + sync acks, inv ack gets priority
      final invSyncFifoDataWidth =
          max(DtiTbuInvAck.totalWidth, DtiTbuSyncAck.totalWidth);
      _outInvSyncAcks = Fifo(
        this.sys.clk,
        ~this.sys.resetN,
        writeEnable: (this.invAckSend?.valid ?? Const(0)) |
            (this.syncAckSend?.valid ?? Const(0)),
        writeData: mux(
            this.invAckSend?.valid ?? Const(0),
            this.invAckSend?.data.zeroExtend(invSyncFifoDataWidth) ??
                Const(0, width: invSyncFifoDataWidth),
            this.syncAckSend?.data.zeroExtend(invSyncFifoDataWidth) ??
                Const(0, width: invSyncFifoDataWidth)),
        readEnable: this.outboundArbiter!.grants[invSyncAckArbIdx] &
            (toSub.valid & (toSub.ready ?? Const(1))),
        depth: invSyncAckSendFifoDepth,
        generateOccupancy: true,
        generateError: true,
        name: 'outInvSyncAckFifo',
      );
      _arbiterReqs[invSyncAckArbIdx] <= ~_outInvSyncAcks!.empty;
      this.invAckSend!.ready <= ~_outInvSyncAcks!.full & _isConnected;
      this.syncAckSend!.ready <=
          ~_outInvSyncAcks!.full &
              _isConnected &
              ~(this.invAckSend?.valid ?? Const(0));
    } else {
      _outInvSyncAcks = null;
      if (invAckSend != null) {
        this.invAckSend!.ready <= Const(0);
      }
      if (syncAckSend != null) {
        this.syncAckSend!.ready <= Const(0);
      }
    }
    _outCondisReqs = Fifo(
      this.sys.clk,
      ~this.sys.resetN,
      writeEnable: this.condisReqSend.valid,
      writeData: this.condisReqSend.data,
      readEnable: this.outboundArbiter!.grants[condisReqArbIdx] &
          (toSub.valid & (toSub.ready ?? Const(1))),
      depth: condisReqSendFifoDepth,
      generateOccupancy: true,
      generateError: true,
      name: 'outCondisReqsFifo',
    );
    _arbiterReqs[condisReqArbIdx] <= ~_outCondisReqs!.empty;
    this.condisReqSend.ready <= ~_outCondisReqs!.full;

    // connState + tokens
    _transReqTokens =
        TODO; // Counter.updn, disable when transReq goes out, enable when transResp/Fault comes back, seed back tokensGranted
    _transTokensGranted = Logic(
        name: 'transTokensGranted', width: DtiTbuCondisAck.tokTransGntWidth);

    // Connection state machine
    final connIn = condisReqSend.accepted & condisReqSend.data.state.eq(1);
    final disconnIn = condisReqSend.accepted & condisReqSend.data.state.eq(1);
    _connState = FiniteStateMachine<DtiConnectionState>(
      this.sys.clk,
      ~this.sys.resetN,
      DtiConnectionState.unconnected,
      [
        // UNCONNECTED: move to PENDINGCONN when the 1st condis connect request
        //  goes out on AXI-S
        State(
          DtiConnectionState.unconnected,
          events: {
            connIn: DtiConnectionState.pendingConn,
          },
          actions: [],
        ),
        // PENDINGCONN: move to CONNECTED when an ACK comes in that confirms
        //  connenction move back to UNCONNECTED when an ACK comes in that
        //  rejects connection
        State(
          DtiConnectionState.pendingConn,
          events: {
            TODO: DtiConnectionState.connected,
            TODO: DtiConnectionState.unconnected
          },
          actions: [],
        ),
        // CONNECTED:
        //  move to PENDINGDISCON when we get a disconnect request in.
        State(DtiConnectionState.connected,
            events: {disconnIn: DtiConnectionState.pendingDisconn},
            actions: []),
        // PENDINGIDSCONN:
        //  move to UNCONNECTED when an ACK comes in that confirms disconnenction
        //  move back CONNECTED when an ACK comes in that rejects disconnection
        State(
          DtiConnectionState.pendingDisconn,
          events: {
            TODO: DtiConnectionState.connected,
            TODO: DtiConnectionState.unconnected
          },
          actions: [],
        ),
      ],
    );

    _build();
  }

  void _build() {
    // are we in a connected state
    _isConnected <=
        _connState.currentState
            .eq(
              Const(
                DtiConnectionState.connected.index,
                width: _connState.currentState.width,
              ),
            )
            .named('isConnected');

    // grab the maximum outbound message size
    final maxOutMsgSize = [
      if (transReqSend != null) DtiTbuTransReq.totalWidth,
      if (invAckSend != null) DtiTbuInvAck.totalWidth,
      if (syncAckSend != null) DtiTbuSyncAck.totalWidth,
      DtiTbuCondisReq.totalWidth
    ].reduce(max);

    // examine arbiter to understand what data queue we should pull from
    // flop this moving forward
    final dataToSendCases = <Logic, Logic>{};
    if (transReqSend != null && transReqSendFifoDepth > 0) {
      dataToSendCases[Const(toOneHot(_transReqArbIdx, _arbiterReqs.length))] =
          _outTransReqs!.readData.zeroExtend(maxOutMsgSize);
    }
    if ((invAckSend != null || syncAckSend != null) &&
        invSyncAckSendFifoDepth > 0) {
      dataToSendCases[Const(toOneHot(_transReqArbIdx, _arbiterReqs.length))] =
          _outInvSyncAcks!.readData.zeroExtend(maxOutMsgSize);
    }
    dataToSendCases[Const(toOneHot(_condisReqArbIdx, _arbiterReqs.length))] =
        _outCondisReqs!.readData.zeroExtend(maxOutMsgSize);
    final dataToSend = cases(
        _arbiterReqs.swizzle(),
        conditionalType: ConditionalType.unique,
        dataToSendCases,
        defaultValue: Const(0, width: maxOutMsgSize));

    // (potentially) must break the message out over multiple beats
    final dataEn = _arbiterReqs.swizzle().or();
    if (maxOutMsgSize > toSub.dataWidth) {
      // determine how many beats we need
      // TODO(kimmeljo): dynamic based on message type??
      final numBeats = (maxOutMsgSize / toSub.dataWidth).ceil();
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
          flop(sys.clk, dataEn, en: acceptNextSend, reset: ~sys.resetN)
              .named('nextOutDataEn');
      final nextOutData =
          flop(sys.clk, dataToSend, en: acceptNextSend, reset: ~sys.resetN)
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
              nextOutDataEn: DtiStreamBeatState.working,
            },
            actions: [],
          ),
          // WORKING: move to IDLE when we are done sending.
          // but only if there isn't another send immediately following
          State(DtiStreamBeatState.working, events: {
            acceptNextSend & dataEn: DtiStreamBeatState.idle,
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
        final end = min(toSub.dataWidth * (i + 1), maxOutMsgSize);
        nextDataToSendCases[Const(i, width: beatCounter.count.width)] =
            nextOutData.getRange(start, end);
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
    }
    // single beat will suffice to send the message
    else {
      final sendIdle = Logic(name: 'sendIdle');
      final acceptNextSend = sendIdle | (toSub.ready ?? Const(1));
      final nextOutDataEn =
          flop(sys.clk, dataEn, en: acceptNextSend, reset: ~sys.resetN)
              .named('nextOutDataEn');
      final nextOutData =
          flop(sys.clk, dataToSend, en: acceptNextSend, reset: ~sys.resetN)
              .named('nextOutData');
      sendIdle <= ~nextOutDataEn;

      toSub.valid <= nextOutDataEn;
      toSub.data! <= nextOutData;
      if (toSub.useLast) {
        toSub.last! <= Const(1);
      }
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
      toSub.user! <= Const(0, width: toSub.strbWidth);
    }
    if (toSub.useWakeup) {
      toSub.wakeup! <= Const(1);
    }
  }
}
