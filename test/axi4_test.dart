// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi_test.dart
// Tests for the AXI4 interface.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class Axi4Subordinate extends Module {
  Axi4Subordinate(Axi4SystemInterface sIntf, List<Axi4BaseCluster> lanes) {
    sIntf = Axi4SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Axi4BaseCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      if (lanes[i] is Axi4Cluster) {
        lanesL.add((lanes[i] as Axi4Cluster).clone()
          ..pairConnectIO(this, lanes[i], PairRole.consumer));
      } else if (lanes[i] is Axi4LiteCluster) {
        lanesL.add((lanes[i] as Axi4LiteCluster).clone()
          ..pairConnectIO(this, lanes[i], PairRole.consumer));
      } else if (lanes[i] is Ace4LiteCluster) {
        lanesL.add((lanes[i] as Ace4LiteCluster).clone()
          ..pairConnectIO(this, lanes[i], PairRole.consumer));
      } else {
        // lanesL.add((lanes[i] as Ace4Cluster).clone()
        //   ..pairConnectIO(this, lanes[i], PairRole.consumer));
      }
    }
  }
}

class Axi4Main extends Module {
  Axi4Main(Axi4SystemInterface sIntf, List<Axi4BaseCluster> lanes) {
    sIntf = Axi4SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Axi4BaseCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      if (lanes[i] is Axi4Cluster) {
        lanesL.add((lanes[i] as Axi4Cluster).clone()
          ..pairConnectIO(this, lanes[i], PairRole.provider));
      } else if (lanes[i] is Axi4LiteCluster) {
        lanesL.add((lanes[i] as Axi4LiteCluster).clone()
          ..pairConnectIO(this, lanes[i], PairRole.provider));
      } else if (lanes[i] is Ace4LiteCluster) {
        lanesL.add((lanes[i] as Ace4LiteCluster).clone()
          ..pairConnectIO(this, lanes[i], PairRole.provider));
      } else {
        // lanesL.add((lanes[i] as Ace4Cluster).clone()
        //   ..pairConnectIO(this, lanes[i], PairRole.provider));
      }
    }
  }
}

class Axi4Pair extends Module {
  Axi4Pair(
    Logic clk,
    Logic reset, {
    int numLanes = 1,
    Type axiType = Axi4Cluster,
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final sIntf = Axi4SystemInterface();
    sIntf.clk <= clk;
    sIntf.resetN <= ~reset;

    final lanes = <Axi4BaseCluster>[];
    for (var i = 0; i < numLanes; i++) {
      if (axiType == Axi4Cluster) {
        lanes.add(Axi4Cluster());
      } else if (axiType == Axi4LiteCluster) {
        lanes.add(Axi4LiteCluster());
      } else if (axiType == Ace4LiteCluster) {
        lanes.add(Ace4LiteCluster());
      } else {
        // lanes.add(Ace4Cluster());
      }
    }

    Axi4Main(sIntf, lanes);
    Axi4Subordinate(sIntf, lanes);
  }
}

void main() {
  test('connect axi4 modules', () async {
    final axi4Pair = Axi4Pair(Logic(), Logic());
    await axi4Pair.build();
  });

  test('connect axi4-lite modules', () async {
    final axi4Pair = Axi4Pair(Logic(), Logic(), axiType: Axi4LiteCluster);
    await axi4Pair.build();
  });

  test('connect ace4-lite modules', () async {
    final axi4Pair = Axi4Pair(Logic(), Logic(), axiType: Ace4LiteCluster);
    await axi4Pair.build();
  });
}
