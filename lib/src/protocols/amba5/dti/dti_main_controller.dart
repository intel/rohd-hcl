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
    final arbiterReqs = <Logic>[];
    var transReqArbIdx = 0;
    var invSyncAckArbIdx = 0;
    var condisReqArbIdx = 0;
    if (this.transReqSend != null && transReqSendFifoDepth > 0) {
      arbiterReqs.add(Logic(name: 'arbiter_req_transReq'));
      transReqArbIdx = arbiterReqs.length - 1;
    }
    if ((this.invAckSend != null || this.syncAckSend != null) &&
        invSyncAckSendFifoDepth > 0) {
      arbiterReqs.add(Logic(name: 'arbiter_req_invSyncAck'));
      invSyncAckArbIdx = arbiterReqs.length - 1;
    }
    arbiterReqs.add(Logic(name: 'arbiter_req_condisReq'));
    condisReqArbIdx = arbiterReqs.length - 1;

    if (outboundArbiter != null) {
      this.outboundArbiter = outboundArbiter;
    } else {
      this.outboundArbiter = RoundRobinArbiter(arbiterReqs,
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
      arbiterReqs[transReqArbIdx] <= ~_outTransReqs!.empty;

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
      arbiterReqs[invSyncAckArbIdx] <= ~_outInvSyncAcks!.empty;
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
    arbiterReqs[condisReqArbIdx] <= ~_outCondisReqs!.empty;
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

    final isUnconnected = _connState.currentState
        .eq(
          Const(
            DtiConnectionState.unconnected.index,
            width: _connState.currentState.width,
          ),
        )
        .named('isUnconnected');
    final transCreditLimitReached = _outgoingReqs.occupancy!
        .zeroExtend(transTokenGrant.width)
        .gte(transTokenGrant)
        .named('transCreditLimitReached');

    // round robin arbitration b/w translation requests and IRQs
    // these can happen simultaneously
    final transIrqArbiter = RoundRobinArbiter(
      [fromCache.valid, fromMsi.valid],
      clk: sys.clk,
      reset: ~sys.resetN,
      name: 'transIrqArbiter',
    );
    final gntCache = transIrqArbiter.grants[0];
    final gntMsi = transIrqArbiter.grants[1];

    // incoming translation/IRQ requests
    // must simulatenously convert them into the appropriate DTI structures
    _outgoingReqsWrEn <=
        isConnected &
            ~transCreditLimitReached &
            ~_outgoingReqs.full &
            (fromCache.valid | fromMsi.valid);
    _outgoingReqsWrData <=
        mux(
          gntCache,
          fromCache.data.payload.zeroExtend(_outgoingReqs.dataWidth),
          fromMsi.data.payload.zeroExtend(_outgoingReqs.dataWidth),
        );
    _outgoingReqsRdEn <=
        ~_outgoingReqs.empty & (toAtu.ready ?? Const(1)) & ~_invalRdEn;
    fromCache.ready <=
        isConnected &
            ~transCreditLimitReached &
            ~_outgoingReqs.full &
            mux(fromMsi.valid, gntCache, Const(1));
    fromMsi.ready <=
        isConnected &
            ~transCreditLimitReached &
            ~_outgoingReqs.full &
            mux(fromCache.valid, gntMsi, Const(1));

    // incoming invalidation ack/sync
    // no arbitration needed b/c these are guaranteed to be mutually exclusive
    final invalEnSw =
        invalVtd ? invalAckVtd!.valid : (invalAck!.valid | syncAck!.valid);
    _invalWrEn <= isConnected & ~_inval.full & invalEnSw;

    final invalDataSw = invalVtd
        ? invalAckVtd!.data.payload.zeroExtend(_outgoingReqs.dataWidth)
        : mux(
            syncAck!.valid,
            syncAck!.data.payload.zeroExtend(_outgoingReqs.dataWidth),
            invalAck!.data.payload.zeroExtend(_outgoingReqs.dataWidth),
          );
    _invalWrData <= invalDataSw;

    _invalRdEn <= ~_inval.empty & (toAtu.ready ?? Const(1));

    if (invalVtd) {
      invalAckVtd!.ready <= isConnected & ~_inval.full;
    } else {
      invalAck!.ready <= isConnected & ~_inval.full;
      syncAck!.ready <= isConnected & ~_inval.full;
    }

    // invalidation/sync ACK always takes priority over translation/IRQ requests
    final outData = mux(
      ~_inval.empty,
      _inval.readData.zeroExtend(toAtu.dataWidth),
      _outgoingReqs.readData.zeroExtend(toAtu.dataWidth),
    );
    final trueOutData = mux(~isUnconnected, outData, connReq);

    // drive DTI interface
    toAtu.valid <=
        (isUnconnected | ~(_outgoingReqs.empty & _inval.empty)) &
            (toAtu.ready ?? Const(1));
    toAtu.id! <= srcId;
    toAtu.dest! <= destId;
    toAtu.data! <= trueOutData;
    toAtu.last! <= Const(1); // always 1 beat
    toAtu.keep! <= ~Const(0, width: toAtu.strbWidth); // keep everything
    toAtu.wakeup! <= Const(1); // always awake if there's power
  }
}
