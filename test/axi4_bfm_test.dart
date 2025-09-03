// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_bfm_test.dart
// Tests for the AXI4 BFM.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'axi4_test.dart';

enum Axi4BfmTestChannelConfig { read, write, readWrite }

class Axi4BfmTest extends Test {
  late final Axi4SystemInterface sIntf;

  final Type axiType;

  final int numLanes;
  final List<Axi4BaseCluster> lanes = [];

  final List<Axi4MainClusterAgent> mainAgents = [];
  final List<Axi4SubordinateClusterAgent> subAgents = [];

  late SparseMemoryStorage storage;

  final int numTransfers;

  final bool withStrobes;

  final int interTxnDelay;

  final bool withRandomRspDelays;

  final bool withErrors;

  final int addrWidth;

  final int dataWidth;

  // large lens can make transactions really long...
  final int lenWidth;

  final bool supportLocking;

  List<AxiAddressRange> ranges = [];

  String get outFolder => 'tmp_test/axi4bfm/$name/';

  /// Mechanism to generate a write request in the test.
  (Axi4RequestPacket, Axi4DataPacket) genWrPacket(
    int laneId, {
    int? addr,
    List<int> data = const [],
    int? len,
    int? size,
    List<int> strb = const [],
    Axi4BurstField? burst,
    bool? lock,
    int? prot,
  }) {
    final awIntfC = lanes[laneId].write.awIntf;
    final wIntfC = lanes[laneId].write.wIntf;
    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << awIntfC.lenWidth);
    final maxSize = Axi4SizeField.fromSize(wIntfC.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    final pData = data.isNotEmpty
        ? data.map((e) => LogicValue.ofInt(e, wIntfC.dataWidth)).toList()
        : List.generate(
            transLen + 1,
            (index) => LogicValue.ofInt(
                Test.random!.nextInt(1 << wIntfC.dataWidth), wIntfC.dataWidth));
    final pStrobes = strb.isNotEmpty
        ? strb.map((e) => LogicValue.ofInt(e, wIntfC.strbWidth)).toList()
        : List.generate(
            transLen + 1,
            (index) => withStrobes
                ? LogicValue.ofInt(Test.random!.nextInt(1 << wIntfC.strbWidth),
                    wIntfC.strbWidth)
                : LogicValue.filled(wIntfC.strbWidth, LogicValue.one));
    final pBurst = burst ?? Axi4BurstField.incr;
    final pLock = supportLocking
        ? (lock != null && lock ? LogicValue.one : LogicValue.zero)
        : LogicValue.zero;
    final pProt = prot ?? 0; // don't randomize protection...

    return (
      Axi4RequestPacket(
        addr: LogicValue.ofInt(pAddr, addrWidth),
        prot: LogicValue.ofInt(pProt, awIntfC.protWidth),
        id: LogicValue.ofInt(laneId, awIntfC.idWidth),
        len: LogicValue.ofInt(transLen, awIntfC.lenWidth),
        size: LogicValue.ofInt(transSize, awIntfC.sizeWidth),
        burst: LogicValue.ofInt(pBurst.value, awIntfC.burstWidth),
        lock: pLock,
        cache: LogicValue.ofInt(0, awIntfC.cacheWidth), // not supported
        qos: LogicValue.ofInt(0, awIntfC.qosWidth), // not supported
        region: LogicValue.ofInt(0, awIntfC.regionWidth), // not supported
        user: LogicValue.ofInt(0, awIntfC.userWidth), // not supported
      ),
      Axi4DataPacket(
        data: pData.rswizzle(),
        strb: pStrobes.rswizzle(),
        user: LogicValue.ofInt(0, wIntfC.userWidth), // not supported
        id: LogicValue.ofInt(laneId, wIntfC.idWidth),
      )
    );
  }

  /// Mechanism to generate a read request in the test.
  Axi4RequestPacket genRdPacket(
    int laneId, {
    int? addr,
    int? len,
    int? size,
    Axi4BurstField? burst,
    bool? lock,
    int? prot,
  }) {
    final arIntfC = lanes[laneId].read.arIntf;
    final rIntfC = lanes[laneId].read.rIntf;
    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << arIntfC.lenWidth);
    final maxSize = Axi4SizeField.fromSize(rIntfC.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    final pBurst = burst ?? Axi4BurstField.incr;
    final pLock = supportLocking
        ? (lock != null && lock ? LogicValue.one : LogicValue.zero)
        : LogicValue.zero;
    final pProt = prot ?? 0; // don't randomize protection...

    return Axi4RequestPacket(
      addr: LogicValue.ofInt(pAddr, addrWidth),
      prot: LogicValue.ofInt(pProt, arIntfC.protWidth),
      id: LogicValue.ofInt(laneId, arIntfC.idWidth),
      len: LogicValue.ofInt(transLen, arIntfC.lenWidth),
      size: LogicValue.ofInt(transSize, arIntfC.sizeWidth),
      burst: LogicValue.ofInt(pBurst.value, arIntfC.burstWidth),
      lock: pLock,
      cache: LogicValue.ofInt(0, arIntfC.cacheWidth), // not supported
      qos: LogicValue.ofInt(0, arIntfC.qosWidth), // not supported
      region: LogicValue.ofInt(0, arIntfC.regionWidth), // not supported
      user: LogicValue.ofInt(0, arIntfC.userWidth), // not supported
    );
  }

  Axi4BfmTest(
    super.name, {
    this.numLanes = 1,
    this.numTransfers = 10,
    this.withStrobes = false,
    this.interTxnDelay = 0,
    this.withRandomRspDelays = false,
    this.withErrors = false,
    this.addrWidth = 32,
    this.dataWidth = 32,
    this.lenWidth = 2,
    this.supportLocking = false,
    this.ranges = const [],
    this.axiType = Axi4Cluster,
  })  : assert(numLanes > 0, 'Every test must have at least one channel.'),
        super(randomSeed: 123) {
    // using default parameter values for all interfaces
    sIntf = Axi4SystemInterface();
    for (var i = 0; i < numLanes; i++) {
      if (axiType == Axi4Cluster) {
        lanes.add(Axi4Cluster(
            addrWidth: addrWidth, lenWidth: lenWidth, dataWidth: dataWidth));
      } else if (axiType == Axi4LiteCluster) {
        lanes.add(Axi4LiteCluster(addrWidth: addrWidth, dataWidth: dataWidth));
      } else if (axiType == Ace4LiteCluster) {
        lanes.add(Ace4LiteCluster(
            addrWidth: addrWidth, lenWidth: lenWidth, dataWidth: dataWidth));
      } else {
        // lanes.add(Ace4Cluster(
        //     addrWidth: addrWidth, lenWidth: lenWidth, dataWidth: dataWidth));
      }
      Axi4ReadComplianceChecker(
          sIntf, lanes.last.read.arIntf, lanes.last.read.rIntf,
          parent: this);
      Axi4WriteComplianceChecker(sIntf, lanes.last.write.awIntf,
          lanes.last.write.wIntf, lanes.last.write.bIntf,
          parent: this);
      mainAgents.add(Axi4MainClusterAgent(
          sIntf: sIntf,
          arIntf: lanes.last.read.arIntf,
          awIntf: lanes.last.write.awIntf,
          rIntf: lanes.last.read.rIntf,
          wIntf: lanes.last.write.wIntf,
          bIntf: lanes.last.write.bIntf,
          parent: this));
      subAgents.add(Axi4SubordinateClusterAgent(
          sIntf: sIntf,
          arIntf: lanes.last.read.arIntf,
          awIntf: lanes.last.write.awIntf,
          rIntf: lanes.last.read.rIntf,
          wIntf: lanes.last.write.wIntf,
          bIntf: lanes.last.write.bIntf,
          parent: this));
    }

    storage = SparseMemoryStorage(
      addrWidth: addrWidth,
      dataWidth: dataWidth,
      onInvalidRead: (addr, dataWidth) =>
          LogicValue.filled(dataWidth, LogicValue.zero),
    );

    sIntf.clk <= SimpleClockGenerator(10).clk;

    Axi4SubordinateMemoryAgent(
      sIntf: sIntf,
      lanes: subAgents,
      parent: this,
      storage: storage,
      readResponseDelay:
          withRandomRspDelays ? (request) => Test.random!.nextInt(5) : null,
      writeResponseDelay:
          withRandomRspDelays ? (request) => Test.random!.nextInt(5) : null,
      respondWithError: withErrors ? (request) => true : null,
      supportLocking: supportLocking,
      ranges: ranges,
    );

    Directory(outFolder).createSync(recursive: true);

    final reqTracker = Axi4RequestTracker(
      dumpTable: false,
      outputFolder: outFolder,
    );
    final dataTracker = Axi4DataTracker(
      dumpTable: false,
      outputFolder: outFolder,
    );
    final respTracker = Axi4ResponseTracker(
      dumpTable: false,
      outputFolder: outFolder,
    );

    Simulator.registerEndOfSimulationAction(() async {
      await reqTracker.terminate();
      await dataTracker.terminate();
      await respTracker.terminate();

      final jsonStr =
          File('$outFolder/Axi4Tracker.tracker.json').readAsStringSync();
      json.decode(jsonStr);

      // Here can do any checking against the tracker contents...

      Directory(outFolder).deleteSync(recursive: true);
    });

    for (var i = 0; i < numLanes; i++) {
      subAgents[i].readAgent.reqAgent.monitor.stream.listen(reqTracker.record);
      mainAgents[i]
          .readAgent
          .dataAgent
          .monitor!
          .stream
          .listen(dataTracker.record);
      subAgents[i].writeAgent.reqAgent.monitor.stream.listen(reqTracker.record);
      subAgents[i]
          .writeAgent
          .dataAgent
          .monitor
          .stream
          .listen(dataTracker.record);
      mainAgents[i]
          .writeAgent
          .respAgent
          .monitor
          .stream
          .listen(respTracker.record);
    }
  }

  int numTransfersCompleted = 0;
  final mandatoryTransWaitPeriod = 10;

  // This base class doesn't do anything interesting...
  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('axi4BfmTestObj');
    await resetFlow();
    obj.drop();
  }

  Future<void> resetFlow() async {
    await sIntf.clk.waitCycles(2);
    sIntf.resetN.inject(0);
    await sIntf.clk.waitCycles(3);
    sIntf.resetN.inject(1);
  }

  // Nothing in particular to check...
  @override
  void check() {}
}

class Axi4BfmSimpleWriteReadTest extends Axi4BfmTest {
  /// Write then read on same channel to same target
  Future<void> simpleWrRd(
    int laneId, {
    int? addr,
    List<int> data = const [],
    int? len,
    int? size,
    List<int> strb = const [],
    Axi4BurstField? burst,
  }) async {
    final wIntfC = lanes[laneId].write.wIntf;
    final arIntfC = lanes[laneId].read.arIntf;

    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << arIntfC.lenWidth);
    final maxSize = Axi4SizeField.fromSize(wIntfC.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    final pBurst = burst ?? Axi4BurstField.incr;
    final pData = data.isNotEmpty
        ? data
        : List.generate(transLen + 1,
            (index) => Test.random!.nextInt(1 << wIntfC.dataWidth));
    final pStrobes = strb.isNotEmpty
        ? strb
        : List.generate(
            transLen + 1,
            (index) => withStrobes
                ? Test.random!.nextInt(1 << wIntfC.strbWidth)
                : LogicValue.filled(wIntfC.strbWidth, LogicValue.one).toInt());

    final wrPkts = genWrPacket(
      laneId,
      addr: pAddr,
      data: pData,
      len: transLen,
      size: transSize,
      strb: pStrobes,
      burst: pBurst,
      lock: false,
    );
    mainAgents[laneId].writeAgent.reqAgent.sequencer.add(wrPkts.$1);
    mainAgents[laneId].writeAgent.dataAgent.sequencer!.add(wrPkts.$2);

    await wrPkts.$1.completed;
    await wrPkts.$2.completed;

    final rdPkt = genRdPacket(
      laneId,
      addr: pAddr,
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: false,
    );
    mainAgents[laneId].readAgent.reqAgent.sequencer.add(rdPkt);

    await rdPkt.completed;
  }

  Axi4BfmSimpleWriteReadTest(
    super.name, {
    super.numLanes,
    super.numTransfers,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
    super.ranges,
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('${name}Obj');

    await resetFlow();

    // perform a random simple write-read on every channel
    // only for channels that are capable of both...
    for (var i = 0; i < lanes.length; i++) {
      await simpleWrRd(i);
    }

    obj.drop();
  }

  // nothing really to check that isn't covered
  // by compliance checker...
  @override
  void check() {}
}

class Axi4BfmWrapWriteReadTest extends Axi4BfmTest {
  /// Write then read on same channel to same target
  /// But targeting the end of a region such that
  /// we end up wrapping around to the beginning
  Future<void> wrapWrRd(
    int laneId, {
    List<int> data = const [],
    int? len,
    int? size,
    List<int> strb = const [],
  }) async {
    final wIntfC = lanes[laneId].write.wIntf;
    final arIntfC = lanes[laneId].read.arIntf;

    final pAddr =
        ranges[Test.random!.nextInt(ranges.length)].end - 1; // back of range
    final transLen = (len ?? Test.random!.nextInt(1 << arIntfC.lenWidth)) |
        0x2; // guarantee a wrap
    final maxSize = Axi4SizeField.fromSize(wIntfC.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    const pBurst = Axi4BurstField.wrap;
    final pData = data.isNotEmpty
        ? data
        : List.generate(transLen + 1,
            (index) => Test.random!.nextInt(1 << wIntfC.dataWidth));
    final pStrobes = strb.isNotEmpty
        ? strb
        : List.generate(
            transLen + 1,
            (index) => withStrobes
                ? Test.random!.nextInt(1 << wIntfC.strbWidth)
                : LogicValue.filled(wIntfC.strbWidth, LogicValue.one).toInt());

    final wrPkts = genWrPacket(
      laneId,
      addr: pAddr.toInt(),
      data: pData,
      len: transLen,
      size: transSize,
      strb: pStrobes,
      burst: pBurst,
      lock: false,
    );
    mainAgents[laneId].writeAgent.reqAgent.sequencer.add(wrPkts.$1);
    mainAgents[laneId].writeAgent.dataAgent.sequencer!.add(wrPkts.$2);

    await wrPkts.$1.completed;
    await wrPkts.$2.completed;

    final rdPkt = genRdPacket(
      laneId,
      addr: pAddr.toInt(),
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: false,
    );
    mainAgents[laneId].readAgent.reqAgent.sequencer.add(rdPkt);

    await rdPkt.completed;
  }

  Axi4BfmWrapWriteReadTest(
    super.name, {
    super.numLanes,
    super.numTransfers,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
    super.ranges,
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('${name}Obj');

    await resetFlow();

    // perform a random simple write-read on every channel
    // only for channels that are capable of both...
    for (var i = 0; i < lanes.length; i++) {
      await wrapWrRd(i);
    }

    obj.drop();
  }

  // nothing really to check that isn't covered
  // by compliance checker...
  @override
  void check() {}
}

class Axi4BfmProtWriteReadTest extends Axi4BfmTest {
  /// Write then read on same channel to same target
  /// But targeting secure and privileged regions
  /// Such that we conditionally trigger errors
  Future<void> protWrRd(
    int laneId, {
    List<int> data = const [],
    int? len,
    int? size,
    List<int> strb = const [],
  }) async {
    final wIntfC = lanes[laneId].write.wIntf;
    final arIntfC = lanes[laneId].read.arIntf;

    final pAddr = ranges[Test.random!.nextInt(ranges.length)].start; // in range
    final transLen = (len ?? Test.random!.nextInt(1 << arIntfC.lenWidth)) |
        0x2; // guarantee a wrap
    final maxSize = Axi4SizeField.fromSize(wIntfC.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    const pBurst = Axi4BurstField.incr;
    final pData = data.isNotEmpty
        ? data
        : List.generate(transLen + 1,
            (index) => Test.random!.nextInt(1 << wIntfC.dataWidth));
    final pStrobes = strb.isNotEmpty
        ? strb
        : List.generate(
            transLen + 1,
            (index) => withStrobes
                ? Test.random!.nextInt(1 << wIntfC.strbWidth)
                : LogicValue.filled(wIntfC.strbWidth, LogicValue.one).toInt());

    const protN = 0;
    const protS = Axi4ProtField.secure;
    const protP = Axi4ProtField.privileged;
    final protB = Axi4ProtField.privileged.value | Axi4ProtField.secure.value;

    final wrPktsBad1 = genWrPacket(
      laneId,
      addr: pAddr.toInt(),
      data: pData,
      len: transLen,
      size: transSize,
      strb: pStrobes,
      burst: pBurst,
      lock: false,
      prot: protS.value,
    );
    mainAgents[laneId].writeAgent.reqAgent.sequencer.add(wrPktsBad1.$1);
    mainAgents[laneId].writeAgent.dataAgent.sequencer!.add(wrPktsBad1.$2);

    await wrPktsBad1.$1.completed;
    await wrPktsBad1.$2.completed;

    final rdPktBad1 = genRdPacket(
      laneId,
      addr: pAddr.toInt(),
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: false,
      prot: protP.value,
    );
    mainAgents[laneId].readAgent.reqAgent.sequencer.add(rdPktBad1);

    await rdPktBad1.completed;

    final rdPktBad2 = genRdPacket(
      laneId,
      addr: pAddr.toInt(),
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: false,
      prot: protN,
    );
    mainAgents[laneId].readAgent.reqAgent.sequencer.add(rdPktBad2);

    await rdPktBad2.completed;

    final wrPktsGood = genWrPacket(
      laneId,
      addr: pAddr.toInt(),
      data: pData,
      len: transLen,
      size: transSize,
      strb: pStrobes,
      burst: pBurst,
      lock: false,
      prot: protB,
    );
    mainAgents[laneId].writeAgent.reqAgent.sequencer.add(wrPktsGood.$1);
    mainAgents[laneId].writeAgent.dataAgent.sequencer!.add(wrPktsGood.$2);

    await wrPktsGood.$1.completed;
    await wrPktsGood.$2.completed;

    final rdPktGood = genRdPacket(
      laneId,
      addr: pAddr.toInt(),
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: false,
      prot: protB,
    );
    mainAgents[laneId].readAgent.reqAgent.sequencer.add(rdPktGood);

    await rdPktGood.completed;
  }

  Axi4BfmProtWriteReadTest(
    super.name, {
    super.numLanes,
    super.numTransfers,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
    super.ranges,
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('${name}Obj');

    await resetFlow();

    // perform a random simple write-read on every channel
    // only for channels that are capable of both...
    for (var i = 0; i < lanes.length; i++) {
      await protWrRd(i);
    }

    obj.drop();
  }

  // nothing really to check that isn't covered
  // by compliance checker...
  @override
  void check() {}
}

class Axi4BfmReadModifyWriteTest extends Axi4BfmTest {
  /// Read-modify-write to same target
  /// Use AXI lock functionality
  Future<void> rmw(
    int laneId,
    Phase phase, {
    int? addr,
    int? len,
    int? size,
    Axi4BurstField? burst,
    int Function(int)? dataModifier,
  }) async {
    final wIntfC = lanes[laneId].write.wIntf;
    final arIntfC = lanes[laneId].read.arIntf;

    dataModifier ??= (data) => data;

    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << arIntfC.lenWidth);
    final maxSize = Axi4SizeField.fromSize(wIntfC.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    final pBurst = burst ?? Axi4BurstField.incr;

    final rdPkt = genRdPacket(
      laneId,
      addr: pAddr,
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: true,
    );
    mainAgents[laneId].readAgent.reqAgent.sequencer.add(rdPkt);

    await rdPkt.completed;

    // must wait for the read data to come back
    final obj = phase.raiseObjection('${name}DataReturnObj');
    mainAgents[laneId].readAgent.dataAgent.monitor!.stream.listen((d) async {
      final pData = List.generate(
          d.data.width ~/ wIntfC.dataWidth,
          (i) => dataModifier!(d.data
              .getRange(i * wIntfC.dataWidth, (i + 1) * wIntfC.dataWidth)
              .toInt()));
      final pStrobes = List.generate(
          transLen + 1,
          (index) =>
              LogicValue.filled(wIntfC.strbWidth, LogicValue.one).toInt());

      // now send the write
      final wrPkts = genWrPacket(
        laneId,
        addr: pAddr,
        data: pData,
        len: transLen,
        size: transSize,
        strb: pStrobes,
        burst: pBurst,
        lock: true,
      );
      mainAgents[laneId].writeAgent.reqAgent.sequencer.add(wrPkts.$1);
      mainAgents[laneId].writeAgent.dataAgent.sequencer!.add(wrPkts.$2);

      await wrPkts.$1.completed;
      await wrPkts.$2.completed;
      obj.drop();
    });
  }

  Axi4BfmReadModifyWriteTest(
    super.name, {
    super.numLanes,
    super.numTransfers,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
    super.ranges,
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('${name}Obj');

    await resetFlow();

    // perform a random read-modify-write on every channel
    // only for channels that are capable of both...
    for (var i = 0; i < lanes.length; i++) {
      await rmw(i, phase);
    }

    obj.drop();
  }

  // nothing really to check that isn't covered
  // by compliance checker...
  @override
  void check() {}
}

class Axi4BfmReadModifyWriteAbortTest extends Axi4BfmTest {
  /// Read-modify-write that gets aborted
  /// Use AXI lock functionality
  Future<void> rmwAbort(
    int laneId1,
    int laneId2,
    Phase phase, {
    int? addr,
    int? len,
    int? size,
    Axi4BurstField? burst,
    int Function(int)? dataModifier,
  }) async {
    final wIntf1 = lanes[laneId1].write.wIntf;
    final arIntf1 = lanes[laneId1].read.arIntf;
    final rIntf1 = lanes[laneId1].read.rIntf;

    dataModifier ??= (data) => data;

    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << arIntf1.lenWidth);
    final maxSize = Axi4SizeField.fromSize(rIntf1.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    final pBurst = burst ?? Axi4BurstField.incr;

    // send the read
    final rdPkt = genRdPacket(
      laneId1,
      addr: pAddr,
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: true,
    );
    mainAgents[laneId1].readAgent.reqAgent.sequencer.add(rdPkt);

    await rdPkt.completed;

    // now send a read on another channel
    final rdPktBad = genRdPacket(
      laneId2,
      addr: pAddr,
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: false,
    );
    mainAgents[laneId2].readAgent.reqAgent.sequencer.add(rdPktBad);

    await rdPktBad.completed;

    // must wait for the read data to come back
    final obj = phase.raiseObjection('${name}DataReturnObj');
    mainAgents[laneId1].readAgent.dataAgent.monitor!.stream.listen((d) async {
      final pData = List.generate(
          d.data.width ~/ wIntf1.dataWidth,
          (i) => dataModifier!(d.data
              .getRange(i * wIntf1.dataWidth, (i + 1) * wIntf1.dataWidth)
              .toInt()));
      final pStrobes = List.generate(
          transLen + 1,
          (index) =>
              LogicValue.filled(wIntf1.strbWidth, LogicValue.one).toInt());

      // lastly send the write
      // this should trigger an error
      final wrPkts = genWrPacket(
        laneId1,
        addr: pAddr,
        data: pData,
        len: transLen,
        size: transSize,
        strb: pStrobes,
        burst: pBurst,
        lock: true,
      );
      mainAgents[laneId1].writeAgent.reqAgent.sequencer.add(wrPkts.$1);
      mainAgents[laneId1].writeAgent.dataAgent.sequencer!.add(wrPkts.$2);

      await wrPkts.$1.completed;
      await wrPkts.$2.completed;
      obj.drop();
    });
  }

  Axi4BfmReadModifyWriteAbortTest(
    super.name, {
    super.numLanes,
    super.numTransfers,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
    super.ranges,
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('${name}Obj');

    await resetFlow();

    // for every channel that is read-write enabled
    // find another channel that is read enabled
    // use those two to confirm the abortion
    for (var i = 0; i < lanes.length; i++) {
      for (var j = 0; j < lanes.length; j++) {
        if (j != i) {
          await rmwAbort(i, j, phase);
        }
      }
    }

    obj.drop();
  }

  // nothing really to check that isn't covered
  // by compliance checker...
  @override
  void check() {}
}

class Axi4BfmRandomAccessTest extends Axi4BfmTest {
  /// Completely random collection of reads and writes.
  Future<void> fullRandom({
    int numTransfers = 10,
  }) async {
    for (var i = 0; i < numTransfers; i++) {
      final nextLane = Test.random!.nextInt(lanes.length);
      final isRead = Test.random!.nextBool();

      if (isRead) {
        final rdPkt = genRdPacket(nextLane);
        mainAgents[nextLane].readAgent.reqAgent.sequencer.add(rdPkt);
        await rdPkt.completed;
      } else {
        final wrPkts = genWrPacket(nextLane);
        mainAgents[nextLane].writeAgent.reqAgent.sequencer.add(wrPkts.$1);
        mainAgents[nextLane].writeAgent.dataAgent.sequencer!.add(wrPkts.$2);
        await wrPkts.$1.completed;
        await wrPkts.$2.completed;
      }
    }
  }

  Axi4BfmRandomAccessTest(
    super.name, {
    required super.numTransfers,
    super.numLanes,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
    super.ranges,
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('${name}Obj');

    await resetFlow();
    await fullRandom(numTransfers: numTransfers);

    obj.drop();
  }

  // nothing really to check that isn't covered
  // by compliance checker...
  @override
  void check() {}
}

class Axi4WriteComplianceEvilTest extends Test {
  late final Axi4SystemInterface sIntf;
  late final Axi4BaseWriteCluster wIntf;

  late final Axi4RequestChannelDriver driver;
  late final Sequencer<Axi4RequestPacket> sequencer;

  late final Axi4DataChannelDriver driverD;
  late final Sequencer<Axi4DataPacket> sequencerD;

  Axi4WriteComplianceEvilTest(super.name, {Type axiType = Axi4WriteCluster})
      : super(randomSeed: 123) {
    // using default parameter values for all interfaces
    sIntf = Axi4SystemInterface();
    if (axiType == Axi4WriteCluster) {
      wIntf = Axi4WriteCluster(
        addrWidth: 4,
        dataWidth: 8,
        lenWidth: 2,
        userWidth: 3,
      );
    } else if (axiType == Axi4LiteWriteCluster) {
      wIntf = Axi4LiteWriteCluster(
        addrWidth: 4,
        dataWidth: 8,
      );
    } else if (axiType == Ace4LiteWriteCluster) {
      wIntf = Ace4LiteWriteCluster(
        addrWidth: 4,
        dataWidth: 8,
        lenWidth: 2,
        userWidth: 3,
      );
    } else {
      wIntf = Ace4WriteCluster(
        addrWidth: 4,
        dataWidth: 8,
        lenWidth: 2,
        userWidth: 3,
      );
    }

    sequencer = Sequencer<Axi4RequestPacket>('${name}_sequencer', this);
    driver = Axi4RequestChannelDriver(
        sIntf: sIntf, rIntf: wIntf.awIntf, sequencer: sequencer, parent: this);
    sequencerD = Sequencer<Axi4DataPacket>('${name}_sequencerD', this);
    driverD = Axi4DataChannelDriver(
        sIntf: sIntf, rIntf: wIntf.wIntf, sequencer: sequencerD, parent: this);
    Axi4WriteComplianceChecker(sIntf, wIntf.awIntf, wIntf.wIntf, wIntf.bIntf,
        parent: this);

    sIntf.clk <= SimpleClockGenerator(10).clk;
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('axi4WriteComplianceEvilTestObj');
    await resetFlow();

    // send a request with an invalid size
    final req1a = Axi4RequestPacket(
      addr: LogicValue.ofInt(0x0, wIntf.awIntf.addrWidth), // don't care
      prot: LogicValue.ofInt(0x0, wIntf.awIntf.protWidth), // don't care
      id: LogicValue.ofInt(0x0, wIntf.awIntf.idWidth), // don't care
      len: LogicValue.ofInt(0x0, wIntf.awIntf.lenWidth), // don't care
      size: LogicValue.ofInt(
          Axi4SizeField.bit128.value, wIntf.awIntf.sizeWidth), // bad
      burst: LogicValue.ofInt(
          Axi4BurstField.fixed.value, wIntf.awIntf.burstWidth), // don't care
      lock: LogicValue.zero, // don't care
      cache: LogicValue.ofInt(0, wIntf.awIntf.cacheWidth), // not supported
      qos: LogicValue.ofInt(0, wIntf.awIntf.qosWidth), // not supported
      region: LogicValue.ofInt(0, wIntf.awIntf.regionWidth), // not supported
      user: LogicValue.ofInt(0, wIntf.awIntf.userWidth), // not supported
    );
    final req1b = Axi4DataPacket(
      data: [LogicValue.ofInt(0x0, wIntf.wIntf.dataWidth)]
          .rswizzle(), // don't care
      id: LogicValue.ofInt(0x0, wIntf.wIntf.idWidth), // don't care
      user: LogicValue.ofInt(0, wIntf.wIntf.userWidth), // not supported
      strb: [LogicValue.ofInt(0x0, wIntf.wIntf.dataWidth)]
          .rswizzle(), // don't care
    );
    sequencer.add(req1a);
    sequencerD.add(req1b);
    await req1a.completed;
    await req1b.completed;
    await sIntf.clk.waitCycles(10);

    // send a request, subsequent data has a different ID
    // TODO(kimmeljo): driving mechanism doesn't allow this right now!!

    // send a request, send too many data flits
    // send a request, send LAST on the wrong flit
    final req2a = Axi4RequestPacket(
      addr: LogicValue.ofInt(0x0, wIntf.awIntf.addrWidth), // don't care
      prot: LogicValue.ofInt(0x0, wIntf.awIntf.protWidth), // don't care// bad
      id: LogicValue.ofInt(0x1, wIntf.awIntf.idWidth), // don't care
      len: LogicValue.ofInt(0x0, wIntf.awIntf.lenWidth), // don't care
      size: LogicValue.ofInt(
          Axi4SizeField.bit8.value, wIntf.awIntf.sizeWidth), // good
      burst: LogicValue.ofInt(
          Axi4BurstField.fixed.value, wIntf.awIntf.burstWidth), // don't care
      lock: LogicValue.zero, // don't care
      cache: LogicValue.ofInt(0, wIntf.awIntf.cacheWidth), // not supported
      qos: LogicValue.ofInt(0, wIntf.awIntf.qosWidth), // not supported
      region: LogicValue.ofInt(0, wIntf.awIntf.regionWidth), // not supported
      user: LogicValue.ofInt(0, wIntf.awIntf.userWidth), // not supported
    );
    final req2b = Axi4DataPacket(
      data: [
        LogicValue.ofInt(0x0, wIntf.wIntf.dataWidth),
        LogicValue.ofInt(0x0, wIntf.wIntf.dataWidth),
        LogicValue.ofInt(0x0, wIntf.wIntf.dataWidth),
        LogicValue.ofInt(0x0, wIntf.wIntf.dataWidth)
      ].rswizzle(), // bad
      id: LogicValue.ofInt(0x1, wIntf.wIntf.idWidth), // don't care
      user: LogicValue.ofInt(0, wIntf.wIntf.userWidth), // not supported
      strb: [
        LogicValue.ofInt(0x0, wIntf.wIntf.strbWidth),
        LogicValue.ofInt(0x0, wIntf.wIntf.strbWidth),
        LogicValue.ofInt(0x0, wIntf.wIntf.strbWidth),
        LogicValue.ofInt(0x0, wIntf.wIntf.strbWidth)
      ].rswizzle(), // bad
    );
    sequencer.add(req2a);
    sequencerD.add(req2b);
    await req2a.completed;
    await req2b.completed;
    await sIntf.clk.waitCycles(10);

    obj.drop();
  }

  Future<void> resetFlow() async {
    await sIntf.clk.waitCycles(2);
    sIntf.resetN.inject(0);
    await sIntf.clk.waitCycles(3);
    sIntf.resetN.inject(1);
    wIntf.awIntf.ready.inject(1);
    wIntf.wIntf.ready.inject(1);
    wIntf.bIntf.ready.inject(1);
  }

  // Nothing in particular to check...
  @override
  void check() {}
}

class Axi4ReadComplianceEvilTest extends Test {
  late final Axi4SystemInterface sIntf;
  late final Axi4BaseReadCluster rIntf;

  late final Axi4RequestChannelDriver driver;
  late final Sequencer<Axi4RequestPacket> sequencer;

  Axi4ReadComplianceEvilTest(super.name, {Type axiType = Axi4ReadCluster})
      : super(randomSeed: 123) {
    // using default parameter values for all interfaces
    sIntf = Axi4SystemInterface();
    if (axiType == Axi4ReadCluster) {
      rIntf = Axi4ReadCluster(
        addrWidth: 4,
        dataWidth: 8,
        lenWidth: 2,
        userWidth: 3,
      );
    } else if (axiType == Axi4LiteReadCluster) {
      rIntf = Axi4LiteReadCluster(
        addrWidth: 4,
        dataWidth: 8,
      );
    } else if (axiType == Ace4LiteReadCluster) {
      rIntf = Ace4LiteReadCluster(
        addrWidth: 4,
        dataWidth: 8,
        lenWidth: 2,
        userWidth: 3,
      );
    } else {
      rIntf = Ace4ReadCluster(
        addrWidth: 4,
        dataWidth: 8,
        lenWidth: 2,
        userWidth: 3,
      );
    }

    sequencer = Sequencer<Axi4RequestPacket>('${name}_sequencer', this);
    driver = Axi4RequestChannelDriver(
        sIntf: sIntf, rIntf: rIntf.arIntf, sequencer: sequencer, parent: this);
    Axi4ReadComplianceChecker(sIntf, rIntf.arIntf, rIntf.rIntf, parent: this);

    sIntf.clk <= SimpleClockGenerator(10).clk;
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('axi4ReadComplianceEvilTestObj');
    await resetFlow();

    // send a request with an invalid size
    final req1 = Axi4RequestPacket(
      addr: LogicValue.ofInt(0x0, rIntf.arIntf.addrWidth), // don't care
      prot: LogicValue.ofInt(0x0, rIntf.arIntf.protWidth), // don't care
      id: LogicValue.ofInt(0x0, rIntf.arIntf.idWidth), // don't care
      len: LogicValue.ofInt(0x0, rIntf.arIntf.lenWidth), // don't care
      size: LogicValue.ofInt(
          Axi4SizeField.bit128.value, rIntf.arIntf.sizeWidth), // bad
      burst: LogicValue.ofInt(
          Axi4BurstField.fixed.value, rIntf.arIntf.burstWidth), // don't care
      lock: LogicValue.zero, // don't care
      cache: LogicValue.ofInt(0, rIntf.arIntf.cacheWidth), // not supported
      qos: LogicValue.ofInt(0, rIntf.arIntf.qosWidth), // not supported
      region: LogicValue.ofInt(0, rIntf.arIntf.regionWidth), // not supported
      user: LogicValue.ofInt(0, rIntf.arIntf.userWidth), // not supported
    );
    sequencer.add(req1);
    await req1.completed;
    await sIntf.clk.waitCycles(10);

    // send a request, response data has a different ID
    // send a request with an invalid size
    final req2 = Axi4RequestPacket(
      addr: LogicValue.ofInt(0x0, rIntf.arIntf.addrWidth), // don't care
      prot: LogicValue.ofInt(0x0, rIntf.arIntf.protWidth), // don't care
      id: LogicValue.ofInt(0x1, rIntf.arIntf.idWidth), // don't care
      len: LogicValue.ofInt(0x0, rIntf.arIntf.lenWidth), // don't care
      size: LogicValue.ofInt(
          Axi4SizeField.bit8.value, rIntf.arIntf.sizeWidth), // good
      burst: LogicValue.ofInt(
          Axi4BurstField.fixed.value, rIntf.arIntf.burstWidth), // don't care
      lock: LogicValue.zero, // don't care
      cache: LogicValue.ofInt(0, rIntf.arIntf.cacheWidth), // not supported
      qos: LogicValue.ofInt(0, rIntf.arIntf.qosWidth), // not supported
      region: LogicValue.ofInt(0, rIntf.arIntf.regionWidth), // not supported
      user: LogicValue.ofInt(0, rIntf.arIntf.userWidth), // not supported
    );
    sequencer.add(req2);
    await req2.completed;
    await sIntf.clk.nextNegedge;
    rIntf.rIntf.valid.inject(1);
    rIntf.rIntf.id!.inject(0x2);
    await sIntf.clk.nextNegedge;
    rIntf.rIntf.valid.inject(0);
    await sIntf.clk.waitCycles(10);

    // send a request, receive too many data flits
    // send a request, receive LAST on the wrong flit
    final req3 = Axi4RequestPacket(
      addr: LogicValue.ofInt(0x0, rIntf.arIntf.addrWidth), // don't care
      prot: LogicValue.ofInt(0x0, rIntf.arIntf.protWidth), // don't care
      id: LogicValue.ofInt(0x2, rIntf.arIntf.idWidth), // don't care
      len: LogicValue.ofInt(0x0, rIntf.arIntf.lenWidth), // don't care
      size: LogicValue.ofInt(
          Axi4SizeField.bit8.value, rIntf.arIntf.sizeWidth), // good
      burst: LogicValue.ofInt(
          Axi4BurstField.fixed.value, rIntf.arIntf.burstWidth), // don't care
      lock: LogicValue.zero, // don't care
      cache: LogicValue.ofInt(0, rIntf.arIntf.cacheWidth), // not supported
      qos: LogicValue.ofInt(0, rIntf.arIntf.qosWidth), // not supported
      region: LogicValue.ofInt(0, rIntf.arIntf.regionWidth), // not supported
      user: LogicValue.ofInt(0, rIntf.arIntf.userWidth), // not supported
    );
    sequencer.add(req3);
    await req3.completed;
    rIntf.rIntf.last!.inject(0);
    for (var i = 0; i < 10; i++) {
      await sIntf.clk.nextNegedge;
      rIntf.rIntf.valid.inject(1);
      rIntf.rIntf.id!.inject(0x2);
      if (i == 10) {
        rIntf.rIntf.last!.inject(0x1);
      }
    }
    await sIntf.clk.waitCycles(10);

    obj.drop();
  }

  Future<void> resetFlow() async {
    await sIntf.clk.waitCycles(2);
    sIntf.resetN.inject(0);
    await sIntf.clk.waitCycles(3);
    sIntf.resetN.inject(1);
    rIntf.arIntf.ready.inject(1);
    rIntf.rIntf.ready.inject(1);
  }

  // Nothing in particular to check...
  @override
  void check() {}
}

void main() {
  tearDown(() async {
    await Test.reset();
  });

  setUp(() async {
    // Set the logger level
    Logger.root.level = Level.OFF;
  });

  Future<void> runTest(Axi4BfmTest axi4BfmTest,
      {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(30000);

    if (dumpWaves) {
      final mod = Axi4Subordinate(axi4BfmTest.sIntf, axi4BfmTest.lanes);
      await mod.build();
      WaveDumper(mod);
    }

    await axi4BfmTest.start();
  }

  test('simple writes and reads no strobes', () async {
    await runTest(Axi4BfmSimpleWriteReadTest('simpleNoStrobes'),
        dumpWaves: true);
  });

  test('simple writes and reads with strobes', () async {
    await runTest(
        Axi4BfmSimpleWriteReadTest('simpleStrobes', withStrobes: true));
  });

  test('simple writes and reads with delays', () async {
    await runTest(Axi4BfmSimpleWriteReadTest('simpleDelays', interTxnDelay: 5));
  });

  test('simple writes and reads with response delays', () async {
    await runTest(Axi4BfmSimpleWriteReadTest('simpleResponseDelays',
        withRandomRspDelays: true));
  });

  test('simple writes and read with errors', () async {
    await runTest(Axi4BfmSimpleWriteReadTest('werr', withErrors: true));
  });

  test('wrapping writes and read', () async {
    await runTest(Axi4BfmWrapWriteReadTest('wrap', ranges: [
      AxiAddressRange(
          start: LogicValue.ofInt(0x0, 32), end: LogicValue.ofInt(0x1000, 32))
    ]));
  });

  test('protection writes and read', () async {
    await runTest(Axi4BfmProtWriteReadTest('prot', ranges: [
      AxiAddressRange(
          start: LogicValue.ofInt(0x0, 32),
          end: LogicValue.ofInt(0x1000, 32),
          isPrivileged: true,
          isSecure: true)
    ]));
  });

  test('read-modify-write flow', () async {
    await runTest(Axi4BfmReadModifyWriteTest(
      'rmw',
      supportLocking: true,
    ));
  });

  test('read-modify-write with abort flow', () async {
    await runTest(Axi4BfmReadModifyWriteAbortTest(
      'rmwAbort',
      numLanes: 2,
      supportLocking: true,
    ));
  });

  test('random everything', () async {
    await runTest(Axi4BfmRandomAccessTest(
      'randeverything',
      numTransfers: 20,
      numLanes: 4,
      withRandomRspDelays: true,
      withStrobes: true,
      interTxnDelay: 3,
      supportLocking: true,
    ));
  });

  test('evil write compliance', () async {
    Simulator.setMaxSimTime(10000);
    try {
      await Axi4WriteComplianceEvilTest('evilWriteCompliance').start();
    } on Exception catch (e) {
      expect(e.toString(), contains('Test failed'));
    }
  });

  test('evil read compliance', () async {
    Simulator.setMaxSimTime(30000);
    try {
      await Axi4ReadComplianceEvilTest('evilReadCompliance').start();
    } on Exception catch (e) {
      expect(e.toString(), contains('Test failed'));
    }
  });
}
