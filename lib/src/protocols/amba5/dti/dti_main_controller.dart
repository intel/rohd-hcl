// two translation interfaces + DTI interface
import 'dart:math';

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

  /// Translation requests.
  late final ReadyValidInterface<DtiTbuTransReq>? transReqSend;

  /// Invalidation ACKs.
  late final ReadyValidInterface<DtiTbuInvAck>? invAckSend;

  /// Synchronization ACKs.
  late final ReadyValidInterface<DtiTbuSyncAck>? syncAckSend;

  /// Connect/Disconnect requests.
  late final ReadyValidInterface<DtiTbuCondisReq> condisReqSend;

  /// Optional custom DTI messages to send.
  final List<ReadyAndValidInterface<LogicStructure>> customSends = [];

  /// Translation responses.
  /// This covers both RESP and RESPEX
  late final ReadyValidInterface<DtiTbuTransRespEx>? transRespOut;

  /// Translation faults.
  late final ReadyValidInterface<DtiTbuTransFault>? transFaultOut;

  /// Invalidation requests.
  late final ReadyValidInterface<DtiTbuInvReq>? invReqOut;

  /// Synchronization requests.
  late final ReadyValidInterface<DtiTbuSyncReq>? syncReqOut;

  /// Connect/Disconnects ACKs.
  late final ReadyValidInterface<DtiTbuCondisAck> condisAckOut;

  /// Arbitration across different message classes for
  /// sending messages out over AXI-S (toSub).
  late final Arbiter? outboundArbiter;
  final _arbiterReqs = <Logic>[];
  late int _transReqArbIdx = 0;
  late int _invSyncAckArbIdx = 0;
  late int _condisReqArbIdx = 0;
  final List<int> _customArbIdx = [];

  /// Depth of FIFO for pending TRANS_REQs to send.
  late final int transReqSendFifoDepth;

  /// Depth of FIFO for TRANS_RESP(EX)s received.
  late final int transRespOutFifoDepth;

  /// Depth of FIFO for TRANS_FAULTs received.
  late final int transFaultOutFifoDepth;

  /// Depth of FIFO for pending INV_ACKs and SYNC_ACKs to send.
  late final int invSyncAckSendFifoDepth;

  /// Depth of FIFO for INV_REQs and SYNC_REQs received.
  late final int invSyncReqOutFifoDepth;

  /// Depth of FIFO for pending CONDIS_REQs to send.
  late final int condisReqSendFifoDepth;

  /// Depth of FIFO for pending CONDIS_ACKs received.
  late final int condisAckOutFifoDepth;

  /// Depths of FIFOs for custom messages to send.
  final List<int> customSendFifoDepths;

  /// Fixed source ID for this module.
  ///
  /// Placed into TID signal when sending.
  /// Expected to be in TDEST signal when receiving.
  late final Logic srcId;

  /// Fixed Destination ID for this module.
  ///
  /// Placed into TDEST signal when sending.
  late final Logic destId;

  // outbound FIFOs
  late final Fifo? _outTransReqs;
  late final Fifo? _outInvSyncAcks;
  late final Fifo _outCondisReqs;
  final List<Fifo> _outCustomMsgs = [];

  // inbound FIFOs
  late final Fifo? _inTransResps;
  late final Fifo? _inTransFaults;
  late final Fifo? _inInvSyncReqs;
  late final Fifo _inCondisAcks;
  late final Logic? _inTransRespsWrEn;
  late final Logic? _inTransRespsWrData;
  late final Logic? _inTransRespsRdEn;
  late final Logic? _inTransFaultsWrEn;
  late final Logic? _inTransFaultsWrData;
  late final Logic? _inTransFaultsRdEn;
  late final Logic? _inInvSyncReqsWrEn;
  late final Logic? _inInvSyncReqsWrData;
  late final Logic? _inInvSyncReqsRdEn;
  late final Logic _inCondisAcksWrEn;
  late final Logic _inCondisAcksWrData;
  late final Logic _inCondisAcksRdEn;

  // track the number of outstanding translation requests
  late final Logic _transTokensGranted;
  late final Counter _transReqTokens;

  // manage the connection state
  late final FiniteStateMachine<DtiConnectionState> _connState;
  late final Logic _isConnected;

  // transmission over DTI
  late final int _maxOutMsgSize;
  late final Logic _senderValid;
  late final Logic _senderData;
  late final DtiInterfaceTx _sender;

  // reception over DTI
  late final int _maxInMsgSize;
  late final Logic _receiverCanAccept;
  late final DtiInterfaceRx _receiver;

  /// Indicator if we are able to send translation requests.
  bool get acceptsTransReqs =>
      transReqSend != null && transReqSendFifoDepth > 0;

  /// Indicator if we are able to send invalidation or synchronization ACKs.
  bool get acceptsInvSyncAcks =>
      (invAckSend != null || syncAckSend != null) &&
      invSyncAckSendFifoDepth > 0;

  /// Indicator if we are able to receive translation responses.
  bool get acceptsTransResps =>
      transRespOut != null && transRespOutFifoDepth > 0;

  /// Indicator if we are able to receive translation faults.
  bool get acceptsTransFaults =>
      transFaultOut != null && transFaultOutFifoDepth > 0;

  /// Indicator if we are able to receive
  /// invalidation or synchronization requests.
  bool get acceptsInvSyncReqs =>
      (invReqOut != null || syncReqOut != null) && invSyncReqOutFifoDepth > 0;

  /// Constructor.
  DtiTbuMainController({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface toSub,
    required Axi5StreamInterface fromSub,
    required Logic srcId,
    required Logic destId,
    required ReadyValidInterface<DtiTbuCondisReq> condisReqSend,
    required ReadyValidInterface<DtiTbuCondisAck> condisAckOut,
    ReadyValidInterface<DtiTbuTransReq>? transReqSend,
    ReadyValidInterface<DtiTbuTransRespEx>? transRespOut,
    ReadyValidInterface<DtiTbuTransFault>? transFaultOut,
    ReadyValidInterface<DtiTbuInvAck>? invAckSend,
    ReadyValidInterface<DtiTbuInvReq>? invReqOut,
    ReadyValidInterface<DtiTbuSyncAck>? syncAckSend,
    ReadyValidInterface<DtiTbuSyncReq>? syncReqOut,
    List<ReadyAndValidInterface<LogicStructure>> customSends = const [],
    this.transReqSendFifoDepth = 1,
    this.invSyncAckSendFifoDepth = 1,
    this.condisReqSendFifoDepth = 1,
    this.transRespOutFifoDepth = 1,
    this.transFaultOutFifoDepth = 1,
    this.invSyncReqOutFifoDepth = 1,
    this.condisAckOutFifoDepth = 1,
    this.customSendFifoDepths = const [],
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
    if (transRespOut != null && transRespOutFifoDepth > 0) {
      this.transRespOut = addPairInterfacePorts(transRespOut, PairRole.consumer,
          uniquify: (original) => '${name}_transRespOut_$original');
    } else {
      this.transRespOut = null;
    }
    if (transFaultOut != null && transFaultOutFifoDepth > 0) {
      this.transFaultOut = addPairInterfacePorts(
          transFaultOut, PairRole.consumer,
          uniquify: (original) => '${name}_transFaultOut_$original');
    } else {
      this.transFaultOut = null;
    }
    if (invAckSend != null && invSyncAckSendFifoDepth > 0) {
      this.invAckSend = addPairInterfacePorts(invAckSend, PairRole.consumer,
          uniquify: (original) => '${name}_invAckSend_$original');
    } else {
      this.invAckSend = null;
    }
    if (invReqOut != null && invSyncReqOutFifoDepth > 0) {
      this.invReqOut = addPairInterfacePorts(invReqOut, PairRole.consumer,
          uniquify: (original) => '${name}_invReqOut_$original');
    } else {
      this.invReqOut = null;
    }
    if (syncAckSend != null && invSyncAckSendFifoDepth > 0) {
      this.syncAckSend = addPairInterfacePorts(syncAckSend, PairRole.consumer,
          uniquify: (original) => '${name}_syncAckSend_$original');
    } else {
      this.syncAckSend = null;
    }
    if (syncReqOut != null && invSyncReqOutFifoDepth > 0) {
      this.syncReqOut = addPairInterfacePorts(syncReqOut, PairRole.consumer,
          uniquify: (original) => '${name}_syncReqOut_$original');
    } else {
      this.syncReqOut = null;
    }
    this.condisReqSend = addPairInterfacePorts(condisReqSend, PairRole.consumer,
        uniquify: (original) => '${name}_condisReqSend_$original');
    this.condisAckOut = addPairInterfacePorts(condisAckOut, PairRole.provider,
        uniquify: (original) => '${name}_condisAckOut_$original');

    // custom messages
    for (var i = 0; i < customSends.length; i++) {
      this.customSends.add(addPairInterfacePorts(
          customSends[i], PairRole.consumer,
          uniquify: (original) => '${name}_customSends${i}_$original'));
    }

    this.srcId = addInput('srcId', srcId, width: srcId.width);
    this.destId = addInput('destId', destId, width: destId.width);

    // connState + tokens
    _transReqTokens = Counter.updn(
        clk: this.sys.clk,
        reset: ~this.sys.resetN,
        enableInc: this.transReqSend?.accepted ??
            Const(0), // sending a translation request
        enableDec: (this.transRespOut?.accepted ?? Const(0)) |
            (this.transFaultOut?.accepted ??
                Const(0)), // receiving a translation resp/respex/fault
        restart: this.condisAckOut.accepted &
            this
                .condisAckOut
                .data
                .state
                .eq(1), // get a condisack for a connect request
        width: DtiTbuCondisAck.tokTransGntWidth.bitLength);
    _transTokensGranted = Logic(
        name: 'transTokensGranted', width: DtiTbuCondisAck.tokTransGntWidth);

    // Connection state machine
    final connIn = condisReqSend.accepted & condisReqSend.data.state.eq(1);
    final disconnIn = condisReqSend.accepted & condisReqSend.data.state.eq(0);
    final connOut = condisAckOut.accepted & condisAckOut.data.state.eq(1);
    final disconnOut = condisAckOut.accepted & condisAckOut.data.state.eq(0);
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
            connOut: DtiConnectionState.connected,
            disconnOut: DtiConnectionState.unconnected
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
            connOut: DtiConnectionState.connected,
            disconnOut: DtiConnectionState.unconnected
          },
          actions: [],
        ),
      ],
    );
    _isConnected <=
        _connState.currentState
            .eq(
              Const(
                DtiConnectionState.connected.index,
                width: _connState.currentState.width,
              ),
            )
            .named('isConnected');

    // transmission over DTI
    final customSendMax = this.customSends.isNotEmpty
        ? this.customSends.map((e) => e.data.width).reduce(max)
        : 0;
    _maxOutMsgSize = [
      if (transReqSend != null) DtiTbuTransReq.totalWidth,
      if (invAckSend != null) DtiTbuInvAck.totalWidth,
      if (syncAckSend != null) DtiTbuSyncAck.totalWidth,
      DtiTbuCondisReq.totalWidth,
      customSendMax,
    ].reduce(max);
    _senderValid = Logic(name: 'senderValid');
    _senderData = Logic(name: 'senderData', width: _maxOutMsgSize);
    _sender = DtiInterfaceTx(
        sys: this.sys,
        toSub: this.toSub,
        msgToSendValid: _senderValid,
        msgToSend: _senderData,
        srcId: srcId,
        destId: destId);

    // reception over DTI
    _maxInMsgSize = [
      if (transRespOut != null) DtiTbuTransRespEx.totalWidth,
      if (transFaultOut != null) DtiTbuTransFault.totalWidth,
      if (invReqOut != null) DtiTbuInvReq.totalWidth,
      if (syncReqOut != null) DtiTbuSyncReq.totalWidth,
      DtiTbuCondisAck.totalWidth
    ].reduce(max);
    _receiverCanAccept = Logic(name: 'receiverCanAccept');
    _receiver = DtiInterfaceRx(
        sys: sys,
        fromSub: fromSub,
        canAcceptMsg: _receiverCanAccept,
        srcId: srcId,
        maxMsgRxSize: _maxInMsgSize);

    // capture the request lines into the arbiter
    // dynamically based on which send queues are available
    if (acceptsTransReqs) {
      _arbiterReqs.add(Logic(name: 'arbiter_req_transReq'));
      _transReqArbIdx = _arbiterReqs.length - 1;
    }
    if (acceptsInvSyncAcks) {
      _arbiterReqs.add(Logic(name: 'arbiter_req_invSyncAck'));
      _invSyncAckArbIdx = _arbiterReqs.length - 1;
    }
    _arbiterReqs.add(Logic(name: 'arbiter_req_condisReq'));
    _condisReqArbIdx = _arbiterReqs.length - 1;
    for (var i = 0; i < this.customSends.length; i++) {
      _arbiterReqs.add(Logic(name: 'arbiter_req_custom$i'));
      _customArbIdx.add(_arbiterReqs.length - 1);
    }

    if (outboundArbiter != null) {
      this.outboundArbiter = outboundArbiter;
    } else {
      this.outboundArbiter = RoundRobinArbiter(_arbiterReqs,
          clk: this.sys.clk, reset: ~this.sys.resetN);
    }

    _isConnected = Logic(name: 'isConnected');

    // FIFOs
    if (acceptsTransReqs) {
      _outTransReqs = Fifo(
        this.sys.clk,
        ~this.sys.resetN,
        writeEnable: this.transReqSend!.valid,
        writeData: this.transReqSend!.data,
        readEnable:
            this.outboundArbiter!.grants[_transReqArbIdx] & _sender.msgAccepted,
        depth: transReqSendFifoDepth,
        generateOccupancy: true,
        generateError: true,
        name: 'outTransReqsFifo',
      );
      _arbiterReqs[_transReqArbIdx] <= ~_outTransReqs!.empty;

      // must have translation tokens to spare
      this.transReqSend!.ready <=
          ~_outTransReqs!.full &
              _isConnected &
              _transReqTokens.count.lt(_transTokensGranted);
    } else {
      _outTransReqs = null;
      if (transReqSend != null) {
        this.transReqSend!.ready <= Const(0);
      }
    }
    if (acceptsInvSyncAcks) {
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
        readEnable: this.outboundArbiter!.grants[_invSyncAckArbIdx] &
            _sender.msgAccepted,
        depth: invSyncAckSendFifoDepth,
        generateOccupancy: true,
        generateError: true,
        name: 'outInvSyncAckFifo',
      );
      _arbiterReqs[_invSyncAckArbIdx] <= ~_outInvSyncAcks!.empty;
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
      readEnable:
          this.outboundArbiter!.grants[_condisReqArbIdx] & _sender.msgAccepted,
      depth: condisReqSendFifoDepth,
      generateOccupancy: true,
      generateError: true,
      name: 'outCondisReqsFifo',
    );
    _arbiterReqs[_condisReqArbIdx] <= ~_outCondisReqs.empty;
    this.condisReqSend.ready <= ~_outCondisReqs.full;
    for (var i = 0; i < this.customSends.length; i++) {
      _outCustomMsgs.add(Fifo(
        this.sys.clk,
        ~this.sys.resetN,
        writeEnable: this.customSends[i].valid,
        writeData: this.customSends[i].data,
        readEnable: this.outboundArbiter!.grants[_customArbIdx[i]] &
            _sender.msgAccepted,
        depth: customSendFifoDepths[i],
        generateOccupancy: true,
        generateError: true,
        name: 'outCustomFifo$i',
      ));
    }

    if (acceptsTransResps) {
      _inTransRespsWrEn = Logic(name: 'inTransRespsWrEn');
      _inTransRespsWrData = Logic(
          name: 'inTransRespsWrData', width: DtiTbuTransRespEx.totalWidth);
      _inTransRespsRdEn = Logic(name: 'inTransRespsRdEn');
      _inTransResps = Fifo(
        this.sys.clk,
        ~this.sys.resetN,
        writeEnable: _inTransRespsWrEn!,
        writeData: _inTransRespsWrData!,
        readEnable: _inTransRespsRdEn!,
        depth: transRespOutFifoDepth,
        generateOccupancy: true,
        generateError: true,
        name: 'inTransRespsFifo',
      );
    }
    if (acceptsTransFaults) {
      _inTransFaultsWrEn = Logic(name: 'inTransFaultssWrEn');
      _inTransFaultsWrData = Logic(
          name: 'inTransFaultsWrData', width: DtiTbuTransFault.totalWidth);
      _inTransFaultsRdEn = Logic(name: 'inTransFaultsRdEn');
      _inTransFaults = Fifo(
        this.sys.clk,
        ~this.sys.resetN,
        writeEnable: _inTransFaultsWrEn!,
        writeData: _inTransFaultsWrData!,
        readEnable: _inTransFaultsRdEn!,
        depth: transFaultOutFifoDepth,
        generateOccupancy: true,
        generateError: true,
        name: 'inTransFaultFifo',
      );
    }
    if (acceptsInvSyncReqs) {
      _inInvSyncReqsWrEn = Logic(name: 'inInvSyncReqsWrEn');
      _inInvSyncReqsWrData = Logic(
          name: 'inInvSyncReqsWrData',
          width: max(DtiTbuInvReq.totalWidth, DtiTbuSyncReq.totalWidth));
      _inInvSyncReqsRdEn = Logic(name: 'inInvSyncReqsRdEn');
      _inInvSyncReqs = Fifo(
        this.sys.clk,
        ~this.sys.resetN,
        writeEnable: _inInvSyncReqsWrEn!,
        writeData: _inInvSyncReqsWrData!,
        readEnable: _inInvSyncReqsRdEn!,
        depth: invSyncReqOutFifoDepth,
        generateOccupancy: true,
        generateError: true,
        name: 'inInvSyncReqsFifo',
      );
    }
    _inCondisAcksWrEn = Logic(name: 'inCondisAcksWrEn');
    _inCondisAcksWrData =
        Logic(name: 'inCondisAcksWrData', width: DtiTbuCondisAck.totalWidth);
    _inCondisAcksRdEn = Logic(name: 'inCondisAcksRdEn');
    _inCondisAcks = Fifo(
      this.sys.clk,
      ~this.sys.resetN,
      writeEnable: _inCondisAcksWrEn,
      writeData: _inCondisAcksWrData,
      readEnable: _inCondisAcksRdEn,
      depth: condisAckOutFifoDepth,
      generateOccupancy: true,
      generateError: true,
      name: 'inCondisAcksFifo',
    );

    _buildSend();
    _buildReceive();
  }

  void _buildSend() {
    // examine arbiter to understand what data queue we should pull from
    // flop this moving forward
    final dataToSendCases = <Logic, Logic>{};
    if (acceptsTransReqs) {
      dataToSendCases[Const(toOneHot(_transReqArbIdx, _arbiterReqs.length))] =
          _outTransReqs!.readData.zeroExtend(_maxOutMsgSize);
    }
    if (acceptsInvSyncAcks) {
      dataToSendCases[Const(toOneHot(_transReqArbIdx, _arbiterReqs.length))] =
          _outInvSyncAcks!.readData.zeroExtend(_maxOutMsgSize);
    }
    dataToSendCases[Const(toOneHot(_condisReqArbIdx, _arbiterReqs.length))] =
        _outCondisReqs.readData.zeroExtend(_maxOutMsgSize);
    for (var i = 0; i < customSends.length; i++) {
      dataToSendCases[Const(toOneHot(_customArbIdx[i], _arbiterReqs.length))] =
          _outCustomMsgs[i].readData.zeroExtend(_maxOutMsgSize);
    }
    final dataToSend = cases(
        _arbiterReqs.swizzle(),
        conditionalType: ConditionalType.unique,
        dataToSendCases,
        defaultValue: Const(0, width: _maxOutMsgSize));

    // (potentially) must break the message out over multiple beats
    final dataEn = _arbiterReqs.swizzle().or();
    _senderValid <= dataEn;
    _senderData <= dataToSend;
  }

  void _buildReceive() {
    // raw DTI message from the interface
    final nextMsgInValid = Logic(name: 'nextMsgInValid');
    final nextMsgIn = Logic(name: 'nextMsgIn', width: _receiver.msg.width);

    // flop the next message received from the stream interface
    Sequential(sys.clk, reset: ~sys.resetN, [
      nextMsgInValid < _receiver.msgValid,
      nextMsgIn < mux(_receiver.msgValid, _receiver.msg, nextMsgIn)
    ]);

    final msgTypeIn = nextMsgIn.getRange(0, DtiTbuTransResp.msgTypeWidth);

    // examine the raw message to determine
    // which message queue to put the message in
    // note that all messages have a message type of the same
    // width in the LSBs
    // use tops of the message queues to drive the outbound valids
    if (acceptsTransReqs) {
      _inTransRespsWrEn! <=
          nextMsgInValid &
              ~_inTransResps!.full &
              (msgTypeIn.eq(DtiUpstreamMsgType.transResp.value) |
                  msgTypeIn.eq(DtiUpstreamMsgType.transRespEx.value));
      _inTransRespsWrData! <= (DtiTbuTransRespEx()..gets(nextMsgIn));
      _inTransRespsRdEn! <= transRespOut!.accepted;
      transRespOut!.valid <= ~_inTransResps!.empty;
      transRespOut!.data <=
          (DtiTbuTransRespEx()..gets(_inTransResps!.readData));
    }
    if (acceptsTransFaults) {
      _inTransFaultsWrEn! <=
          nextMsgInValid &
              ~_inTransFaults!.full &
              msgTypeIn.eq(DtiUpstreamMsgType.transFault.value);
      _inTransFaultsWrData! <= (DtiTbuTransFault()..gets(nextMsgIn));
      _inTransFaultsRdEn! <= transFaultOut!.accepted;
      transFaultOut!.valid <= ~_inTransFaults!.empty;
      transFaultOut!.data <=
          (DtiTbuTransFault()..gets(_inTransFaults!.readData));
    }
    if (acceptsInvSyncReqs) {
      _inInvSyncReqsWrEn! <=
          ~_inInvSyncReqs!.full &
              nextMsgInValid &
              (msgTypeIn.eq(DtiUpstreamMsgType.invReq.value) |
                  msgTypeIn.eq(DtiUpstreamMsgType.syncReq.value));
      _inInvSyncReqsWrData! <=
          nextMsgIn.getRange(
              0, max(DtiTbuInvReq.totalWidth, DtiTbuSyncReq.totalWidth));
      _inInvSyncReqsRdEn! <=
          (invReqOut?.accepted ?? Const(0)) |
              (syncReqOut?.accepted ?? Const(0));
      if (invReqOut != null) {
        invReqOut!.valid <= ~_inInvSyncReqs!.empty;
        invReqOut!.data <=
            (DtiTbuInvReq()
              ..gets(_inInvSyncReqs!.readData
                  .getRange(0, DtiTbuInvReq.totalWidth)));
      }
      if (syncReqOut != null) {
        syncReqOut!.valid <= ~_inInvSyncReqs!.empty;
        syncReqOut!.data <=
            (DtiTbuSyncReq()
              ..gets(_inInvSyncReqs!.readData
                  .getRange(0, DtiTbuSyncReq.totalWidth)));
      }
    }
    _inCondisAcksWrEn <=
        nextMsgInValid &
            ~_inCondisAcks.full &
            msgTypeIn.eq(DtiUpstreamMsgType.condisAck.value);
    _inCondisAcksWrData <= (DtiTbuCondisAck()..gets(nextMsgIn));
    _inCondisAcksRdEn <= condisAckOut.accepted;
    condisAckOut.valid <= ~_inCondisAcks.empty;
    condisAckOut.data <= (DtiTbuCondisAck()..gets(_inCondisAcks.readData));

    // use message queue fulls to drive the interface TREADY
    // if our current message waiting to queue is trying to
    // go into a queue that is full, we must block
    final queueFull = [
      if (acceptsTransReqs)
        _inTransResps!.full &
            (msgTypeIn.eq(DtiUpstreamMsgType.transResp.value) |
                msgTypeIn.eq(DtiUpstreamMsgType.transRespEx.value)),
      if (acceptsTransFaults)
        _inTransFaults!.full &
            msgTypeIn.eq(DtiUpstreamMsgType.transFault.value),
      if (acceptsInvSyncReqs)
        _inInvSyncReqs!.full &
            (msgTypeIn.eq(DtiUpstreamMsgType.invReq.value) |
                msgTypeIn.eq(DtiUpstreamMsgType.syncReq.value)),
      _inCondisAcks.full & msgTypeIn.eq(DtiUpstreamMsgType.condisAck.value),
    ].swizzle().or();
    _receiverCanAccept <= ~queueFull;

    // on CondisAck, make sure to grab the granted # of tokens
    Sequential(sys.clk, reset: ~sys.resetN, [
      _transTokensGranted <
          mux(condisAckOut.accepted & condisAckOut.data.state.eq(1),
              condisAckOut.data.tokTransGnt, _transTokensGranted),
    ]);
  }
}
