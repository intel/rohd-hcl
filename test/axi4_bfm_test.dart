// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_bfm_test.dart
// Tests for the AXI4 BFM.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';
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

  String get outFolder => 'tmp_test/axi4bfm/$name/';

  bool get hasAnyReads => channels.any((element) => element.hasRead);

  bool get hasAnyWrites => channels.any((element) => element.hasWrite);

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
  })  : assert(numChannels > 0, 'Every test must have at least one channel.'),
        assert(numChannels == channelConfigs.length,
            'Every channel must have a config.'),
        super(randomSeed: 123) {
    // using default parameter values for all interfaces
    sIntf = Axi4SystemInterface();
    for (var i = 0; i < numChannels; i++) {
      if (channelConfigs[i] == Axi4BfmTestChannelConfig.readWrite) {
        channels.add(Axi4Channel(
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
          hasWrite: false,
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
          hasRead: false,
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
    );

    Directory(outFolder).createSync(recursive: true);

    final tracker = Axi4Tracker(
      dumpTable: false,
      outputFolder: outFolder,
    );

    Simulator.registerEndOfSimulationAction(() async {
      await tracker.terminate();

      // final jsonStr =
      //     File('$outFolder/axi4Tracker.tracker.json').readAsStringSync();
      // final jsonContents = json.decode(jsonStr);

      // // TODO: check jsonContents...
      // //  APB test checks the number of records based on the number of transactions

      // Directory(outFolder).deleteSync(recursive: true);
    });

    for (var i = 0; i < numChannels; i++) {
      main.getRdMonitor(i)?.stream.listen(tracker.record);
      main.getWrMonitor(i)?.stream.listen(tracker.record);
    }
  }

  int numTransfersCompleted = 0;
  final mandatoryTransWaitPeriod = 10;

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection('axi4BfmTestObj');

    await _resetFlow();

    // LogicValue strobedData(LogicValue originalData, LogicValue strobe) => [
    //       for (var i = 0; i < 4; i++)
    //         strobe[i].toBool()
    //             ? originalData.getRange(i * 8, i * 8 + 8)
    //             : LogicValue.filled(8, LogicValue.zero)
    //     ].rswizzle();

    // to track what was written
    final lens = <int>[];
    final sizes = <int>[];
    final data = <List<LogicValue>>[];
    final strobes = <List<LogicValue>>[];

    // normal writes
    if (hasAnyWrites) {
      for (var i = 0; i < numTransfers; i++) {
        // pick a random write interface
        var foundWrChannel = false;
        var currW = 0;
        while (!foundWrChannel) {
          currW = Test.random!.nextInt(channels.length);
          foundWrChannel = channels[currW].hasWrite;
        }
        final wIntfC = channels[currW].wIntf!;

        // generate a completely random access
        final transLen = Test.random!.nextInt(1 << wIntfC.lenWidth);
        final transSize =
            Test.random!.nextInt(1 << wIntfC.sizeWidth) % (dataWidth ~/ 8);
        final randomData = List.generate(
            transLen + 1,
            (index) => LogicValue.ofInt(
                Test.random!.nextInt(1 << wIntfC.dataWidth), wIntfC.dataWidth));
        final randomStrobes = List.generate(
            transLen + 1,
            (index) => withStrobes
                ? LogicValue.ofInt(Test.random!.nextInt(1 << wIntfC.strbWidth),
                    wIntfC.strbWidth)
                : LogicValue.filled(wIntfC.strbWidth, LogicValue.one));
        lens.add(transLen);
        sizes.add(transSize);
        data.add(randomData);
        strobes.add(randomStrobes);

        final wrPkt = Axi4WriteRequestPacket(
          addr: LogicValue.ofInt(i, 32),
          prot: LogicValue.ofInt(0, wIntfC.protWidth), // not supported
          data: randomData,
          id: LogicValue.ofInt(i, wIntfC.idWidth),
          len: LogicValue.ofInt(transLen, wIntfC.lenWidth),
          size: LogicValue.ofInt(transSize, wIntfC.sizeWidth),
          burst: LogicValue.ofInt(
              Axi4BurstField.incr.value, wIntfC.burstWidth), // fixed for now
          lock: LogicValue.ofInt(0, 1), // not supported
          cache: LogicValue.ofInt(0, wIntfC.cacheWidth), // not supported
          qos: LogicValue.ofInt(0, wIntfC.qosWidth), // not supported
          region: LogicValue.ofInt(0, wIntfC.regionWidth), // not supported
          user: LogicValue.ofInt(0, wIntfC.awuserWidth), // not supported
          strobe: randomStrobes,
          wUser: LogicValue.ofInt(0, wIntfC.wuserWidth), // not supported
        );

        main.getWrSequencer(currW)!.add(wrPkt);
        numTransfersCompleted++;

        // Note that driver will already serialize the writes
        await sIntf.clk.waitCycles(mandatoryTransWaitPeriod);
        await sIntf.clk.waitCycles(interTxnDelay);
      }
    }

    // normal reads that check data
    if (hasAnyReads) {
      for (var i = 0; i < numTransfers; i++) {
        // pick a random read interface
        var foundRdChannel = false;
        var currR = 0;
        while (!foundRdChannel) {
          currR = Test.random!.nextInt(channels.length);
          foundRdChannel = channels[currR].hasRead;
        }
        final rIntfC = channels[currR].rIntf!;

        final rdPkt = Axi4ReadRequestPacket(
          addr: LogicValue.ofInt(i, 32),
          prot: LogicValue.ofInt(0, rIntfC.protWidth), // not supported
          id: LogicValue.ofInt(i, rIntfC.idWidth),
          len: LogicValue.ofInt(lens[i], rIntfC.lenWidth),
          size: LogicValue.ofInt(sizes[i], rIntfC.sizeWidth),
          burst: LogicValue.ofInt(
              Axi4BurstField.incr.value, rIntfC.burstWidth), // fixed for now
          lock: LogicValue.ofInt(0, 1), // not supported
          cache: LogicValue.ofInt(0, rIntfC.cacheWidth), // not supported
          qos: LogicValue.ofInt(0, rIntfC.qosWidth), // not supported
          region: LogicValue.ofInt(0, rIntfC.regionWidth), // not supported
          user: LogicValue.ofInt(0, rIntfC.aruserWidth), // not supported
        );

        main.getRdSequencer(currR)!.add(rdPkt);
        numTransfersCompleted++;

        // Note that driver will already serialize the reads
        await sIntf.clk.waitCycles(mandatoryTransWaitPeriod);
        await sIntf.clk.waitCycles(interTxnDelay);
      }
    }

    obj.drop();
  }

  Future<void> _resetFlow() async {
    await sIntf.clk.waitCycles(2);
    sIntf.resetN.inject(0);
    await sIntf.clk.waitCycles(3);
    sIntf.resetN.inject(1);
  }

  @override
  void check() {
    expect(numTransfersCompleted, numTransfers * 2);

    if (withErrors) {
      expect(storage.isEmpty, true);
    }
  }
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

  test('simple writes and reads', () async {
    await runTest(Axi4BfmTest('simple'));
  });

  test('writes with strobes', () async {
    await runTest(Axi4BfmTest('strobes', numTransfers: 20, withStrobes: true));
  });

  test('writes and reads with 1 cycle delays', () async {
    await runTest(Axi4BfmTest('delay1', interTxnDelay: 1));
  });

  test('writes and reads with 2 cycle delays', () async {
    await runTest(Axi4BfmTest('delay2', interTxnDelay: 2));
  });

  test('writes and reads with 3 cycle delays', () async {
    await runTest(Axi4BfmTest('delay3', interTxnDelay: 3));
  });

  test('writes and reads with big delays', () async {
    await runTest(Axi4BfmTest('delay5', interTxnDelay: 5));
  });

  test('random response delays', () async {
    await runTest(Axi4BfmTest(
      'randrsp',
      numTransfers: 20,
      withRandomRspDelays: true,
    ));
  });

  test('random everything', () async {
    await runTest(Axi4BfmTest(
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
    ));
  });

  test('with errors', () async {
    await runTest(Axi4BfmTest('werr', withErrors: true));
  });
}
