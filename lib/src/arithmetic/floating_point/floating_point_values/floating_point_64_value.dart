import 'dart:typed_data';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A representation of a double precision floating point value
class FloatingPoint64Value extends FloatingPointValue {
  /// The exponent width
  static const int _exponentWidth = 11;

  /// The mantissa width
  static const int _mantissaWidth = 52;

  /// return the exponent width
  static int get exponentWidth => _exponentWidth;

  /// return the mantissa width
  static int get mantissaWidth => _mantissaWidth;

  /// Constructor for a double precision floating point value
  FloatingPoint64Value(
      {required super.sign, required super.mantissa, required super.exponent});

  /// Return the [FloatingPoint64Value] representing the constant specified
  factory FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants constantFloatingPoint) =>
      FloatingPoint64Value.fromLogic(
          FloatingPointValue.getFloatingPointConstant(
                  constantFloatingPoint, _exponentWidth, _mantissaWidth)
              .value);

  /// [FloatingPoint64Value] constructor from string representation of
  /// individual bitfields
  factory FloatingPoint64Value.ofBinaryStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPoint64Value(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPoint64Value] constructor from spaced string representation of
  /// individual bitfields
  FloatingPoint64Value.ofSpacedBinaryString(super.fp)
      : super.ofSpacedBinaryString();

  /// [FloatingPoint64Value] constructor from a single string representing
  /// space-separated bitfields
  FloatingPoint64Value.ofString(String fp, {super.radix})
      : super.ofString(fp, exponentWidth, mantissaWidth);

  /// [FloatingPoint64Value] constructor from a set of [BigInt]s of the binary
  /// representation
  FloatingPoint64Value.ofBigInts(super.exponent, super.mantissa, {super.sign})
      : super.ofBigInts();

  /// [FloatingPoint64Value] constructor from a set of [int]s of the binary
  /// representation
  FloatingPoint64Value.ofInts(super.exponent, super.mantissa, {super.sign})
      : super.ofInts();

  /// Numeric conversion of a [FloatingPoint64Value] from a host double
  factory FloatingPoint64Value.fromDouble(double inDouble) {
    final byteData = ByteData(8)
      ..setFloat64(0, inDouble)
      ..buffer.asUint8List();

    final accum = byteData.buffer
        .asUint8List()
        .map((b) => LogicValue.ofInt(b, 64))
        .reduce((accum, v) => (accum << 8) | v);

    return FloatingPoint64Value(
        sign: accum[-1],
        exponent:
            accum.slice(_exponentWidth + _mantissaWidth - 1, _mantissaWidth),
        mantissa: accum.slice(_mantissaWidth - 1, 0));
  }

  /// Construct a [FloatingPoint32Value] from a Logic word
  factory FloatingPoint64Value.fromLogic(LogicValue val) =>
      FloatingPoint64Value(
          sign: LogicValue.ofBigInt(
              (val[-1] == LogicValue.one) ? BigInt.one : BigInt.zero, 1),
          exponent: val.slice(exponentWidth + mantissaWidth - 1, mantissaWidth),
          mantissa: val.slice(mantissaWidth - 1, 0));
}
