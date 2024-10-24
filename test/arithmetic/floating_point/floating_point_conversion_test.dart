import 'dart:io';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  const fp32ExponentWidth = 8;
  const fp32MantissaWidth = 23;

  const bf19ExponentWidth = 8;
  const bf19MantissaWidth = 10;

  const bf16ExponentWidth = 8;
  const bf16MantissaWidth = 7;

  const fp16ExponentWidth = 5;
  const fp16MantissaWidth = 10;

  const bf8ExponentWidth = 5;
  const bf8MantissaWidth = 2;

  const hf8ExponentWidth = 4;
  const hf8MantissaWidth = 3;

  test('FP: pack infinity test', () {
    final fp32 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);

    final packedFPbf19 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: bf19ExponentWidth,
        destMantissaWidth: bf19MantissaWidth,
        isNaN: false);

    final packedFPbf16 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: bf16ExponentWidth,
        destMantissaWidth: bf16MantissaWidth,
        isNaN: false);

    final packedFPfp16 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: fp16ExponentWidth,
        destMantissaWidth: fp16MantissaWidth,
        isNaN: false);

    final packedFPbf8 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: bf8ExponentWidth,
        destMantissaWidth: bf8MantissaWidth,
        isNaN: false);

    final packedFPhf8 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: hf8ExponentWidth,
        destMantissaWidth: hf8MantissaWidth,
        isNaN: false);

    expect(packedFPbf19.isInfinity().value.toBool(), true);
    expect(packedFPbf16.isInfinity().value.toBool(), true);
    expect(packedFPfp16.isInfinity().value.toBool(), true);
    expect(packedFPbf8.isInfinity().value.toBool(), true);
    expect(packedFPhf8.isInfinity().value.toBool(), true);

    expect(packedFPbf19.isNaN().value.toBool(), false);
    expect(packedFPbf16.isNaN().value.toBool(), false);
    expect(packedFPfp16.isNaN().value.toBool(), false);
    expect(packedFPbf8.isNaN().value.toBool(), false);
    expect(packedFPhf8.isNaN().value.toBool(), false);
  });

  test('FP: pack nan test', () {
    final fp32 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);

    final packedFPbf19 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: bf19ExponentWidth,
        destMantissaWidth: bf19MantissaWidth,
        isNaN: true);

    final packedFPbf16 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: bf16ExponentWidth,
        destMantissaWidth: bf16MantissaWidth,
        isNaN: true);

    final packedFPfp16 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: fp16ExponentWidth,
        destMantissaWidth: fp16MantissaWidth,
        isNaN: true);

    final packedFPbf8 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: bf8ExponentWidth,
        destMantissaWidth: bf8MantissaWidth,
        isNaN: true);

    final packedFPhf8 = FloatingPointConverter.packSpecial(
        source: fp32,
        destExponentWidth: hf8ExponentWidth,
        destMantissaWidth: hf8MantissaWidth,
        isNaN: true);

    expect(packedFPbf19.isNaN().value.toBool(), true);
    expect(packedFPbf16.isNaN().value.toBool(), true);
    expect(packedFPfp16.isNaN().value.toBool(), true);
    expect(packedFPbf8.isNaN().value.toBool(), true);
    expect(packedFPhf8.isNaN().value.toBool(), true);

    expect(packedFPbf19.isInfinity().value.toBool(), false);
    expect(packedFPbf16.isInfinity().value.toBool(), false);
    expect(packedFPfp16.isInfinity().value.toBool(), false);
    expect(packedFPbf8.isInfinity().value.toBool(), false);
    expect(packedFPhf8.isInfinity().value.toBool(), false);
  });

  test('FP: adjust mantissa increase test', () {
    final sourceMantissa =
        Logic(name: 'sourceMantissa', width: fp16MantissaWidth);

    sourceMantissa <=
        Const(int.parse('1010101010', radix: 2), width: fp16MantissaWidth);

    final fp16Tofp32AdjustedMantissa =
        FloatingPointConverter.adjustMantissaPrecision(
            sourceMantissa,
            fp32MantissaWidth,
            Const(FloatingPointRoundingMode.roundNearestEven.index));

    expect(fp16Tofp32AdjustedMantissa.value.toInt(),
        int.parse('10101010100000000000000', radix: 2));
  });

  test('FP: adjust mantissa decrease test', () {
    final sourceMantissa =
        Logic(name: 'sourceMantissa', width: fp32MantissaWidth);

    sourceMantissa <=
        Const(int.parse('10101010101101001101011', radix: 2),
            width: fp32MantissaWidth);

    final fp32Tofp16AdjustedMantissa =
        FloatingPointConverter.adjustMantissaPrecision(
            sourceMantissa,
            fp16MantissaWidth,
            Const(FloatingPointRoundingMode.roundNearestEven.index));

    final fp32Tofp16AdjustedMantissaTruncate =
        FloatingPointConverter.adjustMantissaPrecision(sourceMantissa,
            fp16MantissaWidth, Const(FloatingPointRoundingMode.truncate.index));

    final fp32Tobf8AdjustedMantissa =
        FloatingPointConverter.adjustMantissaPrecision(
            sourceMantissa,
            bf8MantissaWidth,
            Const(FloatingPointRoundingMode.roundNearestEven.index));

    final fp32Tobf8AdjustedMantissaTruncate =
        FloatingPointConverter.adjustMantissaPrecision(sourceMantissa,
            bf8MantissaWidth, Const(FloatingPointRoundingMode.truncate.index));

    expect(fp32Tofp16AdjustedMantissa.value.toInt(),
        int.parse('1010101011', radix: 2));

    expect(fp32Tofp16AdjustedMantissaTruncate.value.toInt(),
        int.parse('1010101010', radix: 2));

    expect(fp32Tobf8AdjustedMantissa.value.toInt(), int.parse('11', radix: 2));

    expect(fp32Tobf8AdjustedMantissaTruncate.value.toInt(),
        int.parse('10', radix: 2));
  });

  test('FP: convert normal test', () {
    final fp32 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);

    final packedFPbf19 = FloatingPointConverter.convertNormalNumber(
      source: fp32,
      destExponentWidth: bf19ExponentWidth,
      destMantissaWidth: bf19MantissaWidth,
    );

    final packedFPbf16 = FloatingPointConverter.convertNormalNumber(
      source: fp32,
      destExponentWidth: bf16ExponentWidth,
      destMantissaWidth: bf16MantissaWidth,
    );

    final packedFPfp16 = FloatingPointConverter.convertNormalNumber(
      source: fp32,
      destExponentWidth: fp16ExponentWidth,
      destMantissaWidth: fp16MantissaWidth,
    );

    final packedFPbf8 = FloatingPointConverter.convertNormalNumber(
      source: fp32,
      destExponentWidth: bf8ExponentWidth,
      destMantissaWidth: bf8MantissaWidth,
    );

    final packedFPhf8 = FloatingPointConverter.convertNormalNumber(
      source: fp32,
      destExponentWidth: hf8ExponentWidth,
      destMantissaWidth: hf8MantissaWidth,
    );

    expect(packedFPbf19.isNormal().value.toBool(), true);
    expect(packedFPbf16.isNormal().value.toBool(), true);
    expect(packedFPfp16.isNormal().value.toBool(), true);
    expect(packedFPbf8.isNormal().value.toBool(), true);
    expect(packedFPhf8.isNormal().value.toBool(), true);
  });

  test('FP: converter builds', () {
    final fp32 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.512312312312312).value);

    final converter = FloatingPointConverter(fp32,
        destExponentWidth: bf19ExponentWidth,
        destMantissaWidth: bf19MantissaWidth,
        name: 'fp32_to_bf19');

    expect(converter.result.floatingPointValue.toString().contains('x'), false);
    expect(converter.result.floatingPointValue.toString().contains('z'), false);
  });

  test('FP: converter processes TestFloat vectors', () async {
    // Run testfloat_gen and capture its output
    // Get the current test file path
    final currentFilePath = Platform.script.toFilePath();
    print('Current test file: $currentFilePath');

    // Get the directory containing the test file
    final testDir = File(currentFilePath).parent.path;
    print('Test directory: $testDir');

    // Run testfloat_gen from a specific directory
    final result = await Process.run(
      'testfloat_gen',
      ['f32_to_f16'],
      workingDirectory: testDir,
    );
    if (result.exitCode != 0) {
      throw Exception('TestFloat failed: ${result.stderr}');
    }

    final testVectors = (result.stdout as String).split('\n');

    for (final line in testVectors) {
      if (line.trim().isEmpty) continue;

      final parts = line.trim().split(RegExp(r'\s+'));
      final inputHex = parts[0];
      final expectedHex = parts[1];
      final flags = parts[2];

      final inputBits = int.parse(inputHex, radix: 16);

      final fp32 = FloatingPoint32()..put(inputBits);

      final converter = FloatingPointConverter(fp32,
          destExponentWidth: fp16ExponentWidth,
          destMantissaWidth: fp16MantissaWidth,
          name: 'fp32_to_bf19');

      print('Test case:');
      print('  Input (hex): $inputHex');
      print('  Input (float): ${fp32.floatingPointValue}');
      print('  Expected (hex): $expectedHex');
      print('  Got: ${converter.result.floatingPointValue}');
      print('  Flags: $flags');
      print('---');
    }
  });
}
