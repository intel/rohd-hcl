// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_bfm_test.dart
// Tests for the AXI5 validation collateral.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

// TODO:
//  for each AXI flavor supported
//    create a main agent and a subordinate agent
//    the main agent sends random read and write requests
//    the subordinate agent is just a persistent memory that responds
//  note that the stream flavor will have to be different
//    main sends streams
//    sub logs streams

// down the road, we can worry about transaction level flows...

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

/// Simple main component BFM
///
/// Sends random (simple) read and write requests.
class SimpleAxi5MainBfm extends Agent {
  late final Axi5MainClusterAgent main;
  SimpleAxi5MainBfm({
    required Axi5SystemInterface sys,
    required Axi5ArChannelInterface ar,
    required Axi5AwChannelInterface aw,
    required Axi5RChannelInterface r,
    required Axi5WChannelInterface w,
    required Axi5BChannelInterface b,
    required Component parent,
    Axi5AcChannelInterface? ac,
    Axi5CrChannelInterface? cr,
    String name = 'simpleAxi5MainBfm',
  }) : super(name, parent) {
    main = Axi5MainClusterAgent(
        sys: sys,
        ar: ar,
        aw: aw,
        r: r,
        w: w,
        b: b,
        ac: ac,
        cr: cr,
        useSnoop: ac != null && cr != null,
        parent: this);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('simpleAxi5MainBfmObj');

    // wait for reset to have occurred
    await main.sys.resetN.nextNegedge;
    await main.sys.clk.waitCycles(10);

    // establish a listener for write responses
    main.write.respAgent.monitor.stream.listen((r) => logger.info(
        'Received write response for write request with ID ${r.id?.id ?? 0}'));

    // establish a listener for read responses
    main.read.dataAgent.monitor.stream.listen((r) => logger.info(
        'Received read response for read request with ID ${r.id?.id ?? 0} '
        'containing data '
        '${r.data.map((d) => d.data.toRadixString(16)).toList().join(',')}'));

    // generate n random transactions
    final numTrans = Test.random!.nextInt(100);
    for (var i = 0; i < numTrans; i++) {
      final isWr = Test.random!.nextBool();
      final addr = Test.random!.nextInt(128);

      // send a write
      if (isWr) {
        final len = main.write.w.last != null ? Test.random!.nextInt(4) : 0;
        final nextWrite = Axi5AwChannelPacket(
            request: Axi5RequestSignalsStruct(
                addr: addr,
                len: len,
                size: Axi5SizeField.fromSize(32).value,
                burst: Axi5BurstField.incr.value),
            prot: Axi5ProtSignalsStruct(prot: Axi4ProtField.instruction.value),
            memAttr: Axi5MemoryAttributeSignalsStruct(
                cache: Axi5CacheField.cacheable.value));
        logger.info('Sending write request with ID ${nextWrite.id?.id ?? 0}');
        main.write.reqAgent.sequencer.add(nextWrite);
        await nextWrite.completed;

        // once the request has been sent, we can send the data
        final wrData = Axi5WChannelPacket(
            data: List.generate(
                len + 1,
                (idx) => Axi5DataSignalsStruct(
                    data: Test.random!.nextInt(64),
                    strb: Test.random!
                        .nextInt(pow(main.write.w.dataWidth ~/ 8, 2).toInt()),
                    last: idx == len)));
        main.write.dataAgent.sequencer.add(wrData);
        await wrData.completed;
      }
      // send a simple read
      // but a random number of beats
      else {
        final nextRead = Axi5ArChannelPacket(
            request: Axi5RequestSignalsStruct(
                addr: addr,
                len: Test.random!.nextInt(4),
                size: Axi5SizeField.fromSize(32).value,
                burst: Axi5BurstField.incr.value),
            prot: Axi5ProtSignalsStruct(prot: Axi4ProtField.instruction.value),
            memAttr: Axi5MemoryAttributeSignalsStruct(
                cache: Axi5CacheField.cacheable.value));
        logger.info('Sending read request with ID ${nextRead.id?.id ?? 0}');
        main.read.reqAgent.sequencer.add(nextRead);
        await nextRead.completed;
      }
    }

    obj.drop();
  }
}

/// Simple subordinate component BFM
///
/// Accepts and responds to (simple) read and write requests.
class SimpleAxi5SubordinateBfm extends Agent {
  late final Axi5SubordinateClusterAgent sub;

  final List<Axi5AwChannelPacket> _wrReqs = [];

  late SparseMemoryStorage storage;

  SimpleAxi5SubordinateBfm({
    required Axi5SystemInterface sys,
    required Axi5ArChannelInterface ar,
    required Axi5AwChannelInterface aw,
    required Axi5RChannelInterface r,
    required Axi5WChannelInterface w,
    required Axi5BChannelInterface b,
    required Component parent,
    Axi5AcChannelInterface? ac,
    Axi5CrChannelInterface? cr,
    String name = 'simpleAxi5SubordinateBfm',
  }) : super(name, parent) {
    sub = Axi5SubordinateClusterAgent(
        sys: sys,
        ar: ar,
        aw: aw,
        r: r,
        w: w,
        b: b,
        ac: ac,
        cr: cr,
        useSnoop: ac != null && cr != null,
        parent: this);

    storage = SparseMemoryStorage(
      addrWidth: max(sub.read.ar.addrWidth, sub.write.aw.addrWidth),
      dataWidth: max(sub.read.r.dataWidth, sub.write.w.dataWidth),
      onInvalidRead: (addr, dataWidth) =>
          LogicValue.filled(dataWidth, LogicValue.zero),
    );
  }

  /// Calculates a strobed version of data.
  static LogicValue _strobeData(
          LogicValue originalData, LogicValue newData, LogicValue strobe) =>
      [
        for (var i = 0; i < strobe.width; i++)
          (strobe[i].toBool() ? newData : originalData)
              .getRange(i * 8, i * 8 + 8)
      ].rswizzle();

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('simpleAxi5SubordinateBfmObj');

    // wait for reset to have occurred
    await sub.sys.resetN.nextNegedge;
    await sub.sys.clk.waitCycles(10);

    // clear any pending write requests on reset
    sub.sys.resetN.negedge.listen((e) {
      _wrReqs.clear();
    });

    // establish a listener for write requests
    // just cache the request until we see its data
    sub.write.reqAgent.monitor.stream.listen((r) {
      logger.info('Received write request with ID ${r.id?.id ?? 0}');
      _wrReqs.add(r);
    });

    // establish a listener for write data
    // update memory, then send a write response
    sub.write.dataAgent.monitor.stream.listen((r) async {
      logger.info('Received write data');
      final currReq = _wrReqs[0];
      for (var j = 0; j < r.data.length; j++) {
        final targ = currReq.request.addr + 4 * j;
        final orig =
            storage.readData(LogicValue.ofInt(targ, storage.addrWidth));
        final strbData = _strobeData(
            orig,
            LogicValue.ofInt(r.data[j].data, storage.dataWidth),
            LogicValue.ofInt(
                r.data[j].strb ??
                    LogicValue.filled(storage.dataWidth ~/ 8, LogicValue.one)
                        .toInt(),
                storage.dataWidth ~/ 8));
        storage.writeData(LogicValue.ofInt(targ, storage.addrWidth), strbData);
      }
      _wrReqs.removeAt(0);
      final resp = Axi5BChannelPacket(
          response: Axi5ResponseSignalsStruct(resp: Axi5RespField.okay.value));
      sub.write.respAgent.sequencer.add(resp);
      await resp.completed;
    });

    // establish a listener for read requests
    // query the memory and respond with the data
    sub.read.reqAgent.monitor.stream.listen((r) async {
      logger.info('Received read request with ID ${r.id?.id ?? 0}');
      final dataQueue = <int>[];
      for (var j = 0; j < (r.request.len ?? 0) + 1; j++) {
        final targ = r.request.addr + 4 * j;
        final data =
            storage.readData(LogicValue.ofInt(targ, storage.addrWidth));
        dataQueue.add(data.toInt());
      }
      final resp = Axi5RChannelPacket(
          data: List.generate(
              dataQueue.length,
              (idx) => Axi5DataSignalsStruct(
                  data: dataQueue[idx], last: idx == dataQueue.length - 1)));
      sub.read.dataAgent.sequencer.add(resp);
      await resp.completed;
    });

    obj.drop();
  }
}

// TODO: add BFMs for Axi5Stream when available

/// Test that instantiates simple main and subordinate BFMs
/// and lets them send transactions back and forth.
class Axi5BfmTest extends Test {
  late final Axi5SystemInterface sIntf;
  late final Type axiType;
  late final dynamic cluster;

  late final SimpleAxi5MainBfm main;
  late final SimpleAxi5SubordinateBfm sub;

  Axi5BfmTest(super.name, {this.axiType = Axi5Cluster})
      : super(randomSeed: 123) {
    const outFolder = 'gen/axi5_bfm';
    Directory(outFolder).createSync(recursive: true);
    sIntf = Axi5SystemInterface();
    if (axiType == Axi5Cluster) {
      final ar = Axi5ArChannelInterface(config: Axi5ArChannelConfig());
      final r = Axi5RChannelInterface(config: Axi5RChannelConfig());
      final aw = Axi5AwChannelInterface(config: Axi5AwChannelConfig());
      final w = Axi5WChannelInterface(config: Axi5WChannelConfig());
      final b = Axi5BChannelInterface(config: Axi5BChannelConfig());
      final ac = Axi5AcChannelInterface();
      final cr = Axi5CrChannelInterface();
      cluster = Axi5Cluster(
          read: Axi5ReadCluster(ar: ar, r: r),
          write: Axi5WriteCluster(aw: aw, w: w, b: b),
          snoop: Axi5SnoopCluster(ac: ac, cr: cr));
      main = SimpleAxi5MainBfm(
          sys: sIntf,
          ar: ar,
          aw: aw,
          r: r,
          w: w,
          b: b,
          ac: ac,
          cr: cr,
          parent: this);
      sub = SimpleAxi5SubordinateBfm(
          sys: sIntf,
          ar: ar,
          aw: aw,
          r: r,
          w: w,
          b: b,
          ac: ac,
          cr: cr,
          parent: this);

      // tracker setup
      final arTracker = Axi5ArChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final awTracker = Axi5AwChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final rTracker = Axi5RChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final wTracker = Axi5WChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final bTracker = Axi5BChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final acTracker = Axi5AcChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final crTracker = Axi5CrChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );

      Simulator.registerEndOfSimulationAction(() async {
        await arTracker.terminate();
        await awTracker.terminate();
        await rTracker.terminate();
        await wTracker.terminate();
        await bTracker.terminate();
        await acTracker.terminate();
        await crTracker.terminate();
      });

      sub.sub.read.reqAgent.monitor.stream.listen(arTracker.record);
      sub.sub.write.reqAgent.monitor.stream.listen(awTracker.record);
      main.main.read.dataAgent.monitor.stream.listen(rTracker.record);
      sub.sub.write.dataAgent.monitor.stream.listen(wTracker.record);
      main.main.write.respAgent.monitor.stream.listen(bTracker.record);
      main.main.snoop!.reqAgent.monitor.stream.listen(acTracker.record);
      sub.sub.snoop!.respAgent.monitor.stream.listen(crTracker.record);
    } else if (axiType == Axi5LiteCluster) {
      final ar = Axi5LiteArChannelInterface(config: Axi5LiteArChannelConfig());
      final r = Axi5LiteRChannelInterface(config: Axi5LiteRChannelConfig());
      final aw = Axi5LiteAwChannelInterface(config: Axi5LiteAwChannelConfig());
      final w = Axi5LiteWChannelInterface(config: Axi5LiteWChannelConfig());
      final b = Axi5LiteBChannelInterface(config: Axi5LiteBChannelConfig());
      cluster = Axi5LiteCluster(
          read: Axi5LiteReadCluster(ar: ar, r: r),
          write: Axi5LiteWriteCluster(aw: aw, w: w, b: b));
      main = SimpleAxi5MainBfm(
          sys: sIntf, ar: ar, aw: aw, r: r, w: w, b: b, parent: this);
      sub = SimpleAxi5SubordinateBfm(
          sys: sIntf, ar: ar, aw: aw, r: r, w: w, b: b, parent: this);

      // tracker setup
      final arTracker = Axi5ArChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final awTracker = Axi5AwChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final rTracker = Axi5RChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final wTracker = Axi5WChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final bTracker = Axi5BChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );

      Simulator.registerEndOfSimulationAction(() async {
        await arTracker.terminate();
        await awTracker.terminate();
        await rTracker.terminate();
        await wTracker.terminate();
        await bTracker.terminate();
      });

      sub.sub.read.reqAgent.monitor.stream.listen(arTracker.record);
      sub.sub.write.reqAgent.monitor.stream.listen(awTracker.record);
      main.main.read.dataAgent.monitor.stream.listen(rTracker.record);
      sub.sub.write.dataAgent.monitor.stream.listen(wTracker.record);
      main.main.write.respAgent.monitor.stream.listen(bTracker.record);
    } else if (axiType == Ace5LiteCluster) {
      final ar = Ace5LiteArChannelInterface(config: Ace5LiteArChannelConfig());
      final r = Ace5LiteRChannelInterface(config: Ace5LiteRChannelConfig());
      final aw = Ace5LiteAwChannelInterface(config: Ace5LiteAwChannelConfig());
      final w = Ace5LiteWChannelInterface(config: Ace5LiteWChannelConfig());
      final b = Ace5LiteBChannelInterface(config: Ace5LiteBChannelConfig());
      cluster = Ace5LiteCluster(
          read: Ace5LiteReadCluster(ar: ar, r: r),
          write: Ace5LiteWriteCluster(aw: aw, w: w, b: b));
      main = SimpleAxi5MainBfm(
          sys: sIntf, ar: ar, aw: aw, r: r, w: w, b: b, parent: this);
      sub = SimpleAxi5SubordinateBfm(
          sys: sIntf, ar: ar, aw: aw, r: r, w: w, b: b, parent: this);

      // tracker setup
      final arTracker = Axi5ArChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final awTracker = Axi5AwChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final rTracker = Axi5RChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final wTracker = Axi5WChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );
      final bTracker = Axi5BChannelTracker(
        dumpTable: false,
        outputFolder: outFolder,
      );

      Simulator.registerEndOfSimulationAction(() async {
        await arTracker.terminate();
        await awTracker.terminate();
        await rTracker.terminate();
        await wTracker.terminate();
        await bTracker.terminate();
      });

      sub.sub.read.reqAgent.monitor.stream.listen(arTracker.record);
      sub.sub.write.reqAgent.monitor.stream.listen(awTracker.record);
      main.main.read.dataAgent.monitor.stream.listen(rTracker.record);
      sub.sub.write.dataAgent.monitor.stream.listen(wTracker.record);
      main.main.write.respAgent.monitor.stream.listen(bTracker.record);
    } else {
      throw Exception('Invalid axiType: $axiType');
    }
  }

  // Just run a reset flow to kick things off
  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('axi5BfmTestObj');
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
    Logger.root.level = Level.INFO;
  });

  Future<void> runTest(Axi5BfmTest axi5BfmTest,
      {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(30000);

    // TODO: set this up...
    if (dumpWaves) {
      // final mod = Axi4Subordinate(axi4BfmTest.sIntf, axi4BfmTest.lanes);
      // await mod.build();
      // WaveDumper(mod);
    }

    await axi5BfmTest.start();
  }

  test('simple run', () async {
    await runTest(Axi5BfmTest('simple'), dumpWaves: true);
  });
}
