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

  /// DTI messages to send.
  final List<ReadyAndValidInterface<LogicStructure>> sendMsgs = [];

  /// DTI messages to receive.
  final List<ReadyAndValidInterface<LogicStructure>> rcvMsgs = [];

  /// Arbitration across different message classes for
  /// sending messages out over AXI-S (toSub).
  late final Arbiter? outboundArbiter;
  final _arbiterReqs = <Logic>[];
  final List<int> _sendArbIdx = [];

  /// Configurations for send messages.
  final List<DtiTxMessageInterfaceConfig> sendCfgs;

  /// Configurations for receive messages.
  final List<DtiTxMessageInterfaceConfig> rcvCfgs;

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
  final List<Fifo> _outMsgs = [];

  // inbound FIFOs
  final List<Fifo> _inMsgs = [];
  final List<Logic> _inMsgsWrEn = [];
  final List<Logic> _inMsgsWrData = [];
  final List<Logic> _inMsgsRdEn = [];

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

  /// Constructor.
  DtiTbuMainController({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface toSub,
    required Axi5StreamInterface fromSub,
    required Logic srcId,
    required Logic destId,
    List<ReadyAndValidInterface<LogicStructure>> sendMsgs = const [],
    List<ReadyAndValidInterface<LogicStructure>> rcvMsgs = const [],
    this.sendCfgs = const [],
    this.rcvCfgs = const [],
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

    // send messages
    for (var i = 0; i < sendMsgs.length; i++) {
      this.sendMsgs.add(addPairInterfacePorts(sendMsgs[i], PairRole.consumer,
          uniquify: (original) => '${name}_sendMsgs${i}_$original'));
    }

    // receive messages
    for (var i = 0; i < rcvMsgs.length; i++) {
      this.rcvMsgs.add(addPairInterfacePorts(rcvMsgs[i], PairRole.provider,
          uniquify: (original) => '${name}_rcvMsgs${i}_$original'));
    }

    this.srcId = addInput('srcId', srcId, width: srcId.width);
    this.destId = addInput('destId', destId, width: destId.width);

    // we need to identify CONDIS_REQ and TRANS_REQ
    // for certain DTI specific activities
    var conReqIdx = -1;
    var transReqIdx = -1;
    for (var i = 0; i < sendMsgs.length; i++) {
      if (sendMsgs[i].data is DtiTbuCondisReq) {
        conReqIdx = i;
      } else if (sendMsgs[i].data is DtiTbuTransReq) {
        transReqIdx = i;
      }
    }
    if (conReqIdx < 0) {
      throw Exception(
          'This module is missing a required DtiTbuCondisReq interface!');
    }
    final condisReqSend = this.sendMsgs[conReqIdx];
    final condisReqData = DtiTbuCondisReq()..gets(condisReqSend.data);

    var conAckIdx = -1;
    var transRespIdx = -1;
    var transFaultIdx = -1;
    for (var i = 0; i < rcvMsgs.length; i++) {
      if (rcvMsgs[i].data is DtiTbuCondisAck) {
        conAckIdx = i;
      } else if (sendMsgs[i].data is DtiTbuTransResp) {
        transRespIdx = i;
      } else if (sendMsgs[i].data is DtiTbuTransRespEx) {
        transRespIdx = i;
      } else if (sendMsgs[i].data is DtiTbuTransFault) {
        transFaultIdx = i;
      }
    }
    if (conAckIdx < 0) {
      throw Exception(
          'This module is missing a required DtiTbuCondisAck interface!');
    }
    final condisAckOut = this.rcvMsgs[conAckIdx];
    final condisAckData = DtiTbuCondisAck()..gets(condisAckOut.data);

    // on CondisAck, make sure to grab the granted # of tokens
    Sequential(sys.clk, reset: ~sys.resetN, [
      _transTokensGranted <
          mux(condisAckOut.accepted & condisAckData.state.eq(1),
              condisAckData.tokTransGnt, _transTokensGranted),
    ]);

    // connState + tokens
    _transReqTokens = Counter.updn(
        clk: this.sys.clk,
        reset: ~this.sys.resetN,
        enableInc: transReqIdx < 0
            ? Const(0)
            : this
                .sendMsgs[transReqIdx]
                .accepted, // sending a translation request
        enableDec: (transRespIdx < 0
                ? Const(0)
                : this.rcvMsgs[transRespIdx].accepted) |
            (transFaultIdx < 0
                ? Const(0)
                : this
                    .rcvMsgs[transFaultIdx]
                    .accepted), // receiving a translation resp/respex/fault
        restart: condisAckOut.accepted &
            condisAckData.state.eq(1), // get a condisack for a connect request
        width: DtiTbuCondisAck.tokTransGntWidth.bitLength);
    _transTokensGranted = Logic(
        name: 'transTokensGranted', width: DtiTbuCondisAck.tokTransGntWidth);

    // Connection state machine
    final connIn = condisReqSend.accepted & condisReqData.state.eq(1);
    final disconnIn = condisReqSend.accepted & condisReqData.state.eq(0);
    final connOut = condisAckOut.accepted & condisAckData.state.eq(1);
    final disconnOut = condisAckOut.accepted & condisAckData.state.eq(0);
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
    _maxOutMsgSize = this.sendMsgs.isNotEmpty
        ? this.sendMsgs.map((e) => e.data.width).reduce(max)
        : 0;
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
    _maxInMsgSize = this.rcvMsgs.isNotEmpty
        ? this.rcvMsgs.map((e) => e.data.width).reduce(max)
        : 0;
    _receiverCanAccept = Logic(name: 'receiverCanAccept');
    _receiver = DtiInterfaceRx(
        sys: sys,
        fromSub: fromSub,
        canAcceptMsg: _receiverCanAccept,
        srcId: srcId,
        maxMsgRxSize: _maxInMsgSize);

    // capture the request lines into the arbiter
    // dynamically based on which send queues are available
    for (var i = 0; i < this.sendMsgs.length; i++) {
      _arbiterReqs.add(Logic(name: 'arbiter_req_$i'));
      _sendArbIdx.add(_arbiterReqs.length - 1);
    }

    if (outboundArbiter != null) {
      this.outboundArbiter = outboundArbiter;
    } else {
      this.outboundArbiter = RoundRobinArbiter(_arbiterReqs,
          clk: this.sys.clk, reset: ~this.sys.resetN);
    }

    _isConnected = Logic(name: 'isConnected');

    // FIFOs
    for (var i = 0; i < this.sendMsgs.length; i++) {
      final outMsgFull = Logic(name: 'outMsgsFull$i');
      _outMsgs.add(Fifo(
        this.sys.clk,
        ~this.sys.resetN,
        writeEnable: this.sendMsgs[i].valid & ~outMsgFull,
        writeData: this.sendMsgs[i].data,
        readEnable:
            this.outboundArbiter!.grants[_sendArbIdx[i]] & _sender.msgAccepted,
        depth: sendCfgs[i].fifoDepth,
        generateOccupancy: true,
        generateError: true,
        name: 'outMsgFifo$i',
      ));
      outMsgFull <= _outMsgs.last.full;

      // ready if mapped queue is not full
      // unless we're TRANS_REQ in which case
      // also must have translation tokens to spare
      this.sendMsgs[i].ready <=
          ~_outMsgs.last.full &
              _isConnected &
              (i == transReqIdx
                  ? _transReqTokens.count.lt(_transTokensGranted)
                  : Const(1));
    }

    for (var i = 0; i < this.rcvMsgs.length; i++) {
      _inMsgsWrEn.add(Logic(name: 'inMsgsWrEn$i'));
      _inMsgsWrData.add(
          Logic(name: 'inMsgsWrData$i', width: this.rcvMsgs[i].data.width));
      _inMsgsRdEn.add(Logic(name: 'inMsgsRdEn$i'));
      _inMsgs.add(Fifo(
        this.sys.clk,
        ~this.sys.resetN,
        writeEnable: _inMsgsWrEn.last,
        writeData: _inMsgsWrData.last,
        readEnable: _inMsgsRdEn.last,
        depth: rcvCfgs[i].fifoDepth,
        generateOccupancy: true,
        generateError: true,
        name: 'inMsgsFifo$i',
      ));
    }

    _buildSend();
    _buildReceive();
  }

  void _buildSend() {
    // examine arbiter to understand what data queue we should pull from
    // flop this moving forward
    final dataToSendCases = <Logic, Logic>{};
    for (var i = 0; i < sendMsgs.length; i++) {
      dataToSendCases[Const(toOneHot(_sendArbIdx[i], _arbiterReqs.length))] =
          _outMsgs[i].readData.zeroExtend(_maxOutMsgSize);
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

    // examine the raw message to determine
    // which message queue to put the message in
    // note that all messages have a message type of the same
    // width in the LSBs
    // use tops of the message queues to drive the outbound valids
    for (var i = 0; i < rcvMsgs.length; i++) {
      _inMsgsWrEn[i] <=
          nextMsgInValid & ~_inMsgs[i].full & rcvCfgs[i].mapToQueue!(nextMsgIn);
      _inMsgsWrData[i] <= nextMsgIn.getRange(0, rcvMsgs[i].data.width);
      _inMsgsRdEn[i] <= rcvMsgs[i].accepted;
      rcvMsgs[i].valid <= ~_inMsgs[i].empty;
      rcvMsgs[i].data <= _inMsgs[i].readData;
    }

    // use message queue fulls to drive the interface TREADY
    // if our current message waiting to queue is trying to
    // go into a queue that is full, we must block
    final queueFull = List.generate(rcvMsgs.length,
            (i) => _inMsgs[i].full & rcvCfgs[i].mapToQueue!(nextMsgIn))
        .swizzle()
        .or();
    _receiverCanAccept <= ~queueFull;
  }
}
