// Copyright (C) 2023-2025 Intel Corporation
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

/// Conditionally constructs a positive edge triggered flip condFlop on [clk].
///
/// It returns either [FlipFlop.q] if [clk] is non-null or [d] if not.
///
/// When the optional [en] is provided, an additional input will be created for
/// condFlop. If optional [en] is high or not provided, output will vary as per
/// input[d]. For low [en], output remains frozen irrespective of input [d].
///
/// - When the optional [reset] is provided, the condFlop will be reset
/// (active-high).
/// - If no [resetValue] is provided, the reset value is always `0`. Otherwise,
/// it will reset to the provided [resetValue].
/// - If [asyncReset] is true, the [reset] signal (if provided) will be treated
/// as an async reset. If [asyncReset] is false, the reset signal will be
/// treated as synchronous.
Logic condFlop(
  Logic? clk,
  Logic d, {
  Logic? en,
  Logic? reset,
  dynamic resetValue,
  bool asyncReset = false,
}) =>
    (clk == null)
        ? d
        : (Logic(name: '${d.name}_flopped', width: d.width)
          ..gets(flop(clk, d,
              en: en,
              reset: reset,
              resetValue: resetValue,
              asyncReset: asyncReset)));

/// Wrapper for constructing a new Logic with a name to bind to a Logic
/// operation.
Logic nameLogic(String name, Logic logic, {Naming? naming}) =>
    Logic(name: name, width: logic.width, naming: naming)..gets(logic);

