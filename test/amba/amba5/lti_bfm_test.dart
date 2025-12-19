// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lti_bfm_test.dart
// Tests for the LTI validation collateral.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

// down the road, we can worry about transaction level flows...

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'lti_test.dart';

/// Convert a virtual channel to a credit return value
LogicValue toOneHot(int vc, int width) {
  final ohLit = List<int>.filled(width, 0);
  ohLit[vc] = 1;
  return ohLit
      .map((e) => e == 1 ? LogicValue.one : LogicValue.zero)
      .toList()
      .rswizzle();
}

/// Simple main component BFM
///
/// Sends random (simple) requests.
class SimpleLtiMainBfm extends Agent {
  late final LtiMainClusterAgent main;
  SimpleLtiMainBfm({
    required Axi5SystemInterface sys,
    required LtiLaChannelInterface la,
    required LtiLrChannelInterface lr,
    required LtiLcChannelInterface lc,
    required LtiManagementInterface lm,
    required Component parent,
    LtiLtChannelInterface? lt,
    String name = 'simpleLtiMainBfm',
  }) : super(name, parent) {
    main = LtiMainClusterAgent(
        sys: sys, la: la, lr: lr, lc: lc, lm: lm, lt: lt, parent: this);
  }

  // perform the LTI interface open handshake
  Future<void> ltiIntfInit() async {
    main.manDriver.toggleOpenReq(on: true);
    await main.lm.openAck.nextPosedge;
    logger.info('OpenReq acknowledged.');
    main.manDriver.toggleActive(on: true);
  }

  // initialize LTI credits over the LR and LT channels
  Future<void> ltiCreditInit(int numCredits) async {
    for (var i = 0; i < numCredits; i++) {
      main.respAgent.sequencer.add(
        LtiCreditPacket(
          credit: LogicValue.filled(
            main.lr.credit?.width ?? 1,
            LogicValue.one,
          ).toInt(),
        ),
      );
      main.tagAgent?.sequencer.add(
        LtiCreditPacket(
          credit: LogicValue.filled(
            main.lt?.credit?.width ?? 1,
            LogicValue.one,
          ).toInt(),
        ),
      );
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('simpleLtiMainBfmObj');

    // establish a listener for responses
    // must send a completion
    // and return the credit
    main.respAgent.monitor.stream.listen((r) {
      logger.info('Received response for request with ID ${r.id?.id ?? 0} '
          'with translated address ${r.addr}.');
      main.respAgent.sequencer.add(
        LtiCreditPacket(credit: toOneHot(r.vc, main.lr.credit!.width).toInt()),
      );
      main.compAgent.sequencer.add(LtiLcChannelPacket(tag: r.ctag ?? 0));
    });

    // establish a listener for tag messages
    // nothing really to do here for the simple BFM
    // except for returning the credit
    main.tagAgent?.monitor.stream.listen((r) {
      logger.info('Received tag message for tag ${r.tag}');
      main.tagAgent?.sequencer.add(
        LtiCreditPacket(credit: 0x1),
      );
    });

    // establish listeners for management signals
    main.lm.askClose.posedge.listen((d) {
      logger.info('Asked to be closed.');
      main.manDriver.toggleActive(on: false);
    });

    // wait for reset to have occurred
    await main.sys.resetN.nextNegedge;

    // start by opening the connection
    // and initializing credits
    await ltiIntfInit();
    await main.sys.clk.nextPosedge;
    await ltiCreditInit(15);

    // generate n random transactions
    final numTrans = Test.random!.nextInt(100);
    for (var i = 0; i < numTrans; i++) {
      final nextReq = LtiLaChannelPacket(
          addr: Test.random!.nextInt(128),
          trans: Test.random!.nextInt(4),
          ogV: Test.random!.nextBool(),
          og: Test.random!.nextInt(4),
          vc: Test.random!.nextInt(8),
          id: Axi5IdSignalsStruct(id: Test.random!.nextInt(4)));
      logger.info('Sending request with ID ${nextReq.id?.id ?? 0}');
      main.reqAgent.sequencer.add(nextReq);
      await nextReq.completed;
    }

    obj.drop();
  }
}

/// Simple subordinate component BFM
///
/// Accepts and responds to (simple) requests.
class SimpleLtiSubordinateBfm extends Agent {
  late final LtiSubordinateClusterAgent sub;

  int currCtag = 0;

  SimpleLtiSubordinateBfm({
    required Axi5SystemInterface sys,
    required LtiLaChannelInterface la,
    required LtiLrChannelInterface lr,
    required LtiLcChannelInterface lc,
    required LtiManagementInterface lm,
    required Component parent,
    LtiLtChannelInterface? lt,
    String name = 'simpleLtiSubordinateBfm',
  }) : super(name, parent) {
    sub = LtiSubordinateClusterAgent(
        sys: sys, la: la, lr: lr, lc: lc, lt: lt, lm: lm, parent: this);
  }

  // perform the LTI interface open handshake
  Future<void> ltiIntfInit() async {
    while (
        !((sub.lm.openReq.value.isValid) && (sub.lm.openReq.value.toBool()))) {
      await sub.sys.clk.nextPosedge;
    }
    logger.info('OpenReq received.');
    sub.manDriver.toggleOpenAck(on: true);
  }

  // initialize LTI credits over the LA and LC channels
  Future<void> ltiCreditInit(int numCredits) async {
    for (var i = 0; i < numCredits; i++) {
      sub.reqAgent.sequencer.add(
        LtiCreditPacket(
          credit: LogicValue.filled(
            sub.la.credit?.width ?? 1,
            LogicValue.one,
          ).toInt(),
        ),
      );
      sub.compAgent.sequencer.add(
        LtiCreditPacket(
          credit: LogicValue.filled(
            sub.lc.credit?.width ?? 1,
            LogicValue.one,
          ).toInt(),
        ),
      );
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('simpleLtiSubordinateBfmObj');

    // establish a listener for requests
    // perform some dumb address translation
    // and return the credit
    sub.reqAgent.monitor.stream.listen((r) {
      logger.info('Received request with ID ${r.id?.id ?? 0}');
      sub.reqAgent.sequencer.add(
        LtiCreditPacket(credit: toOneHot(r.vc, sub.la.credit!.width).toInt()),
      );
      sub.respAgent.sequencer.add(LtiLrChannelPacket(
          addr: r.addr + 4,
          ctag: currCtag,
          size: Test.random!.nextInt(4),
          id: r.id?.clone(),
          vc: r.vc,
          response:
              Axi5ResponseSignalsStruct(resp: LtiRespField.success.value)));
    });

    // establish a listener for completions
    // for now, do nothing but return a credit...
    sub.compAgent.monitor.stream.listen((r) {
      logger.info('Received completion for tag ${r.tag}');
      sub.compAgent.sequencer.add(
        LtiCreditPacket(credit: 0x1),
      );
    });

    // wait for reset to have occurred
    await sub.sys.resetN.nextNegedge;

    await ltiIntfInit();
    await sub.sys.clk.nextPosedge;
    await ltiCreditInit(15);

    obj.drop();
  }
}

/// Test that instantiates simple main and subordinate BFMs
/// and lets them send transactions back and forth.
class LtiBfmTest extends Test {
  late final Axi5SystemInterface sIntf;
  late final LtiCluster cluster;

  late final SimpleLtiMainBfm main;
  late final SimpleLtiSubordinateBfm sub;

  LtiBfmTest(super.name, {bool useTag = false}) : super(randomSeed: 123) {
    const outFolder = 'gen/lti_bfm';
    Directory(outFolder).createSync(recursive: true);
    sIntf = Axi5SystemInterface();
    sIntf.clk <= SimpleClockGenerator(10).clk;
    sIntf.resetN.put(1);

    final la = LtiLaChannelInterface(config: LtiLaChannelConfig(), vcCount: 8);
    final lr = LtiLrChannelInterface(config: LtiLrChannelConfig(), vcCount: 8);
    final lc = LtiLcChannelInterface(config: LtiLcChannelConfig());
    final lt = LtiLtChannelInterface(config: LtiLtChannelConfig());
    final lm = LtiManagementInterface();

    cluster = LtiCluster(
      la: la,
      lr: lr,
      lc: lc,
      lm: lm,
      lt: useTag ? lt : null,
    );

    main = SimpleLtiMainBfm(
        sys: sIntf,
        la: la,
        lr: lr,
        lc: lc,
        lm: lm,
        lt: useTag ? lt : null,
        parent: this);
    sub = SimpleLtiSubordinateBfm(
        sys: sIntf,
        la: la,
        lr: lr,
        lc: lc,
        lm: lm,
        lt: useTag ? lt : null,
        parent: this);

    // tracker setup
    final laTracker = LtiLaChannelTracker(
      dumpTable: false,
      outputFolder: outFolder,
    );
    final lrTracker = LtiLrChannelTracker(
      dumpTable: false,
      outputFolder: outFolder,
    );
    final lcTracker = LtiLcChannelTracker(
      dumpTable: false,
      outputFolder: outFolder,
    );
    final ltTracker = LtiLtChannelTracker(
      dumpTable: false,
      outputFolder: outFolder,
    );

    Simulator.registerEndOfSimulationAction(() async {
      await laTracker.terminate();
      await lrTracker.terminate();
      await lcTracker.terminate();
      await ltTracker.terminate();
    });

    sub.sub.reqAgent.monitor.stream.listen(laTracker.record);
    main.main.respAgent.monitor.stream.listen(lrTracker.record);
    sub.sub.compAgent.monitor.stream.listen(lcTracker.record);
    main.main.tagAgent?.monitor.stream.listen(ltTracker.record);
  }

  // Just run a reset flow to kick things off
  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('ltiBfmTestObj');
    await resetFlow();
    obj.drop();
  }

  Future<void> resetFlow() async {
    await sIntf.clk.waitCycles(2);
    sIntf.resetN.inject(0);
    await sIntf.clk.waitCycles(3);
    sIntf.resetN.inject(1);
  }
}

void main() {
  tearDown(() async {
    await Test.reset();
  });

  setUp(() async {
    // Set the logger level
    Logger.root.level = Level.WARNING;
  });

  Future<void> runTest(LtiBfmTest ltiBfmTest, {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(30000);

    if (dumpWaves) {
      final mod = LtiSubordinate(ltiBfmTest.sIntf, [ltiBfmTest.cluster]);
      await mod.build();
      WaveDumper(mod);
    }

    await ltiBfmTest.start();
  }

  test('simple run', () async {
    await runTest(LtiBfmTest('simple'));
  });
}
