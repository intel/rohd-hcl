import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a single precision floating point value
class FloatingPoint32Value extends FloatingPointValue {
  /// The exponent width
  static const int exponentWidth = 8;

  /// The mantissa width
  static const int mantissaWidth = 23;

  @override
  @protected
  int get constrainedExponentWidth => exponentWidth;

  @override
  @protected
  int get constrainedMantissaWidth => mantissaWidth;

  /// Constructor for a single precision floating point value
  FloatingPoint32Value(
      {required super.sign, required super.exponent, required super.mantissa});

  /// Return the [FloatingPoint32Value] representing the constant specified
  factory FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPointValue.getFloatingPointConstant(
              constantFloatingPoint, exponentWidth, mantissaWidth)
          as FloatingPoint32Value;

  /// [FloatingPoint32Value] constructor from string representation of
  /// individual bitfields
  FloatingPoint32Value.ofBinaryStrings(
      super.sign, super.exponent, super.mantissa)
      : super.ofBinaryStrings();

  /// [FloatingPoint32Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPoint32Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPoint32Value] constructor from a set of [BigInt]s of the binary
  /// representation
  FloatingPoint32Value.ofBigInts(super.exponent, super.mantissa, {super.sign})
      : super.ofBigInts();

  /// [FloatingPoint32Value] constructor from a set of [int]s of the binary
  /// representation
  factory FloatingPoint32Value.ofInts(int exponent, int mantissa,
      {bool sign = false}) {
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      LogicValue.ofBigInt(BigInt.from(exponent), exponentWidth),
      LogicValue.ofBigInt(BigInt.from(mantissa), mantissaWidth)
    );

    return FloatingPoint32Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }

  /// Numeric conversion of a [FloatingPoint32Value] from a host double
  factory FloatingPoint32Value.fromDouble(double inDouble) {
    final byteData = ByteData(4)
      ..setFloat32(0, inDouble)
      ..buffer.asUint8List();
    final bytes = byteData.buffer.asUint8List();
    final lv = bytes.map((b) => LogicValue.ofInt(b, 32));

    final accum = lv.reduce((accum, v) => (accum << 8) | v);

    final sign = accum[-1];
    final exponent =
        accum.slice(exponentWidth + mantissaWidth - 1, mantissaWidth);
    final mantissa = accum.slice(mantissaWidth - 1, 0);

    return FloatingPoint32Value(
        sign: sign, exponent: exponent, mantissa: mantissa);
  }

  /// Construct a [FloatingPoint32Value] from a Logic word
  factory FloatingPoint32Value.fromLogic(LogicValue val) {
    final sign = (val[-1] == LogicValue.one);
    final exponent =
        val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth);
    final mantissa = val.slice(mantissaWidth - 1, 0);
    final (signLv, exponentLv, mantissaLv) = (
      LogicValue.ofBigInt(sign ? BigInt.one : BigInt.zero, 1),
      exponent,
      mantissa
    );
    return FloatingPoint32Value(
        sign: signLv, exponent: exponentLv, mantissa: mantissaLv);
  }
}
