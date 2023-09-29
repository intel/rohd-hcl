// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// example.dart
// Example of how to use the library
//
// 2023 February 17
// Author: Max Korbel <max.korbel@intel.com>

// ignore_for_file: avoid_print

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

Future<void> main() async {
  // Build a module that rotates a 16-bit signal by an 8-bit signal, which
  // we guarantee will never see more than 10 as the rotate amount.
  final original = Logic(width: 16);
  final rotateAmount = Logic(width: 8);
  final mod = RotateLeft(original, rotateAmount, maxAmount: 10);
  final rotated = mod.rotated;

  // Do a quick little simulation with some inputs
  original.put(0x4321);
  rotateAmount.put(4);
  print('Shifting ${original.value} by ${rotateAmount.value} '
      'yields ${rotated.value}');

  // Generate verilog for it and print it out
  await mod.build();
  print('Generating verilog...');
  print(mod.generateSynth());
}
