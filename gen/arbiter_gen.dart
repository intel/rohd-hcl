// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// arbiter_gen.dart
// Generate an example arbiter
//
// 2023 May 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//

// ignore_for_file: unused_element

import 'dart:async';
import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arbiter.dart';

Future<void> arbiterGen() async {
  const width = 8;

  final vector = Logic(width: width);
  final reqs = List.generate(width, (i) => vector[i]);

  final arb = PriorityArbiter(reqs);

  await arb.build();
  final res = arb.generateSynth();
  File('build/${arb.definitionName}.v').writeAsStringSync(res);
}
