// two translation interfaces + DTI interface
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// DTI TBU Main controller handles transactions over DTI (AXI-S)
/// in the Main direction.
///
/// Namely, sending TRANS_REQ, INV_ACK, SYNC_ACK, CONDIS_REQ.
/// and receiving TRANS_RESP{EX}, TRANS_FAULT, INV_REQ, SYNC_REQ, CONDIS_ACK.
class DtiTbuMainController extends Module {
  /// Clock and reset.
  late final Axi5SystemInterface sys;

  /// Outbound DTI messages.
  late final Axi5StreamInterface toSub;

  /// Inbound DTI messages.
  late final Axi5StreamInterface fromSub;

  /// Translation requests from IOTLB.
  late final ReadyValidInterface<DtiTbuTransReq> transReqSend;

  /// Interrupts mapped as Translation requests.
  late final IrqRequestInterface fromMsi;

  /// Invaliation ACK.
  late final InvalidationAckInterface? invalAck;

  /// Invaliation ACK (Intel forked).
  late final InvalidationAckVtdInterface? invalAckVtd;

  /// Synchronization ACK.
  late final SynchronizationAckInterface? syncAck;

  // outbound request FIFO
  late final Logic _outgoingReqsWrEn;
  late final Logic _outgoingReqsWrData;
  late final Logic _outgoingReqsRdEn;
  late final Fifo _outgoingReqs;

  // invalidation responses
  // separate FIFO for QoS
  late final Logic _invalWrEn;
  late final Logic _invalWrData;
  late final Logic _invalRdEn;
  late final Fifo _inval;

  /// Source ID is configurable at ATCB CSR level.
  late final Logic atcbSrcId;

  /// Destination ID is configurable at ATCB CSR level.
  late final Logic atuDestId;

  /// Number of translation tokens to request is
  /// configurable at ATCB CSR level.
  late final Logic tokTransReq;

  /// Number of invalidation tokens to grant is
  /// configurable at ATCB CSR level.
  late final Logic tokInvGnt;

  /// Connection request ACK received
  late final Logic connAck;

  /// Granted number of translation request tokens.
  late final Logic transTokenGrant;

  late final FiniteStateMachine<DtiOutboundConnectionState> _connState;

  // helper generate a connection request over DTI
  // it is assumed that the configured token values
  // don't exceed our FIFO depths
  Logic _generateConnReq() => DtiTbuCondisReq('conReq')
    ..msgType.gets(
      Const(
        DtiDownstreamMsgType.condisReq.value,
        width: DtiTbuCondisReq.msgTypeWidth,
      ),
    )
    ..state.gets(
      Const(1, width: DtiTbuCondisReq.stateWidth),
    ) // connection request
    ..protocol.gets(Const(0, width: DtiTbuCondisReq.protocolWidth)) // must be 0
    ..rsvd1.gets(Const(0, width: DtiTbuCondisReq.rsvd1Width))
    ..impDef.gets(Const(0, width: DtiTbuCondisReq.impDefWidth))
    ..version.gets(Const(4, width: DtiTbuCondisReq.versionWidth)) // v5
    ..tokTransReq1.gets(
      tokTransReq.getRange(0, DtiTbuCondisReq.tokTransReq1Width),
    )
    ..tokInvGnt.gets(tokInvGnt)
    ..supReg.gets(
      Const(0, width: DtiTbuCondisReq.supRegWidth),
    ) // no register accesses
    ..spd.gets(
      Const(1, width: DtiTbuCondisReq.spdWidth),
    ) // same power domain as ATU
    ..stages.gets(
      Const(1, width: DtiTbuCondisReq.stagesWidth),
    ) // 1 = translations + GPC
    ..tokTransReq2.gets(
      tokTransReq.getRange(
        DtiTbuCondisReq.tokTransReq1Width,
        DtiTbuCondisReq.tokTransReqWidth,
      ),
    );

  /// Constructor.
  DtiTbuMainController({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface toAtu,
    required TranslationRequestInterface fromCache,
    required IrqRequestInterface fromMsi,
    required Logic atcbSrcId,
    required Logic atuDestId,
    required Logic tokTransReq,
    required Logic tokInvGnt,
    required Logic connAck,
    required Logic transTokenGrant,
    InvalidationAckInterface? invalAck,
    SynchronizationAckInterface? syncAck,
    InvalidationAckVtdInterface? invalAckVtd,
    super.name = 'dtiOutboundController',
    this.requestFifoDepth = 8,
  }) {
    this.sys = addPairInterfacePorts(sys, PairRole.consumer);
    this.toAtu = addPairInterfacePorts(
      toAtu,
      PairRole.provider,
      uniquify: (original) => '${name}_toAtu_$original',
    );
    this.fromCache = addPairInterfacePorts(
      fromCache,
      PairRole.consumer,
      uniquify: (original) => '${name}_fromCache_$original',
    );
    this.fromMsi = addPairInterfacePorts(
      fromMsi,
      PairRole.consumer,
      uniquify: (original) => '${name}_fromMsi_$original',
    );
    if (invalAck != null) {
      this.invalAck = addPairInterfacePorts(
        invalAck,
        PairRole.consumer,
        uniquify: (original) => '${name}_invalAck_$original',
      );
    } else {
      this.invalAck = null;
    }
    if (syncAck != null) {
      this.syncAck = addPairInterfacePorts(
        syncAck,
        PairRole.consumer,
        uniquify: (original) => '${name}_syncAck_$original',
      );
    } else {
      this.syncAck = null;
    }
    if (invalAckVtd != null) {
      this.invalAckVtd = addPairInterfacePorts(
        invalAckVtd,
        PairRole.consumer,
        uniquify: (original) => '${name}_invalAck_$original',
      );
    } else {
      this.invalAckVtd = null;
    }
    this.atcbSrcId = addInput('atuSrcId', atcbSrcId, width: atcbSrcId.width);
    this.atuDestId = addInput('atuDestId', atuDestId, width: atuDestId.width);
    this.tokTransReq = addInput(
      'tokTransReq',
      tokTransReq,
      width: tokTransReq.width,
    );
    this.tokInvGnt = addInput('tokInvGnt', tokInvGnt, width: tokInvGnt.width);
    this.connAck = addInput('connAck', connAck, width: connAck.width);
    this.transTokenGrant = addInput(
      'transTokenGrant',
      transTokenGrant,
      width: transTokenGrant.width,
    );

    _outgoingReqsWrEn = Logic(name: 'outgoingReqsWrEn');
    _outgoingReqsWrData = Logic(
      name: 'outgoingReqsWrData',
      width: toAtu.dataWidth,
    );
    _outgoingReqsRdEn = Logic(name: 'outgoingReqsRdEn');
    _outgoingReqs = Fifo(
      this.sys.clk,
      ~this.sys.resetN,
      writeEnable: _outgoingReqsWrEn,
      writeData: _outgoingReqsWrData,
      readEnable: _outgoingReqsRdEn,
      depth: requestFifoDepth,
      generateOccupancy: true,
      generateError: true,
      // generateBypass: false,
      name: 'outgoingReqsFifo',
    );

    _invalWrEn = Logic(name: 'invalWrEn');
    _invalWrData = Logic(name: 'invalWrData', width: toAtu.dataWidth);
    _invalRdEn = Logic(name: 'invalRdEn');
    _inval = Fifo(
      this.sys.clk,
      ~this.sys.resetN,
      writeEnable: _invalWrEn,
      writeData: _invalWrData,
      readEnable: _invalRdEn,
      depth: requestFifoDepth,
      generateOccupancy: true,
      generateError: true,
      // generateBypass: false,
      name: 'invalFifo',
    );

    _connState = FiniteStateMachine<DtiOutboundConnectionState>(
      this.sys.clk,
      ~this.sys.resetN,
      DtiOutboundConnectionState.unconnected,
      [
        // UNCONNECTED
        //  move to PENDING when the 1st request goes out on AXI-S
        State(
          DtiOutboundConnectionState.unconnected,
          events: {
            (this.toAtu.valid & (this.toAtu.ready ?? Const(1))):
                DtiOutboundConnectionState.pending,
          },
          actions: [],
        ),
        // PENDING
        //  move to CONNECTED when we get the connection ACK from outside
        State(
          DtiOutboundConnectionState.pending,
          events: {this.connAck: DtiOutboundConnectionState.connected},
          actions: [],
        ),
        // CONNECTED
        //  never leave this state once in it for now...
        State(DtiOutboundConnectionState.connected, events: {}, actions: []),
      ],
    );

    _build();
  }

  void _build() {
    final invalVtd = invalAckVtd != null;

    final connReq = _generateConnReq().zeroExtend(toAtu.dataWidth);
    final isConnected = _connState.currentState
        .eq(
          Const(
            DtiOutboundConnectionState.connected.index,
            width: _connState.currentState.width,
          ),
        )
        .named('isConnected');
    final isUnconnected = _connState.currentState
        .eq(
          Const(
            DtiOutboundConnectionState.unconnected.index,
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
    toAtu.id! <= atcbSrcId;
    toAtu.dest! <= atuDestId;
    toAtu.data! <= trueOutData;
    toAtu.last! <= Const(1); // always 1 beat
    toAtu.keep! <= ~Const(0, width: toAtu.strbWidth); // keep everything
    toAtu.wakeup! <= Const(1); // always awake if there's power
  }
}
