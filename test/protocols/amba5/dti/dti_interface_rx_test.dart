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
    final fromSub = Axi5StreamInterface(dataWidth: 256, destWidth: 4);
    final srcId = Logic(width: fromSub.destWidth);
    final canAcceptMsg = Logic();

    final receiver = DtiInterfaceRx(
        sys: sys,
        fromSub: fromSub,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();
  });

  test('doa - complex', () async {
    final sys = Axi5SystemInterface();
    final fromSub = Axi5StreamInterface(dataWidth: 32, destWidth: 4);
    final srcId = Logic(width: fromSub.destWidth);
    final canAcceptMsg = Logic();

    final receiver = DtiInterfaceRx(
        sys: sys,
        fromSub: fromSub,
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

    final fromSub =
        Axi5StreamInterface(dataWidth: 256, destWidth: 4, useLast: true);
    final canAcceptMsg = Logic()..put(1);
    final srcId = Logic(width: fromSub.destWidth)..put(0xa);

    fromSub.valid.put(0);
    fromSub.id!.put(0);
    fromSub.dest!.put(srcId.value);
    fromSub.data!.put(0);
    fromSub.last!.put(0);

    final receiver = DtiInterfaceRx(
        sys: sys,
        fromSub: fromSub,
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
    expect(fromSub.ready!.value.toBool(), true);
    expect(receiver.msgValid.value.toBool(), false);
    final respIn = DtiTbuTransRespEx()
      ..zeroInit()
      ..translationId1.put(0xfe);
    fromSub.valid.inject(1);
    fromSub.data!.inject(respIn.zeroExtend(fromSub.dataWidth).value);
    fromSub.last!.inject(1);

    // should see the message out in the same cycle
    await clk.nextNegedge;
    expect(receiver.msgValid.value.toBool(), true);
    final respOut = DtiTbuTransRespEx()
      ..gets(receiver.msg.getRange(0, DtiTbuTransRespEx.totalWidth));
    expect(respOut.msgType.value.toInt(), DtiUpstreamMsgType.transRespEx.value);
    expect(respOut.translationId.value.toInt(), 0xfe);

    await clk.nextPosedge;
    fromSub.valid.put(0);

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

    // final fromSub =
    final fromSub =
        Axi5StreamInterface(dataWidth: 32, destWidth: 4, useLast: true);
    final canAcceptMsg = Logic()..put(1);
    final srcId = Logic(width: fromSub.destWidth)..put(0xa);

    fromSub.valid.put(0);
    fromSub.id!.put(0);
    fromSub.dest!.put(srcId.value);
    fromSub.data!.put(0);
    fromSub.last!.put(0);

    final receiver = DtiInterfaceRx(
        sys: sys,
        fromSub: fromSub,
        canAcceptMsg: canAcceptMsg,
        srcId: srcId,
        maxMsgRxSize: DtiTbuTransRespEx.totalWidth);

    await receiver.build();

    WaveDumper(receiver);

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
    expect(fromSub.ready!.value.toBool(), true);
    expect(receiver.msgValid.value.toBool(), false);
    final respIn = DtiTbuTransRespEx()
      ..zeroInit()
      ..translationId1.put(0xfe);
    final numBeats = (DtiTbuTransRespEx.totalWidth / fromSub.dataWidth).ceil();

    for (var i = 0; i < numBeats; i++) {
      fromSub.valid.inject(1);
      fromSub.data!.inject(respIn
          .getRange(i * fromSub.dataWidth,
              min((i + 1) * fromSub.dataWidth, respIn.width))
          .zeroExtend(fromSub.dataWidth)
          .value);
      fromSub.last!.inject(i == numBeats - 1);
      await clk.nextNegedge;
      expect(receiver.msgValid.value.toBool(), i == numBeats - 1);
      await clk.nextPosedge;
    }

    // can now check the message
    fromSub.valid.inject(0);
    final respOut = DtiTbuTransRespEx()
      ..gets(receiver.msg.getRange(0, DtiTbuTransRespEx.totalWidth));
    expect(respOut.msgType.value.toInt(), DtiUpstreamMsgType.transRespEx.value);
    expect(respOut.translationId.value.toInt(), 0xfe);

    await clk.waitCycles(10);

    await Simulator.endSimulation();
    await Simulator.simulationEnded;
  });
}
