import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a 8-bit floating point value as defined in
/// [FP8 Formats for Deep Learning](https://arxiv.org/abs/2209.05433).
class FloatingPoint8Value extends FloatingPointValue {
  /// The exponent width
  late final int exponentWidth;

  /// The mantissa width
  late final int mantissaWidth;

  static double get _e4m3max => 448.toDouble();
  static double get _e5m2max => 57344.toDouble();
  static double get _e4m3min => pow(2, -9).toDouble();
  static double get _e5m2min => pow(2, -16).toDouble();

  /// Return if the exponent and mantissa widths match E4M3 or E5M2
  static bool isLegal(int exponentWidth, int mantissaWidth) {
    if (((exponentWidth == 4) & (mantissaWidth == 3)) |
        ((exponentWidth == 5) & (mantissaWidth == 2))) {
      return true;
    } else {
      return false;
    }
  }

  /// Constructor for a double precision floating point value
  FloatingPoint8Value(
      {required super.sign, required super.mantissa, required super.exponent})
      : super.withConstraints() {
    exponentWidth = exponent.width;
    mantissaWidth = mantissa.width;
    if (!isLegal(exponentWidth, mantissaWidth)) {
      throw RohdHclException('FloatingPoint8 must follow E4M3 or E5M2');
    }
  }

  /// [FloatingPoint8Value] constructor from string representation of
  /// individual bitfields
  factory FloatingPoint8Value.ofStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPoint8Value(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPoint8Value] constructor from a single string representing
  /// space-separated bitfields
  factory FloatingPoint8Value.ofString(String fp) {
    final s = fp.split(' ');
    assert(s.length == 3, 'Wrong FloatingPointValue string length ${s.length}');
    return FloatingPoint8Value.ofStrings(s[0], s[1], s[2]);
  }

  /// Construct a [FloatingPoint8Value] from a Logic word
  factory FloatingPoint8Value.fromLogic(LogicValue val, int exponentWidth) {
    if (val.width != 8) {
      throw RohdHclException('Width must be 8');
    }

    final mantissaWidth = 7 - exponentWidth;
    if (!isLegal(exponentWidth, mantissaWidth)) {
      throw RohdHclException('FloatingPoint8 must follow E4M3 or E5M2');
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
    return FloatingPoint8Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// Numeric conversion of a [FloatingPoint8Value] from a host double
  factory FloatingPoint8Value.fromDouble(double inDouble,
      {required int exponentWidth}) {
    final mantissaWidth = 7 - exponentWidth;
    if (!isLegal(exponentWidth, mantissaWidth)) {
      throw RohdHclException('FloatingPoint8 must follow E4M3 or E5M2');
    }
    if (exponentWidth == 4) {
      if ((inDouble > _e4m3max) | (inDouble < _e4m3min)) {
        throw RohdHclException('Number exceeds E4M3 range');
      }
    } else if (exponentWidth == 5) {
      if ((inDouble > _e5m2max) | (inDouble < _e5m2min)) {
        throw RohdHclException('Number exceeds E5M2 range');
      }
    }
    final fpv = FloatingPointValue.fromDouble(inDouble,
        exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
    return FloatingPoint8Value(
        sign: fpv.sign, exponent: fpv.exponent, mantissa: fpv.mantissa);
  }
}
