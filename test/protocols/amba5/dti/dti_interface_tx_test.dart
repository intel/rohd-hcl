import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() async {
  tearDown(() async {
    await Simulator.reset();
  });

  test('doa - simple', () async {
    final sys = Axi5SystemInterface();
    final stream = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final msgToSendValid = Logic();
    final msgToSend = DtiTbuTransReq();
    final srcId = Logic(width: stream.idWidth);
    final destId = Logic(width: stream.destWidth);

    final sender = DtiInterfaceTx(
      sys: sys,
      stream: stream,
      msgToSendValid: msgToSendValid,
      msgToSend: msgToSend,
      srcId: srcId,
      destId: destId,
    );

    await sender.build();
  });

  test('doa - complex', () async {
    final sys = Axi5SystemInterface();
    final stream = Axi5StreamInterface(
        dataWidth: 32,
        destWidth: 4,
        useKeep: true,
        useLast: true,
        useWakeup: true,
        useStrb: true,
        userWidth: 4);
    final msgToSendValid = Logic();
    final msgToSend = DtiTbuTransReq();
    final srcId = Logic(width: stream.idWidth);
    final destId = Logic(width: stream.destWidth);

    final sender = DtiInterfaceTx(
      sys: sys,
      stream: stream,
      msgToSendValid: msgToSendValid,
      msgToSend: msgToSend,
      srcId: srcId,
      destId: destId,
    );

    await sender.build();
  });

  test('single beat - simple', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    final stream =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    final msgToSendValid = Logic()..put(0);
    final msgToSend = DtiTbuTransReq()..put(0);
    final srcId = Logic(width: stream.idWidth)..put(0xa);
    final destId = Logic(width: stream.destWidth)..put(0xb);
    stream.ready!.put(1);

    final sender = DtiInterfaceTx(
      sys: sys,
      stream: stream,
      msgToSendValid: msgToSendValid,
      msgToSend: msgToSend,
      srcId: srcId,
      destId: destId,
    );

    await sender.build();

    // WaveDumper(sender);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // push a message in
    expect(sender.canAcceptMsg.value.toBool(), true);
    await clk.nextNegedge;
    msgToSendValid.inject(1);
    msgToSend.zeroInit();
    msgToSend.translationId1.inject(0xef);
    expect(sender.canAcceptMsg.value.toBool(), true);

    // should see it on the interface in the next cycle
    await clk.nextNegedge;
    msgToSendValid.inject(0);
    expect(sender.canAcceptMsg.value.toBool(), true);
    expect(stream.valid.value.toBool(), true);
    expect(stream.last!.value.toBool(), true);
    expect(stream.id!.value.toInt(), 0xa);
    expect(stream.dest!.value.toInt(), 0xb);

    final reqOut = DtiTbuTransReq()
      ..gets(stream.data!.getRange(0, DtiTbuTransReq.totalWidth));
    expect(reqOut.msgType.value.toInt(), DtiDownstreamMsgType.transReq.value);
    expect(reqOut.translationId.value.toInt(), 0xef);

    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('multi beat - simple', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    final stream =
        Axi5StreamInterface(dataWidth: 32, destWidth: 4, useLast: true);
    final msgToSendValid = Logic()..put(0);
    final msgToSend = DtiTbuTransReq()..put(0);
    final srcId = Logic(width: stream.idWidth)..put(0xa);
    final destId = Logic(width: stream.destWidth)..put(0xb);
    stream.ready!.put(1);

    final sender = DtiInterfaceTx(
      sys: sys,
      stream: stream,
      msgToSendValid: msgToSendValid,
      msgToSend: msgToSend,
      srcId: srcId,
      destId: destId,
    );

    await sender.build();

    // WaveDumper(sender);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // push a message in
    expect(sender.canAcceptMsg.value.toBool(), true);
    await clk.nextNegedge;
    msgToSendValid.inject(1);
    msgToSend.zeroInit();
    msgToSend.translationId1.inject(0xef);
    expect(sender.canAcceptMsg.value.toBool(), true);

    // as of the next cycle, we should start to see flits
    final numBeats = (DtiTbuTransReq.totalWidth / stream.dataWidth).ceil();
    await clk.nextNegedge;
    msgToSendValid.inject(0);
    final flits = <LogicValue>[];
    for (var i = 0; i < numBeats; i++) {
      expect(stream.valid.value.toBool(), true);
      flits.add(stream.data!.value);
      expect(stream.last!.value.toBool(), i == numBeats - 1);
      expect(sender.canAcceptMsg.value.toBool(), i == numBeats - 1);
      await clk.nextNegedge;
    }

    final reqOut = DtiTbuTransReq()
      ..put(flits.rswizzle().getRange(0, DtiTbuTransReq.totalWidth));
    expect(reqOut.msgType.value.toInt(), DtiDownstreamMsgType.transReq.value);
    expect(reqOut.translationId.value.toInt(), 0xef);

    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('single beat - bandwidth', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    final stream =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    final msgToSendValid = Logic()..put(0);
    final msgToSend = DtiTbuTransReq()..put(0);
    final srcId = Logic(width: stream.idWidth)..put(0xa);
    final destId = Logic(width: stream.destWidth)..put(0xb);
    stream.ready!.put(1);

    final sender = DtiInterfaceTx(
      sys: sys,
      stream: stream,
      msgToSendValid: msgToSendValid,
      msgToSend: msgToSend,
      srcId: srcId,
      destId: destId,
    );

    await sender.build();

    // WaveDumper(sender);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // stream 100 consecutive transactions
    // expect 1 message per cycle to be accepted
    // i.e., the link is always busy
    for (var i = 0; i < 100; i++) {
      expect(sender.canAcceptMsg.value.toBool(), true);
      await clk.nextNegedge;
      msgToSendValid.inject(1);
      msgToSend.zeroInit();
      msgToSend.translationId1.put(i);
    }
    await clk.nextNegedge;
    msgToSendValid.inject(0);

    await clk.waitCycles(5);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('multi beat - bandwidth', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    final stream =
        Axi5StreamInterface(dataWidth: 32, destWidth: 4, useLast: true);
    final msgToSendValid = Logic()..put(0);
    final msgToSend = DtiTbuTransReq()..put(0);
    final srcId = Logic(width: stream.idWidth)..put(0xa);
    final destId = Logic(width: stream.destWidth)..put(0xb);
    stream.ready!.put(1);

    final sender = DtiInterfaceTx(
      sys: sys,
      stream: stream,
      msgToSendValid: msgToSendValid,
      msgToSend: msgToSend,
      srcId: srcId,
      destId: destId,
    );

    await sender.build();

    // WaveDumper(sender);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // stream 100 consecutive transactions
    // expect 1 message per [numBeats] cycles to be accepted
    // i.e., the link is always busy sending message flits
    final numBeats = (DtiTbuTransReq.totalWidth / stream.dataWidth).ceil();
    final cadence = numBeats - 1;

    // start up
    // need to wait 1 cycle extra for the 1st one
    await clk.nextPosedge;
    expect(sender.canAcceptMsg.value.toBool(), true);
    msgToSendValid.inject(1);
    msgToSend.zeroInit();
    msgToSend.translationId1.put(0);
    await clk.waitCycles(numBeats);
    expect(sender.canAcceptMsg.value.toBool(), true);
    msgToSend.translationId1.put(1);

    for (var i = 0; i < 100; i++) {
      await clk.waitCycles(cadence);
      expect(sender.canAcceptMsg.value.toBool(), true);
      msgToSend.translationId1.put(2 + i ~/ cadence);
    }
    await clk.nextPosedge;
    msgToSendValid.inject(0);

    await clk.waitCycles(5);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('single beat - backpressure', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    final stream =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    final msgToSendValid = Logic()..put(0);
    final msgToSend = DtiTbuTransReq()..put(0);
    final srcId = Logic(width: stream.idWidth)..put(0xa);
    final destId = Logic(width: stream.destWidth)..put(0xb);
    stream.ready!.put(0); // not ready

    final sender = DtiInterfaceTx(
      sys: sys,
      stream: stream,
      msgToSendValid: msgToSendValid,
      msgToSend: msgToSend,
      srcId: srcId,
      destId: destId,
    );

    await sender.build();

    // WaveDumper(sender);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // push a message in
    await clk.nextPosedge;
    msgToSendValid.inject(1);
    msgToSend.zeroInit();
    msgToSend.translationId1.inject(0xef);

    // attempt to push a second message in
    await clk.nextPosedge;
    msgToSend.translationId1.inject(0xde);

    // but should be reported as not being ready
    for (var i = 0; i < 10; i++) {
      await clk.nextNegedge;
      expect(sender.canAcceptMsg.value.toBool(), false);
    }

    // now the interface is ready
    await clk.nextPosedge;
    stream.ready!.inject(1);

    // should see it on the interface in the next cycle
    await clk.nextNegedge;
    expect(sender.canAcceptMsg.value.toBool(), true);
    expect(stream.valid.value.toBool(), true);
    expect(stream.last!.value.toBool(), true);
    expect(stream.id!.value.toInt(), 0xa);
    expect(stream.dest!.value.toInt(), 0xb);

    final reqOut = DtiTbuTransReq()
      ..gets(stream.data!.getRange(0, DtiTbuTransReq.totalWidth));
    expect(reqOut.msgType.value.toInt(), DtiDownstreamMsgType.transReq.value);
    expect(reqOut.translationId.value.toInt(), 0xef);

    await clk.nextPosedge;
    sender.msgToSendValid.inject(0);

    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('multi beat - backpressure', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    final stream =
        Axi5StreamInterface(dataWidth: 32, destWidth: 4, useLast: true);
    final msgToSendValid = Logic()..put(0);
    final msgToSend = DtiTbuTransReq()..put(0);
    final srcId = Logic(width: stream.idWidth)..put(0xa);
    final destId = Logic(width: stream.destWidth)..put(0xb);
    stream.ready!.put(1);

    final sender = DtiInterfaceTx(
      sys: sys,
      stream: stream,
      msgToSendValid: msgToSendValid,
      msgToSend: msgToSend,
      srcId: srcId,
      destId: destId,
    );

    await sender.build();

    // WaveDumper(sender);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    final numBeats = (DtiTbuTransReq.totalWidth / stream.dataWidth).ceil();
    final flits = <LogicValue>[];

    // push a message in
    await clk.nextPosedge;
    msgToSendValid.inject(1);
    msgToSend.zeroInit();
    msgToSend.translationId1.inject(0xef);

    // in the next cycle, let the first flit go
    await clk.nextPosedge;
    msgToSendValid.inject(0);
    await clk.nextNegedge;
    expect(stream.valid.value.toBool(), true);
    flits.add(stream.data!.value);
    expect(stream.last!.value.toBool(), false);

    // in the following cycle, interface is no longer ready
    await clk.nextPosedge;
    stream.ready!.inject(0);

    // hold this for some time
    for (var i = 0; i < 10; i++) {
      await clk.nextNegedge;
      expect(sender.canAcceptMsg.value.toBool(), false);
    }

    // interface becomes ready again
    await clk.nextPosedge;
    stream.ready!.inject(1);

    // should immediately see the remainder of the flits
    for (var i = 1; i < numBeats; i++) {
      await clk.nextNegedge;
      expect(stream.valid.value.toBool(), true);
      flits.add(stream.data!.value);
      expect(stream.last!.value.toBool(), i == numBeats - 1);
      expect(sender.canAcceptMsg.value.toBool(), i == numBeats - 1);
    }

    final reqOut = DtiTbuTransReq()
      ..put(flits.rswizzle().getRange(0, DtiTbuTransReq.totalWidth));
    expect(reqOut.msgType.value.toInt(), DtiDownstreamMsgType.transReq.value);
    expect(reqOut.translationId.value.toInt(), 0xef);

    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
