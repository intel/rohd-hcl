// Copyright (C) 2023-2026 Intel Corporation
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
  BinaryToOneHot(Logic binary,
      {super.name = 'binary_to_one_hot',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : super(
            definitionName:
                definitionName ?? 'BinaryToOneHot_W${binary.width}') {
    binary = addInput('binary', binary, width: binary.width);
    addOutput('encoded', width: pow(2, binary.width).toInt());
    encoded <= Const(1, width: encoded.width) << binary;
  }
}

/// Converts binary [Logic] signals to one-hot signals.
extension BinaryToOneHotLogic on Logic {
  /// Encodes this binary index using [BinaryToOneHot].
  ///
  /// The output has `2^width` bits.
  Logic binaryToOneHot() => BinaryToOneHot(this).encoded;
}

/// Converts binary [LogicValue]s to one-hot values.
extension BinaryToOneHotLogicValue on LogicValue {
  /// Evaluates [BinaryToOneHot] for this binary index.
  ///
  /// The output has `2^width` bits and follows the codec's four-state
  /// behavior.
  LogicValue binaryToOneHot() => BinaryToOneHot(Const(this)).encoded.value;
}
