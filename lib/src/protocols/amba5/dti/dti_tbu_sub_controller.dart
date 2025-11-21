import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// DTI TBU Sub controller handles transactions over DTI (AXI-S)
/// in the Subordinate direction.
class DtiTbuSubController extends DtiController {
  // track the number of outstanding invalidation requests
  late final Logic _invTokensGranted;

  // manage the connection state
  late final FiniteStateMachine<DtiConnectionState> _connState;

  /// Constructor.
  DtiTbuSubController({
    required super.sys,
    required super.outStream,
    required super.inStream,
    required super.srcId,
    required super.destId,
    super.sendMsgs = const [],
    super.rcvMsgs = const [],
    super.sendCfgs = const [],
    super.rcvCfgs = const [],
    super.outboundArbiter,
    super.name = 'dtiTbuSubController',
  }) {
    _buildSub();
  }

  /// Convenience constructor for a "standard" DTI sub
  ///
  /// All standard message types enabled appropriately.
  DtiTbuSubController.standard({
    required super.sys,
    required super.outStream,
    required super.inStream,
    required super.srcId,
    required super.destId,
    required ReadyAndValidInterface<DtiTbuTransReq> transReq,
    required int transReqFifoDepth,
    required ReadyAndValidInterface<DtiTbuInvAck> invAck,
    required int invAckFifoDepth,
    required ReadyAndValidInterface<DtiTbuSyncAck> syncAck,
    required int syncAckFifoDepth,
    required ReadyAndValidInterface<DtiTbuCondisReq> condisReq,
    required int condisReqFifoDepth,
    required ReadyAndValidInterface<DtiTbuTransRespEx> transResp,
    required int transRespFifoDepth,
    required ReadyAndValidInterface<DtiTbuTransFault> transFault,
    required int transFaultFifoDepth,
    required ReadyAndValidInterface<DtiTbuInvReq> invReq,
    required int invReqFifoDepth,
    required ReadyAndValidInterface<DtiTbuSyncReq> syncReq,
    required int syncReqFifoDepth,
    required ReadyAndValidInterface<DtiTbuCondisAck> condisAck,
    required int condisAckFifoDepth,
    super.outboundArbiter,
    super.name = 'dtiTbuSubController',
  }) : super(rcvMsgs: [
          transReq,
          invAck,
          syncAck,
          condisReq,
        ], rcvCfgs: [
          DtiRxMessageInterfaceConfig(
              fifoDepth: transReqFifoDepth,
              mapToQueue: (msg) => msg
                  .getRange(0, DtiTbuTransReq.msgTypeWidth)
                  .eq(DtiDownstreamMsgType.transReq.value)),
          DtiRxMessageInterfaceConfig(
              fifoDepth: invAckFifoDepth,
              mapToQueue: (msg) => msg
                  .getRange(0, DtiTbuInvAck.msgTypeWidth)
                  .eq(DtiDownstreamMsgType.invAck.value)),
          DtiRxMessageInterfaceConfig(
              fifoDepth: syncAckFifoDepth,
              mapToQueue: (msg) => msg
                  .getRange(0, DtiTbuSyncAck.msgTypeWidth)
                  .eq(DtiDownstreamMsgType.syncAck.value)),
          DtiRxMessageInterfaceConfig(
              fifoDepth: condisReqFifoDepth,
              mapToQueue: (msg) => msg
                  .getRange(0, DtiTbuCondisReq.msgTypeWidth)
                  .eq(DtiDownstreamMsgType.condisReq.value)),
        ], sendMsgs: [
          transResp,
          transFault,
          invReq,
          syncReq,
          condisAck,
        ], sendCfgs: [
          DtiTxMessageInterfaceConfig(fifoDepth: transRespFifoDepth),
          DtiTxMessageInterfaceConfig(fifoDepth: transFaultFifoDepth),
          DtiTxMessageInterfaceConfig(
              fifoDepth: invReqFifoDepth,
              isCredited: true,
              creditCountWidth: DtiTbuCondisReq.tokInvGntWidth),
          DtiTxMessageInterfaceConfig(fifoDepth: syncReqFifoDepth),
          DtiTxMessageInterfaceConfig(
              fifoDepth: condisAckFifoDepth, connectedExempt: true),
        ]) {
    _buildSub();
  }

  void _buildSub() {
    // we need to identify CONDIS_ACK and INV_REQ
    // for certain DTI specific activities
    var conAckIdx = -1;
    var invReqIdx = -1;
    for (var i = 0; i < sendMsgs.length; i++) {
      if (sendMsgs[i].data is DtiTbuCondisAck) {
        conAckIdx = i;
      } else if (sendMsgs[i].data is DtiTbuInvReq) {
        invReqIdx = i;
      }
    }
    if (conAckIdx < 0) {
      throw Exception(
          'This module is missing a required DtiTbuCondisAck interface!');
    }
    final condisAckSend = sendMsgs[conAckIdx];
    final condisAckData = DtiTbuCondisAck(name: 'condisAckData')
      ..gets(condisAckSend.data);

    var conReqIdx = -1;
    var invAckIdx = -1;
    for (var i = 0; i < rcvMsgs.length; i++) {
      if (rcvMsgs[i].data is DtiTbuCondisReq) {
        conReqIdx = i;
      } else if (rcvMsgs[i].data is DtiTbuInvAck) {
        invAckIdx = i;
      }
    }
    if (conReqIdx < 0) {
      throw Exception(
          'This module is missing a required DtiTbuCondisReq interface!');
    }
    final condisReqOut = rcvMsgs[conReqIdx];
    final condisReqData = DtiTbuCondisReq(name: 'condisReqData')
      ..gets(condisReqOut.data);

    // on CondisReq, make sure to grab the granted # of tokens
    _invTokensGranted =
        Logic(name: 'invTokensGranted', width: DtiTbuCondisReq.tokInvGntWidth);
    Sequential(sys.clk, reset: ~sys.resetN, [
      _invTokensGranted <
          mux(condisReqOut.accepted & condisReqData.state.eq(1),
              condisReqData.tokInvGnt, _invTokensGranted),
    ]);

    // drive crediting logic for INV_REQ
    // note that it is possible not to have an INV_REQ
    if (invReqIdx >= 0) {
      hasCredits[invReqIdx]! <=
          creditCnts[invReqIdx]!
              .count
              .lt(_invTokensGranted); // counter doesn't exceed max
      incrCredits[invReqIdx]! <=
          sendMsgs[invReqIdx].accepted; // sending an inv request
      decrCredits[invReqIdx]! <=
          rcvMsgs[invAckIdx].accepted; // receiving an inv ack
      restartCredits[invReqIdx]! <=
          condisReqOut.accepted & condisReqData.state.eq(1); // get a condisreq
    }

    // Connection state machine
    final connIn = condisReqOut.accepted & condisReqData.state.eq(1);
    final disconnIn = condisReqOut.accepted & condisReqData.state.eq(0);
    final connOut = condisAckSend.accepted & condisAckData.state.eq(1);
    final disconnOut = condisAckSend.accepted & condisAckData.state.eq(0);
    _connState = FiniteStateMachine<DtiConnectionState>(
      sys.clk,
      ~sys.resetN,
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
    isConnected <=
        _connState.currentState.eq(
          Const(
            DtiConnectionState.connected.index,
            width: _connState.currentState.width,
          ),
        );
  }
}
