// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rf_gen.dart
// Generate an example register file
//
// 2023 May 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

Future<void> rfGen() async {
  const dataWidth = 16;
  const addrWidth = 4;

  const numWr = 2;
  const numRd = 2;

  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();

  final wrPorts = [
    for (var i = 0; i < numWr; i++) DataPortInterface(dataWidth, addrWidth)
  ];
  final rdPorts = [
    for (var i = 0; i < numRd; i++) DataPortInterface(dataWidth, addrWidth)
  ];

  final rf = RegisterFile(clk, reset, wrPorts, rdPorts, numEntries: 20);

  await rf.build();

  final res = rf.generateSynth();
  File('build/${rf.definitionName}.v').writeAsStringSync(res);
}
