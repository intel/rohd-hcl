// Copyright (C) 2024-2026 Intel Corporation
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
    sIntf = addPairInterfacePorts(sIntf, PairRole.consumer);

    final lanesL = <Axi4BaseCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      if (lanes[i] is Axi4Cluster) {
        lanesL.add(addPairInterfacePorts(
            lanes[i] as Axi4Cluster, PairRole.consumer,
            uniquify: (original) => '$original$i'));
      } else if (lanes[i] is Axi4LiteCluster) {
        lanesL.add(addPairInterfacePorts(
            lanes[i] as Axi4LiteCluster, PairRole.consumer,
            uniquify: (original) => '$original$i'));
      } else if (lanes[i] is Ace4LiteCluster) {
        lanesL.add(addPairInterfacePorts(
            lanes[i] as Ace4LiteCluster, PairRole.consumer,
            uniquify: (original) => '$original$i'));
      } else {
        // lanesL.add(
        //     addPairInterfacePorts(
        //         lanes[i] as Ace4Cluster, PairRole.consumer));
      }
    }
  }
}

class Axi4Main extends Module {
  Axi4Main(Axi4SystemInterface sIntf, List<Axi4BaseCluster> lanes) {
    sIntf = addPairInterfacePorts(sIntf, PairRole.consumer);

    final lanesL = <Axi4BaseCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      if (lanes[i] is Axi4Cluster) {
        lanesL.add(addPairInterfacePorts(
            lanes[i] as Axi4Cluster, PairRole.provider,
            uniquify: (original) => '$original$i'));
      } else if (lanes[i] is Axi4LiteCluster) {
        lanesL.add(addPairInterfacePorts(
            lanes[i] as Axi4LiteCluster, PairRole.provider,
            uniquify: (original) => '$original$i'));
      } else if (lanes[i] is Ace4LiteCluster) {
        lanesL.add(addPairInterfacePorts(
            lanes[i] as Ace4LiteCluster, PairRole.provider,
            uniquify: (original) => '$original$i'));
      } else {
        // lanesL.add(
        //     addPairInterfacePorts(
        //         lanes[i] as Ace4Cluster, PairRole.provider));
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

class _Ace4PortModule extends Module {
  _Ace4PortModule(Ace4Cluster ace, PairRole role) {
    addPairInterfacePorts(ace, role);
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

  test('ACE4 defaults retain the historical port layout', () {
    final ace = Ace4Cluster();
    expect(ace.rack, isNull);
    expect(ace.read.rIntf.resp!.width, 2);
    expect(ace.write.wIntf.id, isNotNull);
    expect(ace.snoop.acIntf.id, isNotNull);
    expect(ace.snoop.acIntf.tryPort('ACSIZE'), isNotNull);
    expect(ace.snoop.cdIntf.user, isNotNull);
    expect(ace.snoop.crIntf.resp!.width, 2);
    expect(ace.snoop.crIntf.last, isNotNull);
    expect(ace.clone().snoop.crIntf.last, isNotNull);
  });

  test('ACE4 signal mode preserves ports, directions and widths in clones', () {
    final ace = Ace4Cluster(
      legacyMode: false,
      readIdWidth: 3,
      writeIdWidth: 5,
      dataWidth: 128,
      snoopDataWidth: 64,
      arUserWidth: 1,
      rUserWidth: 2,
      awUserWidth: 3,
      wUserWidth: 4,
      bUserWidth: 5,
    );
    final clone = ace.clone();
    final channels = [
      ace.read.arIntf,
      ace.read.rIntf,
      ace.write.awIntf,
      ace.write.wIntf,
      ace.write.bIntf,
      ace.snoop.acIntf,
      ace.snoop.cdIntf,
      ace.snoop.crIntf,
    ];
    final clonedChannels = [
      clone.read.arIntf,
      clone.read.rIntf,
      clone.write.awIntf,
      clone.write.wIntf,
      clone.write.bIntf,
      clone.snoop.acIntf,
      clone.snoop.cdIntf,
      clone.snoop.crIntf,
    ];
    for (var i = 0; i < channels.length; i++) {
      for (final tag in PairDirection.values) {
        expect(
          clonedChannels[i]
              .getPorts([tag]).map((name, port) => MapEntry(name, port.width)),
          channels[i]
              .getPorts([tag]).map((name, port) => MapEntry(name, port.width)),
        );
      }
    }

    expect(ace.read.arIntf.id!.width, 3);
    expect(ace.read.rIntf.id!.width, 3);
    expect(ace.write.awIntf.id!.width, 5);
    expect(ace.write.bIntf.id!.width, 5);
    expect(channels.take(5).map((channel) => channel.user!.width),
        [1, 2, 3, 4, 5]);
    expect(ace.read.arIntf.ports.keys.toSet(), {
      'ARID',
      'ARUSER',
      'ARVALID',
      'ARREADY',
      'ARADDR',
      'ARLEN',
      'ARSIZE',
      'ARBURST',
      'ARCACHE',
      'ARPROT',
      'ARQOS',
      'ARREGION',
      'ARDOMAIN',
      'ARBAR',
      'ARSNOOP'
    });
    expect(ace.write.awIntf.ports.keys.toSet(), {
      'AWID',
      'AWUSER',
      'AWVALID',
      'AWREADY',
      'AWADDR',
      'AWLEN',
      'AWSIZE',
      'AWBURST',
      'AWCACHE',
      'AWPROT',
      'AWQOS',
      'AWREGION',
      'AWDOMAIN',
      'AWBAR',
      'AWSNOOP',
      'AWUNIQUE'
    });
    expect(ace.read.rIntf.ports.keys.toSet(),
        {'RID', 'RUSER', 'RVALID', 'RREADY', 'RDATA', 'RLAST', 'RRESP'});
    expect(ace.write.wIntf.ports.keys.toSet(),
        {'WUSER', 'WVALID', 'WREADY', 'WDATA', 'WLAST', 'WSTRB'});
    expect(ace.write.bIntf.ports.keys.toSet(),
        {'BID', 'BUSER', 'BVALID', 'BREADY', 'BRESP'});
    expect(ace.write.wIntf.id, isNull);
    expect(ace.read.arIntf.port('ARDOMAIN').width, 2);
    expect(ace.read.arIntf.port('ARBAR').width, 2);
    expect(ace.read.arIntf.port('ARSNOOP').width, 4);
    expect(ace.write.awIntf.port('AWSNOOP').width, 3);
    expect(ace.write.awIntf.port('AWUNIQUE').width, 1);
    expect(ace.read.rIntf.resp!.width, 4);
    expect(ace.snoop.acIntf.ports.keys.toSet(),
        {'ACVALID', 'ACREADY', 'ACADDR', 'ACPROT', 'ACSNOOP'});
    expect(ace.snoop.cdIntf.ports.keys.toSet(),
        {'CDVALID', 'CDREADY', 'CDDATA', 'CDLAST'});
    expect(
        ace.snoop.crIntf.ports.keys.toSet(), {'CRVALID', 'CRREADY', 'CRRESP'});
    expect(ace.snoop.cdIntf.data.width, 64);
    expect(ace.snoop.crIntf.resp!.width, 5);
    expect(ace.snoop.acIntf.getPorts([PairDirection.fromConsumer]).keys,
        containsAll(['ACVALID', 'ACADDR', 'ACPROT', 'ACSNOOP']));
    expect(ace.snoop.cdIntf.getPorts([PairDirection.fromProvider]).keys,
        containsAll(['CDVALID', 'CDDATA', 'CDLAST']));
    expect(ace.snoop.crIntf.getPorts([PairDirection.fromProvider]).keys,
        containsAll(['CRVALID', 'CRRESP']));
    expect(ace.getPorts([PairDirection.fromProvider]).keys,
        containsAll(['RACK', 'WACK']));
    expect(clone.rack, isNotNull);
    expect(clone.wack, isNotNull);
  });

  test('ACE4 signal mode rejects incompatible channel parameters', () {
    expect(() => Ace4ArChannelInterface(legacyMode: false, domainWidth: 1),
        throwsA(isA<RohdHclException>()));
    expect(() => Ace4ArChannelInterface(legacyMode: false, lenWidth: 4),
        throwsA(isA<RohdHclException>()));
    expect(() => Ace4WChannelInterface(legacyMode: false, idWidth: 4),
        throwsA(isA<RohdHclException>()));
    expect(() => Ace4CrChannelInterface(legacyMode: false, respWidth: 2),
        throwsA(isA<RohdHclException>()));
    expect(() => Ace4CdChannelInterface(legacyMode: false, dataWidth: 16),
        throwsA(isA<RohdHclException>()));
    expect(() => Ace4Cluster(legacyMode: false, bUserWidth: -1),
        throwsA(isA<RohdHclException>()));
    expect(() => Ace4SnoopCluster(legacyMode: false, idWidth: 4),
        throwsA(isA<RohdHclException>()));
  });

  test('ACE4 clusters expose snoop signals in manager directions', () async {
    final module =
        _Ace4PortModule(Ace4Cluster(legacyMode: false), PairRole.provider);
    await module.build();
    expect(module.inputs.keys, containsAll(['ACVALID', 'ACADDR', 'ACSNOOP']));
    expect(
        module.outputs.keys,
        containsAll(
            ['ACREADY', 'CRVALID', 'CRRESP', 'CDVALID', 'RACK', 'WACK']));
  });

  test('legacy ACE4 clones retain independently configured widths', () {
    final ace = Ace4Cluster(
      idWidth: 7,
      readIdWidth: 2,
      writeIdWidth: 3,
      userWidth: 9,
      arUserWidth: 1,
      awUserWidth: 2,
      snoopDataWidth: 128,
    ).clone();
    expect(ace.snoop.acIntf.idWidth, 7);
    expect(ace.snoop.acIntf.userWidth, 9);
    expect(ace.snoop.cdIntf.dataWidth, 128);
    expect(ace.read.arIntf.idWidth, 2);
    expect(ace.write.awIntf.idWidth, 3);
    expect(ace.read.arIntf.userWidth, 1);
    expect(ace.write.awIntf.userWidth, 2);
  });
}
