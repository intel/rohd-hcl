// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_inference_compute.dart
// Configurators for inference arithmetic and online normalization.
//
// 2026 November 24
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures mixed-width products with static or runtime signedness.
class MixedPrecisionDotProductConfigurator extends Configurator {
  /// Number of products.
  final lanesKnob = PositiveIntConfigKnob(value: 2);

  /// Left operand width.
  final leftWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Right operand width.
  final rightWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Result width.
  final outputWidthKnob = PositiveIntConfigKnob(value: 16);

  /// Left operand interpretation.
  final signedLeftKnob = StaticOrRuntimeBoolKnob();

  /// Right operand interpretation.
  final signedRightKnob = StaticOrRuntimeBoolKnob();

  /// Result interpretation.
  final signedResultKnob = StaticOrRuntimeBoolKnob();

  /// Whether to expose lane masking.
  final maskKnob = ToggleConfigKnob(value: true);

  /// Whether to expose an initial accumulator.
  final initialValueKnob = ToggleConfigKnob(value: false);

  /// Overflow policy.
  final overflowKnob = ChoiceConfigKnob(NumericOverflowMode.values,
      value: NumericOverflowMode.saturate);

  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'compute';
  @override
  String get name => 'Mixed-Precision Dot Product';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Lanes': lanesKnob,
        'Left Width': leftWidthKnob,
        'Right Width': rightWidthKnob,
        'Output Width': outputWidthKnob,
        'Signed Left': signedLeftKnob,
        'Signed Right': signedRightKnob,
        'Signed Result': signedResultKnob,
        'Active Mask': maskKnob,
        'Initial Value': initialValueKnob,
        'Overflow': overflowKnob,
      };
  @override
  Module createModule() => MixedPrecisionDotProduct(
        LogicArray([lanesKnob.value], leftWidthKnob.value),
        LogicArray([lanesKnob.value], rightWidthKnob.value),
        outputWidth: outputWidthKnob.value,
        signedLeft: signedLeftKnob.resolve('signedLeft'),
        signedRight: signedRightKnob.resolve('signedRight'),
        signedResult: signedResultKnob.resolve('signedResult'),
        activeMask: maskKnob.value ? Logic(width: lanesKnob.value) : null,
        initialValue:
            initialValueKnob.value ? Logic(width: outputWidthKnob.value) : null,
        overflowMode: overflowKnob.value,
      );
}

/// Configures masked sum, minimum, and maximum reductions.
class VectorReduceConfigurator extends Configurator {
  /// Number of physical lanes.
  final lanesKnob = PositiveIntConfigKnob(value: 4);

  /// Lane width.
  final widthKnob = PositiveIntConfigKnob(value: 8);

  /// Reduction operation.
  final operationKnob = ChoiceConfigKnob(InferenceVectorReduction.values,
      value: InferenceVectorReduction.sum);

  /// Signed lane interpretation.
  final signedKnob = ToggleConfigKnob(value: true);

  /// Whether to expose lane masking.
  final maskKnob = ToggleConfigKnob(value: true);

  /// Optional result width; unset uses the operation's lossless default.
  final outputWidthKnob = IntOptionalConfigKnob(value: null);

  /// Overflow policy.
  final overflowKnob = ChoiceConfigKnob(NumericOverflowMode.values,
      value: NumericOverflowMode.saturate);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'compute';
  @override
  String get name => 'Vector Reduce';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Lanes': lanesKnob,
        'Element Width': widthKnob,
        'Operation': operationKnob,
        'Signed': signedKnob,
        'Active Mask': maskKnob,
        'Output Width': outputWidthKnob,
        'Overflow': overflowKnob,
      };
  @override
  Module createModule() => VectorReduce(
        LogicArray([lanesKnob.value], widthKnob.value),
        operation: operationKnob.value,
        signed: signedKnob.value,
        outputWidth: outputWidthKnob.value,
        overflowMode: overflowKnob.value,
        activeMask: maskKnob.value ? Logic(width: lanesKnob.value) : null,
      );
}

/// Configures grouped scaling, rounding, and zero-point application.
class GroupScaleApplyConfigurator extends Configurator {
  /// Physical lane count.
  final lanesKnob = PositiveIntConfigKnob(value: 4);

  /// Lanes sharing each scale.
  final groupSizeKnob = PositiveIntConfigKnob(value: 2);

  /// Input value width.
  final valueWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Scale width and fractional precision.
  final scaleKnob = InferenceFixedPointFormatKnob(fractionBits: 4);

  /// Output width.
  final outputWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Input value interpretation.
  final signedValueKnob =
      StaticOrRuntimeBoolKnob(value: StaticOrRuntimeBoolMode.enabled);

  /// Scale interpretation.
  final signedScaleKnob =
      StaticOrRuntimeBoolKnob(value: StaticOrRuntimeBoolMode.enabled);

  /// Output interpretation.
  final signedOutputKnob =
      StaticOrRuntimeBoolKnob(value: StaticOrRuntimeBoolMode.enabled);

  /// Whether to expose zero points.
  final zeroPointsKnob = ToggleConfigKnob(value: false);

  /// Whether to expose lane masking.
  final maskKnob = ToggleConfigKnob(value: true);

  /// Rounding policy.
  final roundingKnob = ChoiceConfigKnob(NumericRoundingMode.values,
      value: NumericRoundingMode.nearestEven);

  /// Overflow policy.
  final overflowKnob = ChoiceConfigKnob(NumericOverflowMode.values,
      value: NumericOverflowMode.saturate);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'compute';
  @override
  String get name => 'Group Scale Apply';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Lanes': lanesKnob,
        'Group Size': groupSizeKnob,
        'Value Width': valueWidthKnob,
        'Scale Format': scaleKnob,
        'Output Width': outputWidthKnob,
        'Signed Values': signedValueKnob,
        'Signed Scales': signedScaleKnob,
        'Signed Output': signedOutputKnob,
        'Zero Points': zeroPointsKnob,
        'Active Mask': maskKnob,
        'Rounding': roundingKnob,
        'Overflow': overflowKnob,
      };
  @override
  Module createModule() {
    final groups =
        (lanesKnob.value + groupSizeKnob.value - 1) ~/ groupSizeKnob.value;
    LogicArray array(int count, int width) => LogicArray([count], width);
    return GroupScaleApply(
      array(lanesKnob.value, valueWidthKnob.value),
      array(groups, scaleKnob.widthKnob.value),
      groupSize: groupSizeKnob.value,
      fractionalBits: scaleKnob.fractionBitsKnob.value,
      outputWidth: outputWidthKnob.value,
      signedValue: signedValueKnob.resolve('signedValue'),
      signedScale: signedScaleKnob.resolve('signedScale'),
      signedOutput: signedOutputKnob.resolve('signedOutput'),
      zeroPoints:
          zeroPointsKnob.value ? array(groups, outputWidthKnob.value) : null,
      activeMask: maskKnob.value ? Logic(width: lanesKnob.value) : null,
      roundingMode: roundingKnob.value,
      overflowMode: overflowKnob.value,
    );
  }
}

/// Configures the three bounded lookup approximation implementations.
class FixedPointApproximationConfigurator extends Configurator {
  /// Function to approximate.
  final operationKnob = ChoiceConfigKnob(
      FixedPointApproximationOperation.values,
      value: FixedPointApproximationOperation.exp2);

  /// Input width and fractional precision.
  final inputKnob = InferenceFixedPointFormatKnob(width: 4, fractionBits: 2);

  /// Output width and fractional precision.
  final outputKnob = InferenceFixedPointFormatKnob(fractionBits: 4);

  /// Optional minimum raw input; unset uses the operation's domain.
  final minimumKnob = IntOptionalConfigKnob(value: null);

  /// Optional maximum raw input; unset uses the operation's domain.
  final maximumKnob = IntOptionalConfigKnob(value: null);

  /// Quantization rounding.
  final roundingKnob = ChoiceConfigKnob(NumericRoundingMode.values,
      value: NumericRoundingMode.nearestEven);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'compute';
  @override
  String get name => 'Fixed-Point Approximation';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Operation': operationKnob,
        'Input Format': inputKnob,
        'Output Format': outputKnob,
        'Minimum Input Raw': minimumKnob,
        'Maximum Input Raw': maximumKnob,
        'Rounding': roundingKnob,
      };
  @override
  Module createModule() {
    final input = Logic(width: inputKnob.widthKnob.value);
    return switch (operationKnob.value) {
      FixedPointApproximationOperation.exp2 => Exp2Approximation(input,
          inputFractionBits: inputKnob.fractionBitsKnob.value,
          outputWidth: outputKnob.widthKnob.value,
          outputFractionBits: outputKnob.fractionBitsKnob.value,
          minimumInputRaw: minimumKnob.value,
          maximumInputRaw: maximumKnob.value,
          roundingMode: roundingKnob.value),
      FixedPointApproximationOperation.reciprocal => ReciprocalApproximation(
          input,
          inputFractionBits: inputKnob.fractionBitsKnob.value,
          outputWidth: outputKnob.widthKnob.value,
          outputFractionBits: outputKnob.fractionBitsKnob.value,
          minimumInputRaw: minimumKnob.value ?? 1,
          maximumInputRaw: maximumKnob.value,
          roundingMode: roundingKnob.value),
      FixedPointApproximationOperation.reciprocalSquareRoot =>
        ReciprocalSqrtApproximation(input,
            inputFractionBits: inputKnob.fractionBitsKnob.value,
            outputWidth: outputKnob.widthKnob.value,
            outputFractionBits: outputKnob.fractionBitsKnob.value,
            minimumInputRaw: minimumKnob.value ?? 1,
            maximumInputRaw: maximumKnob.value,
            roundingMode: roundingKnob.value),
    };
  }
}

/// Available online softmax state operations.
enum OnlineSoftmaxConfiguratorOperation {
  /// Merge scalar states.
  merge,

  /// Add one score to a scalar state.
  update,

  /// Merge weighted-vector states.
  weightedMerge,

  /// Add one score and value vector.
  weightedUpdate,

  /// Normalize a weighted-vector state.
  normalize,
}

/// Configures scalar and weighted online softmax state operations.
class OnlineSoftmaxConfigurator extends Configurator {
  /// State operation.
  final operationKnob = ChoiceConfigKnob(
      OnlineSoftmaxConfiguratorOperation.values,
      value: OnlineSoftmaxConfiguratorOperation.merge);

  /// Score format.
  final scoreKnob = InferenceFixedPointFormatKnob(width: 4);

  /// Normalization sum format.
  final normalizerKnob = InferenceFixedPointFormatKnob(fractionBits: 4);

  /// Exponential scale format.
  final expKnob = InferenceFixedPointFormatKnob(width: 6, fractionBits: 4);

  /// Number of weighted values.
  final valueCountKnob = PositiveIntConfigKnob(value: 2);

  /// Weighted value format.
  final valueKnob = InferenceFixedPointFormatKnob();

  /// Reciprocal scale format.
  final reciprocalKnob = InferenceFixedPointFormatKnob(fractionBits: 6);

  /// Normalized output width.
  final outputWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Rounding policy.
  final roundingKnob = ChoiceConfigKnob(NumericRoundingMode.values,
      value: NumericRoundingMode.nearestEven);

  /// Overflow policy for weighted arithmetic.
  final overflowKnob = ChoiceConfigKnob(NumericOverflowMode.values,
      value: NumericOverflowMode.saturate);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'normalization';
  @override
  String get name => 'Online Softmax';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Operation': operationKnob,
        'Score Format': scoreKnob,
        'Normalizer Format': normalizerKnob,
        if (operationKnob.value != OnlineSoftmaxConfiguratorOperation.normalize)
          'Exponential Format': expKnob,
        if (operationKnob.value != OnlineSoftmaxConfiguratorOperation.merge &&
            operationKnob.value !=
                OnlineSoftmaxConfiguratorOperation.update) ...{
          'Value Count': valueCountKnob,
          'Value Format': valueKnob,
          'Overflow': overflowKnob,
        },
        if (operationKnob.value ==
            OnlineSoftmaxConfiguratorOperation.normalize) ...{
          'Reciprocal Format': reciprocalKnob,
          'Output Width': outputWidthKnob,
        },
        'Rounding': roundingKnob,
      };
  @override
  Module createModule() {
    OnlineSoftmaxState scalar() => OnlineSoftmaxState(
        scoreWidth: scoreKnob.widthKnob.value,
        scoreFractionBits: scoreKnob.fractionBitsKnob.value,
        normalizerWidth: normalizerKnob.widthKnob.value,
        normalizerFractionBits: normalizerKnob.fractionBitsKnob.value);
    OnlineSoftmaxWeightedState weighted() => OnlineSoftmaxWeightedState(
        scoreWidth: scoreKnob.widthKnob.value,
        scoreFractionBits: scoreKnob.fractionBitsKnob.value,
        normalizerWidth: normalizerKnob.widthKnob.value,
        normalizerFractionBits: normalizerKnob.fractionBitsKnob.value,
        valueCount: valueCountKnob.value,
        valueWidth: valueKnob.widthKnob.value,
        valueFractionBits: valueKnob.fractionBitsKnob.value);
    return switch (operationKnob.value) {
      OnlineSoftmaxConfiguratorOperation.merge => OnlineSoftmaxMerge(
          scalar(), scalar(),
          expWidth: expKnob.widthKnob.value,
          expFractionBits: expKnob.fractionBitsKnob.value,
          roundingMode: roundingKnob.value),
      OnlineSoftmaxConfiguratorOperation.update => OnlineSoftmaxUpdate(
          scalar(), Logic(width: scoreKnob.widthKnob.value),
          scoreValid: Logic(),
          expWidth: expKnob.widthKnob.value,
          expFractionBits: expKnob.fractionBitsKnob.value,
          roundingMode: roundingKnob.value),
      OnlineSoftmaxConfiguratorOperation.weightedMerge =>
        OnlineSoftmaxWeightedMerge(weighted(), weighted(),
            expWidth: expKnob.widthKnob.value,
            expFractionBits: expKnob.fractionBitsKnob.value,
            roundingMode: roundingKnob.value,
            overflowMode: overflowKnob.value),
      OnlineSoftmaxConfiguratorOperation.weightedUpdate =>
        OnlineSoftmaxWeightedUpdate(
            weighted(),
            Logic(width: scoreKnob.widthKnob.value),
            LogicArray([valueCountKnob.value], valueKnob.widthKnob.value),
            scoreValid: Logic(),
            expWidth: expKnob.widthKnob.value,
            expFractionBits: expKnob.fractionBitsKnob.value,
            roundingMode: roundingKnob.value,
            overflowMode: overflowKnob.value),
      OnlineSoftmaxConfiguratorOperation.normalize => OnlineSoftmaxNormalize(
          weighted(),
          reciprocalWidth: reciprocalKnob.widthKnob.value,
          reciprocalFractionBits: reciprocalKnob.fractionBitsKnob.value,
          outputWidth: outputWidthKnob.value,
          roundingMode: roundingKnob.value,
          overflowMode: overflowKnob.value),
    };
  }
}

/// Configures fixed-point RMS normalization.
class RmsNormConfigurator extends Configurator {
  /// Physical lane count.
  final lanesKnob = PositiveIntConfigKnob(value: 2);

  /// Input value format.
  final valueKnob = InferenceFixedPointFormatKnob(width: 4, fractionBits: 1);

  /// Per-lane weight format.
  final weightKnob = InferenceFixedPointFormatKnob(width: 4, fractionBits: 1);

  /// Quantized mean-square width.
  final meanSquareWidthKnob = PositiveIntConfigKnob(value: 6);

  /// Active-count reciprocal format.
  final countReciprocalKnob = InferenceFixedPointFormatKnob(fractionBits: 6);

  /// Inverse-RMS scale format.
  final inverseRmsKnob = InferenceFixedPointFormatKnob(fractionBits: 6);

  /// Output width.
  final outputWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Positive epsilon in raw mean-square units.
  final epsilonKnob = PositiveIntConfigKnob(value: 1);

  /// Static or runtime weight signedness.
  final signedWeightsKnob =
      StaticOrRuntimeBoolKnob(value: StaticOrRuntimeBoolMode.enabled);

  /// Whether to expose lane masking.
  final maskKnob = ToggleConfigKnob(value: true);

  /// Rounding policy.
  final roundingKnob = ChoiceConfigKnob(NumericRoundingMode.values,
      value: NumericRoundingMode.nearestEven);

  /// Overflow policy.
  final overflowKnob = ChoiceConfigKnob(NumericOverflowMode.values,
      value: NumericOverflowMode.saturate);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'normalization';
  @override
  String get name => 'RMS Normalization';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Lanes': lanesKnob,
        'Value Format': valueKnob,
        'Weight Format': weightKnob,
        'Signed Weights': signedWeightsKnob,
        'Mean-Square Width': meanSquareWidthKnob,
        'Count Reciprocal Format': countReciprocalKnob,
        'Inverse RMS Format': inverseRmsKnob,
        'Output Width': outputWidthKnob,
        'Epsilon Raw': epsilonKnob,
        'Active Mask': maskKnob,
        'Rounding': roundingKnob,
        'Overflow': overflowKnob,
      };
  @override
  Module createModule() => RmsNorm(
        LogicArray([lanesKnob.value], valueKnob.widthKnob.value),
        LogicArray([lanesKnob.value], weightKnob.widthKnob.value),
        valueFractionBits: valueKnob.fractionBitsKnob.value,
        weightFractionBits: weightKnob.fractionBitsKnob.value,
        meanSquareWidth: meanSquareWidthKnob.value,
        countReciprocalWidth: countReciprocalKnob.widthKnob.value,
        countReciprocalFractionBits: countReciprocalKnob.fractionBitsKnob.value,
        inverseRmsWidth: inverseRmsKnob.widthKnob.value,
        inverseRmsFractionBits: inverseRmsKnob.fractionBitsKnob.value,
        outputWidth: outputWidthKnob.value,
        epsilonRaw: epsilonKnob.value,
        signedWeights: signedWeightsKnob.resolve('signedWeights'),
        activeMask: maskKnob.value ? Logic(width: lanesKnob.value) : null,
        roundingMode: roundingKnob.value,
        overflowMode: overflowKnob.value,
      );
}

/// Configures narrowing with a runtime shift input.
class DynamicNumericNarrowingConfigurator extends NumericNarrowingConfigurator {
  /// Width of the runtime shift.
  final shiftWidthKnob = PositiveIntConfigKnob(value: 4);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'compute';
  @override
  String get name => 'Dynamic Numeric Narrowing';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs =>
      (super.knobs..remove('Right Shift'))..['Shift Width'] = shiftWidthKnob;
  @override
  Module createModule() => DynamicNumericNarrowing(
        Logic(width: inputWidthKnob.value),
        Logic(width: shiftWidthKnob.value),
        outputWidth: outputWidthKnob.value,
        signed: signedKnob.value,
        roundingMode: roundingKnob.value,
        overflowMode: overflowKnob.value,
      );
}
