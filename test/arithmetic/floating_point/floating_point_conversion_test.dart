import 'dart:math';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';
import 'package:rohd/rohd.dart';

void main() {
  test('FP: FP16 to FP32 conversion test', () {
    final fp32 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);

    print(Const(0, width: 3).eq(Const(0, width: 1)));

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
