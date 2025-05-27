// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_value_populator.dart
// Populator for Floating Point Values
//
// 2024 October 15
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A populator for [FloatingPointValue]s, a utility that can populate various
/// forms of [FloatingPointValue]s.
class FloatingPointValuePopulator<FpvType extends FloatingPointValue> {
  /// An unpopulated [FloatingPointValue] that this populator will populate.
  ///
  /// The `late final` variables will not yet be initialized until after this
  /// populator is used to [populate] it.
  final FpvType _unpopulated;

  /// The width of the exponent field.
  int get exponentWidth => _unpopulated.exponentWidth;

  /// The width of the mantissa field.
  int get mantissaWidth => _unpopulated.mantissaWidth;

  // bool explicitJBit() => _unpopulated.explicitJBit;

  /// The bias of floating point value.
  int get bias => _unpopulated.bias;

  /// The minimum exponent value.
  int get minExponent => _unpopulated.minExponent;

  /// The maximum exponent value.
  int get maxExponent => _unpopulated.maxExponent;

  /// True if the format stores the Jbit explicitly.
  bool get explicitJBit => _unpopulated.explicitJBit;

  /// Whether or not this populator has already populated values.
  bool _hasPopulated = false;

  /// Creates a [FloatingPointValuePopulator] for the given [_unpopulated]
  /// [FloatingPointValue].
  FloatingPointValuePopulator(this._unpopulated);

  @override
  String toString() =>
      'FloatingPointValuePopulator<${_unpopulated.runtimeType}>';

  /// Populates the [FloatingPointValue] with the given [sign], [exponent], and
  /// [mantissa], then performs additional validation.
  FpvType populate({
    required LogicValue sign,
    required LogicValue exponent,
    required LogicValue mantissa,
    bool explicitJBit = false,
  }) {
    if (_hasPopulated) {
      throw RohdHclException('FloatingPointPopulator: already populated');
    }
    _hasPopulated = true;

    return _unpopulated
      ..sign = sign
      ..exponent = exponent
      ..mantissa = mantissa
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_overriding_member
      ..validate();
  }

  /// Extracts a [FloatingPointValue] from a [FloatingPoint]'s current `value`.
  FpvType ofFloatingPoint(FloatingPoint fp) => populate(
        sign: fp.sign.value,
        exponent: fp.exponent.value,
        mantissa: fp.mantissa.value,
      );

  /// Extracts a [FloatingPointValue] from a [FloatingPoint]'s `previousValue`.
  FpvType? ofFloatingPointPrevious(FloatingPoint fp) {
    final prevVal = fp.previousValue;
    if (prevVal == null) {
      return null;
    }

    return ofLogicValue(prevVal);
  }

  /// [FloatingPointValue] constructor from a binary string representation of
  /// individual bitfields
  FpvType ofBinaryStrings(String sign, String exponent, String mantissa) =>
      populate(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPointValue] constructor from a single binary string representing
  /// space-separated bitfields in the order of sign, exponent, mantissa.
  ///
  /// For example:
  /// ```dart
  /// //                    s e        m
  /// ofSpacedBinaryString('0 00000000 00000000000000000000000')
  /// ```
  FpvType ofSpacedBinaryString(String fp) {
    final split = fp.split(' ');
    return ofBinaryStrings(split[0], split[1], split[2]);
  }

  /// Helper function for extracting binary strings from a longer
  /// binary string and the known exponent and mantissa widths.
  static ({String sign, String exponent, String mantissa})
      _extractBinaryStrings(
          String fp, int exponentWidth, int mantissaWidth, int radix) {
    final binaryFp = LogicValue.ofBigInt(
            BigInt.parse(fp, radix: radix), exponentWidth + mantissaWidth + 1)
        .bitString;

    return (
      sign: binaryFp.substring(0, 1),
      exponent: binaryFp.substring(1, 1 + exponentWidth),
      mantissa: binaryFp.substring(
          1 + exponentWidth, 1 + exponentWidth + mantissaWidth)
    );
  }

  /// [FloatingPointValue] constructor from a radix-encoded string
  /// representation and the size of the exponent and mantissa
  FpvType ofString(String fp, {int radix = 2}) {
    final extracted =
        _extractBinaryStrings(fp, exponentWidth, mantissaWidth, radix);
    return ofBinaryStrings(
        extracted.sign, extracted.exponent, extracted.mantissa);
  }

  /// [FloatingPointValue] constructor from a set of [BigInt]s of the binary
  /// representation and the size of the exponent and mantissa
  FpvType ofBigInts(BigInt exponent, BigInt mantissa, {bool sign = false}) =>
      populate(
          sign: LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
          exponent: LogicValue.ofBigInt(exponent, exponentWidth),
          mantissa: LogicValue.ofBigInt(mantissa, mantissaWidth));

  /// [FloatingPointValue] constructor from a set of [int]s of the binary
  /// representation and the size of the exponent and mantissa
  FpvType ofInts(int exponent, int mantissa, {bool sign = false}) => populate(
      sign: LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      exponent: LogicValue.ofBigInt(BigInt.from(exponent), exponentWidth),
      mantissa: LogicValue.ofBigInt(BigInt.from(mantissa), mantissaWidth));

  /// Construct a [FloatingPointValue] from a [LogicValue]
  FpvType ofLogicValue(LogicValue val) => populate(
        sign: val[-1],
        exponent: val.getRange(mantissaWidth, mantissaWidth + exponentWidth),
        mantissa: val.getRange(0, mantissaWidth),
      );

  /// Creates a new [FloatingPointValue] represented by the given
  /// [constantFloatingPoint].
  FpvType ofConstant(FloatingPointConstants constantFloatingPoint) {
    final components =
        // ignore: invalid_use_of_protected_member
        _unpopulated.getConstantComponents(constantFloatingPoint);

    return populate(
        sign: components.sign,
        exponent: components.exponent,
        mantissa: components.mantissa);
  }

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.positiveInfinity].
  FpvType get positiveInfinity =>
      ofConstant(FloatingPointConstants.positiveInfinity);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.negativeInfinity].
  FpvType get negativeInfinity =>
      ofConstant(FloatingPointConstants.negativeInfinity);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.nan].
  FpvType get nan => ofConstant(FloatingPointConstants.nan);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.one].
  FpvType get one => ofConstant(FloatingPointConstants.one);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.positiveZero].
  FpvType get positiveZero => ofConstant(FloatingPointConstants.positiveZero);

  /// Creates a new [FloatingPointValue] representing
  /// [FloatingPointConstants.negativeZero].
  FpvType get negativeZero => ofConstant(FloatingPointConstants.negativeZero);

  // TODO(desmonddak): we may have a bug in ofDouble() when
  //  the FPV is close to the width of the native double:  for LGRS to work
  //  we need three bits of space to handle the LSB|Guard|Round|Sticky.
  //  If the FPV is only 2 bits shorter than native, then we know we can round
  //  with LSB+Guard, but can't fit the round and sticky bits.
  //  The algorithm needs to extend with zeros and handle.

  /// Convert from double using its native binary representation
  FpvType ofDouble(double inDouble,
      {FloatingPointRoundingMode roundingMode =
          FloatingPointRoundingMode.roundNearestEven}) {
    if (inDouble.isNaN) {
      return nan;
    }

    if (inDouble.isInfinite) {
      return ofConstant(
        inDouble < 0.0
            ? FloatingPointConstants.negativeInfinity
            : FloatingPointConstants.positiveInfinity,
      );
    }

    if (roundingMode != FloatingPointRoundingMode.roundNearestEven &&
        roundingMode != FloatingPointRoundingMode.truncate) {
      throw UnimplementedError(
          'Only roundNearestEven or truncate is supported for this width');
    }

    final fp64 = FloatingPoint64Value.populator().ofDouble(inDouble);
    final fp64Mw = fp64.mantissa.width;
    final exponent64 = fp64.exponent;

    var expVal = (exponent64.toInt() - fp64.bias) + bias;
    final mantissa64n = ((expVal <= 0)
        ? [LogicValue.one, fp64.mantissa].swizzle() >>>
            (-expVal +
                (!explicitJBit & (fp64.exponent.toInt() > 0)
                    ? 1
                    : explicitJBit
                        ? 1
                        : 0))
        : [LogicValue.one, fp64.mantissa].swizzle());

    var mantissa = mantissa64n.slice(fp64Mw - (explicitJBit ? 0 : 1),
        fp64Mw - mantissaWidth + (explicitJBit ? 1 : 0));

    // TODO(desmonddak): this should be in a separate function to use
    //  with a FloatingPointValue converter we need.
    if (roundingMode == FloatingPointRoundingMode.roundNearestEven) {
      final stickyPos = fp64Mw - (mantissaWidth + 3);
      final sticky =
          (stickyPos >= 0) ? mantissa64n.slice(stickyPos, 0).or() : 0;
      final roundPos = stickyPos + 1;
      final round = ((roundPos >= 0) & (roundPos > stickyPos))
          ? mantissa64n[roundPos]
          : 0;
      final guardPos = roundPos + 1;
      final guard = (guardPos >= 1) ? mantissa64n[roundPos + 1] : 0;

      // RNE Rounding
      if (guard == LogicValue.one) {
        if ((round == LogicValue.one) |
            (sticky == LogicValue.one) |
            (mantissa[0] == LogicValue.one)) {
          mantissa += 1;
          if (mantissa == LogicValue.zero.zeroExtend(mantissa.width)) {
            expVal += 1;
            if (explicitJBit) {
              mantissa = [
                LogicValue.one,
                LogicValue.zero.zeroExtend(mantissa.width - 1)
              ].swizzle();
            }
          }
        }
      }
    }

    if (_unpopulated.supportsInfinities && expVal > maxExponent + bias) {
      return ofConstant(
        fp64.sign.toBool()
            ? FloatingPointConstants.negativeInfinity
            : FloatingPointConstants.positiveInfinity,
      );
    }

    final exponent =
        LogicValue.ofBigInt(BigInt.from(max(expVal, 0)), exponentWidth);

    final sign = fp64.sign;

    return populate(
      sign: sign,
      exponent: exponent,
      mantissa: mantissa,
    );
  }

  /// Convert a floating point number into a [FloatingPointValue]
  /// representation. This form performs NO ROUNDING.
  @internal
  FpvType ofDoubleUnrounded(double inDouble) {
    if (inDouble.isNaN) {
      return ofConstant(FloatingPointConstants.nan);
    }

    var doubleVal = inDouble;
    LogicValue sign;
    if (inDouble < 0.0) {
      doubleVal = -doubleVal;
      sign = LogicValue.one;
    } else {
      sign = LogicValue.zero;
    }
    if (inDouble.isInfinite) {
      return ofConstant(
        sign.toBool()
            ? FloatingPointConstants.negativeInfinity
            : FloatingPointConstants.positiveInfinity,
      );
    }

    // If we are dealing with a really small number we need to scale it up
    var scaleToWhole = (doubleVal != 0) ? (-log(doubleVal) / log(2)).ceil() : 0;

    if (doubleVal < 1.0) {
      var myCnt = 0;
      var myVal = doubleVal;
      while (myVal % 1 != 0.0) {
        myVal = myVal * 2.0;
        myCnt++;
      }
      if (myCnt < scaleToWhole) {
        scaleToWhole = myCnt;
      }
    }

    // Scale it up to go beyond the mantissa and include the GRS bits
    final scale = mantissaWidth + scaleToWhole;
    var s = scale;

    var sVal = doubleVal;
    if (s > 0) {
      while (s > 0) {
        sVal *= 2.0;
        s = s - 1;
      }
    } else {
      sVal = doubleVal * pow(2.0, scale);
    }

    final scaledValue = BigInt.from(sVal);
    final fullLength = scaledValue.bitLength;

    var fullValue = LogicValue.ofBigInt(scaledValue, fullLength);
    var e = (fullLength > 0)
        ? fullLength - mantissaWidth - scaleToWhole
        : minExponent;

    if (e <= -bias) {
      fullValue = fullValue >>> (scaleToWhole - bias);
      e = -bias;
    } else {
      // Could be just one away from subnormal
      e -= 1;
      if (e > -bias) {
        fullValue = fullValue << 1; // Chop the first '1'
      }
    }

    if (e > maxExponent) {
      return ofConstant(sign.toBool()
          ? FloatingPointConstants.negativeInfinity
          : FloatingPointConstants.positiveInfinity);
    }
    // We reverse so that we fit into a shorter BigInt, we keep the MSB.
    // The conversion fills leftward.
    // We reverse again after conversion.
    final exponent = LogicValue.ofInt(e + bias, exponentWidth);
    final mantissa =
        LogicValue.ofBigInt(fullValue.reversed.toBigInt(), mantissaWidth)
            .reversed;

    return populate(
      exponent: exponent,
      mantissa: mantissa,
      sign: sign,
    );
  }

  /// Generate a random [FloatingPointValue], supplying random seed [rv].
  ///
  /// This generates a valid [FloatingPointValue] anywhere in the range it can
  /// represent:a general [FloatingPointValue] has a mantissa in `[0,2)` with `0
  /// <= exponent <= maxExponent()`.
  ///
  /// If [normal] is true, This routine will only generate mantissas in the
  /// range of `[1,2)` and `minExponent() <= exponent <= maxExponent().`
  FpvType random(Random rv, {bool normal = false}) {
    final sign = rv.nextLogicValue(width: 1);

    final mantissa = rv.nextLogicValue(width: mantissaWidth);

    final largestExponent = bias + maxExponent;
    final LogicValue exponent;
    if (normal) {
      exponent =
          rv.nextLogicValue(width: exponentWidth, max: largestExponent - 1) +
              LogicValue.one.zeroExtend(exponentWidth);
    } else {
      exponent = rv.nextLogicValue(width: exponentWidth, max: largestExponent);
    }

    return populate(sign: sign, exponent: exponent, mantissa: mantissa);
  }
}

/// A populator for [FloatingPointExplicitJBitValue]s, a utility that can
/// populate various forms of [FloatingPointExplicitJBitValue]s.
class FloatingPointExplicitJBitPopulator
    extends FloatingPointValuePopulator<FloatingPointExplicitJBitValue> {
  /// Creates a [FloatingPointValuePopulator] for the given [_unpopulated]
  /// [FloatingPointExplicitJBitValue].
  FloatingPointExplicitJBitPopulator(super._unpopulated);

  /// Construct a [FloatingPointExplicitJBitValue] from a
  /// [FloatingPointValue] with a mantissa that is one smaller (implicit jbit)
  FloatingPointExplicitJBitValue ofFloatingPointValue(FloatingPointValue fpv) =>
      populate(
          sign: fpv.sign,
          exponent: fpv.exponent,
          mantissa: fpv.mantissa.zeroExtend(fpv.mantissa.width + 1) |
              (fpv.isNormal() & !fpv.isAnInfinity & !fpv.isNaN
                  ? (LogicValue.of(1, width: fpv.mantissa.width + 1) <<
                      fpv.mantissa.width)
                  : LogicValue.of(0, width: fpv.mantissa.width + 1)));

  @override
  FloatingPointExplicitJBitValue ofConstant(
          FloatingPointConstants constantFloatingPoint) =>
      ofFloatingPointValue(FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1)
          .ofConstant(constantFloatingPoint));
  @override
  FloatingPointExplicitJBitValue ofDouble(double inDouble,
          {FloatingPointRoundingMode roundingMode =
              FloatingPointRoundingMode.roundNearestEven}) =>
      ofFloatingPointValue(FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1)
          .ofDouble(inDouble, roundingMode: roundingMode));

  @override
  @internal
  FloatingPointExplicitJBitValue ofDoubleUnrounded(double inDouble) =>
      ofFloatingPointValue(FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1)
          .ofDoubleUnrounded(inDouble));

  @override
  FloatingPointExplicitJBitValue random(Random rv, {bool normal = false}) =>
      ofFloatingPointValue(FloatingPointValue.populator(
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth - 1)
          .random(rv, normal: normal));
}
