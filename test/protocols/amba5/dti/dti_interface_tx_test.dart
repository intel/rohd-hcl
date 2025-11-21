import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

// TODO(kimmeljo):
//  add backpressure testing
//  add throughput testing

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
    expect(sender.msgAccepted.value.toBool(), true);
    await clk.nextNegedge;
    msgToSendValid.inject(1);
    msgToSend.zeroInit();
    msgToSend.translationId1.inject(0xef);
    expect(sender.msgAccepted.value.toBool(), true);

    // should see it on the interface in the next cycle
    await clk.nextNegedge;
    msgToSendValid.inject(0);
    expect(sender.msgAccepted.value.toBool(), true);
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
    expect(sender.msgAccepted.value.toBool(), true);
    await clk.nextNegedge;
    msgToSendValid.inject(1);
    msgToSend.zeroInit();
    msgToSend.translationId1.inject(0xef);
    expect(sender.msgAccepted.value.toBool(), true);

    // as of the next cycle, we should start to see flits
    final numBeats = (DtiTbuTransReq.totalWidth / stream.dataWidth).ceil();
    await clk.nextNegedge;
    msgToSendValid.inject(0);
    final flits = <LogicValue>[];
    for (var i = 0; i < numBeats; i++) {
      expect(stream.valid.value.toBool(), true);
      flits.add(stream.data!.value);
      expect(stream.last!.value.toBool(), i == numBeats - 1);
      expect(sender.msgAccepted.value.toBool(), i == numBeats - 1);
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
}
