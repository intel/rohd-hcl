// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// utils.dart
// Various utilities helpful for working with the component library

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// Returns the minimum number of bits needed to represent [val] distinct
/// values, with a minimum of 1 (since 0-width signals are not valid in
/// hardware).
///
/// Equivalent to `max(1, val.log2Ceil)`.
int widthFor(int val) => max(1, val.log2Ceil);

/// This extension will eventually move to ROHD once it is proven useful.
extension LogicValueBitString on LogicValue {
  /// Simplest version of bit string representation as shorthand.
  String get bitString => toString(includeWidth: false);
}

/// This extension will eventually move to ROHD once it is proven useful.
extension LogicValueMajority on LogicValue {
  /// Whether strictly more than half of the bits are one.
  ///
  /// Returns false for a tie or when any bit is X or Z.
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

  /// Compute the first One find operation on [LogicValue], returning its
  /// position.
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
  /// Convert a BigInt to Signed when [signed] is `true`.
  BigInt toCondSigned(int width, {bool signed = false}) =>
      signed ? toSigned(width) : toUnsigned(width);

  /// Construct a Signed BigInt from an int when [signed] is `true`.
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
///   (active-high).
/// - If no [resetValue] is provided, the reset value is always `0`. Otherwise,
///   it will reset to the provided [resetValue].
/// - If [asyncReset] is `true`, the [reset] signal (if provided) will be
///   treated as an async reset. If [asyncReset] is `false`, the reset signal
///   will be treated as synchronous.
///
/// Preserves [LogicType] and runtime structured layouts. [outputGenerator] can
/// supply an explicit registered output schema. A null [clk] returns [d]
/// unchanged. Use `condFlop<Logic>` for scalar constants or nets that need a
/// driveable registered result. The output must be compatible with the input
/// and any signal reset value; packed values remain valid bridges.
LogicType condFlop<LogicType extends Logic>(
  Logic? clk,
  LogicType d, {
  Logic? en,
  Logic? reset,
  dynamic resetValue,
  bool asyncReset = false,
  LogicType Function({String? name})? outputGenerator,
}) {
  if (clk == null) {
    return d;
  }
  if (reset != null &&
      resetValue is Logic &&
      d.width == resetValue.width &&
      !compatiblePayloadConnectionAllowingRenamedClone(d, resetValue)) {
    throw ArgumentError(
        'Register input and reset payloads must be compatible.');
  }
  final generator = outputGenerator ??
      (hasDeclaredPayloadShape(d)
          ? ({name}) => d.cloneTyped(name: name)
          : null);
  LogicType checkedOutput({String? name}) {
    final output = generator!(name: name);
    if (output.width == d.width &&
        !compatiblePayloadConnectionAllowingRenamedClone(output, d)) {
      throw ArgumentError('Register output and input payloads must be '
          'compatible.');
    }
    if (reset != null &&
        resetValue is Logic &&
        output.width == resetValue.width &&
        !compatiblePayloadConnectionAllowingRenamedClone(output, resetValue)) {
      throw ArgumentError('Register output and reset payloads must be '
          'compatible.');
    }
    return output;
  }

  final registered = flop<LogicType>(clk, d,
      en: en,
      reset: reset,
      resetValue: resetValue,
      asyncReset: asyncReset,
      outputGenerator: generator == null ? null : checkedOutput);
  return registered.cloneTyped(name: '${d.name}_flopped')..gets(registered);
}

/// Swap two compatible payloads based on a conditional [doSwap].
///
/// Declared payload formats must match; plain packed values are bridges.
(LogicType, LogicType) swap<LogicType extends Logic>(
    Logic doSwap, (LogicType, LogicType) toSwap) {
  final (in1, in2) = toSwap;
  if (in1.width == in2.width &&
      !compatiblePayloadConnectionAllowingRenamedClone(in1, in2)) {
    throw ArgumentError('Swap payloads must be compatible.');
  }
  LogicType firstClone({String? name}) => in1.cloneTyped(name: name);
  LogicType secondClone({String? name}) => in2.cloneTyped(name: name);
  final out1 = mux<LogicType>(doSwap, in2, in1,
      outputGenerator: hasDeclaredPayloadShape(in1) ? firstClone : null);
  final out2 = mux<LogicType>(doSwap, in1, in2,
      outputGenerator: hasDeclaredPayloadShape(in2) ? secondClone : null);
  return (
    out1.cloneTyped(name: 'swapOut1')..gets(out1),
    out2.cloneTyped(name: 'swapOut2')..gets(out2),
  );
}
