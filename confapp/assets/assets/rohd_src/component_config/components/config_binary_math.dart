// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_binary_math.dart
// Configurators for binary-field and recurrence hardware.
//
// 2026 November 15
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

BigInt _hex(String text) => BigInt.parse(text.trim(), radix: 16);

List<String> _entries(String text) =>
    text.split(',').map((entry) => entry.trim()).toList();

BinaryMatrix _matrix(String text) =>
    BinaryMatrix.fromBinaryRows(_entries(text));

abstract class _BinaryMathConfigurator extends Configurator {
  @override
  ComponentCategory get category => ComponentCategory.binaryMath;
}

/// Configures a constant binary linear or affine transform.
class BinaryLinearTransformConfigurator extends _BinaryMathConfigurator {
  /// Comma-separated binary matrix rows, least-significant output first.
  final rowsKnob = StringConfigKnob(value: '0001, 0010, 0100, 1000');

  /// Packed affine offset in hexadecimal.
  final offsetKnob = StringConfigKnob(value: '0');

  /// XOR reduction radix.
  final radixKnob = IntConfigKnob(value: 2, minValue: 2);

  @override
  String get subcategory => 'algebra';
  @override
  String get name => 'Binary Linear/Affine Transform';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Matrix Rows (binary, output 0 first)': rowsKnob,
        'Affine Offset (hex)': offsetKnob,
        'XOR Radix': radixKnob,
      };
  @override
  Module createModule() {
    final matrix = _matrix(rowsKnob.value);
    return BinaryLinearTransform(
      Logic(name: 'data', width: matrix.columnCount),
      matrix: matrix,
      affineOffset: _hex(offsetKnob.value),
      radix: radixKnob.value,
    );
  }
}

abstract class _FiniteFieldConfigurator extends _BinaryMathConfigurator {
  /// Packed irreducible polynomial in hexadecimal.
  final modulusKnob = StringConfigKnob(value: '13');

  BinaryExtensionField get field => BinaryExtensionField(
      modulus: BinaryPolynomial.fromHex(modulusKnob.value.trim()));

  @override
  String get subcategory => 'finite-field';
}

/// Configures finite-field multiplication by a constant.
class GfConstantMultiplierConfigurator extends _FiniteFieldConfigurator {
  /// Packed field constant in hexadecimal.
  final constantKnob = StringConfigKnob(value: '2');
  @override
  String get name => 'GF Constant Multiplier';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Irreducible Polynomial (hex)': modulusKnob,
        'Constant (hex)': constantKnob,
      };
  @override
  Module createModule() {
    final field = this.field;
    return GfConstantMultiplier.typed(GfLogic(field, name: 'data'),
        constant: field.element(_hex(constantKnob.value)));
  }
}

/// Configures a finite-field inverse.
class GfInverseConfigurator extends _FiniteFieldConfigurator {
  @override
  String get name => 'GF Inverse';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs =>
      {'Irreducible Polynomial (hex)': modulusKnob};
  @override
  Module createModule() {
    final field = this.field;
    return GfInverse.typed(GfLogic(field, name: 'data'));
  }
}

/// Configures finite-field polynomial evaluation.
class GfPolynomialEvaluatorConfigurator extends _FiniteFieldConfigurator {
  /// Coefficients in hexadecimal, highest degree first.
  final coefficientsKnob = StringConfigKnob(value: '1, 2, 3');
  @override
  String get name => 'GF Polynomial Evaluator';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Irreducible Polynomial (hex)': modulusKnob,
        'Coefficients (hex, highest degree first)': coefficientsKnob,
      };
  @override
  Module createModule() {
    final field = this.field;
    return GfPolynomialEvaluator.typed(
      GfLogic(field, name: 'data'),
      coefficients: [
        for (final coefficient in _entries(coefficientsKnob.value))
          field.element(_hex(coefficient))
      ],
    );
  }
}

/// Configures a general registered binary linear recurrence.
class BinaryLinearRecurrenceConfigurator extends _BinaryMathConfigurator {
  /// State transition matrix in binary row order.
  final stateRowsKnob = StringConfigKnob(value: '0010, 0100, 1000, 0011');

  /// Whether to include input-driven state changes.
  final hasInputKnob = ToggleConfigKnob(value: false);

  /// Input matrix in binary row order.
  final inputRowsKnob = StringConfigKnob(value: '0, 0, 0, 1');

  /// Affine offset in hexadecimal.
  final offsetKnob = StringConfigKnob(value: '0');

  /// Reset state in hexadecimal.
  final initialKnob = StringConfigKnob(value: '1');

  /// Whether to expose an enable input.
  final enableKnob = ToggleConfigKnob(value: false);

  /// Whether to expose load and load-state inputs.
  final loadKnob = ToggleConfigKnob(value: false);

  @override
  String get subcategory => 'recurrence';
  @override
  String get name => 'Binary Linear Recurrence';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'State Matrix Rows (binary, state 0 first)': stateRowsKnob,
        'Input Matrix Enabled': hasInputKnob,
        if (hasInputKnob.value)
          'Input Matrix Rows (binary, state 0 first)': inputRowsKnob,
        'Affine Offset (hex)': offsetKnob,
        'Initial State (hex)': initialKnob,
        'Enable Input': enableKnob,
        'Load Input': loadKnob,
      };
  @override
  Module createModule() {
    final stateMatrix = _matrix(stateRowsKnob.value);
    final descriptor = BinaryLinearRecurrenceDescriptor(
      stateMatrix: stateMatrix,
      inputMatrix: hasInputKnob.value ? _matrix(inputRowsKnob.value) : null,
      offset: _hex(offsetKnob.value),
    );
    return BinaryLinearRecurrence(
      clk: Logic(name: 'clk'),
      reset: Logic(name: 'reset'),
      descriptor: descriptor,
      dataIn: descriptor.inputWidth == 0
          ? null
          : Logic(name: 'data', width: descriptor.inputWidth),
      enable: enableKnob.value ? Logic(name: 'enable') : null,
      load: loadKnob.value ? Logic(name: 'load') : null,
      loadState: loadKnob.value
          ? Logic(name: 'load_state', width: descriptor.stateWidth)
          : null,
      initialState: _hex(initialKnob.value),
    );
  }
}

abstract class _PolynomialLfsrConfigurator extends _BinaryMathConfigurator {
  /// Packed characteristic polynomial in hexadecimal.
  final polynomialKnob = StringConfigKnob(value: '13');

  /// Reset state in hexadecimal.
  final initialKnob = StringConfigKnob(value: '1');

  /// Whether to expose an enable input.
  final enableKnob = ToggleConfigKnob(value: false);
  LfsrDescriptor get descriptor =>
      LfsrDescriptor(BinaryPolynomial.fromHex(polynomialKnob.value.trim()));
  @override
  String get subcategory => 'recurrence';
}

/// Configures a serial Fibonacci LFSR.
class SerialLfsrConfigurator extends _PolynomialLfsrConfigurator {
  @override
  String get name => 'Serial LFSR';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Polynomial (hex)': polynomialKnob,
        'Initial State (hex)': initialKnob,
        'Enable Input': enableKnob,
      };
  @override
  Module createModule() => SerialLfsr(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        lfsrDescriptor: descriptor,
        initialState: _hex(initialKnob.value),
        enable: enableKnob.value ? Logic(name: 'enable') : null,
      );
}

/// Configures a parallel Fibonacci LFSR.
class ParallelLfsrConfigurator extends _PolynomialLfsrConfigurator {
  /// Serial advances per clock.
  final stepsKnob = PositiveIntConfigKnob(value: 4);
  @override
  String get name => 'Parallel LFSR';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Polynomial (hex)': polynomialKnob,
        'Initial State (hex)': initialKnob,
        'Steps Per Cycle': stepsKnob,
        'Enable Input': enableKnob,
      };
  @override
  Module createModule() => ParallelLfsr(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        lfsrDescriptor: descriptor,
        initialState: _hex(initialKnob.value),
        stepsPerCycle: stepsKnob.value,
        enable: enableKnob.value ? Logic(name: 'enable') : null,
      );
}

/// Configures an LFSR using zero-based feedback taps.
class LfsrConfigurator extends _BinaryMathConfigurator {
  /// Number of state bits.
  final widthKnob = PositiveIntConfigKnob(value: 4);

  /// Comma-separated zero-based state-bit indices.
  final tapsKnob = StringConfigKnob(value: '0, 1');

  /// Serial advances per clock.
  final stepsKnob = PositiveIntConfigKnob(value: 1);

  /// Reset state in hexadecimal.
  final initialKnob = StringConfigKnob(value: '1');

  /// Whether to expose an enable input.
  final enableKnob = ToggleConfigKnob(value: false);
  @override
  String get subcategory => 'recurrence';
  @override
  String get name => 'Tap-List LFSR';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'State Width': widthKnob,
        'Feedback Taps (zero-based)': tapsKnob,
        'Steps Per Cycle': stepsKnob,
        'Initial State (hex)': initialKnob,
        'Enable Input': enableKnob,
      };
  @override
  Module createModule() => Lfsr(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        stateWidth: widthKnob.value,
        feedbackTaps: _entries(tapsKnob.value).map(int.parse).toList(),
        stepsPerCycle: stepsKnob.value,
        initialState: _hex(initialKnob.value),
        enable: enableKnob.value ? Logic(name: 'enable') : null,
      );
}

/// Configures a multiple-input signature analyzer.
class SignatureAnalyzerConfigurator extends _PolynomialLfsrConfigurator {
  /// Number of input bits per cycle.
  final inputWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Whether to expose a clear input.
  final clearKnob = ToggleConfigKnob(value: false);
  @override
  String get name => 'Signature Analyzer';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Polynomial (hex)': polynomialKnob,
        'Initial Signature (hex)': initialKnob,
        'Input Width': inputWidthKnob,
        'Enable Input': enableKnob,
        'Clear Input': clearKnob,
      };
  @override
  Module createModule() => SignatureAnalyzer(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        dataIn: Logic(name: 'data', width: inputWidthKnob.value),
        descriptor: SignatureAnalyzerDescriptor(
            lfsrDescriptor: descriptor, inputWidth: inputWidthKnob.value),
        initialSignature: _hex(initialKnob.value),
        enable: enableKnob.value ? Logic(name: 'enable') : null,
        clear: clearKnob.value ? Logic(name: 'clear') : null,
      );
}

abstract class _PrbsConfigurator extends _BinaryMathConfigurator {
  /// Whether to use a custom polynomial instead of a standard.
  final customPolynomialKnob = ToggleConfigKnob(value: false);

  /// Custom characteristic polynomial in hexadecimal.
  final polynomialKnob = StringConfigKnob(value: 'c1');

  /// Standard PRBS polynomial.
  final standardKnob = ChoiceConfigKnob<PrbsStandard>(PrbsStandard.values,
      value: PrbsStandard.prbs7);

  /// Consecutive bits per cycle.
  final bitsKnob = PositiveIntConfigKnob(value: 1);

  /// Whether to override the standard all-ones seed.
  final customSeedKnob = ToggleConfigKnob(value: false);

  /// Custom seed in hexadecimal.
  final seedKnob = StringConfigKnob(value: '1');

  /// Whether to expose an enable input.
  final enableKnob = ToggleConfigKnob(value: false);
  PrbsConfiguration get configuration {
    final seed = customSeedKnob.value ? _hex(seedKnob.value) : null;
    return customPolynomialKnob.value
        ? PrbsConfiguration(
            polynomial: BinaryPolynomial.fromHex(polynomialKnob.value.trim()),
            seed: seed,
          )
        : PrbsConfiguration.standard(standardKnob.value, seed: seed);
  }

  @override
  String get subcategory => 'prbs';
  Map<String, ConfigKnob<dynamic>> get sharedKnobs => {
        'Custom Polynomial': customPolynomialKnob,
        if (customPolynomialKnob.value)
          'Polynomial (hex)': polynomialKnob
        else
          'Standard': standardKnob,
        'Bits Per Cycle': bitsKnob,
        'Custom Seed': customSeedKnob,
        if (customSeedKnob.value) 'Seed (hex)': seedKnob,
        'Enable Input': enableKnob,
      };
}

/// Configures a standard PRBS generator.
class PrbsGeneratorConfigurator extends _PrbsConfigurator {
  @override
  String get name => 'PRBS Generator';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => sharedKnobs;
  @override
  Module createModule() => PrbsGenerator(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        configuration: configuration,
        bitsPerCycle: bitsKnob.value,
        enable: enableKnob.value ? Logic(name: 'enable') : null,
      );
}

/// Configures a seed-aligned PRBS checker.
class PrbsCheckerConfigurator extends _PrbsConfigurator {
  /// Consecutive matches needed for lock.
  final lockKnob = PositiveIntConfigKnob(value: 4);

  /// Width of the saturating error count.
  final errorWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Whether to expose an error-counter clear input.
  final clearKnob = ToggleConfigKnob(value: false);
  @override
  String get name => 'PRBS Checker';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ...sharedKnobs,
        'Lock Threshold': lockKnob,
        'Error Count Width': errorWidthKnob,
        'Clear Errors Input': clearKnob,
      };
  @override
  Module createModule() => PrbsChecker(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        dataIn: Logic(name: 'data', width: bitsKnob.value),
        configuration: configuration,
        bitsPerCycle: bitsKnob.value,
        lockThreshold: lockKnob.value,
        errorCountWidth: errorWidthKnob.value,
        enable: enableKnob.value ? Logic(name: 'enable') : null,
        clearErrors: clearKnob.value ? Logic(name: 'clear_errors') : null,
      );
}
