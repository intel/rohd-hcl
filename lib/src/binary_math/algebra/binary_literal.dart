// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_literal.dart
// ROHD radix-string parsing support for binary mathematics.
//
// 2026 October 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Converts a [value] into a packed, two-state binary math value.
///
/// Binary math descriptors do not represent `x` or `z`, so invalid
/// [LogicValue]s are rejected.
({BigInt value, int width}) parseBinaryMathLogicValue(LogicValue value) {
  if (value.width <= 0) {
    throw RohdHclException(
        'Binary math radix strings must have a positive width.');
  }
  if (!value.isValid) {
    throw RohdHclException(
        'Binary math radix strings cannot contain x or z values.');
  }
  return (value: value.toBigInt(), width: value.width);
}

/// Parses a ROHD width/radix-encoded [literal] into a two-state value.
({BigInt value, int width}) parseBinaryMathRadixString(String literal) {
  try {
    return parseBinaryMathLogicValue(LogicValue.ofRadixString(literal));
  } on LogicValueConstructionException catch (exception) {
    throw RohdHclException(
        'Invalid binary math radix string "$literal": $exception');
  } on FormatException catch (exception) {
    throw RohdHclException(
        'Invalid binary math radix string "$literal": $exception');
  }
}
