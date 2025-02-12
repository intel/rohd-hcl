//TODO: header

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// The E4M3 representation of a 8-bit floating point value as defined in
/// [FP8 Formats for Deep Learning](https://arxiv.org/abs/2209.05433).
class FloatingPoint8E4M3Value extends FloatingPointValue {
  @override
  final int exponentWidth = 4;

  @override
  final int mantissaWidth = 3;

  /// Constructor for an 8-bit E4M3 floating point value.
  factory FloatingPoint8E4M3Value(
          {required LogicValue sign,
          required LogicValue exponent,
          required LogicValue mantissa}) =>
      populator().populate(sign: sign, exponent: exponent, mantissa: mantissa);

  @protected
  @override
  FloatingPoint8E4M3Value.unpop() : super.uninitialized();

  static FloatingPointValuePopulator<FloatingPoint8E4M3Value> populator() =>
      FloatingPointValuePopulator(FloatingPoint8E4M3Value.unpop());

  @override
  FloatingPointValuePopulator clonePopulator() => populator();

  /// The maximum value representable by the E4M3 format
  static double get maxValue =>
      populator().ofConstant(FloatingPointConstants.largestNormal).toDouble();

  /// The minimum value representable by the E4M3 format
  static double get minValue => populator()
      .ofConstant(FloatingPointConstants.smallestPositiveSubnormal)
      .toDouble();

  /// Inf is not representable in this format
  @override
  bool get isAnInfinity => false;

  @override
  bool get isNaN => (exponent.toInt() == 15) && (mantissa.toInt() == 7);

  /// Override the toDouble to avoid NaN
  @override
  double toDouble() {
    if (exponent.toInt() == 15) {
      return 448;
    }
    return super.toDouble();
  }

  @override
  @protected
  ({LogicValue sign, LogicValue exponent, LogicValue mantissa})
      getConstantComponents(FloatingPointConstants constantFloatingPoint) {
    final (
      String signStr,
      String exponentStr,
      String mantissaStr
    ) stringComponents;

    switch (constantFloatingPoint) {
      /// Largest positive number, most positive exponent, full mantissa
      case FloatingPointConstants.largestNormal:
        stringComponents =
            ('0', '1' * exponentWidth, '${'1' * (mantissaWidth - 1)}0');
      case FloatingPointConstants.nan:
        stringComponents =
            ('0', '${'1' * (exponentWidth - 1)}1', '1' * mantissaWidth);
      case FloatingPointConstants.positiveInfinity:
      case FloatingPointConstants.negativeInfinity:
        throw RohdHclException('Infinity is not representable in this format');
      case _:
        return super.getConstantComponents(constantFloatingPoint);
    }

    return (
      sign: LogicValue.of(stringComponents.$1),
      exponent: LogicValue.of(stringComponents.$2),
      mantissa: LogicValue.of(stringComponents.$3)
    );
  }
}
