import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() async {
  tearDown(() async {
    await Simulator.reset();
  });

  test('doa - tbu main', () async {
    final sys = Axi5SystemInterface();
    final toSub = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final fromSub = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final srcId = Logic(width: toSub.idWidth);
    final destId = Logic(width: toSub.destWidth);

    final transReqD = DtiTbuTransReq();
    final transReq = ReadyAndValidInterface<DtiTbuTransReq>(transReqD);
    final invAckD = DtiTbuInvAck();
    final invAck = ReadyAndValidInterface<DtiTbuInvAck>(invAckD);
    final syncAckD = DtiTbuSyncAck();
    final syncAck = ReadyAndValidInterface<DtiTbuSyncAck>(syncAckD);
    final condisReqD = DtiTbuCondisReq();
    final condisReq = ReadyAndValidInterface<DtiTbuCondisReq>(condisReqD);

    final transRespD = DtiTbuTransRespEx();
    final transResp = ReadyAndValidInterface<DtiTbuTransRespEx>(transRespD);
    final transFaultD = DtiTbuTransFault();
    final transFault = ReadyAndValidInterface<DtiTbuTransFault>(transFaultD);
    final invReqD = DtiTbuInvReq();
    final invReq = ReadyAndValidInterface<DtiTbuInvReq>(invReqD);
    final syncReqD = DtiTbuSyncReq();
    final syncReq = ReadyAndValidInterface<DtiTbuSyncReq>(syncReqD);
    final condisAckD = DtiTbuCondisAck();
    final condisAck = ReadyAndValidInterface<DtiTbuCondisAck>(condisAckD);

    final main = DtiTbuMainController.standard(
        sys: sys,
        toSub: toSub,
        fromSub: fromSub,
        srcId: srcId,
        destId: destId,
        transReq: transReq,
        transReqFifoDepth: 8,
        invAck: invAck,
        invAckFifoDepth: 8,
        syncAck: syncAck,
        syncAckFifoDepth: 8,
        condisReq: condisReq,
        condisReqFifoDepth: 8,
        transResp: transResp,
        transRespFifoDepth: 8,
        transFault: transFault,
        transFaultFifoDepth: 8,
        invReq: invReq,
        invReqFifoDepth: 8,
        syncReq: syncReq,
        syncReqFifoDepth: 8,
        condisAck: condisAck,
        condisAckFifoDepth: 8);

    await main.build();
  });

  test('doa - tbu sub', () async {
    final sys = Axi5SystemInterface();
    final toSub = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final fromSub = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final srcId = Logic(width: toSub.idWidth);
    final destId = Logic(width: toSub.destWidth);

    final transReqD = DtiTbuTransReq();
    final transReq = ReadyAndValidInterface<DtiTbuTransReq>(transReqD);
    final invAckD = DtiTbuInvAck();
    final invAck = ReadyAndValidInterface<DtiTbuInvAck>(invAckD);
    final syncAckD = DtiTbuSyncAck();
    final syncAck = ReadyAndValidInterface<DtiTbuSyncAck>(syncAckD);
    final condisReqD = DtiTbuCondisReq();
    final condisReq = ReadyAndValidInterface<DtiTbuCondisReq>(condisReqD);

    final transRespD = DtiTbuTransRespEx();
    final transResp = ReadyAndValidInterface<DtiTbuTransRespEx>(transRespD);
    final transFaultD = DtiTbuTransFault();
    final transFault = ReadyAndValidInterface<DtiTbuTransFault>(transFaultD);
    final invReqD = DtiTbuInvReq();
    final invReq = ReadyAndValidInterface<DtiTbuInvReq>(invReqD);
    final syncReqD = DtiTbuSyncReq();
    final syncReq = ReadyAndValidInterface<DtiTbuSyncReq>(syncReqD);
    final condisAckD = DtiTbuCondisAck();
    final condisAck = ReadyAndValidInterface<DtiTbuCondisAck>(condisAckD);

    final main = DtiTbuSubController.standard(
        sys: sys,
        toSub: toSub,
        fromSub: fromSub,
        srcId: srcId,
        destId: destId,
        transReq: transReq,
        transReqFifoDepth: 8,
        invAck: invAck,
        invAckFifoDepth: 8,
        syncAck: syncAck,
        syncAckFifoDepth: 8,
        condisReq: condisReq,
        condisReqFifoDepth: 8,
        transResp: transResp,
        transRespFifoDepth: 8,
        transFault: transFault,
        transFaultFifoDepth: 8,
        invReq: invReq,
        invReqFifoDepth: 8,
        syncReq: syncReq,
        syncReqFifoDepth: 8,
        condisAck: condisAck,
        condisAckFifoDepth: 8);

    await main.build();
  });
}
