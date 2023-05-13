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

void one_hot_gen() async {
  const pos = 8;
  final w = log2Ceil(pos + 1);
  final mod = BinaryToOneHot(Const(pos, width: w));
  await mod.build();
  final res = mod.generateSynth();
  File('build/${mod.definitionName}.v').openWrite().write(res);
  final val = BigInt.from(2).pow(pos);
  final mod2 = OneHotToBinary(Const(val, width: pos + 1));
  await mod2.build();
  final res2 = mod2.generateSynth();
  File('build/${mod2.definitionName}.v').openWrite().write(res2);
}
