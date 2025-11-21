import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A generic controller for sending and receiving DTI messages over AXI-S.
abstract class DtiController extends Module {
  /// Clock and reset.
  late final Axi5SystemInterface sys;

  /// Outbound DTI messages.
  late final Axi5StreamInterface outStream;

  /// Inbound DTI messages.
  late final Axi5StreamInterface inStream;

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
  final List<DtiRxMessageInterfaceConfig> rcvCfgs;

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

  // transmission over DTI
  late final int _maxOutMsgSize;
  late final Logic _senderValid;
  late final Logic _senderData;
  late final DtiInterfaceTx _sender;

  // reception over DTI
  late final int _maxInMsgSize;
  late final Logic _receiverCanAccept;
  late final DtiInterfaceRx _receiver;

  /// Logic to determine if a given Tx message
  /// currently has credits to accept new outbound messages.
  ///
  /// This is only applicable for messages whose config
  /// "isCredited" property is true.
  ///
  /// For all such messages, the deriving class must
  /// drive the given index's Logic.
  final List<Logic?> hasCredits = [];

  /// Logic to determine if a given Tx message
  /// should increment its credit count (consume a credit).
  ///
  /// This is only applicable for messages whose config
  /// "isCredited" property is true.
  ///
  /// For all such messages, the deriving class must
  /// drive the given index's Logic.
  final List<Logic?> incrCredits = [];

  /// Logic to determine if a given Tx message
  /// should decrement its credit count (return a credit).
  ///
  /// This is only applicable for messages whose config
  /// "isCredited" property is true.
  ///
  /// For all such messages, the deriving class must
  /// drive the given index's Logic.
  final List<Logic?> decrCredits = [];

  /// Logic to determine if a given Tx message
  /// should restart its credit count from 0.
  ///
  /// This is only applicable for messages whose config
  /// "isCredited" property is true.
  ///
  /// For all such messages, the deriving class must
  /// drive the given index's Logic.
  final List<Logic?> restartCredits = [];

  /// Is the DTI controller currently in the connected
  /// state per the DTI protocol.
  ///
  /// The deriving class must drive this.
  late final Logic isConnected;

  /// Current credit counts for credited Tx messages.
  ///
  /// This is only applicable for messages whose config
  /// "isCredited" property is true.
  @protected
  final List<Counter?> creditCnts = [];

  /// Constructor.
  DtiController({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface outStream,
    required Axi5StreamInterface inStream,
    required Logic srcId,
    required Logic destId,
    List<ReadyAndValidInterface<LogicStructure>> sendMsgs = const [],
    List<ReadyAndValidInterface<LogicStructure>> rcvMsgs = const [],
    this.sendCfgs = const [],
    this.rcvCfgs = const [],
    Arbiter? outboundArbiter,
    super.name = 'dtiController',
  }) {
    this.sys = addPairInterfacePorts(sys, PairRole.consumer);
    this.outStream = addPairInterfacePorts(
      outStream,
      PairRole.provider,
      uniquify: (original) => '${name}_toSub_$original',
    );
    this.inStream = addPairInterfacePorts(
      inStream,
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

    // transmission over DTI
    _maxOutMsgSize = this.sendMsgs.isNotEmpty
        ? this.sendMsgs.map((e) => e.data.width).reduce(max)
        : 0;
    _senderValid = Logic(name: 'senderValid');
    _senderData = Logic(name: 'senderData', width: _maxOutMsgSize);
    _sender = DtiInterfaceTx(
        sys: this.sys,
        stream: this.outStream,
        msgToSendValid: _senderValid,
        msgToSend: _senderData,
        srcId: this.srcId,
        destId: this.destId);

    // reception over DTI
    _maxInMsgSize = this.rcvMsgs.isNotEmpty
        ? this.rcvMsgs.map((e) => e.data.width).reduce(max)
        : 0;
    _receiverCanAccept = Logic(name: 'receiverCanAccept');
    _receiver = DtiInterfaceRx(
        sys: this.sys,
        stream: this.inStream,
        canAcceptMsg: _receiverCanAccept,
        srcId: this.srcId,
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

    // credit initializetion
    for (var i = 0; i < sendCfgs.length; i++) {
      hasCredits
          .add(sendCfgs[i].isCredited ? Logic(name: 'hasCredits$i') : null);
      incrCredits
          .add(sendCfgs[i].isCredited ? Logic(name: 'incrCredits$i') : null);
      decrCredits
          .add(sendCfgs[i].isCredited ? Logic(name: 'decrCredits$i') : null);
      restartCredits
          .add(sendCfgs[i].isCredited ? Logic(name: 'restartCredits$i') : null);
      creditCnts.add(sendCfgs[i].isCredited
          ? Counter.updn(
              clk: this.sys.clk,
              reset: ~this.sys.resetN,
              enableInc: incrCredits.last!,
              enableDec: decrCredits.last!,
              restart: restartCredits.last,
              width: sendCfgs[i].creditCountWidth)
          : null);
    }

    isConnected = Logic(name: 'isConnected');

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

      // request from the arbiter if we're not empty
      _arbiterReqs[i] <= ~_outMsgs.last.empty;

      // ready if mapped queue is not full
      // in addition, some message types should block if not connected
      // in addition, some message types should block if lacking credits
      this.sendMsgs[i].ready <=
          ~_outMsgs.last.full &
              (sendCfgs[i].connectedExempt ? Const(1) : isConnected) &
              (sendCfgs[i].isCredited ? hasCredits[i]! : Const(1));
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
        _arbiterReqs.rswizzle(),
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
