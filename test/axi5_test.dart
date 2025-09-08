// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi5_test.dart
// Tests for the AXI5 interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class Axi5Subordinate extends Module {
  Axi5Subordinate(Axi5SystemInterface sIntf, List<Axi5Cluster> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Axi5Cluster>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.consumer));
    }
  }
}

class Axi5Main extends Module {
  Axi5Main(Axi5SystemInterface sIntf, List<Axi5Cluster> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Axi5Cluster>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.provider));
    }
  }
}

class Axi5Pair extends Module {
  Axi5Pair(
    Logic clk,
    Logic reset, {
    int numLanes = 1,
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final sIntf = Axi5SystemInterface();
    sIntf.clk <= clk;
    sIntf.resetN <= ~reset;

    final lanes = <Axi5Cluster>[];
    for (var i = 0; i < numLanes; i++) {
      final ar = Axi5ArChannelInterface(config: Axi5ArChannelConfig());
      final r = Axi5RChannelInterface(config: Axi5RChannelConfig());
      final aw = Axi5AwChannelInterface(config: Axi5AwChannelConfig());
      final w = Axi5WChannelInterface(config: Axi5WChannelConfig());
      final b = Axi5BChannelInterface(config: Axi5BChannelConfig());
      final ac = Axi5AcChannelInterface();
      final cr = Axi5CrChannelInterface();

      lanes.add(Axi5Cluster(
          read: Axi5ReadCluster(ar: ar, r: r),
          write: Axi5WriteCluster(aw: aw, w: w, b: b),
          snoop: Axi5SnoopCluster(ac: ac, cr: cr)));
    }

    Axi5Main(sIntf, lanes);
    Axi5Subordinate(sIntf, lanes);
  }
}

class Axi5LiteSubordinate extends Module {
  Axi5LiteSubordinate(Axi5SystemInterface sIntf, List<Axi5LiteCluster> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Axi5LiteCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.consumer));
    }
  }
}

class Axi5LiteMain extends Module {
  Axi5LiteMain(Axi5SystemInterface sIntf, List<Axi5LiteCluster> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Axi5LiteCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.provider));
    }
  }
}

class Axi5LitePair extends Module {
  Axi5LitePair(
    Logic clk,
    Logic reset, {
    int numLanes = 1,
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final sIntf = Axi5SystemInterface();
    sIntf.clk <= clk;
    sIntf.resetN <= ~reset;

    final lanes = <Axi5LiteCluster>[];
    for (var i = 0; i < numLanes; i++) {
      final ar = Axi5LiteArChannelInterface(config: Axi5LiteArChannelConfig());
      final r = Axi5LiteRChannelInterface(config: Axi5LiteRChannelConfig());
      final aw = Axi5LiteAwChannelInterface(config: Axi5LiteAwChannelConfig());
      final w = Axi5LiteWChannelInterface(config: Axi5LiteWChannelConfig());
      final b = Axi5LiteBChannelInterface(config: Axi5LiteBChannelConfig());

      lanes.add(Axi5LiteCluster(
        read: Axi5LiteReadCluster(ar: ar, r: r),
        write: Axi5LiteWriteCluster(aw: aw, w: w, b: b),
      ));
    }

    Axi5LiteMain(sIntf, lanes);
    Axi5LiteSubordinate(sIntf, lanes);
  }
}

class Ace5LiteSubordinate extends Module {
  Ace5LiteSubordinate(Axi5SystemInterface sIntf, List<Ace5LiteCluster> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Ace5LiteCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.consumer));
    }
  }
}

class Ace5LiteMain extends Module {
  Ace5LiteMain(Axi5SystemInterface sIntf, List<Ace5LiteCluster> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Ace5LiteCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.provider));
    }
  }
}

class Ace5LitePair extends Module {
  Ace5LitePair(
    Logic clk,
    Logic reset, {
    int numLanes = 1,
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final sIntf = Axi5SystemInterface();
    sIntf.clk <= clk;
    sIntf.resetN <= ~reset;

    final lanes = <Ace5LiteCluster>[];
    for (var i = 0; i < numLanes; i++) {
      final ar = Ace5LiteArChannelInterface(config: Ace5LiteArChannelConfig());
      final r = Ace5LiteRChannelInterface(config: Ace5LiteRChannelConfig());
      final aw = Ace5LiteAwChannelInterface(config: Ace5LiteAwChannelConfig());
      final w = Ace5LiteWChannelInterface(config: Ace5LiteWChannelConfig());
      final b = Ace5LiteBChannelInterface(config: Ace5LiteBChannelConfig());

      lanes.add(Ace5LiteCluster(
        read: Ace5LiteReadCluster(ar: ar, r: r),
        write: Ace5LiteWriteCluster(aw: aw, w: w, b: b),
      ));
    }

    Ace5LiteMain(sIntf, lanes);
    Ace5LiteSubordinate(sIntf, lanes);
  }
}

class Axi5StreamSubordinate extends Module {
  Axi5StreamSubordinate(
      Axi5SystemInterface sIntf, List<Axi5StreamInterface> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Axi5StreamInterface>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.consumer));
    }
  }
}

class Axi5StreamMain extends Module {
  Axi5StreamMain(Axi5SystemInterface sIntf, List<Axi5StreamInterface> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <Axi5StreamInterface>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.provider));
    }
  }
}

class Axi5StreamPair extends Module {
  Axi5StreamPair(
    Logic clk,
    Logic reset, {
    int numLanes = 1,
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final sIntf = Axi5SystemInterface();
    sIntf.clk <= clk;
    sIntf.resetN <= ~reset;

    final lanes = <Axi5StreamInterface>[];
    for (var i = 0; i < numLanes; i++) {
      lanes.add(Axi5StreamInterface());
    }

    Axi5StreamMain(sIntf, lanes);
    Axi5StreamSubordinate(sIntf, lanes);
  }
}

void main() {
  test('connect axi5 modules', () async {
    final axi5Pair = Axi5Pair(Logic(), Logic());
    await axi5Pair.build();
  });

  test('connect axi5-lite modules', () async {
    final axi5Pair = Axi5LitePair(Logic(), Logic());
    await axi5Pair.build();
  });

  test('connect ace5-lite modules', () async {
    final axi5Pair = Axi5Pair(Logic(), Logic());
    await axi5Pair.build();
  });

  test('connect axi5-s modules', () async {
    final axi5Pair = Axi5StreamPair(Logic(), Logic());
    await axi5Pair.build();
  });
}
