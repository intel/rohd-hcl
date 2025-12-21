// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// dti_tbu_main_controller.dart
// Implementation of DTI Controller for a TBU in the Main direction.
//
// 2025 December
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// DTI TBU Main controller handles transactions over DTI (AXI-S)
/// in the Main direction.
class DtiTbuMainController extends DtiController {
  // track the number of outstanding translation requests
  late final Logic _transTokensGranted;

  // manage the connection state
  late final FiniteStateMachine<DtiConnectionState> _connState;

  /// Constructor.
  DtiTbuMainController({
    required super.sys,
    required super.outStream,
    required super.inStream,
    super.srcId,
    super.wakeupTx,
    super.sendMsgs = const [],
    super.rcvMsgs = const [],
    super.sendCfgs = const [],
    super.rcvCfgs = const [],
    super.arbiterGen,
    super.name = 'dtiTbuMainController',
  }) {
    _buildMain();
  }

  /// Convenience constructor for a "standard" DTI main
  ///
  /// All standard message types enabled appropriately.
  DtiTbuMainController.standard({
    required super.sys,
    required super.outStream,
    required super.inStream,
    required ReadyAndValidInterface<DtiMessage> transReq,
    required int transReqFifoDepth,
    required ReadyAndValidInterface<DtiMessage> invAck,
    required int invAckFifoDepth,
    required ReadyAndValidInterface<DtiMessage> syncAck,
    required int syncAckFifoDepth,
    required ReadyAndValidInterface<DtiMessage> condisReq,
    required int condisReqFifoDepth,
    required ReadyAndValidInterface<DtiMessage> transResp,
    required int transRespFifoDepth,
    required ReadyAndValidInterface<DtiMessage> transFault,
    required int transFaultFifoDepth,
    required ReadyAndValidInterface<DtiMessage> invReq,
    required int invReqFifoDepth,
    required ReadyAndValidInterface<DtiMessage> syncReq,
    required int syncReqFifoDepth,
    required ReadyAndValidInterface<DtiMessage> condisAck,
    required int condisAckFifoDepth,
    ReadyAndValidInterface<DtiMessage>? regWack,
    int? regWackFifoDepth,
    ReadyAndValidInterface<DtiMessage>? regRdata,
    int? regRdataFifoDepth,
    ReadyAndValidInterface<DtiMessage>? regWr,
    int? regWrFifoDepth,
    ReadyAndValidInterface<DtiMessage>? regRd,
    int? regRdFifoDepth,
    super.srcId,
    super.wakeupTx,
    super.arbiterGen,
    super.name = 'dtiTbuMainController',
  }) : super(sendMsgs: [
          transReq,
          invAck,
          syncAck,
          condisReq,
          if (regWack != null) regWack,
          if (regRdata != null) regRdata,
        ], sendCfgs: [
          DtiTxMessageInterfaceConfig(
              fifoDepth: transReqFifoDepth,
              isCredited: true,
              creditCountWidth: DtiTbuCondisAck.tokTransGntWidth),
          DtiTxMessageInterfaceConfig(fifoDepth: invAckFifoDepth),
          DtiTxMessageInterfaceConfig(
            fifoDepth: syncAckFifoDepth,
          ),
          DtiTxMessageInterfaceConfig(
              fifoDepth: condisReqFifoDepth, connectedExempt: true),
          if (regWack != null)
            DtiTxMessageInterfaceConfig(fifoDepth: regWackFifoDepth!),
          if (regRdata != null)
            DtiTxMessageInterfaceConfig(fifoDepth: regRdataFifoDepth!),
        ], rcvMsgs: [
          transResp,
          transFault,
          invReq,
          syncReq,
          condisAck,
          if (regWr != null) regWr,
          if (regRd != null) regRd,
        ], rcvCfgs: [
          DtiRxMessageInterfaceConfig(
            fifoDepth: transRespFifoDepth,
            mapToQueue: (msg) =>
                msg
                    .getRange(0, DtiTbuTransResp.msgTypeWidth)
                    .eq(DtiUpstreamMsgType.transResp.value) |
                msg
                    .getRange(0, DtiTbuTransResp.msgTypeWidth)
                    .eq(DtiUpstreamMsgType.transRespEx.value),
          ),
          DtiRxMessageInterfaceConfig(
            fifoDepth: transFaultFifoDepth,
            mapToQueue: (msg) => msg
                .getRange(0, DtiTbuTransFault.msgTypeWidth)
                .eq(DtiUpstreamMsgType.transFault.value),
          ),
          DtiRxMessageInterfaceConfig(
            fifoDepth: invReqFifoDepth,
            mapToQueue: (msg) => msg
                .getRange(0, DtiTbuInvReq.msgTypeWidth)
                .eq(DtiUpstreamMsgType.invReq.value),
          ),
          DtiRxMessageInterfaceConfig(
            fifoDepth: syncReqFifoDepth,
            mapToQueue: (msg) => msg
                .getRange(0, DtiTbuSyncReq.msgTypeWidth)
                .eq(DtiUpstreamMsgType.syncReq.value),
          ),
          DtiRxMessageInterfaceConfig(
            fifoDepth: condisAckFifoDepth,
            mapToQueue: (msg) => msg
                .getRange(0, DtiTbuCondisAck.msgTypeWidth)
                .eq(DtiUpstreamMsgType.condisAck.value),
          ),
          if (regWr != null)
            DtiRxMessageInterfaceConfig(
              fifoDepth: regWrFifoDepth!,
              mapToQueue: (msg) => msg
                  .getRange(0, DtiTbuRegWrite.msgTypeWidth)
                  .eq(DtiUpstreamMsgType.regWr.value),
            ),
          if (regRd != null)
            DtiRxMessageInterfaceConfig(
              fifoDepth: regRdFifoDepth!,
              mapToQueue: (msg) => msg
                  .getRange(0, DtiTbuRegRead.msgTypeWidth)
                  .eq(DtiUpstreamMsgType.regRd.value),
            ),
        ]) {
    _buildMain();
  }

  void _buildMain() {
    // we need to identify CONDIS_REQ and TRANS_REQ
    // for certain DTI specific activities
    var conReqIdx = -1;
    var transReqIdx = -1;
    for (var i = 0; i < sendMsgs.length; i++) {
      if (sendMsgs[i].data.msg is DtiTbuCondisReq) {
        conReqIdx = i;
      } else if (sendMsgs[i].data.msg is DtiTbuTransReq) {
        transReqIdx = i;
      }
    }
    if (conReqIdx < 0) {
      throw Exception(
          'This module is missing a required DtiTbuCondisReq interface!');
    }
    if (transReqIdx < 0) {
      throw Exception(
          'This module is missing a required DtiTbuTransReq interface!');
    }
    final condisReqSend = sendMsgs[conReqIdx];
    final condisReqData = DtiTbuCondisReq(name: 'condisReqData')
      ..gets(condisReqSend.data.msg);

    var conAckIdx = -1;
    var transRespIdx = -1;
    var transFaultIdx = -1;
    for (var i = 0; i < rcvMsgs.length; i++) {
      if (rcvMsgs[i].data.msg is DtiTbuCondisAck) {
        conAckIdx = i;
      } else if (rcvMsgs[i].data.msg is DtiTbuTransResp) {
        transRespIdx = i;
      } else if (rcvMsgs[i].data.msg is DtiTbuTransRespEx) {
        transRespIdx = i;
      } else if (rcvMsgs[i].data.msg is DtiTbuTransFault) {
        transFaultIdx = i;
      }
    }
    if (conAckIdx < 0) {
      throw Exception(
          'This module is missing a required DtiTbuCondisAck interface!');
    }
    if (transRespIdx < 0) {
      throw Exception('This module is missing a required '
          'DtiTbuTransResp or DtiTbuTransRespEx interface!');
    }

    final condisAckOut = rcvMsgs[conAckIdx];
    final condisAckData = DtiTbuCondisAck(name: 'condisAckData')
      ..gets(condisAckOut.data.msg);

    // on CondisAck, make sure to grab the granted # of tokens
    _transTokensGranted = Logic(
        name: 'transTokensGranted', width: DtiTbuCondisAck.tokTransGntWidth);
    Sequential(sys.clk, reset: ~sys.resetN, [
      _transTokensGranted <
          mux(condisAckOut.accepted & condisAckData.state.eq(1),
              condisAckData.tokTransGnt, _transTokensGranted),
    ]);

    // drive crediting logic for TRANS_REQ
    hasCredits[transReqIdx]! <=
        creditCnts[transReqIdx]!
            .count
            .lt(_transTokensGranted); // counter doesn't exceed max
    incrCredits[transReqIdx]! <=
        sendMsgs[transReqIdx].accepted; // sending a translation request
    decrCredits[transReqIdx]! <=
        rcvMsgs[transRespIdx].accepted |
            (transFaultIdx < 0
                ? Const(0)
                : rcvMsgs[transFaultIdx]
                    .accepted); // receiving a translation resp/respex/fault
    restartCredits[transReqIdx]! <=
        condisAckOut.accepted &
            condisAckData.state.eq(1); // get a condisack for a connect request

    // Connection state machine
    final connIn = condisReqSend.accepted & condisReqData.state.eq(1);
    final disconnIn = condisReqSend.accepted & condisReqData.state.eq(0);
    final connOut = condisAckOut.accepted & condisAckData.state.eq(1);
    final disconnOut = condisAckOut.accepted & condisAckData.state.eq(0);
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
        //  move to UNCONNECTED when ACK comes in that confirms disconnenction
        //  move back CONNECTED when ACK comes in that rejects disconnection
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
