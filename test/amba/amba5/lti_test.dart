// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// lti_test.dart
// Tests for the LTI interface.
//
// 2025 August
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

class LtiSubordinate extends Module {
  LtiSubordinate(Axi5SystemInterface sIntf, List<LtiCluster> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <LtiCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.consumer));
    }
  }
}

class LtiMain extends Module {
  LtiMain(Axi5SystemInterface sIntf, List<LtiCluster> lanes) {
    sIntf = Axi5SystemInterface()
      ..pairConnectIO(this, sIntf, PairRole.consumer);

    final lanesL = <LtiCluster>[];
    for (var i = 0; i < lanes.length; i++) {
      lanesL.add(
          lanes[i].clone()..pairConnectIO(this, lanes[i], PairRole.provider));
    }
  }
}

class LtiPair extends Module {
  LtiPair(
    Logic clk,
    Logic reset, {
    int numLanes = 1,
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);

    final sIntf = Axi5SystemInterface();
    sIntf.clk <= clk;
    sIntf.resetN <= ~reset;

    final lanes = <LtiCluster>[];
    for (var i = 0; i < numLanes; i++) {
      final la = LtiLaChannelInterface(config: LtiLaChannelConfig());
      final lr = LtiLrChannelInterface(config: LtiLrChannelConfig());
      final lc = LtiLcChannelInterface(config: LtiLcChannelConfig());
      final lt = LtiLtChannelInterface(config: LtiLtChannelConfig());
      final lm = LtiManagementInterface();

      lanes.add(LtiCluster(la: la, lr: lr, lc: lc, lt: lt, lm: lm));
    }

    LtiMain(sIntf, lanes);
    LtiSubordinate(sIntf, lanes);
  }
}

void main() {
  test('connect lti modules', () async {
    final ltiPair = LtiPair(Logic(), Logic());
    await ltiPair.build();
  });
}
