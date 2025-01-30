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

/// This extension will provide conversion to Signed or Unsigned BigInt
extension SignedBigInt on BigInt {
  /// Convert a BigInt to Signed when [signed] is true
  BigInt toCondSigned(int width, {bool signed = false}) =>
      signed ? toSigned(width) : toUnsigned(width);

  /// Construct a Signed BigInt from an int when [signed] is true
  static BigInt fromSignedInt(int value, int width, {bool signed = false}) =>
      signed
          ? BigInt.from(value).toSigned(width)
          : BigInt.from(value).toUnsigned(width);
}
