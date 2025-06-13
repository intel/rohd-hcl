// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_test.dart
// Tests for ready_valid building blocks.
//
// 2024 February 29
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class ConnectTwoRVStages extends Module {
  ConnectTwoRVStages(Logic clk, Logic reset, ReadyValidInterface upstream,
      ReadyAndValidInterface downstream,
      {super.name = 'ConnectTwoRVStages'}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    upstream = ReadyAndValidInterface(
      modify: (original) => 'up_$original',
    )..pairConnectIO(this, upstream, PairRole.consumer);
    downstream = ReadyAndValidInterface(
      modify: (original) => 'dn_$original',
    )..pairConnectIO(this, downstream, PairRole.provider);

    final midl = ReadyAndValidInterface();
    final midr = ReadyAndValidInterface();
    // ReadyValidConnector these to connect them!
    ReadyValidConnector(clk, reset, List.generate(1, (index) => midl),
        List.generate(1, (index) => midr));
    ReadyAndValidStage(clk, reset, upstream, midl);
    ReadyAndValidStage(clk, reset, midr, downstream);
  }
}

class ConnectThreeRVStages extends Module {
  ConnectThreeRVStages(Logic clk, Logic reset, ReadyValidInterface upstream,
      ReadyAndValidInterface downstream,
      {super.name = 'ConnectThreeRVStages'}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    upstream = ReadyAndValidInterface(
      modify: (original) => 'up_$original',
    )..pairConnectIO(this, upstream, PairRole.consumer);
    downstream = ReadyAndValidInterface(
      modify: (original) => 'dn_$original',
    )..pairConnectIO(this, downstream, PairRole.provider);

    final midl = ReadyAndValidInterface();
    final midr = ReadyAndValidInterface();
    ReadyAndValidStage(clk, reset, upstream, midl);
    ReadyAndValidStage(clk, reset, midl, midr);
    ReadyAndValidStage(clk, reset, midr, downstream);
  }
}

class ConnectFanOutRVStages extends Module {
  ConnectFanOutRVStages(Logic clk, Logic reset, ReadyValidInterface upstream,
      List<ReadyAndValidInterface> downstreams,
      {super.name = 'ConnectFanOutRVStages'}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    upstream = ReadyAndValidInterface(
      modify: (original) => 'up_$original',
    )..pairConnectIO(this, upstream, PairRole.consumer);
    downstreams = [
      for (var i = 0; i < downstreams.length; i++)
        ReadyAndValidInterface(
          modify: (original) => 'dn_${i}_$original',
        )..pairConnectIO(this, downstreams[i], PairRole.provider),
    ];

    final midl = List.generate(1, (index) => ReadyAndValidInterface());
    final midr = List.generate(2, (index) => ReadyAndValidInterface());
    ReadyAndValidStage(clk, reset, upstream, midl[0]);
    ReadyValidConnector(clk, reset, midl, midr);
    ReadyAndValidStage(clk, reset, midr[0], downstreams[0]);
    ReadyAndValidStage(clk, reset, midr[1], downstreams[1]);
  }
}

class ConnectFanInRVStages extends Module {
  ConnectFanInRVStages(Logic clk, Logic reset,
      List<ReadyAndValidInterface> upstreams, ReadyValidInterface downstream,
      {super.name = 'ConnectFanInRVStages'}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    upstreams = [
      for (var i = 0; i < upstreams.length; i++)
        ReadyAndValidInterface(
          modify: (original) => 'up_${i}_$original',
        )..pairConnectIO(this, upstreams[i], PairRole.consumer),
    ];
    downstream = ReadyAndValidInterface(
      modify: (original) => 'dn_$original',
    )..pairConnectIO(this, downstream, PairRole.provider);

    final midl = List.generate(2, (index) => ReadyAndValidInterface());
    final midr = List.generate(1, (index) => ReadyAndValidInterface());

    ReadyAndValidStage(clk, reset, upstreams[0], midl[0]);
    ReadyAndValidStage(clk, reset, upstreams[1], midl[1]);
    ReadyValidConnector(clk, reset, midl, midr);
    ReadyAndValidStage(clk, reset, midr[0], downstream);
  }
}

Future<void> main() async {
  tearDown(() async {
    await Simulator.reset();
  });

  test('RV fanin', () async {
    final clk = SimpleClockGenerator(10).clk;

    final reset = Logic();
    final dn = ReadyAndValidInterface();
    final up = List.generate(2, (index) => ReadyAndValidInterface());
    final mod = ConnectFanInRVStages(clk, reset, up, dn);
    await mod.build();

    // WaveDumper(mod);

    up[0].valid.inject(0);
    up[1].valid.inject(0);
    dn.ready.inject(0);
    reset.inject(1);

    Simulator.setMaxSimTime(500);
    unawaited(Simulator.run());

    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);
    await clk.nextNegedge;
    await clk.nextNegedge;
    up[0].data.inject(1);
    var data = 2;
    up[0].valid.inject(1);
    clk.posedge.listen((event) {
      if (up[0].ready.previousValue!.isValid &&
          up[0].ready.previousValue!.toBool() &&
          up[0].valid.previousValue!.toBool()) {
        up[0].data.inject(data++);
      }
    });

    up[1].data.inject(101);
    var data2 = 102;
    up[1].valid.inject(101);
    clk.posedge.listen((event) {
      if (up[1].ready.previousValue!.isValid &&
          up[1].ready.previousValue!.toBool() &&
          up[1].valid.previousValue!.toBool()) {
        up[1].data.inject(data2++);
      }
    });

    // Real start
    await clk.waitCycles(2);
    up[0].valid.inject(1);
    up[1].valid.inject(1);

    await clk.waitCycles(10);
    await clk.nextNegedge;
    dn.ready.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    up[0].valid.inject(0);
    up[1].valid.inject(0);

    await clk.waitCycles(5);
    await clk.nextNegedge;
    up[0].valid.inject(0);
    up[1].valid.inject(0);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    up[0].valid.inject(1);
    up[1].valid.inject(1);
    await clk.waitCycles(3);
    await clk.nextNegedge;
    dn.ready.inject(0);
    await clk.waitCycles(2);
    await clk.nextNegedge;
    up[0].valid.inject(0);
    up[1].valid.inject(0);
    dn.ready.inject(1);
    await clk.waitCycles(5);
    expect(dn.data.value.toInt(), 5);
    await Simulator.endSimulation();
  });

  test('RV fanout', () async {
    final clk = SimpleClockGenerator(10).clk;

    final reset = Logic();
    final up = ReadyAndValidInterface();
    final dn = List.generate(2, (index) => ReadyAndValidInterface());
    final mod = ConnectFanOutRVStages(clk, reset, up, dn);
    await mod.build();

    // WaveDumper(mod);

    up.valid.inject(0);
    dn[0].ready.inject(0);
    dn[1].ready.inject(0);
    reset.inject(1);

    Simulator.setMaxSimTime(500);
    unawaited(Simulator.run());

    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);
    await clk.nextNegedge;
    await clk.nextNegedge;
    up.data.inject(1);
    var data = 2;
    up.valid.inject(1);
    clk.posedge.listen((event) {
      if (up.ready.previousValue!.isValid &&
          up.ready.previousValue!.toBool() &&
          up.valid.previousValue!.toBool()) {
        up.data.inject(data++);
      }
    });

    // Real start
    await clk.waitCycles(2);
    up.valid.inject(1);

    await clk.waitCycles(10);
    await clk.nextNegedge;
    dn[0].ready.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    up.valid.inject(0);

    await clk.waitCycles(5);
    await clk.nextNegedge;
    up.valid.inject(0);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    up.valid.inject(1);
    await clk.waitCycles(3);
    await clk.nextNegedge;
    dn[0].ready.inject(0);
    await clk.waitCycles(2);
    await clk.nextNegedge;
    dn[0].ready.inject(1);
    dn[1].ready.inject(1);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    up.valid.inject(0);

    await clk.waitCycles(5);
    expect(dn[0].data.value.toInt(), 13);
    expect(dn[1].data.value.toInt(), 12);
    await Simulator.endSimulation();
  });

  test('RV first bubble', () async {
    final clk = SimpleClockGenerator(10).clk;

    final reset = Logic();
    final up = ReadyAndValidInterface();
    final dn = ReadyAndValidInterface();
    final mod = ConnectTwoRVStages(clk, reset, up, dn);
    await mod.build();

    // WaveDumper(mod);

    up.valid.inject(0);
    dn.ready.inject(0);
    reset.inject(1);

    Simulator.setMaxSimTime(500);
    unawaited(Simulator.run());

    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);
    await clk.nextNegedge;
    await clk.nextNegedge;
    up.data.inject(1);
    var data = 2;
    up.valid.inject(1);
    clk.posedge.listen((event) {
      if (up.ready.previousValue!.isValid &&
          up.ready.previousValue!.toBool() &&
          up.valid.previousValue!.toBool()) {
        up.data.inject(data++);
      }
    });

    // Real start
    await clk.waitCycles(2);
    up.valid.inject(1);

    await clk.waitCycles(3);
    await clk.nextNegedge;
    dn.ready.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    up.valid.inject(0);

    await clk.waitCycles(5);
    await clk.nextNegedge;
    up.valid.inject(0);
    await clk.waitCycles(5);
    await clk.nextNegedge;
    up.valid.inject(1);
    await clk.waitCycles(3);
    await clk.nextNegedge;
    dn.ready.inject(0);
    await clk.waitCycles(2);
    await clk.nextNegedge;
    up.valid.inject(0);
    dn.ready.inject(1);
    await clk.waitCycles(5);
    expect(dn.data.value.toInt(), 7);
    await Simulator.endSimulation();
  });
}
