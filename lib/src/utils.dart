// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// utils.dart
// Various utilities helpful for working with the component library

import 'dart:math';
import 'dart:math' as math;
import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/exceptions/logic_value/invalid_random_logic_value_exception.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/web.dart';

/// Computes the bit width needed to store [w] addresses.
int log2Ceil(int w) => (log(w) / log(2)).ceil();

/// Returns whether [n] is a power of two.
bool isPowerOfTwo(int n) => n != 0 && (n & (n - 1) == 0);

/// This extension will eventually move to ROHD once it is proven useful.
extension LogicValueBitString on LogicValue {
  /// Simplest version of bit string representation as shorthand.
  String get bitString => toString(includeWidth: false);
}

/// This extension will eventually move to ROHD once it is proven useful.
extension LogicValueMajority on LogicValue {
  /// Compute the unary majority on [LogicValue].
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
        : flop(clk, d,
                en: en,
                reset: reset,
                resetValue: resetValue,
                asyncReset: asyncReset)
            .named('${d.name}_flopped');

/// Swap two [Logic] structures based on a conditional [doSwap].
(LogicType, LogicType) swap<LogicType extends Logic>(
    Logic doSwap, (LogicType, LogicType) toSwap) {
  final in1 = toSwap.$1.named('swapIn1_${toSwap.$1.name}');
  final in2 = toSwap.$2.named('swapIn2_${toSwap.$2.name}');

  LogicType clone({String? name}) => toSwap.$1.clone(name: name) as LogicType;

  final out1 = mux(doSwap, in2, in1).named('swapOut1');
  final out2 = mux(doSwap, in1, in2).named('swapOut2');
  final first = clone(name: 'swapOut1')..gets(out1);
  final second = clone(name: 'swapOut2')..gets(out2);

  return (first, second);
}

/// Allows random generation of [LogicValue] for [BigInt] and [int].
extension RandLogicValueNew on math.Random {
  /// Generate unsigned random [BigInt] value that consists of
  /// [numBits] bits.
  BigInt _nextBigInt({required int numBits}) {
    var result = BigInt.zero;
    for (var i = 0; i < numBits; i += 32) {
      // BigInt is safe with it, though
      result = (result << 32) | BigInt.from(nextInt(oneSllBy(32)));
    }
    return result & ((BigInt.one << numBits) - BigInt.one);
  }

  /// Generate a random [LogicValue] with the given [width] and optional [min]
  /// and [max] values.
  ///
  /// The random number can be mixed in invalid bits x and z by set
  /// [includeInvalidBits] to `true`. [max] can be used to set the maximum
  /// range of the generated number and its only accept runtimeType `int` and
  /// `BigInt`. [max] only work when [includeInvalidBits] is set to false
  /// else an exception will be thrown. if [min] is provided, the generated
  /// number will be in the range of [min] (inclusive) to [max] (exclusive).
  /// [min] can be only runtimeType `int` and `BigInt`. [min] only work when
  /// [includeInvalidBits] is set to false else an exception will be thrown
  LogicValue nextLogicValueNew({
    required int width,
    dynamic min,
    dynamic max,
    bool includeInvalidBits = false,
  }) {
    if (width == 0) {
      return LogicValue.empty;
    }

    if (max != null) {
      if (max is! int && max is! BigInt) {
        throw InvalidRandomLogicValueException(
            'max can be only runtimeType of int or BigInt.');
      }

      if (max is int && max == 0) {
        return LogicValue.ofInt(max, width);
      } else if (max is BigInt && max == BigInt.zero) {
        return LogicValue.ofBigInt(BigInt.zero, width);
      }

      if ((max is int && max < 0) || (max is BigInt && max < BigInt.zero)) {
        throw InvalidRandomLogicValueException('max cannot be less than 0');
      }
    }
    if (min != null) {
      if (min is! int && min is! BigInt) {
        throw InvalidRandomLogicValueException(
            'min can be only runtimeType of int or BigInt.');
      }
      if (max != null) {
        if (min is int && max is int && min > max) {
          throw InvalidRandomLogicValueException('min cannot be > max');
        } else if (min is BigInt && max is BigInt && min.compareTo(max) > 0) {
          throw InvalidRandomLogicValueException('min cannot be > max');
        } else if (min is int && max is BigInt) {
          if (BigInt.from(min).compareTo(max) > 0) {
            throw InvalidRandomLogicValueException('min cannot be > max');
          }
        } else if (min is BigInt && max is int) {
          if (min.compareTo(BigInt.from(max)) > 0) {
            throw InvalidRandomLogicValueException('min cannot be > max');
          }
        }
      }
    }

    if (includeInvalidBits) {
      if (max != null) {
        throw InvalidRandomLogicValueException(
            'max does not work with invalid bits random number generation.');
      }
      if (min != null) {
        throw InvalidRandomLogicValueException(
            'max does not work with invalid bits random number generation.');
      }

      final bitString = StringBuffer();
      for (var i = 0; i < width; i++) {
        bitString.write(const ['1', '0', 'x', 'z'][nextInt(4)]);
      }

      return LogicValue.ofString(bitString.toString());
    } else {
      // This could be replaced with adding `min` to
      // `LogicValue.nextLogicVal(max:max)` but this version was easier to
      // reason about corner cases and bitLength constraints.
      if (width <= INT_BITS) {
        final ranNum = width <= 32
            ? nextInt(oneSllBy(width))
            : _nextBigInt(numBits: width).toInt();

        final base =
            (min == null) ? 0 : (min is int ? min : (min as BigInt).toInt());
        if (max == null || (max is BigInt && max.bitLength > INT_BITS)) {
          return LogicValue.ofInt(base + ranNum, width);
        } else {
          final mod = (min == null)
              ? (max is int)
                  ? max
                  : (max as BigInt).toInt()
              : (max is int)
                  ? (max - (min is int ? min : (min as BigInt).toInt()))
                  : ((max as BigInt) -
                          (min is int ? BigInt.from(min) : min as BigInt))
                      .toInt();

          return LogicValue.ofInt(base + ranNum % mod, width);
        }
      } else {
        final ranNum = _nextBigInt(numBits: width);
        final base = (min == null)
            ? BigInt.zero
            : (min is int ? BigInt.from(min) : min as BigInt);

        if (max == null ||
            (max is BigInt && (base + ranNum).bitLength < max.bitLength)) {
          return LogicValue.ofBigInt(base + ranNum, width);
        } else {
          final maxBigInt = max is int ? BigInt.from(max) : max as BigInt;
          final mod = (min == null)
              ? maxBigInt
              : maxBigInt - (min is int ? BigInt.from(min) : min as BigInt);
          return LogicValue.ofBigInt(base + ranNum % mod, width);
        }
      }
    }
  }
}
