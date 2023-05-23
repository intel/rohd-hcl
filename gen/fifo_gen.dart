// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo_gen.dart
// Genarate a FIFO.
//
// 2023 May 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//

import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/fifo.dart';

Future<void> fifoGen() async {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();

  final wrEn = Logic();
  final rdEn = Logic();
  final wrData = Logic(width: 32);

  final fifo = Fifo(
    clk,
    reset,
    writeEnable: wrEn,
    readEnable: rdEn,
    writeData: wrData,
    generateError: true,
    generateOccupancy: true,
    depth: 3,
  );
  await fifo.build();
  final res = fifo.generateSynth();
  File('build/${fifo.definitionName}.v').writeAsStringSync(res);
}
