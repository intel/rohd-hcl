// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// one_hot_gen.dart
// Generate one_hot codecs.
//
// 2023 May 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//

import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/one_hot.dart';
import 'package:rohd_hcl/src/utils.dart';

Future<void> oneHotGen() async {
  const pos = 8;
  final binaryInput = Logic(width: log2Ceil(pos + 1));
  final m1 = BinaryToOneHot(binaryInput);
  await m1.build();
  File('build/${m1.definitionName}.v').writeAsStringSync(m1.generateSynth());

  final onehotInput = Logic(width: pos + 1);
  final m2 = OneHotToBinary(onehotInput);
  await m2.build();
  File('build/${m2.definitionName}.v').writeAsStringSync(m2.generateSynth());

  final m3 = TreeOneHotToBinary(onehotInput);
  await m3.build();
  File('build/${m3.definitionName}.v').writeAsStringSync(m3.generateSynth());
}
