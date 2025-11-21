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
    final outStream = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final inStream = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final srcId = Logic(width: outStream.idWidth);
    final destId = Logic(width: outStream.destWidth);

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
        outStream: outStream,
        inStream: inStream,
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
    final outStream = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final inStream = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final srcId = Logic(width: outStream.idWidth);
    final destId = Logic(width: outStream.destWidth);

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
        outStream: outStream,
        inStream: inStream,
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

    final outStream =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    outStream.ready!.put(1);

    final inStream =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    inStream.valid.put(0);
    inStream.id!.put(0);
    inStream.data!.put(0);
    inStream.last!.put(0);

    final srcId = Logic(width: outStream.idWidth)..put(0xa);
    final destId = Logic(width: outStream.destWidth)..put(0xb);
    inStream.dest!.put(srcId.value);

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
        outStream: outStream,
        inStream: inStream,
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

    // WaveDumper(main);

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
    while (!outStream.valid.value.toBool()) {
      await clk.nextNegedge;
    }

    // send a CondisAck back
    await clk.nextPosedge;
    inStream.valid.inject(1);
    final tmp1 = DtiTbuCondisAck()
      ..zeroInit()
      ..tokTransGnt1.put(0x5)
      ..state.put(1);
    inStream.data!.inject(tmp1.value);
    inStream.last!.inject(1);
    await clk.nextPosedge;
    inStream.valid.inject(0);
    inStream.last!.inject(0);

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
    while (!outStream.valid.value.toBool()) {
      await clk.nextNegedge;
    }

    // send a TransResp back
    await clk.nextPosedge;
    inStream.valid.inject(1);
    final tmp2 = DtiTbuTransRespEx()
      ..zeroInit()
      ..translationId1.put(0xcc)
      ..oa.put(0xbeefdead);
    inStream.data!.inject(tmp2.value);
    inStream.last!.inject(1);
    await clk.nextPosedge;
    inStream.valid.inject(0);
    inStream.last!.inject(0);

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

  test('simple connect+trans - tbu sub', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);
    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    final outStream =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    outStream.ready!.put(1);

    final inStream =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    inStream.valid.put(0);
    inStream.id!.put(0);
    inStream.data!.put(0);
    inStream.last!.put(0);

    final srcId = Logic(width: outStream.idWidth)..put(0xa);
    final destId = Logic(width: outStream.destWidth)..put(0xb);
    inStream.dest!.put(srcId.value);

    final transReqD = DtiTbuTransReq();
    final transReq = ReadyAndValidInterface<DtiTbuTransReq>(transReqD);
    transReq.ready.put(1);

    final invAckD = DtiTbuInvAck();
    final invAck = ReadyAndValidInterface<DtiTbuInvAck>(invAckD);
    invAck.ready.put(1);

    final syncAckD = DtiTbuSyncAck();
    final syncAck = ReadyAndValidInterface<DtiTbuSyncAck>(syncAckD);
    syncAck.ready.put(1);

    final condisReqD = DtiTbuCondisReq();
    final condisReq = ReadyAndValidInterface<DtiTbuCondisReq>(condisReqD);
    condisReq.ready.put(1);

    final transRespD = DtiTbuTransRespEx()..zeroInit();
    final transResp = ReadyAndValidInterface<DtiTbuTransRespEx>(transRespD);
    transResp.valid.put(0);

    final transFaultD = DtiTbuTransFault()..zeroInit();
    final transFault = ReadyAndValidInterface<DtiTbuTransFault>(transFaultD);
    transFault.valid.put(0);

    final invReqD = DtiTbuInvReq()..zeroInit();
    final invReq = ReadyAndValidInterface<DtiTbuInvReq>(invReqD);
    invReq.valid.put(0);

    final syncReqD = DtiTbuSyncReq()..zeroInit();
    final syncReq = ReadyAndValidInterface<DtiTbuSyncReq>(syncReqD);
    syncReq.valid.put(0);

    final condisAckD = DtiTbuCondisAck()..zeroInit();
    final condisAck = ReadyAndValidInterface<DtiTbuCondisAck>(condisAckD);
    condisAck.valid.put(0);

    final main = DtiTbuSubController.standard(
        sys: sys,
        outStream: outStream,
        inStream: inStream,
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

    // receive a connection request
    expect(transResp.ready.value.toBool(), false);
    expect(transFault.ready.value.toBool(), false);
    expect(invReq.ready.value.toBool(), false);
    expect(syncReq.ready.value.toBool(), false);
    inStream.valid.inject(1);
    final tmp1 = DtiTbuCondisReq()
      ..zeroInit()
      ..tokTransReq1.put(0x5)
      ..tokInvGnt.put(0x5)
      ..state.put(1);
    inStream.data!.inject(tmp1.value);
    inStream.last!.inject(1);
    await clk.nextPosedge;
    inStream.valid.inject(0);
    inStream.last!.inject(0);

    // wait condisReq to be reported
    while (!condisReq.valid.value.toBool()) {
      await clk.nextNegedge;
    }
    expect(condisReq.data.tokTransReq.value.toInt(), 0x5);
    expect(condisReq.data.tokInvGnt.value.toInt(), 0x5);
    expect(condisReq.data.state.value.toInt(), 0x1);

    // send the CondisAck
    condisAckD.tokTransGnt1.put(0x5);
    condisAckD.state.put(0x1);
    await clk.nextPosedge;
    expect(condisAck.ready.value.toBool(), true);
    condisAck.valid.inject(1);

    // wait for the CondisAck to go out on the interface
    await clk.nextPosedge;
    condisAck.valid.inject(0);
    while (!outStream.valid.value.toBool()) {
      await clk.nextNegedge;
    }
    final out1 = DtiTbuCondisAck()
      ..gets(outStream.data!.getRange(0, DtiTbuCondisAck.totalWidth));
    expect(out1.tokTransGnt.value.toInt(), 0x5);
    expect(out1.state.value.toInt(), 0x1);

    // receive a translation request
    expect(transResp.ready.value.toBool(), true);
    expect(transFault.ready.value.toBool(), true);
    expect(invReq.ready.value.toBool(), true);
    expect(syncReq.ready.value.toBool(), true);
    inStream.valid.inject(1);
    final tmp2 = DtiTbuTransReq()
      ..zeroInit()
      ..translationId1.put(0xdd)
      ..addr.put(0xdeadbeef);
    inStream.data!.inject(tmp2.value);
    inStream.last!.inject(1);
    await clk.nextPosedge;
    inStream.valid.inject(0);
    inStream.last!.inject(0);

    // wait transReq to be reported
    while (!transReq.valid.value.toBool()) {
      await clk.nextNegedge;
    }
    expect(transReq.data.translationId.value.toInt(), 0xdd);
    expect(transReq.data.addr.value.toInt(), 0xdeadbeef);

    // send the TransResp
    transRespD.translationId1.put(0xdd);
    transRespD.oa.put(0xbeefdead);
    await clk.nextPosedge;
    transResp.valid.inject(1);

    // wait for the TransResp to go out on the interface
    await clk.nextPosedge;
    transResp.valid.inject(0);
    while (!outStream.valid.value.toBool()) {
      await clk.nextNegedge;
    }
    final out2 = DtiTbuTransRespEx()
      ..gets(outStream.data!.getRange(0, DtiTbuTransRespEx.totalWidth));
    expect(out2.translationId.value.toInt(), 0xdd);
    expect(out2.oa.value.toInt(), 0xbeefdead);

    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
