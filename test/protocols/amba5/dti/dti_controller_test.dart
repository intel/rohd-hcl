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

  test('simple connect+trans - tbu main', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);
    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    final toSub =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    toSub.ready!.put(1);

    final fromSub =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    fromSub.valid.put(0);
    fromSub.id!.put(0);
    fromSub.data!.put(0);
    fromSub.last!.put(0);

    final srcId = Logic(width: toSub.idWidth)..put(0xa);
    final destId = Logic(width: toSub.destWidth)..put(0xb);
    fromSub.dest!.put(srcId.value);

    final transReqD = DtiTbuTransReq()..zeroInit();
    final transReq = ReadyAndValidInterface<DtiTbuTransReq>(transReqD);
    transReq.valid.put(0);

    final invAckD = DtiTbuInvAck()..zeroInit();
    final invAck = ReadyAndValidInterface<DtiTbuInvAck>(invAckD);
    invAck.valid.put(0);

    final syncAckD = DtiTbuSyncAck()..zeroInit();
    final syncAck = ReadyAndValidInterface<DtiTbuSyncAck>(syncAckD);
    syncAck.valid.put(0);

    final condisReqD = DtiTbuCondisReq()..zeroInit();
    final condisReq = ReadyAndValidInterface<DtiTbuCondisReq>(condisReqD);
    condisReq.valid.put(0);

    final transRespD = DtiTbuTransRespEx();
    final transResp = ReadyAndValidInterface<DtiTbuTransRespEx>(transRespD);
    transResp.ready.put(1);

    final transFaultD = DtiTbuTransFault();
    final transFault = ReadyAndValidInterface<DtiTbuTransFault>(transFaultD);
    transFault.ready.put(1);

    final invReqD = DtiTbuInvReq();
    final invReq = ReadyAndValidInterface<DtiTbuInvReq>(invReqD);
    invReq.ready.put(1);

    final syncReqD = DtiTbuSyncReq();
    final syncReq = ReadyAndValidInterface<DtiTbuSyncReq>(syncReqD);
    syncReq.ready.put(1);

    final condisAckD = DtiTbuCondisAck();
    final condisAck = ReadyAndValidInterface<DtiTbuCondisAck>(condisAckD);
    condisAck.ready.put(1);

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

    WaveDumper(main);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // send a CondisReq in
    condisReqD.tokTransReq.put(0x5);
    condisReqD.tokInvGnt.put(0x5);
    condisReqD.state.put(0x1);
    await clk.nextPosedge;
    expect(transReq.ready.value.toBool(), false);
    expect(invAck.ready.value.toBool(), false);
    expect(syncAck.ready.value.toBool(), false);
    expect(condisReq.ready.value.toBool(), true);
    condisReq.valid.inject(1);

    // wait for the CondisReq to go out on the interface
    await clk.nextPosedge;
    condisReq.valid.inject(0);
    while (!toSub.valid.value.toBool()) {
      await clk.nextNegedge;
    }

    // send a CondisAck back
    await clk.nextPosedge;
    fromSub.valid.inject(1);
    final tmp1 = DtiTbuCondisAck()
      ..zeroInit()
      ..tokTransGnt1.put(0x5)
      ..state.put(1);
    fromSub.data!.inject(tmp1.value);
    fromSub.last!.inject(1);
    await clk.nextPosedge;
    fromSub.valid.inject(0);
    fromSub.last!.inject(0);

    // wait condisAck to be reported
    while (!condisAck.valid.value.toBool()) {
      await clk.nextNegedge;
    }
    expect(condisAck.data.tokTransGnt.value.toInt(), 0x5);
    expect(condisAck.data.state.value.toInt(), 0x1);

    // send a TransReq in
    transReqD.translationId1.put(0xcc);
    transReqD.addr.put(0xdeadbeef);
    await clk.nextPosedge;
    expect(transReq.ready.value.toBool(), true);
    expect(invAck.ready.value.toBool(), true);
    expect(syncAck.ready.value.toBool(), true);
    transReq.valid.inject(1);

    // wait for the TransReq to go out on the interface
    await clk.nextPosedge;
    transReq.valid.inject(0);
    while (!toSub.valid.value.toBool()) {
      await clk.nextNegedge;
    }

    // send a TransResp back
    await clk.nextPosedge;
    fromSub.valid.inject(1);
    final tmp2 = DtiTbuTransRespEx()
      ..zeroInit()
      ..translationId1.put(0xcc)
      ..oa.put(0xbeefdead);
    fromSub.data!.inject(tmp2.value);
    fromSub.last!.inject(1);
    await clk.nextPosedge;
    fromSub.valid.inject(0);
    fromSub.last!.inject(0);

    // wait for transResp to be reported
    while (!transResp.valid.value.toBool()) {
      await clk.nextNegedge;
    }
    expect(transResp.data.translationId.value.toInt(), 0xcc);
    expect(transResp.data.oa.value.toInt(), 0xbeefdead);

    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
