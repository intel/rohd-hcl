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
    final wakeup = Logic();

    final transReqD = DtiTbuTransReq();
    final transReqDa =
        DtiMessage(msg: transReqD, streamId: Logic(width: outStream.destWidth));
    final transReq = ReadyAndValidInterface<DtiMessage>(transReqDa);
    final invAckD = DtiTbuInvAck();
    final invAckDa =
        DtiMessage(msg: invAckD, streamId: Logic(width: outStream.destWidth));
    final invAck = ReadyAndValidInterface<DtiMessage>(invAckDa);
    final syncAckD = DtiTbuSyncAck();
    final syncAckDa =
        DtiMessage(msg: syncAckD, streamId: Logic(width: outStream.destWidth));
    final syncAck = ReadyAndValidInterface<DtiMessage>(syncAckDa);
    final condisReqD = DtiTbuCondisReq();
    final condisReqDa = DtiMessage(
        msg: condisReqD, streamId: Logic(width: outStream.destWidth));
    final condisReq = ReadyAndValidInterface<DtiMessage>(condisReqDa);

    final transRespD = DtiTbuTransRespEx();
    final transRespDa = DtiMessage(
        msg: transRespD, streamId: Logic(width: outStream.destWidth));
    final transResp = ReadyAndValidInterface<DtiMessage>(transRespDa);
    final transFaultD = DtiTbuTransFault();
    final transFaultDa = DtiMessage(
        msg: transFaultD, streamId: Logic(width: outStream.destWidth));
    final transFault = ReadyAndValidInterface<DtiMessage>(transFaultDa);
    final invReqD = DtiTbuInvReq();
    final invReqDa =
        DtiMessage(msg: invReqD, streamId: Logic(width: outStream.destWidth));
    final invReq = ReadyAndValidInterface<DtiMessage>(invReqDa);
    final syncReqD = DtiTbuSyncReq();
    final syncReqDa =
        DtiMessage(msg: syncReqD, streamId: Logic(width: outStream.destWidth));
    final syncReq = ReadyAndValidInterface<DtiMessage>(syncReqDa);
    final condisAckD = DtiTbuCondisAck();
    final condisAckDa = DtiMessage(
        msg: condisAckD, streamId: Logic(width: outStream.destWidth));
    final condisAck = ReadyAndValidInterface<DtiMessage>(condisAckDa);

    final main = DtiTbuMainController.standard(
        sys: sys,
        outStream: outStream,
        inStream: inStream,
        srcId: srcId,
        wakeupTx: wakeup,
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
    final wakeup = Logic();

    final transReqD = DtiTbuTransReq();
    final transReqDa =
        DtiMessage(msg: transReqD, streamId: Logic(width: outStream.destWidth));
    final transReq = ReadyAndValidInterface<DtiMessage>(transReqDa);
    final invAckD = DtiTbuInvAck();
    final invAckDa =
        DtiMessage(msg: invAckD, streamId: Logic(width: outStream.destWidth));
    final invAck = ReadyAndValidInterface<DtiMessage>(invAckDa);
    final syncAckD = DtiTbuSyncAck();
    final syncAckDa =
        DtiMessage(msg: syncAckD, streamId: Logic(width: outStream.destWidth));
    final syncAck = ReadyAndValidInterface<DtiMessage>(syncAckDa);
    final condisReqD = DtiTbuCondisReq();
    final condisReqDa = DtiMessage(
        msg: condisReqD, streamId: Logic(width: outStream.destWidth));
    final condisReq = ReadyAndValidInterface<DtiMessage>(condisReqDa);

    final transRespD = DtiTbuTransRespEx();
    final transRespDa = DtiMessage(
        msg: transRespD, streamId: Logic(width: outStream.destWidth));
    final transResp = ReadyAndValidInterface<DtiMessage>(transRespDa);
    final transFaultD = DtiTbuTransFault();
    final transFaultDa = DtiMessage(
        msg: transFaultD, streamId: Logic(width: outStream.destWidth));
    final transFault = ReadyAndValidInterface<DtiMessage>(transFaultDa);
    final invReqD = DtiTbuInvReq();
    final invReqDa =
        DtiMessage(msg: invReqD, streamId: Logic(width: outStream.destWidth));
    final invReq = ReadyAndValidInterface<DtiMessage>(invReqDa);
    final syncReqD = DtiTbuSyncReq();
    final syncReqDa =
        DtiMessage(msg: syncReqD, streamId: Logic(width: outStream.destWidth));
    final syncReq = ReadyAndValidInterface<DtiMessage>(syncReqDa);
    final condisAckD = DtiTbuCondisAck();
    final condisAckDa = DtiMessage(
        msg: condisAckD, streamId: Logic(width: outStream.destWidth));
    final condisAck = ReadyAndValidInterface<DtiMessage>(condisAckDa);

    final main = DtiTbuSubController.standard(
        sys: sys,
        outStream: outStream,
        inStream: inStream,
        srcId: srcId,
        wakeupTx: wakeup,
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
    final wakeup = Logic()..put(1);
    inStream.dest!.put(srcId.value);

    final transReqD = DtiTbuTransReq()..zeroInit();
    final transReqDa = DtiMessage(
        msg: transReqD, streamId: Logic(width: outStream.destWidth)..put(0x0));
    final transReq = ReadyAndValidInterface<DtiMessage>(transReqDa);
    transReq.valid.put(0);

    final invAckD = DtiTbuInvAck()..zeroInit();
    final invAckDa = DtiMessage(
        msg: invAckD, streamId: Logic(width: outStream.destWidth)..put(0x1));
    final invAck = ReadyAndValidInterface<DtiMessage>(invAckDa);
    invAck.valid.put(0);

    final syncAckD = DtiTbuSyncAck()..zeroInit();
    final syncAckDa = DtiMessage(
        msg: syncAckD, streamId: Logic(width: outStream.destWidth)..put(0x2));
    final syncAck = ReadyAndValidInterface<DtiMessage>(syncAckDa);
    syncAck.valid.put(0);

    final condisReqD = DtiTbuCondisReq()..zeroInit();
    final condisReqDa = DtiMessage(
        msg: condisReqD, streamId: Logic(width: outStream.destWidth)..put(0x3));
    final condisReq = ReadyAndValidInterface<DtiMessage>(condisReqDa);
    condisReq.valid.put(0);

    final transRespD = DtiTbuTransRespEx();
    final transRespDa =
        DtiMessage(msg: transRespD, streamId: Logic(width: inStream.idWidth));
    final transResp = ReadyAndValidInterface<DtiMessage>(transRespDa);
    transResp.ready.put(1);

    final transFaultD = DtiTbuTransFault();
    final transFaultDa =
        DtiMessage(msg: transFaultD, streamId: Logic(width: inStream.idWidth));
    final transFault = ReadyAndValidInterface<DtiMessage>(transFaultDa);
    transFault.ready.put(1);

    final invReqD = DtiTbuInvReq();
    final invReqDa =
        DtiMessage(msg: invReqD, streamId: Logic(width: inStream.idWidth));
    final invReq = ReadyAndValidInterface<DtiMessage>(invReqDa);
    invReq.ready.put(1);

    final syncReqD = DtiTbuSyncReq();
    final syncReqDa =
        DtiMessage(msg: syncReqD, streamId: Logic(width: inStream.idWidth));
    final syncReq = ReadyAndValidInterface<DtiMessage>(syncReqDa);
    syncReq.ready.put(1);

    final condisAckD = DtiTbuCondisAck();
    final condisAckDa =
        DtiMessage(msg: condisAckD, streamId: Logic(width: inStream.idWidth));
    final condisAck = ReadyAndValidInterface<DtiMessage>(condisAckDa);
    condisAck.ready.put(1);

    final main = DtiTbuMainController.standard(
        sys: sys,
        outStream: outStream,
        inStream: inStream,
        srcId: srcId,
        wakeupTx: wakeup,
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
    final condisAckCheck = DtiTbuCondisAck()..gets(condisAck.data.msg);
    expect(condisAckCheck.tokTransGnt.value.toInt(), 0x5);
    expect(condisAckCheck.state.value.toInt(), 0x1);

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
    final transRespCheck = DtiTbuTransRespEx()..gets(transResp.data.msg);
    expect(transRespCheck.translationId.value.toInt(), 0xcc);
    expect(transRespCheck.oa.value.toInt(), 0xbeefdead);

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
    final wakeup = Logic()..put(1);
    inStream.dest!.put(srcId.value);

    final transReqD = DtiTbuTransReq();
    final transReqDa =
        DtiMessage(msg: transReqD, streamId: Logic(width: outStream.destWidth));
    final transReq = ReadyAndValidInterface<DtiMessage>(transReqDa);
    transReq.ready.put(1);

    final invAckD = DtiTbuInvAck();
    final invAckDa =
        DtiMessage(msg: invAckD, streamId: Logic(width: outStream.destWidth));
    final invAck = ReadyAndValidInterface<DtiMessage>(invAckDa);
    invAck.ready.put(1);

    final syncAckD = DtiTbuSyncAck();
    final syncAckDa =
        DtiMessage(msg: syncAckD, streamId: Logic(width: outStream.destWidth));
    final syncAck = ReadyAndValidInterface<DtiMessage>(syncAckDa);
    syncAck.ready.put(1);

    final condisReqD = DtiTbuCondisReq();
    final condisReqDa = DtiMessage(
        msg: condisReqD, streamId: Logic(width: outStream.destWidth));
    final condisReq = ReadyAndValidInterface<DtiMessage>(condisReqDa);
    condisReq.ready.put(1);

    final transRespD = DtiTbuTransRespEx()..zeroInit();
    final transRespDa = DtiMessage(
        msg: transRespD, streamId: Logic(width: inStream.idWidth)..put(0x0));
    final transResp = ReadyAndValidInterface<DtiMessage>(transRespDa);
    transResp.valid.put(0);

    final transFaultD = DtiTbuTransFault()..zeroInit();
    final transFaultDa = DtiMessage(
        msg: transFaultD, streamId: Logic(width: inStream.idWidth)..put(0x1));
    final transFault = ReadyAndValidInterface<DtiMessage>(transFaultDa);
    transFault.valid.put(0);

    final invReqD = DtiTbuInvReq()..zeroInit();
    final invReqDa = DtiMessage(
        msg: invReqD, streamId: Logic(width: inStream.idWidth)..put(0x2));
    final invReq = ReadyAndValidInterface<DtiMessage>(invReqDa);
    invReq.valid.put(0);

    final syncReqD = DtiTbuSyncReq()..zeroInit();
    final syncReqDa = DtiMessage(
        msg: syncReqD, streamId: Logic(width: inStream.idWidth)..put(0x3));
    final syncReq = ReadyAndValidInterface<DtiMessage>(syncReqDa);
    syncReq.valid.put(0);

    final condisAckD = DtiTbuCondisAck()..zeroInit();
    final condisAckDa = DtiMessage(
        msg: condisAckD, streamId: Logic(width: inStream.idWidth)..put(0x4));
    final condisAck = ReadyAndValidInterface<DtiMessage>(condisAckDa);
    condisAck.valid.put(0);

    final main = DtiTbuSubController.standard(
        sys: sys,
        outStream: outStream,
        inStream: inStream,
        srcId: srcId,
        wakeupTx: wakeup,
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
    final condisReqCheck = DtiTbuCondisReq()..gets(condisReq.data.msg);
    expect(condisReqCheck.tokTransReq.value.toInt(), 0x5);
    expect(condisReqCheck.tokInvGnt.value.toInt(), 0x5);
    expect(condisReqCheck.state.value.toInt(), 0x1);

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
    final transReqCheck = DtiTbuTransReq()..gets(transReq.data.msg);
    expect(transReqCheck.translationId.value.toInt(), 0xdd);
    expect(transReqCheck.addr.value.toInt(), 0xdeadbeef);

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
