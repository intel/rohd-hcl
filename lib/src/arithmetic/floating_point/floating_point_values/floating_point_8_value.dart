import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// The E4M3 representation of a 8-bit floating point value as defined in
/// [FP8 Formats for Deep Learning](https://arxiv.org/abs/2209.05433).
class FloatingPoint8E4M3Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 4;

  /// The mantissa width
  static const int mantissaWidth = 3;

  @override
  @protected
  int get constrainedExponentWidth => exponentWidth;

  @override
  @protected
  int get constrainedMantissaWidth => mantissaWidth;

  /// The maximum value representable by the E4M3 format
  static double get maxValue => 448.toDouble();

  /// The minimum value representable by the E4M3 format
  static double get minValue => pow(2, -9).toDouble();

  /// Return if the exponent and mantissa widths match E4M3
  static bool isLegal(int exponentWidth, int mantissaWidth) =>
      (exponentWidth == 4) & (mantissaWidth == 3);

  /// Constructor for a double precision floating point value
  FloatingPoint8E4M3Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// [FloatingPoint8E4M3Value] constructor from string representation of
  /// individual bitfields
  factory FloatingPoint8E4M3Value.ofBinaryStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPoint8E4M3Value(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPoint8E4M3Value] constructor from a single string representing
  /// space-separated bitfields
  factory FloatingPoint8E4M3Value.ofString(String fp) {
    final s = fp.split(' ');
    assert(s.length == 3, 'Wrong FloatingPointValue string length ${s.length}');
    return FloatingPoint8E4M3Value.ofBinaryStrings(s[0], s[1], s[2]);
  }

  /// Construct a [FloatingPoint8E4M3Value] from a Logic word
  factory FloatingPoint8E4M3Value.fromLogic(LogicValue val) {
    if (val.width != 8) {
      throw RohdHclException('Width must be 8');
    }

    final sign = (val[-1] == LogicValue.one);
    final exponent =
        val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth).toBigInt();
    final mantissa = val.slice(mantissaWidth - 1, 0).toBigInt();
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(exponent, exponentWidth),
      LogicValue.ofBigInt(mantissa, mantissaWidth)
    );
    return FloatingPoint8E4M3Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// Numeric conversion of a [FloatingPoint8E4M3Value] from a host double
  factory FloatingPoint8E4M3Value.fromDouble(double inDouble) {
    if ((inDouble > maxValue) | (inDouble < minValue)) {
      throw RohdHclException('Number exceeds E4M3 range');
    }
    final fpv = FloatingPointValue.fromDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    return FloatingPoint8E4M3Value(
        sign: fpv.sign, exponent: fpv.exponent, mantissa: fpv.mantissa);
  }
}

/// The E5M2 representation of a 8-bit floating point value as defined in
/// [FP8 Formats for Deep Learning](https://arxiv.org/abs/2209.05433).
class FloatingPoint8E5M2Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 5;

  /// The mantissa width
  static const int mantissaWidth = 2;

  @override
  @protected
  int get constrainedExponentWidth => exponentWidth;

  @override
  @protected
  int get constrainedMantissaWidth => mantissaWidth;

  /// The maximum value representable by the E5M2 format
  static double get maxValue => 57344.toDouble();

  /// The minimum value representable by the E5M2 format
  static double get minValue => pow(2, -16).toDouble();

  /// Return if the exponent and mantissa widths match E5M2
  static bool isLegal(int exponentWidth, int mantissaWidth) =>
      (exponentWidth == 5) & (mantissaWidth == 2);

  /// Constructor for a double precision floating point value
  FloatingPoint8E5M2Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// [FloatingPoint8E5M2Value] constructor from string representation of
  /// individual bitfields
  factory FloatingPoint8E5M2Value.ofBinaryStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPoint8E5M2Value(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPoint8E5M2Value] constructor from a single string representing
  /// space-separated bitfields
  factory FloatingPoint8E5M2Value.ofString(String fp) {
    final s = fp.split(' ');
    assert(s.length == 3, 'Wrong FloatingPointValue string length ${s.length}');
    return FloatingPoint8E5M2Value.ofBinaryStrings(s[0], s[1], s[2]);
  }

  /// Construct a [FloatingPoint8E5M2Value] from a Logic word
  factory FloatingPoint8E5M2Value.fromLogic(LogicValue val, int exponentWidth) {
    if (val.width != 8) {
      throw RohdHclException('Width must be 8');
    }

    final mantissaWidth = 7 - exponentWidth;
    if (!isLegal(exponentWidth, mantissaWidth)) {
      throw RohdHclException('FloatingPoint8E5M2 must follow E5M2');
    }

    final sign = (val[-1] == LogicValue.one);
    final exponent =
        val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth).toBigInt();
    final mantissa = val.slice(mantissaWidth - 1, 0).toBigInt();
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(exponent, exponentWidth),
      LogicValue.ofBigInt(mantissa, mantissaWidth)
    );
    return FloatingPoint8E5M2Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// Numeric conversion of a [FloatingPoint8E5M2Value] from a host double
  factory FloatingPoint8E5M2Value.fromDouble(double inDouble) {
    if ((inDouble > maxValue) | (inDouble < minValue)) {
      throw RohdHclException('Number exceeds E5M2 range');
    }
    final fpv = FloatingPointValue.fromDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    return FloatingPoint8E5M2Value(
        sign: fpv.sign, exponent: fpv.exponent, mantissa: fpv.mantissa);
  }
}