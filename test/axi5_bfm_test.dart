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

import 'axi5_test.dart';

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
                    data: BigInt.from(Test.random!.nextInt(64)),
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
            LogicValue.ofBigInt(r.data[j].data, storage.dataWidth),
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
      final dataQueue = <BigInt>[];
      for (var j = 0; j < (r.request.len ?? 0) + 1; j++) {
        final targ = r.request.addr + 4 * j;
        final data =
            storage.readData(LogicValue.ofInt(targ, storage.addrWidth));
        dataQueue.add(data.toBigInt());
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

/// Simple stream main component BFM
///
/// Sends random streams.
class SimpleAxi5StreamMainBfm extends Agent {
  late final Axi5StreamMainAgent main;
  SimpleAxi5StreamMainBfm({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface strm,
    required Component parent,
    String name = 'simpleAxi5StreamMainBfm',
  }) : super(name, parent) {
    main = Axi5StreamMainAgent(sys: sys, stream: strm, parent: this);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('simpleAxi5StreamMainBfmObj');

    // wait for reset to have occurred
    await main.sys.resetN.nextNegedge;
    await main.sys.clk.waitCycles(10);

    // generate n random transactions
    final numTrans = Test.random!.nextInt(100);
    for (var i = 0; i < numTrans; i++) {
      final beats = main.stream.useLast ? Test.random!.nextInt(4) : 1;
      for (var j = 0; j < beats; j++) {
        final nextStrm = Axi5StreamPacket(
            data: BigInt.from(Test.random!
                .nextInt(pow(min(main.stream.dataWidth, 32), 2).toInt())),
            last: j == beats - 1);
        logger.info('Sending stream beat with ID ${nextStrm.id ?? 0}');
        main.sequencer.add(nextStrm);
        await nextStrm.completed;
      }
    }

    obj.drop();
  }
}

/// Simple stream subordinate component BFM
///
/// Accepts streams and logs them.
class SimpleAxi5StreamSubordinateBfm extends Agent {
  late final Axi5StreamSubordinateAgent sub;

  final List<Axi5StreamPacket> _streams = [];

  SimpleAxi5StreamSubordinateBfm({
    required Axi5SystemInterface sys,
    required Axi5StreamInterface strm,
    required Component parent,
    String name = 'simpleAxi5StreamSubordinateBfm',
  }) : super(name, parent) {
    sub = Axi5StreamSubordinateAgent(sys: sys, stream: strm, parent: this);
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

    final obj = phase.raiseObjection('simpleAxi5StreamSubordinateBfmObj');

    // wait for reset to have occurred
    await sub.sys.resetN.nextNegedge;
    await sub.sys.clk.waitCycles(10);

    // clear any pending beats on reset
    sub.sys.resetN.negedge.listen((e) {
      _streams.clear();
    });

    // establish a listener for write requests
    // just cache the request until we see its data
    sub.monitor.stream.listen((r) {
      logger.info('Received stream beat with ID ${r.id ?? 0}');
      _streams.add(r);
      if (r.last ?? true) {
        logger.info('Stream with ID ${r.id ?? 0} has completed - dropping.');
        for (var j = 0; j < _streams.length; j++) {
          logger.info('Stream beat $j data: '
              '${_strobeData(LogicValue.filled(sub.stream.dataWidth, LogicValue.zero), LogicValue.ofBigInt(_streams[j].data, sub.stream.dataWidth), LogicValue.ofInt(_streams[j].strb ?? LogicValue.filled(sub.stream.strbWidth, LogicValue.one).toInt(), sub.stream.strbWidth))}.');
        }
        _streams.clear();
      }
    });

    obj.drop();
  }
}

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
    sIntf.clk <= SimpleClockGenerator(10).clk;
    sIntf.resetN.put(1);
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

/// Test that instantiates simple main and subordinate BFMs
/// and lets them send transactions back and forth.
class Axi5StreamBfmTest extends Test {
  late final Axi5SystemInterface sIntf;
  late final Axi5StreamInterface stream;

  late final SimpleAxi5StreamMainBfm main;
  late final SimpleAxi5StreamSubordinateBfm sub;

  Axi5StreamBfmTest(
    super.name,
  ) : super(randomSeed: 123) {
    const outFolder = 'gen/axi5_s_bfm';
    Directory(outFolder).createSync(recursive: true);
    sIntf = Axi5SystemInterface();
    sIntf.clk <= SimpleClockGenerator(10).clk;
    sIntf.resetN.put(1);

    stream = Axi5StreamInterface();

    main = SimpleAxi5StreamMainBfm(sys: sIntf, strm: stream, parent: this);
    sub =
        SimpleAxi5StreamSubordinateBfm(sys: sIntf, strm: stream, parent: this);

    // tracker setup
    final strmTracker = Axi5StreamTracker(
      dumpTable: false,
      outputFolder: outFolder,
    );

    Simulator.registerEndOfSimulationAction(() async {
      await strmTracker.terminate();
    });

    sub.sub.monitor.stream.listen(strmTracker.record);
  }

  // Just run a reset flow to kick things off
  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('axi5StreamBfmTestObj');
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

    if (dumpWaves) {
      if (axi5BfmTest.axiType == Axi5Cluster) {
        final mod = Axi5Subordinate(
            axi5BfmTest.sIntf, [axi5BfmTest.cluster as Axi5Cluster]);
        await mod.build();
        WaveDumper(mod);
      } else if (axi5BfmTest.axiType == Axi5LiteCluster) {
        final mod = Axi5LiteSubordinate(
            axi5BfmTest.sIntf, [axi5BfmTest.cluster as Axi5LiteCluster]);
        await mod.build();
        WaveDumper(mod);
      }
      if (axi5BfmTest.axiType == Ace5LiteCluster) {
        final mod = Ace5LiteSubordinate(
            axi5BfmTest.sIntf, [axi5BfmTest.cluster as Ace5LiteCluster]);
        await mod.build();
        WaveDumper(mod);
      }
    }

    await axi5BfmTest.start();
  }

  Future<void> runStreamTest(Axi5StreamBfmTest axi5BfmTest,
      {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(30000);

    if (dumpWaves) {
      final mod =
          Axi5StreamSubordinate(axi5BfmTest.sIntf, [axi5BfmTest.stream]);
      await mod.build();
      WaveDumper(mod);
    }

    await axi5BfmTest.start();
  }

  test('simple run - axi5', () async {
    await runTest(Axi5BfmTest('simple'));
  });

  test('simple run - axi5-lite', () async {
    await runTest(Axi5BfmTest('simple', axiType: Axi5LiteCluster));
  });

  test('simple run - ace5-lite', () async {
    await runTest(Axi5BfmTest('simple', axiType: Ace5LiteCluster));
  });

  test('simple run - axi5-s', () async {
    await runStreamTest(Axi5StreamBfmTest('simple'));
  });
}
