// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_approximation.dart
// Fixed-point special-function approximation contracts and lookup hardware.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';

/// Fixed-point special function implemented by an approximation.
enum FixedPointApproximationOperation {
  /// Computes `2^x`.
  exp2,

  /// Computes `1 / x`.
  reciprocal,

  /// Computes `1 / sqrt(x)`.
  reciprocalSquareRoot,
}

/// Static shape, domain, and accuracy contract for one approximation.
@immutable
class FixedPointApproximationContract {
  /// Approximated mathematical operation.
  final FixedPointApproximationOperation operation;

  /// Width of the packed input.
  final int inputWidth;

  /// Number of input fractional bits.
  final int inputFractionBits;

  /// Whether the input uses two's-complement interpretation.
  final bool signedInput;

  /// Width of the packed output.
  final int outputWidth;

  /// Number of output fractional bits.
  final int outputFractionBits;

  /// Smallest accepted raw mathematical input.
  final int minimumInputRaw;

  /// Largest accepted raw mathematical input.
  final int maximumInputRaw;

  /// Rounding mode used to quantize the mathematical result.
  final NumericRoundingMode roundingMode;

  /// Maximum quantization error in output least-significant-bit units.
  final double maximumErrorLsb;

  /// Whether non-invalid outputs are monotonically nondecreasing.
  final bool monotonicallyIncreasing;

  /// Creates a validated approximation contract.
  FixedPointApproximationContract({
    required this.operation,
    required this.inputWidth,
    required this.inputFractionBits,
    required this.signedInput,
    required this.outputWidth,
    required this.outputFractionBits,
    required this.minimumInputRaw,
    required this.maximumInputRaw,
    required this.roundingMode,
    required this.maximumErrorLsb,
    required this.monotonicallyIncreasing,
  }) {
    if (inputWidth < 1 ||
        inputFractionBits < 0 ||
        inputFractionBits >= inputWidth ||
        outputWidth < 1 ||
        outputFractionBits < 0) {
      throw ArgumentError(
          'Approximation widths and fraction widths are invalid.');
    }
    final representableMinimum = signedInput ? -(1 << (inputWidth - 1)) : 0;
    final representableMaximum =
        signedInput ? (1 << (inputWidth - 1)) - 1 : (1 << inputWidth) - 1;
    if (minimumInputRaw < representableMinimum ||
        maximumInputRaw > representableMaximum ||
        minimumInputRaw > maximumInputRaw) {
      throw ArgumentError(
        'Approximation domain must fit the packed input representation.',
      );
    }
    if ((operation == FixedPointApproximationOperation.reciprocal ||
            operation ==
                FixedPointApproximationOperation.reciprocalSquareRoot) &&
        minimumInputRaw < 1) {
      throw ArgumentError(
        'Reciprocal operations require a strictly positive input domain.',
      );
    }
    if (maximumErrorLsb < 0) {
      throw ArgumentError.value(
        maximumErrorLsb,
        'maximumErrorLsb',
        'Must be non-negative.',
      );
    }
  }

  /// Stable identity suitable for generated definition names.
  String get configurationSignature => '${operation.name}_'
      'I${inputWidth}F${inputFractionBits}S${signedInput ? 1 : 0}_'
      'O${outputWidth}F${outputFractionBits}_'
      'D${minimumInputRaw}_${maximumInputRaw}_'
      '${roundingMode.name}';
}

/// Status produced by a fixed-point approximation.
class FixedPointApproximationStatus extends LogicStructure {
  /// Input is outside the mathematical domain.
  late final Logic invalidInput;

  /// Input is outside the configured approximation interval.
  late final Logic outOfRange;

  /// Mathematical result exceeds the output range.
  late final Logic overflow;

  /// Quantized output differs from the mathematical result.
  late final Logic inexact;

  /// Creates approximation status signals.
  FixedPointApproximationStatus({
    String name = 'fixedPointApproximationStatus',
  }) : this._(
          [
            Logic(name: 'invalidInput'),
            Logic(name: 'outOfRange'),
            Logic(name: 'overflow'),
            Logic(name: 'inexact'),
          ],
          name: name,
        );

  FixedPointApproximationStatus._(
    List<Logic> elements, {
    required super.name,
  }) : super(elements) {
    invalidInput = elements[0];
    outOfRange = elements[1];
    overflow = elements[2];
    inexact = elements[3];
  }

  @override
  FixedPointApproximationStatus clone({String? name}) =>
      FixedPointApproximationStatus._(
        elements.map((element) => element.clone(name: element.name)).toList(),
        name: name ?? this.name,
      );
}

/// Pure-Dart result from one fixed-point approximation lookup.
@immutable
class FixedPointApproximationReferenceResult {
  /// Quantized raw output.
  final BigInt result;

  /// Whether the mathematical input is invalid.
  final bool invalidInput;

  /// Whether the input was clamped to the configured interval.
  final bool outOfRange;

  /// Whether the mathematical result exceeded the output range.
  final bool overflow;

  /// Whether the quantized output differs from the mathematical result.
  final bool inexact;

  /// Creates an immutable reference result.
  const FixedPointApproximationReferenceResult({
    required this.result,
    required this.invalidInput,
    required this.outOfRange,
    required this.overflow,
    required this.inexact,
  });
}

/// Evaluates an approximation contract in software.
FixedPointApproximationReferenceResult evaluateFixedPointApproximation(
  FixedPointApproximationContract contract,
  int inputRaw,
) {
  final invalid = switch (contract.operation) {
    FixedPointApproximationOperation.exp2 => false,
    FixedPointApproximationOperation.reciprocal ||
    FixedPointApproximationOperation.reciprocalSquareRoot =>
      inputRaw <= 0,
  };
  final outOfRange = inputRaw < contract.minimumInputRaw ||
      inputRaw > contract.maximumInputRaw;
  final clamped = inputRaw.clamp(
    contract.minimumInputRaw,
    contract.maximumInputRaw,
  );
  final input = clamped / pow(2, contract.inputFractionBits);
  final value = switch (contract.operation) {
    FixedPointApproximationOperation.exp2 => pow(2, input).toDouble(),
    FixedPointApproximationOperation.reciprocal => 1.0 / input,
    FixedPointApproximationOperation.reciprocalSquareRoot => 1.0 / sqrt(input),
  };
  final scaled = value * pow(2, contract.outputFractionBits);
  final maximum = (BigInt.one << contract.outputWidth) - BigInt.one;
  final roundedBig = scaled.isFinite
      ? BigInt.from(_roundPositive(scaled, contract.roundingMode))
      : maximum + BigInt.one;
  final overflow = !scaled.isFinite || roundedBig > maximum;
  final result = invalid
      ? maximum
      : overflow
          ? maximum
          : roundedBig;
  final exactInteger = scaled.isFinite && scaled == scaled.truncateToDouble();
  return FixedPointApproximationReferenceResult(
    result: result,
    invalidInput: invalid,
    outOfRange: outOfRange,
    overflow: overflow,
    inexact: invalid || overflow || !exactInteger,
  );
}

int _roundPositive(double value, NumericRoundingMode mode) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'Must be finite.');
  }
  if (value <= 0) {
    return 0;
  }
  final floorValue = value.floor();
  final fraction = value - floorValue;
  return switch (mode) {
    NumericRoundingMode.truncate ||
    NumericRoundingMode.towardZero ||
    NumericRoundingMode.towardNegativeInfinity =>
      floorValue,
    NumericRoundingMode.towardPositiveInfinity => value.ceil(),
    NumericRoundingMode.nearestTiesAway =>
      fraction >= 0.5 ? floorValue + 1 : floorValue,
    NumericRoundingMode.nearestEven =>
      fraction > 0.5 || (fraction == 0.5 && floorValue.isOdd)
          ? floorValue + 1
          : floorValue,
  };
}

/// Common lookup-table implementation for fixed-point special functions.
abstract class FixedPointApproximation extends Module {
  /// Static approximation contract.
  final FixedPointApproximationContract contract;

  /// Quantized approximation result.
  Logic get result => output('result');

  /// Status associated with [result].
  late final FixedPointApproximationStatus status;

  /// Creates a full-domain combinational lookup approximation.
  FixedPointApproximation(
    Logic input, {
    required this.contract,
    required String definitionPrefix,
    super.name = 'fixed_point_approximation',
  }) : super(
          definitionName:
              '${definitionPrefix}_${contract.configurationSignature}',
        ) {
    if (input.width != contract.inputWidth) {
      throw PortWidthMismatchException(input, contract.inputWidth);
    }
    if ((1 << input.width) > 4096) {
      throw ArgumentError(
        'Lookup approximation inputs are limited to 4096 entries.',
      );
    }
    input = addInput('inputData', input, width: input.width);
    final entries = 1 << input.width;
    final results = <Logic>[];
    final invalidBits = <Logic>[];
    final rangeBits = <Logic>[];
    final overflowBits = <Logic>[];
    final inexactBits = <Logic>[];
    for (var encoded = 0; encoded < entries; encoded++) {
      final raw = contract.signedInput
          ? BigInt.from(encoded).toSigned(input.width).toInt()
          : encoded;
      final reference = evaluateFixedPointApproximation(contract, raw);
      results.add(Const(reference.result, width: contract.outputWidth));
      invalidBits.add(Const(reference.invalidInput ? 1 : 0));
      rangeBits.add(Const(reference.outOfRange ? 1 : 0));
      overflowBits.add(Const(reference.overflow ? 1 : 0));
      inexactBits.add(Const(reference.inexact ? 1 : 0));
    }
    addOutput('result', width: contract.outputWidth) <=
        results.selectIndex(input);
    final internalStatus = FixedPointApproximationStatus(
      name: '${name}_internal_status',
    );
    internalStatus.invalidInput <= invalidBits.selectIndex(input);
    internalStatus.outOfRange <= rangeBits.selectIndex(input);
    internalStatus.overflow <= overflowBits.selectIndex(input);
    internalStatus.inexact <= inexactBits.selectIndex(input);
    status = addTypedOutput('status', internalStatus.clone);
    status <= internalStatus;
  }
}

/// Combinational lookup approximation of `2^x`.
class Exp2Approximation extends FixedPointApproximation {
  /// Creates a fixed-point `2^x` lookup approximation.
  // ignore: use_super_parameters
  Exp2Approximation(
    Logic input, {
    required int inputFractionBits,
    required int outputWidth,
    required int outputFractionBits,
    int? minimumInputRaw,
    int? maximumInputRaw,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    super.name = 'exp2_approximation',
  }) : super(
          input,
          contract: FixedPointApproximationContract(
            operation: FixedPointApproximationOperation.exp2,
            inputWidth: input.width,
            inputFractionBits: inputFractionBits,
            signedInput: true,
            outputWidth: outputWidth,
            outputFractionBits: outputFractionBits,
            minimumInputRaw: minimumInputRaw ?? -(1 << (input.width - 1)),
            maximumInputRaw: maximumInputRaw ?? (1 << (input.width - 1)) - 1,
            roundingMode: roundingMode,
            maximumErrorLsb: roundingMode == NumericRoundingMode.nearestEven ||
                    roundingMode == NumericRoundingMode.nearestTiesAway
                ? 0.5
                : 1.0,
            monotonicallyIncreasing: true,
          ),
          definitionPrefix: 'Exp2Approximation',
        );
}

/// Combinational lookup approximation of `1 / x`.
class ReciprocalApproximation extends FixedPointApproximation {
  /// Creates a fixed-point reciprocal lookup approximation.
  // ignore: use_super_parameters
  ReciprocalApproximation(
    Logic input, {
    required int inputFractionBits,
    required int outputWidth,
    required int outputFractionBits,
    int minimumInputRaw = 1,
    int? maximumInputRaw,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    super.name = 'reciprocal_approximation',
  }) : super(
          input,
          contract: FixedPointApproximationContract(
            operation: FixedPointApproximationOperation.reciprocal,
            inputWidth: input.width,
            inputFractionBits: inputFractionBits,
            signedInput: false,
            outputWidth: outputWidth,
            outputFractionBits: outputFractionBits,
            minimumInputRaw: minimumInputRaw,
            maximumInputRaw: maximumInputRaw ?? (1 << input.width) - 1,
            roundingMode: roundingMode,
            maximumErrorLsb: roundingMode == NumericRoundingMode.nearestEven ||
                    roundingMode == NumericRoundingMode.nearestTiesAway
                ? 0.5
                : 1.0,
            monotonicallyIncreasing: false,
          ),
          definitionPrefix: 'ReciprocalApproximation',
        );
}

/// Combinational lookup approximation of `1 / sqrt(x)`.
class ReciprocalSqrtApproximation extends FixedPointApproximation {
  /// Creates a fixed-point reciprocal-square-root lookup approximation.
  // ignore: use_super_parameters
  ReciprocalSqrtApproximation(
    Logic input, {
    required int inputFractionBits,
    required int outputWidth,
    required int outputFractionBits,
    int minimumInputRaw = 1,
    int? maximumInputRaw,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    super.name = 'reciprocal_sqrt_approximation',
  }) : super(
          input,
          contract: FixedPointApproximationContract(
            operation: FixedPointApproximationOperation.reciprocalSquareRoot,
            inputWidth: input.width,
            inputFractionBits: inputFractionBits,
            signedInput: false,
            outputWidth: outputWidth,
            outputFractionBits: outputFractionBits,
            minimumInputRaw: minimumInputRaw,
            maximumInputRaw: maximumInputRaw ?? (1 << input.width) - 1,
            roundingMode: roundingMode,
            maximumErrorLsb: roundingMode == NumericRoundingMode.nearestEven ||
                    roundingMode == NumericRoundingMode.nearestTiesAway
                ? 0.5
                : 1.0,
            monotonicallyIncreasing: false,
          ),
          definitionPrefix: 'ReciprocalSqrtApproximation',
        );
}

/// Builder signature for a replaceable `2^x` approximation.
typedef Exp2ApproximationBuilder = FixedPointApproximation Function(
  Logic input, {
  required int inputFractionBits,
  required int outputWidth,
  required int outputFractionBits,
  required int minimumInputRaw,
  required int maximumInputRaw,
  required NumericRoundingMode roundingMode,
  required String name,
});

/// A named, replaceable `2^x` approximation implementation.
@immutable
class Exp2ApproximationFunctor {
  final Exp2ApproximationBuilder _build;

  /// Stable implementation identity.
  final String identity;

  /// Creates a named `2^x` implementation.
  const Exp2ApproximationFunctor({
    required this.identity,
    required Exp2ApproximationBuilder build,
  }) : _build = build;

  /// Builds one `2^x` approximation.
  FixedPointApproximation call(
    Logic input, {
    required int inputFractionBits,
    required int outputWidth,
    required int outputFractionBits,
    required int minimumInputRaw,
    required int maximumInputRaw,
    required String name,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
  }) =>
      _build(
        input,
        inputFractionBits: inputFractionBits,
        outputWidth: outputWidth,
        outputFractionBits: outputFractionBits,
        minimumInputRaw: minimumInputRaw,
        maximumInputRaw: maximumInputRaw,
        roundingMode: roundingMode,
        name: name,
      );
}

FixedPointApproximation _buildLookupExp2(
  Logic input, {
  required int inputFractionBits,
  required int outputWidth,
  required int outputFractionBits,
  required int minimumInputRaw,
  required int maximumInputRaw,
  required NumericRoundingMode roundingMode,
  required String name,
}) =>
    Exp2Approximation(
      input,
      inputFractionBits: inputFractionBits,
      outputWidth: outputWidth,
      outputFractionBits: outputFractionBits,
      minimumInputRaw: minimumInputRaw,
      maximumInputRaw: maximumInputRaw,
      roundingMode: roundingMode,
      name: name,
    );

/// Full-domain combinational lookup-table implementation of `2^x`.
const lookupExp2ApproximationFunctor = Exp2ApproximationFunctor(
  identity: 'lookup',
  build: _buildLookupExp2,
);

/// Builder signature for a replaceable positive-input approximation.
typedef PositiveApproximationBuilder = FixedPointApproximation Function(
  Logic input, {
  required int inputFractionBits,
  required int outputWidth,
  required int outputFractionBits,
  required int minimumInputRaw,
  required int maximumInputRaw,
  required NumericRoundingMode roundingMode,
  required String name,
});

/// A named positive-input approximation implementation.
@immutable
class PositiveApproximationFunctor {
  final PositiveApproximationBuilder _build;

  /// Stable implementation identity.
  final String identity;

  /// Mathematical operation built by this functor.
  final FixedPointApproximationOperation operation;

  /// Creates a named positive-input implementation.
  const PositiveApproximationFunctor({
    required this.identity,
    required this.operation,
    required PositiveApproximationBuilder build,
  }) : _build = build;

  /// Builds one positive-input approximation.
  FixedPointApproximation call(
    Logic input, {
    required int inputFractionBits,
    required int outputWidth,
    required int outputFractionBits,
    required int minimumInputRaw,
    required int maximumInputRaw,
    required String name,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
  }) =>
      _build(
        input,
        inputFractionBits: inputFractionBits,
        outputWidth: outputWidth,
        outputFractionBits: outputFractionBits,
        minimumInputRaw: minimumInputRaw,
        maximumInputRaw: maximumInputRaw,
        roundingMode: roundingMode,
        name: name,
      );
}

FixedPointApproximation _buildLookupReciprocal(
  Logic input, {
  required int inputFractionBits,
  required int outputWidth,
  required int outputFractionBits,
  required int minimumInputRaw,
  required int maximumInputRaw,
  required NumericRoundingMode roundingMode,
  required String name,
}) =>
    ReciprocalApproximation(
      input,
      inputFractionBits: inputFractionBits,
      outputWidth: outputWidth,
      outputFractionBits: outputFractionBits,
      minimumInputRaw: minimumInputRaw,
      maximumInputRaw: maximumInputRaw,
      roundingMode: roundingMode,
      name: name,
    );

FixedPointApproximation _buildLookupReciprocalSqrt(
  Logic input, {
  required int inputFractionBits,
  required int outputWidth,
  required int outputFractionBits,
  required int minimumInputRaw,
  required int maximumInputRaw,
  required NumericRoundingMode roundingMode,
  required String name,
}) =>
    ReciprocalSqrtApproximation(
      input,
      inputFractionBits: inputFractionBits,
      outputWidth: outputWidth,
      outputFractionBits: outputFractionBits,
      minimumInputRaw: minimumInputRaw,
      maximumInputRaw: maximumInputRaw,
      roundingMode: roundingMode,
      name: name,
    );

/// Full-domain combinational lookup-table reciprocal implementation.
const lookupReciprocalApproximationFunctor = PositiveApproximationFunctor(
  identity: 'lookupReciprocal',
  operation: FixedPointApproximationOperation.reciprocal,
  build: _buildLookupReciprocal,
);

/// Full-domain combinational lookup-table reciprocal-square-root
/// implementation.
const lookupReciprocalSqrtApproximationFunctor = PositiveApproximationFunctor(
  identity: 'lookupReciprocalSqrt',
  operation: FixedPointApproximationOperation.reciprocalSquareRoot,
  build: _buildLookupReciprocalSqrt,
);
