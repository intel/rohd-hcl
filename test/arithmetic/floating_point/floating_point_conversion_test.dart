import 'dart:convert';
import 'dart:math';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';
import 'package:rohd/rohd.dart';


void main() {
  test('FP: packSpecial test', () {
    final fp32 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);

    const fp16MantissaWidth = 11;
    const fp16ExponentWidth = 5;

    final converter_fp32_fp16 = FloatingPointConverter(fp32,
        destExponentWidth: fp16ExponentWidth,
        destMantissaWidth: fp16MantissaWidth,
        name: 'FP32_to_FP16_Converter');

    final result = converter_fp32_fp16.result;
    final packedFP = converter_fp32_fp16.packSpecial(source: fp32, destExponentWidth: fp16ExponentWidth, destMantissaWidth: fp16MantissaWidth, isNaN: false);
    
    expect(packedFP.isInfinity(), true);
  });

  test('FP: FP64 to FP32 conversion test', () {
    // final fp64 = FloatingPoint64()
    //   ..put(FloatingPoint64Value.fromDouble(1.5).value);

    // const fp16MantissaWidth = 11;
    // const fp16ExponentWidth = 5;

    // final converter = FloatingPointConverter(fp64,
    //     destExponentWidth: fp16ExponentWidth,
    //     destMantissaWidth: fp16MantissaWidth,
    //     name: 'FP64_to_FP32_Converter');

    // final result = converter.result.value;
    // expect(result, equals(FloatingPoint32Value.fromDouble(1.5).value));

    // final packed = converter.packSpecial(source: fp64, destExponentWidth: fp16ExponentWidth, destMantissaWidth: fp16MantissaWidth, isNaN: false);
    // // expect(packed.exponent.width, matcher)


    // final converter = FloatingPointConverter(fp32,
    // Declare a constant for exponent width for FP16
    // const ingress_exponentWidth = 5;
    // const ingress_mantissaWidth = 11;

    // const egress_exponentWidth = 8;
    // const egress_mantissaWidth = 23;

    // Get FP16 value from a double, we will feed this FP16 value to both the software and hardware model, and then compare the results
    // var fp16val = FloatingPointValue.fromDouble(val,
    //     exponentWidth: ingress_exponentWidth,
    //     mantissaWidth: ingress_mantissaWidth);

    // // First get the exponent and rebias it
    // var fp16_exponent = fp16val.exponent;

    // // Re-bias the exponent for 32
    // var fp32_exponent = (fp16_exponent - fp16.bias()) +
    //     FloatingPointValue.computeBias(egress_exponentWidth);

    // // Zero extend the mantissa
    // var mantissa64 = fp16val.mantissa;

    // // Compare FP16 values
    // expect(fp16val, fp16val2);
  });
}
