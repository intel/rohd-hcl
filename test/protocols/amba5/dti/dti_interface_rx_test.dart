import 'dart:async';
import 'dart:math';

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
    final srcId = Logic(width: stream.destWidth);
    final canAcceptMsg = Logic();

    final receiver = DtiInterfaceRx(
        sys: sys,
        stream: stream,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();
  });

  test('doa - complex', () async {
    final sys = Axi5SystemInterface();
    final stream = Axi5StreamInterface(dataWidth: 32, destWidth: 4);
    final srcId = Logic(width: stream.destWidth);
    final canAcceptMsg = Logic();

    final receiver = DtiInterfaceRx(
        sys: sys,
        stream: stream,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();
  });

  test('single beat - simple', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    final stream =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    final canAcceptMsg = Logic()..put(1);
    final srcId = Logic(width: stream.destWidth)..put(0xa);

    stream.valid.put(0);
    stream.id!.put(0);
    stream.dest!.put(srcId.value);
    stream.data!.put(0);
    stream.last!.put(0);

    final receiver = DtiInterfaceRx(
        sys: sys,
        stream: stream,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();

    // WaveDumper(receiver);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // send a message on the interface
    await clk.nextPosedge;
    expect(stream.ready!.value.toBool(), true);
    expect(receiver.msgValid.value.toBool(), false);
    final respIn = DtiTbuTransRespEx()
      ..zeroInit()
      ..translationId1.put(0xfe);
    stream.valid.inject(1);
    stream.data!.inject(respIn.zeroExtend(stream.dataWidth).value);
    stream.last!.inject(1);

    // should see the message out in the same cycle
    await clk.nextNegedge;
    expect(receiver.msgValid.value.toBool(), true);
    final respOut = DtiTbuTransRespEx()
      ..gets(receiver.msg.getRange(0, DtiTbuTransRespEx.totalWidth));
    expect(respOut.msgType.value.toInt(), DtiUpstreamMsgType.transRespEx.value);
    expect(respOut.translationId.value.toInt(), 0xfe);

    await clk.nextPosedge;
    stream.valid.put(0);

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

    // final stream =
    final stream =
        Axi5StreamInterface(dataWidth: 32, destWidth: 4, useLast: true);
    final canAcceptMsg = Logic()..put(1);
    final srcId = Logic(width: stream.destWidth)..put(0xa);

    stream.valid.put(0);
    stream.id!.put(0);
    stream.dest!.put(srcId.value);
    stream.data!.put(0);
    stream.last!.put(0);

    final receiver = DtiInterfaceRx(
        sys: sys,
        stream: stream,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();

    // WaveDumper(receiver);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // send a message on the interface
    // this occurs over multiple beats
    await clk.nextPosedge;
    expect(stream.ready!.value.toBool(), true);
    expect(receiver.msgValid.value.toBool(), false);
    final respIn = DtiTbuTransRespEx()
      ..zeroInit()
      ..translationId1.put(0xfe);
    final numBeats = (DtiTbuTransRespEx.totalWidth / stream.dataWidth).ceil();

    LogicValue? msgOut;
    for (var i = 0; i < numBeats; i++) {
      stream.valid.inject(1);
      stream.data!.inject(respIn
          .getRange(i * stream.dataWidth,
              min((i + 1) * stream.dataWidth, respIn.width))
          .zeroExtend(stream.dataWidth)
          .value);
      stream.last!.inject(i == numBeats - 1);
      await clk.nextNegedge;
      expect(receiver.msgValid.value.toBool(), i == numBeats - 1);
      if (i == numBeats - 1) {
        msgOut = receiver.msg.value;
      }
      await clk.nextPosedge;
    }

    // can now check the message
    stream.valid.inject(0);
    final respOut = DtiTbuTransRespEx()
      ..put(msgOut!.getRange(0, DtiTbuTransRespEx.totalWidth));
    expect(respOut.msgType.value.toInt(), DtiUpstreamMsgType.transRespEx.value);
    expect(respOut.translationId.value.toInt(), 0xfe);

    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('multi beat - scarier', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    // final stream =
    final stream =
        Axi5StreamInterface(dataWidth: 8, destWidth: 4, useLast: true);
    final canAcceptMsg = Logic()..put(1);
    final srcId = Logic(width: stream.destWidth)..put(0xa);

    stream.valid.put(0);
    stream.id!.put(0);
    stream.dest!.put(srcId.value);
    stream.data!.put(0);
    stream.last!.put(0);

    final receiver = DtiInterfaceRx(
        sys: sys,
        stream: stream,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();

    // WaveDumper(receiver);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // send a message on the interface
    // this occurs over multiple beats
    await clk.nextPosedge;
    expect(stream.ready!.value.toBool(), true);
    expect(receiver.msgValid.value.toBool(), false);
    final respIn = DtiTbuTransFault()
      ..zeroInit()
      ..translationId1.put(0xfe)
      ..translationId2.put(0xb);
    final numBeats = (DtiTbuTransFault.totalWidth / stream.dataWidth).ceil();

    LogicValue? msgOut;
    for (var i = 0; i < numBeats; i++) {
      stream.valid.inject(1);
      stream.data!.inject(respIn
          .getRange(i * stream.dataWidth,
              min((i + 1) * stream.dataWidth, respIn.width))
          .zeroExtend(stream.dataWidth)
          .value);
      stream.last!.inject(i == numBeats - 1);
      await clk.nextNegedge;
      expect(receiver.msgValid.value.toBool(), i == numBeats - 1);
      if (i == numBeats - 1) {
        msgOut = receiver.msg.value;
      }
      await clk.nextPosedge;
    }

    // can now check the message
    stream.valid.inject(0);
    final respOut = DtiTbuTransFault()
      ..put(msgOut!.getRange(0, DtiTbuTransFault.totalWidth));
    expect(respOut.msgType.value.toInt(), DtiUpstreamMsgType.transFault.value);
    expect(respOut.translationId.value.toInt(), 0xbfe);

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
    final canAcceptMsg = Logic()..put(1);
    final srcId = Logic(width: stream.destWidth)..put(0xa);

    stream.valid.put(0);
    stream.id!.put(0);
    stream.dest!.put(srcId.value);
    stream.data!.put(0);
    stream.last!.put(0);

    final receiver = DtiInterfaceRx(
        sys: sys,
        stream: stream,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();

    // WaveDumper(receiver);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // stream 100 messages on the interface
    // should be accepting every cycle
    await clk.nextPosedge;
    for (var i = 0; i < 100; i++) {
      expect(stream.ready!.value.toBool(), true);
      final respIn = DtiTbuTransRespEx()
        ..zeroInit()
        ..translationId1.put(i);
      stream.valid.inject(1);
      stream.data!.inject(respIn.zeroExtend(stream.dataWidth).value);
      stream.last!.inject(1);
      await clk.nextPosedge;
      expect(receiver.msgValid.value.toBool(), true);
    }
    stream.valid.put(0);

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

    // final stream =
    final stream =
        Axi5StreamInterface(dataWidth: 32, destWidth: 4, useLast: true);
    final canAcceptMsg = Logic()..put(1);
    final srcId = Logic(width: stream.destWidth)..put(0xa);

    stream.valid.put(0);
    stream.id!.put(0);
    stream.dest!.put(srcId.value);
    stream.data!.put(0);
    stream.last!.put(0);

    final receiver = DtiInterfaceRx(
        sys: sys,
        stream: stream,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();

    // WaveDumper(receiver);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // stream 100 messages consecutively on the interface
    // the interface should never backpressure
    // and every [numBeats] cycles the receiver should report a message
    final numBeats = (DtiTbuTransRespEx.totalWidth / stream.dataWidth).ceil();
    final respIn = DtiTbuTransRespEx()..zeroInit();

    await clk.nextPosedge;
    for (var i = 0; i < 100; i++) {
      expect(stream.ready!.value.toBool(), true);
      final beat = i % numBeats;
      stream.valid.inject(1);
      respIn.translationId1.put(i ~/ numBeats);
      stream.data!.inject(respIn
          .getRange(beat * stream.dataWidth,
              min((beat + 1) * stream.dataWidth, respIn.width))
          .zeroExtend(stream.dataWidth)
          .value);
      stream.last!.inject(beat == numBeats - 1);
      await clk.nextNegedge;
      expect(receiver.msgValid.value.toBool(), beat == numBeats - 1);
      await clk.nextPosedge;
    }
    stream.valid.inject(0);

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
    final canAcceptMsg = Logic()..put(0); // can't accept yet
    final srcId = Logic(width: stream.destWidth)..put(0xa);

    stream.valid.put(0);
    stream.id!.put(0);
    stream.dest!.put(srcId.value);
    stream.data!.put(0);
    stream.last!.put(0);

    final receiver = DtiInterfaceRx(
        sys: sys,
        stream: stream,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();

    // WaveDumper(receiver);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    // try sending a message
    await clk.nextPosedge;
    final respIn = DtiTbuTransRespEx()
      ..zeroInit()
      ..translationId1.put(0xfe);
    stream.valid.inject(1);
    stream.data!.inject(respIn.zeroExtend(stream.dataWidth).value);
    stream.last!.inject(1);

    // but should be reported as not being ready
    for (var i = 0; i < 10; i++) {
      await clk.nextNegedge;
      expect(stream.ready!.value.toBool(), false);
      expect(receiver.msgValid.value.toBool(), false);
    }

    // only when ready does the output show up
    await clk.nextPosedge;
    canAcceptMsg.inject(1);

    await clk.nextNegedge;
    expect(stream.ready!.value.toBool(), true);
    expect(receiver.msgValid.value.toBool(), true);

    await clk.nextPosedge;
    stream.valid.inject(0);

    await clk.waitCycles(5);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });

  test('multi beat - backpressure', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic()..put(0);

    final sys = Axi5SystemInterface();
    sys.clk <= clk;
    sys.resetN <= ~reset;

    // final stream =
    final stream =
        Axi5StreamInterface(dataWidth: 32, destWidth: 4, useLast: true);
    final canAcceptMsg = Logic()..put(1);
    final srcId = Logic(width: stream.destWidth)..put(0xa);

    stream.valid.put(0);
    stream.id!.put(0);
    stream.dest!.put(srcId.value);
    stream.data!.put(0);
    stream.last!.put(0);

    final receiver = DtiInterfaceRx(
        sys: sys,
        stream: stream,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();

    // WaveDumper(receiver);

    Simulator.setMaxSimTime(10000);
    unawaited(Simulator.run());

    // reset flow
    await clk.nextNegedge;
    reset.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    reset.inject(0);

    final numBeats = (DtiTbuTransRespEx.totalWidth / stream.dataWidth).ceil();
    final respIn = DtiTbuTransRespEx()
      ..zeroInit()
      ..translationId1.put(0xfe);

    // start sending a message
    await clk.nextPosedge;
    stream.valid.inject(1);
    stream.data!.inject(respIn.getRange(0, stream.dataWidth).value);
    stream.last!.inject(0);

    // after the first beat, indicate that we can't accept for some time
    await clk.nextPosedge;
    canAcceptMsg.inject(0);
    stream.data!
        .inject(respIn.getRange(stream.dataWidth, 2 * stream.dataWidth).value);

    // should be reported as not being ready
    for (var i = 0; i < 10; i++) {
      await clk.nextNegedge;
      expect(stream.ready!.value.toBool(), false);
      expect(receiver.msgValid.value.toBool(), false);
    }

    // now ready to accept again
    await clk.nextPosedge;
    canAcceptMsg.inject(1);

    for (var i = 1; i < numBeats; i++) {
      stream.data!.inject(respIn
          .getRange(i * stream.dataWidth,
              min((i + 1) * stream.dataWidth, respIn.width))
          .zeroExtend(stream.dataWidth)
          .value);
      stream.last!.inject(i == numBeats - 1);
      await clk.nextNegedge;
      expect(receiver.msgValid.value.toBool(), i == numBeats - 1);
      await clk.nextPosedge;
    }
    stream.valid.inject(0);

    await clk.waitCycles(5);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
