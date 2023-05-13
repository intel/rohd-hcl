// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rotate_gen.dart
// Generate an example rotator
//
// 2023 May 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//

import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/rotate.dart';

void rotate_gen() async {
  final rot = RotateLeft(
    Const(0xf000, width: 16),
    Const(4, width: 8),
    maxAmount: 4,
  );
  await rot.build();
  final res = rot.generateSynth();
  File('build/${rot.definitionName}.v').openWrite().write(res);
}
