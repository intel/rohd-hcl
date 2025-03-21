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

import 'axi4_bfm_test.dart';

class Axi4Subordinate extends Module {
  Axi4Subordinate(Axi4SystemInterface sIntf, List<Axi4Channel> channels) {
    sIntf = Axi4SystemInterface()
      ..connectIO(this, sIntf, inputTags: {Axi4Direction.misc});

    final channelsL = <Axi4Channel>[];
    for (var i = 0; i < channels.length; i++) {
      channelsL.add(Axi4Channel(
          channelId: channels[i].channelId,
          rIntf: channels[i].hasRead
              ? (Axi4ReadInterface.clone(channels[i].rIntf!)
                ..connectIO(this, channels[i].rIntf!,
                    inputTags: {Axi4Direction.fromMain},
                    outputTags: {Axi4Direction.fromSubordinate}))
              : null,
          wIntf: channels[i].hasWrite
              ? (Axi4WriteInterface.clone(channels[i].wIntf!)
                ..connectIO(this, channels[i].wIntf!,
                    inputTags: {Axi4Direction.fromMain},
                    outputTags: {Axi4Direction.fromSubordinate}))
              : null));
    }
  }
}

class Axi4Main extends Module {
  Axi4Main(Axi4SystemInterface sIntf, List<Axi4Channel> channels) {
    sIntf = Axi4SystemInterface()
      ..connectIO(this, sIntf, inputTags: {Axi4Direction.misc});

    final channelsL = <Axi4Channel>[];
    for (var i = 0; i < channels.length; i++) {
      channelsL.add(Axi4Channel(
          channelId: channels[i].channelId,
          rIntf: channels[i].hasRead
              ? (Axi4ReadInterface.clone(channels[i].rIntf!)
                ..connectIO(this, channels[i].rIntf!,
                    inputTags: {Axi4Direction.fromSubordinate},
                    outputTags: {Axi4Direction.fromMain}))
              : null,
          wIntf: channels[i].hasWrite
              ? (Axi4WriteInterface.clone(channels[i].wIntf!)
                ..connectIO(this, channels[i].wIntf!,
                    inputTags: {Axi4Direction.fromSubordinate},
                    outputTags: {Axi4Direction.fromMain}))
              : null));
    }
  }
}

class Axi4Pair extends Module {
  Axi4Pair(Logic clk, Logic reset,
      {int numChannels = 1,
      List<Axi4BfmTestChannelConfig> channelConfigs = const [
        Axi4BfmTestChannelConfig.readWrite
      ]}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final sIntf = Axi4SystemInterface();
    sIntf.clk <= clk;
    sIntf.resetN <= ~reset;

    final channels = <Axi4Channel>[];
    for (var i = 0; i < numChannels; i++) {
      final hasRead = channelConfigs[i] == Axi4BfmTestChannelConfig.read ||
          channelConfigs[i] == Axi4BfmTestChannelConfig.readWrite;
      final hasWrite = channelConfigs[i] == Axi4BfmTestChannelConfig.write ||
          channelConfigs[i] == Axi4BfmTestChannelConfig.readWrite;
      channels.add(Axi4Channel(
          channelId: i,
          rIntf: hasRead ? Axi4ReadInterface() : null,
          wIntf: hasWrite ? Axi4WriteInterface() : null));
    }

    Axi4Main(sIntf, channels);
    Axi4Subordinate(sIntf, channels);
  }
}

void main() {
  test('connect axi4 modules', () async {
    final axi4Pair = Axi4Pair(Logic(), Logic());
    await axi4Pair.build();
  });

  test('axi4 optional ports null', () async {
    final rIntf = Axi4ReadInterface(
        idWidth: 0,
        lenWidth: 0,
        aruserWidth: 0,
        ruserWidth: 0,
        useLast: false,
        useLock: false);
    expect(rIntf.arId, isNull);
    expect(rIntf.arLen, isNull);
    expect(rIntf.arLock, isNull);
    expect(rIntf.arUser, isNull);
    expect(rIntf.rId, isNull);
    expect(rIntf.rLast, isNull);
    expect(rIntf.rUser, isNull);

    final wIntf = Axi4WriteInterface(
        idWidth: 0,
        lenWidth: 0,
        awuserWidth: 0,
        wuserWidth: 0,
        buserWidth: 0,
        useLock: false);
    expect(wIntf.awId, isNull);
    expect(wIntf.awLen, isNull);
    expect(wIntf.awLock, isNull);
    expect(wIntf.awUser, isNull);
    expect(wIntf.wUser, isNull);
    expect(wIntf.bUser, isNull);
  });
}
