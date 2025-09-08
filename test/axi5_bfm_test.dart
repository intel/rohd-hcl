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

// TODO: create a test that simply instantiates the two BFMs and lets them go...
