// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// policy_arbiter_icarus_test.dart
// Cross-backend test for retained arbitration ownership.
//
// 2026 October 6
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  // Capture request zero and create an owner request gap so both functional
  // simulation and Icarus verify active-grant masking.
  test('retained owner gap agrees across simulators', () async {
    final arbiter = PolicyArbiter(
      List.generate(3, (_) => Logic()),
      clk: Logic(),
      reset: Logic(),
      policy: roundRobinArbitrationPolicy,
      advanceMode: ArbitrationAdvanceMode.onCompletion,
      retentionPolicy: ArbitrationRetentionPolicy.lockUntilRelease,
      accepted: Logic(),
      complete: Logic(),
      captureOwner: Logic(),
      releaseOwner: Logic(),
    );
    await arbiter.build();

    final vectors = [
      Vector({
        'clk': 0,
        'reset': 1,
        'accepted': 0,
        'complete': 0,
        'captureOwner': 0,
        'releaseOwner': 0,
        'request_0': 0,
        'request_1': 0,
        'request_2': 0,
      }, {}),
      Vector({
        'clk': 1,
        'reset': 1,
        'accepted': 0,
        'complete': 0,
        'captureOwner': 0,
        'releaseOwner': 0,
        'request_0': 0,
        'request_1': 0,
        'request_2': 0,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'accepted': 1,
        'complete': 0,
        'captureOwner': 1,
        'releaseOwner': 0,
        'request_0': 1,
        'request_1': 1,
        'request_2': 0,
      }, {
        'grant_0': 1,
        'grant_1': 0,
        'grant_2': 0,
        'selection': 1,
        'locked': 0,
      }),
      Vector({
        'clk': 1,
        'reset': 0,
        'accepted': 1,
        'complete': 0,
        'captureOwner': 1,
        'releaseOwner': 0,
        'request_0': 1,
        'request_1': 1,
        'request_2': 0,
      }, {}),
      Vector({
        'clk': 0,
        'reset': 0,
        'accepted': 0,
        'complete': 0,
        'captureOwner': 0,
        'releaseOwner': 0,
        'request_0': 0,
        'request_1': 1,
        'request_2': 1,
      }, {
        'grant_0': 0,
        'grant_1': 0,
        'grant_2': 0,
        'selection': 1,
        'locked': 1,
      }),
    ];

    await SimCompare.checkFunctionalVector(arbiter, vectors);
    SimCompare.checkIverilogVector(arbiter, vectors);
  });
}
