// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// one_hot_gen.dart
// Generate one_hot codecs.
//
// 2023 Oct 02
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/parallel_prefix_operations.dart';

Future<void> parallelPrefixGen() async {
  const n = 8;
  final a = Logic(name: 'a', width: n);
  final b = Logic(name: 'b', width: n);

  final generators = [Ripple.new, Sklansky.new, KoggeStone.new, BrentKung.new];
  final names = ['Ripple', 'Sklansky', 'KoggeStone', 'BrentKung'];
  var i = 0;
  for (final ppGen in generators) {
    final m1 = PPAdder(a, b, ppGen);
    await m1.build();
    File('build/${m1.definitionName}_${names[i]}.v').writeAsStringSync(m1
        .generateSynth()
        .replaceAll('PPAdder', '${m1.definitionName}_${names[i]}'));
    i = i + 1;
  }
}
