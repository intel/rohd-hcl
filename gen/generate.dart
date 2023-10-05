// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generate.dart
// Generate a series of examples for documentation.
//
// Call a generator to create an instance of your component for
// schematic viewing.
//
// 2023 May 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'arbiter_gen.dart';
import 'fifo_gen.dart';
import 'one_hot_gen.dart';
import 'rf_gen.dart';
import 'rotate_gen.dart';

void main() async {
  await arbiterGen();
  await fifoGen();
  await oneHotGen();
  await rfGen();
  await rotateGen();
}
