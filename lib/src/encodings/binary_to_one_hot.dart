// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_to_one_hot.dart
// Implementation of one hot codec from binary to one-hot.
//
// 2023 February 24
// Author: Desmond Kirkpatrick

import 'dart:math';
import 'package:rohd/rohd.dart';

/// Encodes a binary number into one-hot.
class BinaryToOneHot extends Module {
  /// The [encoded] one-hot result.
  Logic get encoded => output('encoded');

  /// Constructs a [Module] which encodes a 2's complement number [binary]
  /// into a one-hot, or thermometer code
  BinaryToOneHot(Logic binary, {super.name = 'binary_to_one_hot'})
      : super(definitionName: 'BinaryToOneHot_W${binary.width}') {
    binary = addInput('binary', binary, width: binary.width);
    addOutput('encoded', width: pow(2, binary.width).toInt());
    encoded <= Const(1, width: encoded.width) << binary;
  }
}
