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

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

import 'axi4_test.dart';

enum Axi4BfmTestChannelConfig { read, write, readWrite }

class Axi4BfmTest extends Test {
  late final Axi4SystemInterface sIntf;

  final int numChannels;
  final List<Axi4BfmTestChannelConfig> channelConfigs;
  final List<Axi4Channel> channels = [];

  late final Axi4MainAgent main;

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

  String get outFolder => 'tmp_test/axi4bfm/$name/';

  bool get hasAnyReads => channels.any((element) => element.hasRead);

  bool get hasAnyWrites => channels.any((element) => element.hasWrite);

  /// Mechanism to generate a write request in the test.
  Axi4WriteRequestPacket genWrPacket(
    int channelId, {
    int? addr,
    List<int> data = const [],
    int? len,
    int? size,
    List<int> strb = const [],
    Axi4BurstField? burst,
    bool? lock,
  }) {
    final wIntfC = channels[channelId].wIntf!;
    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << wIntfC.lenWidth);
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

    return Axi4WriteRequestPacket(
      addr: LogicValue.ofInt(pAddr, addrWidth),
      prot: LogicValue.ofInt(0, wIntfC.protWidth), // not supported
      data: pData,
      id: LogicValue.ofInt(channelId, wIntfC.idWidth),
      len: LogicValue.ofInt(transLen, wIntfC.lenWidth),
      size: LogicValue.ofInt(transSize, wIntfC.sizeWidth),
      burst: LogicValue.ofInt(pBurst.value, wIntfC.burstWidth),
      lock: pLock,
      cache: LogicValue.ofInt(0, wIntfC.cacheWidth), // not supported
      qos: LogicValue.ofInt(0, wIntfC.qosWidth), // not supported
      region: LogicValue.ofInt(0, wIntfC.regionWidth), // not supported
      user: LogicValue.ofInt(0, wIntfC.awuserWidth), // not supported
      strobe: pStrobes,
      wUser: LogicValue.ofInt(0, wIntfC.wuserWidth), // not supported
    );
  }

  /// Mechanism to generate a read request in the test.
  Axi4ReadRequestPacket genRdPacket(
    int channelId, {
    int? addr,
    int? len,
    int? size,
    Axi4BurstField? burst,
    bool? lock,
  }) {
    final rIntfC = channels[channelId].rIntf!;
    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << rIntfC.lenWidth);
    final maxSize = Axi4SizeField.fromSize(rIntfC.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    final pBurst = burst ?? Axi4BurstField.incr;
    final pLock = supportLocking
        ? (lock != null && lock ? LogicValue.one : LogicValue.zero)
        : LogicValue.zero;

    return Axi4ReadRequestPacket(
      addr: LogicValue.ofInt(pAddr, addrWidth),
      prot: LogicValue.ofInt(0, rIntfC.protWidth), // not supported
      id: LogicValue.ofInt(channelId, rIntfC.idWidth),
      len: LogicValue.ofInt(transLen, rIntfC.lenWidth),
      size: LogicValue.ofInt(transSize, rIntfC.sizeWidth),
      burst: LogicValue.ofInt(pBurst.value, rIntfC.burstWidth),
      lock: pLock,
      cache: LogicValue.ofInt(0, rIntfC.cacheWidth), // not supported
      qos: LogicValue.ofInt(0, rIntfC.qosWidth), // not supported
      region: LogicValue.ofInt(0, rIntfC.regionWidth), // not supported
      user: LogicValue.ofInt(0, rIntfC.aruserWidth), // not supported
    );
  }

  Axi4BfmTest(
    super.name, {
    this.numChannels = 1,
    this.channelConfigs = const [Axi4BfmTestChannelConfig.readWrite],
    this.numTransfers = 10,
    this.withStrobes = false,
    this.interTxnDelay = 0,
    this.withRandomRspDelays = false,
    this.withErrors = false,
    this.addrWidth = 32,
    this.dataWidth = 32,
    this.lenWidth = 2,
    this.supportLocking = false,
  })  : assert(numChannels > 0, 'Every test must have at least one channel.'),
        assert(numChannels == channelConfigs.length,
            'Every channel must have a config.'),
        super(randomSeed: 123) {
    // using default parameter values for all interfaces
    sIntf = Axi4SystemInterface();
    for (var i = 0; i < numChannels; i++) {
      if (channelConfigs[i] == Axi4BfmTestChannelConfig.readWrite) {
        channels.add(Axi4Channel(
          channelId: i,
          rIntf: Axi4ReadInterface(
            addrWidth: addrWidth,
            dataWidth: dataWidth,
            lenWidth: lenWidth,
            ruserWidth: dataWidth ~/ 2 - 1,
          ),
          wIntf: Axi4WriteInterface(
            addrWidth: addrWidth,
            dataWidth: dataWidth,
            lenWidth: lenWidth,
            wuserWidth: dataWidth ~/ 2 - 1,
          ),
        ));
        Axi4ReadComplianceChecker(sIntf, channels.last.rIntf!, parent: this);
        Axi4WriteComplianceChecker(sIntf, channels.last.wIntf!, parent: this);
      } else if (channelConfigs[i] == Axi4BfmTestChannelConfig.read) {
        channels.add(Axi4Channel(
          channelId: i,
          rIntf: Axi4ReadInterface(
            addrWidth: addrWidth,
            dataWidth: dataWidth,
            lenWidth: lenWidth,
            ruserWidth: dataWidth ~/ 2 - 1,
          ),
        ));
        Axi4ReadComplianceChecker(sIntf, channels.last.rIntf!, parent: this);
      } else if (channelConfigs[i] == Axi4BfmTestChannelConfig.write) {
        channels.add(Axi4Channel(
          channelId: i,
          wIntf: Axi4WriteInterface(
            addrWidth: addrWidth,
            dataWidth: dataWidth,
            lenWidth: lenWidth,
            wuserWidth: dataWidth ~/ 2 - 1,
          ),
        ));
        Axi4WriteComplianceChecker(sIntf, channels.last.wIntf!, parent: this);
      }
    }

    storage = SparseMemoryStorage(
      addrWidth: addrWidth,
      dataWidth: dataWidth,
      onInvalidRead: (addr, dataWidth) =>
          LogicValue.filled(dataWidth, LogicValue.zero),
    );

    sIntf.clk <= SimpleClockGenerator(10).clk;

    main = Axi4MainAgent(sIntf: sIntf, channels: channels, parent: this);

    Axi4SubordinateAgent(
      sIntf: sIntf,
      channels: channels,
      parent: this,
      storage: storage,
      readResponseDelay:
          withRandomRspDelays ? (request) => Test.random!.nextInt(5) : null,
      writeResponseDelay:
          withRandomRspDelays ? (request) => Test.random!.nextInt(5) : null,
      respondWithError: withErrors ? (request) => true : null,
      supportLocking: supportLocking,
    );

    Directory(outFolder).createSync(recursive: true);

    final tracker = Axi4Tracker(
      dumpTable: false,
      outputFolder: outFolder,
    );

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      final jsonStr =
          File('$outFolder/axi4Tracker.tracker.json').readAsStringSync();
      json.decode(jsonStr);

      // Here can do any checking against the tracker contents...

      Directory(outFolder).deleteSync(recursive: true);
    });

    for (var i = 0; i < numChannels; i++) {
      main.getRdMonitor(i)?.stream.listen(tracker.record);
      main.getWrMonitor(i)?.stream.listen(tracker.record);
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
    int channelId, {
    int? addr,
    List<int> data = const [],
    int? len,
    int? size,
    List<int> strb = const [],
    Axi4BurstField? burst,
  }) async {
    final wIntfC = channels[channelId].wIntf!;
    final rIntfC = channels[channelId].rIntf!;

    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << rIntfC.lenWidth);
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

    final wrPkt = genWrPacket(
      channelId,
      addr: pAddr,
      data: pData,
      len: transLen,
      size: transSize,
      strb: pStrobes,
      burst: pBurst,
      lock: false,
    );
    this.main.getWrSequencer(channelId)!.add(wrPkt);

    await wrPkt.completed;

    final rdPkt = genRdPacket(
      channelId,
      addr: pAddr,
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: false,
    );
    this.main.getRdSequencer(channelId)!.add(rdPkt);

    await rdPkt.completed;
  }

  Axi4BfmSimpleWriteReadTest(
    super.name, {
    super.numChannels,
    super.channelConfigs,
    super.numTransfers,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('${name}Obj');

    await resetFlow();

    // perform a random simple write-read on every channel
    // only for channels that are capable of both...
    for (var i = 0; i < channels.length; i++) {
      if (channels[i].hasWrite && channels[i].hasRead) {
        await simpleWrRd(i);
      }
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
    int channelId, {
    int? addr,
    int? len,
    int? size,
    Axi4BurstField? burst,
    int Function(int)? dataModifier,
  }) async {
    final wIntfC = channels[channelId].wIntf!;
    final rIntfC = channels[channelId].rIntf!;

    dataModifier ??= (data) => data;

    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << rIntfC.lenWidth);
    final maxSize = Axi4SizeField.fromSize(wIntfC.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    final pBurst = burst ?? Axi4BurstField.incr;

    final rdPkt = genRdPacket(
      channelId,
      addr: pAddr,
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: true,
    );
    this.main.getRdSequencer(channelId)!.add(rdPkt);

    await rdPkt.completed;

    final pData =
        rdPkt.returnedData.map((e) => dataModifier!(e.toInt())).toList();
    final pStrobes = List.generate(transLen + 1,
        (index) => LogicValue.filled(wIntfC.strbWidth, LogicValue.one).toInt());

    final wrPkt = genWrPacket(
      channelId,
      addr: pAddr,
      data: pData,
      len: transLen,
      size: transSize,
      strb: pStrobes,
      burst: pBurst,
      lock: true,
    );
    this.main.getWrSequencer(channelId)!.add(wrPkt);

    await wrPkt.completed;
  }

  Axi4BfmReadModifyWriteTest(
    super.name, {
    super.numChannels,
    super.channelConfigs,
    super.numTransfers,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('${name}Obj');

    await resetFlow();

    // perform a random read-modify-write on every channel
    // only for channels that are capable of both...
    for (var i = 0; i < channels.length; i++) {
      if (channels[i].hasWrite && channels[i].hasRead) {
        await rmw(i);
      }
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
    int channelId1,
    int channelId2, {
    int? addr,
    int? len,
    int? size,
    Axi4BurstField? burst,
    int Function(int)? dataModifier,
  }) async {
    final wIntf1 = channels[channelId1].wIntf!;
    final rIntf1 = channels[channelId1].rIntf!;

    dataModifier ??= (data) => data;

    final pAddr = addr ?? Test.random!.nextInt(1 << addrWidth);
    final transLen = len ?? Test.random!.nextInt(1 << rIntf1.lenWidth);
    final maxSize = Axi4SizeField.fromSize(rIntf1.dataWidth).value;
    final transSize = size ?? Test.random!.nextInt(maxSize + 1);
    final pBurst = burst ?? Axi4BurstField.incr;

    // send the read
    final rdPkt = genRdPacket(
      channelId1,
      addr: pAddr,
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: true,
    );
    this.main.getRdSequencer(channelId1)!.add(rdPkt);

    await rdPkt.completed;

    // now send a read on another channel
    final rdPktBad = genRdPacket(
      channelId2,
      addr: pAddr,
      len: transLen,
      size: transSize,
      burst: pBurst,
      lock: false,
    );
    this.main.getRdSequencer(channelId2)!.add(rdPktBad);

    await rdPktBad.completed;

    final pData =
        rdPkt.returnedData.map((e) => dataModifier!(e.toInt())).toList();
    final pStrobes = List.generate(transLen + 1,
        (index) => LogicValue.filled(wIntf1.strbWidth, LogicValue.one).toInt());

    // lastly send the write
    // this should trigger an error
    final wrPkt = genWrPacket(
      channelId1,
      addr: pAddr,
      data: pData,
      len: transLen,
      size: transSize,
      strb: pStrobes,
      burst: pBurst,
      lock: true,
    );
    this.main.getWrSequencer(channelId1)!.add(wrPkt);

    await wrPkt.completed;
  }

  Axi4BfmReadModifyWriteAbortTest(
    super.name, {
    super.numChannels,
    super.channelConfigs,
    super.numTransfers,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
  });

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('${name}Obj');

    await resetFlow();

    // for every channel that is read-write enabled
    // find another channel that is read enabled
    // use those two to confirm the abortion
    for (var i = 0; i < channels.length; i++) {
      if (channels[i].hasWrite && channels[i].hasRead) {
        for (var j = 0; j < channels.length; j++) {
          if (channels[j].hasRead && j != i) {
            await rmwAbort(i, j);
          }
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
      final nextChannel = Test.random!.nextInt(channels.length);
      final channel = channels[nextChannel];
      final isRead = (channel.hasRead && !channel.hasWrite) ||
          (channel.hasRead && channel.hasWrite && Test.random!.nextBool());

      if (isRead) {
        final rdPkt = genRdPacket(nextChannel);
        this.main.getRdSequencer(nextChannel)!.add(rdPkt);
        await rdPkt.completed;
      } else {
        final wrPkt = genWrPacket(nextChannel);
        this.main.getWrSequencer(nextChannel)!.add(wrPkt);
        await wrPkt.completed;
      }
    }
  }

  Axi4BfmRandomAccessTest(
    super.name, {
    required super.numTransfers,
    super.numChannels,
    super.channelConfigs,
    super.withStrobes,
    super.interTxnDelay,
    super.withRandomRspDelays,
    super.withErrors,
    super.addrWidth,
    super.dataWidth,
    super.lenWidth,
    super.supportLocking,
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

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Future<void> runTest(Axi4BfmTest axi4BfmTest,
      {bool dumpWaves = false}) async {
    Simulator.setMaxSimTime(30000);

    if (dumpWaves) {
      final mod = Axi4Subordinate(axi4BfmTest.sIntf, axi4BfmTest.channels);
      await mod.build();
      WaveDumper(mod);
    }

    await axi4BfmTest.start();
  }

  test('simple writes and reads no strobes', () async {
    await runTest(Axi4BfmSimpleWriteReadTest('simpleNoStrobes'));
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

  test('read-modify-write flow', () async {
    await runTest(Axi4BfmReadModifyWriteTest(
      'rmw',
      supportLocking: true,
    ));
  });

  test('read-modify-write with abort flow', () async {
    await runTest(Axi4BfmReadModifyWriteAbortTest(
      'rmwAbort',
      numChannels: 2,
      channelConfigs: [
        Axi4BfmTestChannelConfig.readWrite,
        Axi4BfmTestChannelConfig.read,
      ],
      supportLocking: true,
    ));
  });

  test('random everything', () async {
    await runTest(Axi4BfmRandomAccessTest(
      'randeverything',
      numTransfers: 20,
      numChannels: 4,
      channelConfigs: [
        Axi4BfmTestChannelConfig.read,
        Axi4BfmTestChannelConfig.write,
        Axi4BfmTestChannelConfig.readWrite,
        Axi4BfmTestChannelConfig.write,
      ],
      withRandomRspDelays: true,
      withStrobes: true,
      interTxnDelay: 3,
      supportLocking: true,
    ));
  });
}
