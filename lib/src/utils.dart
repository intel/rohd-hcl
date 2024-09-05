// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// utils.dart
// Various utilities helpful for working with the component library

import 'dart:math';
import 'package:rohd/rohd.dart';

/// Computes the bit width needed to store [w] addresses.
int log2Ceil(int w) => (log(w) / log(2)).ceil();

/// This extension will eventually move to ROHD once it is proven useful
extension LogicValueBitString on LogicValue {
  /// Simplest version of bit string representation as shorthand
  String get bitString => toString(includeWidth: false);
}

/// This extension will eventually move to ROHD once it is proven useful
extension LogicValueMajority on LogicValue {
  /// Compute the unary majority on LogicValue
  bool majority() {
    if (!isValid) {
      return false;
    }
    final zero = LogicValue.filled(width, LogicValue.zero);
    var shiftedValue = this;
    var result = 0;
    while (shiftedValue != zero) {
      result += (shiftedValue[0] & LogicValue.one == LogicValue.one) ? 1 : 0;
      shiftedValue >>>= 1;
    }
    return result > (width ~/ 2);
  }

  /// Compute the first One find operation on LogicValue, returning its position
  int? firstOne() {
    if (!isValid) {
      return null;
    }
    var shiftedValue = this;
    var result = 0;
    while (shiftedValue[0] != LogicValue.one) {
      result++;
      if (result == width) {
        return null;
      }
      shiftedValue >>>= 1;
    }
    return result;
  }
}
