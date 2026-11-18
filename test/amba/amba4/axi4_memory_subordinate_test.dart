// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_memory_subordinate_test.dart
// Tests for captured AXI4 subordinate memory transactions.
//
// 2026 November
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

enum _Scenario {
  writeId,
  writeAddress,
  readAddress,
  writeDataTiming,
  simultaneousWriteData,
  writeDataBeforeAddress,
  writeDataSampling,
  queuedWrites,
}

class _ResponseMonitorTest extends Test {
  final sys = Axi4SystemInterface();
  final response = Axi4BChannelInterface(userWidth: 0);
  final captured = <LogicValue?>[];

  _ResponseMonitorTest() : super('responseMonitor', randomSeed: 123) {
    sys.clk <= SimpleClockGenerator(10).clk;
    sys.resetN.put(0);
    response.valid.put(0);
    response.ready.put(1);
    response.id!.put(0);
    Sequential(sys.clk, [
      If(~sys.resetN, then: [
        response.resp! < 0,
      ], orElse: [
        If(response.valid & response.ready, then: [response.resp! < 2]),
      ]),
    ]);
    Axi4ResponseChannelMonitor(sIntf: sys, rIntf: response, parent: this)
        .stream
        .listen((packet) => captured.add(packet.resp));
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    final objection = phase.raiseObjection('response handshake');
    await sys.clk.waitCycles(2);
    sys.resetN.inject(1);
    await sys.clk.nextNegedge;
    response.valid.inject(1);
    await sys.clk.nextPosedge;
    response.valid.inject(0);
    await sys.clk.waitCycles(2);
    objection.drop();
  }
}

class _MemoryTest extends Test {
  final _Scenario scenario;
  final sys = Axi4SystemInterface();
  final bus = Axi4Cluster(dataWidth: 32, userWidth: 0);
  final storage = SparseMemoryStorage(addrWidth: 32, dataWidth: 32);
  final requestIds = <int>[];
  final requestAddresses = <int>[];
  final responseIds = <int>[];
  final readData = <int>[];
  late final Axi4RequestChannelInterface request;

  _MemoryTest(this.scenario) : super(scenario.name, randomSeed: 123) {
    final isRead = scenario == _Scenario.readAddress;
    final earlyData = scenario == _Scenario.writeDataTiming;
    final sampledData = scenario == _Scenario.writeDataSampling;
    final queuedWrites = scenario == _Scenario.queuedWrites;
    request = isRead ? bus.read.arIntf : bus.write.awIntf;
    sys.clk <= SimpleClockGenerator(10).clk;
    sys.resetN.put(0);
    bus.read.arIntf.valid.put(0);
    bus.write.awIntf.valid.put(0);
    bus.read.rIntf.ready.put(1);
    bus.write.bIntf.ready.put(1);
    final w = bus.write.wIntf;
    if (!earlyData) {
      w.valid.put(0);
    }
    if (!sampledData) {
      w.data.put(0x12345678);
      w.strb.put(0xf);
    }
    w.last!.put(1);
    w.id?.put(0);
    for (final p in [
      request.prot,
      request.len,
      request.lock,
      request.cache,
      request.qos,
      request.region,
    ]) {
      p?.put(0);
    }
    request.size!.put(2);
    request.burst!.put(Axi4BurstField.incr.value);
    final id = request.id!;
    final address = request.addr;
    final handshake = request.valid & request.ready;
    Sequential(sys.clk, [
      If(~sys.resetN, then: [
        id < 0,
        address < 0,
        if (earlyData) w.valid < 0,
        if (sampledData) ...[
          w.data < 0x12345678,
          w.strb < 0x5,
        ],
      ], orElse: [
        if (scenario == _Scenario.writeId || queuedWrites)
          If(handshake, then: [id < id + 1]),
        if (scenario == _Scenario.writeAddress || isRead || queuedWrites)
          If(handshake, then: [address < address + 4]),
        if (sampledData)
          If(w.valid & w.ready, then: [
            w.data < 0xdeadbeef,
            w.strb < 0xa,
          ]),
        // WVALID rises after AW's edge, one edge before its own handshake.
        if (earlyData) w.valid < handshake,
      ]),
    ]);
    final lane = Axi4SubordinateClusterAgent(
      sIntf: sys,
      parent: this,
      arIntf: bus.read.arIntf,
      rIntf: bus.read.rIntf,
      awIntf: bus.write.awIntf,
      wIntf: w,
      bIntf: bus.write.bIntf,
    );
    final monitor = isRead
        ? lane.readAgent.reqAgent.monitor
        : lane.writeAgent.reqAgent.monitor;
    monitor.stream.listen((p) {
      requestIds.add(p.id!.toInt());
      requestAddresses.add(p.addr.toInt());
    });
    if (isRead) {
      Axi4DataChannelMonitor(sIntf: sys, rIntf: bus.read.rIntf, parent: this)
          .stream
          .listen((p) {
        responseIds.add(p.id!.toInt());
        readData.add(p.data.toInt());
      });
    } else {
      Axi4ResponseChannelMonitor(
              sIntf: sys, rIntf: bus.write.bIntf, parent: this)
          .stream
          .listen((p) => responseIds.add(p.id!.toInt()));
    }
    Axi4SubordinateMemoryAgent(
        sIntf: sys,
        lanes: [lane],
        storage: storage,
        parent: this,
        writeResponseDelay: queuedWrites ? (_) => 8 : null);
  }

  Future<void> sendWriteData() async {
    bus.write.wIntf.valid.inject(1);
    do {
      await sys.clk.nextPosedge;
    } while (!bus.write.wIntf.ready.previousValue!.toBool());
    bus.write.wIntf.valid.inject(0);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    final objection = phase.raiseObjection('one transaction');
    await sys.clk.waitCycles(2);
    sys.resetN.inject(1);
    storage
      ..writeData(LogicValue.ofInt(0, 32), LogicValue.ofInt(0x11111111, 32))
      ..writeData(LogicValue.ofInt(4, 32), LogicValue.ofInt(0x22222222, 32));
    if (scenario == _Scenario.queuedWrites) {
      for (var i = 0; i < 3; i++) {
        await sys.clk.nextNegedge;
        bus.write.wIntf.data.inject(0x100 + i);
        request.valid.inject(1);
        final dataSent = sendWriteData();
        do {
          await sys.clk.nextPosedge;
        } while (!request.ready.previousValue!.toBool());
        request.valid.inject(0);
        await dataSent;
      }
      await sys.clk.waitCycles(50);
      objection.drop();
      return;
    }
    await sys.clk.nextNegedge;
    if (scenario == _Scenario.writeDataBeforeAddress) {
      await sendWriteData();
      await sys.clk.waitCycles(2);
      expect(responseIds, isEmpty, reason: 'AW has not handshaken yet.');
      expect(storage.readData(LogicValue.ofInt(0, 32)),
          LogicValue.ofInt(0x11111111, 32));
      await sys.clk.nextNegedge;
    }
    request.valid.inject(1);
    if (scenario == _Scenario.simultaneousWriteData) {
      bus.write.wIntf.valid.inject(1);
    }
    do {
      await sys.clk.nextPosedge;
    } while (!request.ready.previousValue!.toBool());
    request.valid.inject(0);
    if (scenario == _Scenario.simultaneousWriteData) {
      bus.write.wIntf.valid.inject(0);
    }
    if (scenario == _Scenario.writeId ||
        scenario == _Scenario.writeAddress ||
        scenario == _Scenario.writeDataSampling) {
      await sys.clk.nextNegedge;
      await sendWriteData();
    }
    await sys.clk.waitCycles(10);
    objection.drop();
  }
}

void main() {
  tearDown(Test.reset);

  test('response monitor captures BRESP before it changes at the edge',
      () async {
    Simulator.setMaxSimTime(300);
    final tb = _ResponseMonitorTest();
    await tb.start();
    expect(tb.captured, [LogicValue.ofInt(0, 2)]);
    expect(tb.response.resp!.value, LogicValue.ofInt(2, 2));
  });

  Future<_MemoryTest> run(_Scenario scenario) async {
    Simulator.setMaxSimTime(1000);
    final tb = _MemoryTest(scenario);
    await tb.start();
    expect(tb.requestIds, [0], reason: 'One request with captured ID 0.');
    expect(tb.requestAddresses, [0], reason: 'One request at address 0.');
    return tb;
  }

  test('write response preserves captured AWID', () async {
    final tb = await run(_Scenario.writeId);
    expect(tb.responseIds, [0],
        reason: 'Live AWID advanced to 1 after the edge.');
  });

  test('write destination preserves captured AWADDR', () async {
    final tb = await run(_Scenario.writeAddress);
    expect(tb.storage.readData(LogicValue.ofInt(0, 32)),
        LogicValue.ofInt(0x12345678, 32));
    expect(tb.storage.readData(LogicValue.ofInt(4, 32)),
        LogicValue.ofInt(0x22222222, 32));
    expect(tb.responseIds, [0]);
  });

  test('read data uses captured ARADDR', () async {
    final tb = await run(_Scenario.readAddress);
    expect(tb.responseIds, [0]);
    expect(tb.readData, [0x11111111],
        reason: 'Live ARADDR advanced to 4, whose data is 0x22222222.');
  });

  test('write data and strobes preserve handshake values', () async {
    final tb = await run(_Scenario.writeDataSampling);
    expect(tb.responseIds, [0]);
    expect(tb.storage.readData(LogicValue.ofInt(0, 32)),
        LogicValue.ofInt(0x11341178, 32),
        reason: 'Only bytes selected by the captured strobe 0x5 are written.');
  });

  test('delayed writes preserve each queued data burst', () async {
    Simulator.setMaxSimTime(1000);
    final tb = _MemoryTest(_Scenario.queuedWrites);
    await tb.start();
    expect(tb.requestIds, [0, 1, 2]);
    expect(tb.requestAddresses, [0, 4, 8]);
    expect(tb.responseIds, [0, 1, 2]);
    for (var i = 0; i < 3; i++) {
      expect(tb.storage.readData(LogicValue.ofInt(i * 4, 32)),
          LogicValue.ofInt(0x100 + i, 32));
    }
  });

  for (final scenario in [
    _Scenario.writeDataTiming,
    _Scenario.simultaneousWriteData,
    _Scenario.writeDataBeforeAddress,
  ]) {
    test('write data is captured exactly once: ${scenario.name}', () async {
      final tb = await run(scenario);
      expect(tb.responseIds, [0],
          reason: 'One write must produce one response.');
      expect(tb.storage.readData(LogicValue.ofInt(0, 32)),
          LogicValue.ofInt(0x12345678, 32));
    });
  }
}
