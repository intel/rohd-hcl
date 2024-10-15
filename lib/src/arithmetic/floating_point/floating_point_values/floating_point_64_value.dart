import 'dart:typed_data';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a double precision floating point value
class FloatingPoint64Value extends FloatingPointValue {
  static const int _exponentWidth = 11;
  static const int _mantissaWidth = 52;

  /// return the exponent width
  static int get exponentWidth => _exponentWidth;

  /// return the mantissa width
  static int get mantissaWidth => _mantissaWidth;

  /// Constructor for a double precision floating point value
  FloatingPoint64Value(
      {required super.sign, required super.mantissa, required super.exponent})
      : super.withConstraints(
            constrainExponentWidth: exponentWidth,
            constrainMantissaWidth: mantissaWidth);

  /// Return the [FloatingPoint64Value] representing the constant specified
  factory FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPointValue.getFloatingPointConstant(
              constantFloatingPoint, _exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// [FloatingPoint64Value] constructor from string representation of
  /// individual bitfields
  factory FloatingPoint64Value.ofStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPoint64Value(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPoint64Value] constructor from a single string representing
  /// space-separated bitfields
  factory FloatingPoint64Value.ofString(String fp) {
    final s = fp.split(' ');
    assert(s.length == 3, 'Wrong FloatingPointValue string length ${s.length}');
    return FloatingPoint64Value.ofStrings(s[0], s[1], s[2]);
  }

  /// [FloatingPoint64Value] constructor from a set of [BigInt]s of the binary
  /// representation
  factory FloatingPoint64Value.ofBigInts(BigInt exponent, BigInt mantissa,
          {bool sign = false}) =>
      FloatingPointValue.ofBigInts(exponent, mantissa,
          sign: sign,
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth) as FloatingPoint64Value;

  /// [FloatingPoint64Value] constructor from a set of [int]s of the binary
  /// representation
  factory FloatingPoint64Value.ofInts(int exponent, int mantissa,
          {bool sign = false}) =>
      FloatingPointValue.ofInts(exponent, mantissa,
          sign: sign,
          exponentWidth: exponentWidth,
          mantissaWidth: mantissaWidth) as FloatingPoint64Value;

  /// Numeric conversion of a [FloatingPoint64Value] from a host double
  factory FloatingPoint64Value.fromDouble(double inDouble) {
    final byteData = ByteData(8)
      ..setFloat64(0, inDouble)
      ..buffer.asUint8List();
    final bytes = byteData.buffer.asUint8List();
    final lv = bytes.map((b) => LogicValue.ofInt(b, 64));

    final accum = lv.reduce((accum, v) => (accum << 8) | v);

    final sign = accum[-1];
    final exponent =
        accum.slice(_exponentWidth + _mantissaWidth - 1, _mantissaWidth);
    final mantissa = accum.slice(_mantissaWidth - 1, 0);

    return FloatingPoint64Value(
        sign: sign, mantissa: mantissa, exponent: exponent);
  }

  /// Construct a [FloatingPoint32Value] from a Logic word
  factory FloatingPoint64Value.fromLogic(LogicValue val) {
    final sign = (val[-1] == LogicValue.one);
    final exponent =
        val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth).toBigInt();
    final mantissa = val.slice(mantissaWidth - 1, 0).toBigInt();
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(exponent, exponentWidth),
      LogicValue.ofBigInt(mantissa, mantissaWidth)
    );
    return FloatingPoint64Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }
}
