// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// online_softmax_weighted_state.dart
// Mergeable weighted-value online softmax state and normalization.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';
import 'package:rohd_hcl/src/inference/fixed_point_approximation.dart';
import 'package:rohd_hcl/src/inference/group_scale_apply.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/online_softmax_state.dart';

/// Online softmax state with a weighted output-vector numerator.
/// {@category Inference}
class OnlineSoftmaxWeightedState extends LogicStructure {
  /// Scalar maximum, normalization sum, and status.
  late final OnlineSoftmaxState scalar;

  /// Weighted value-vector numerator relative to the scalar maximum.
  late final LogicArray weightedValues;

  /// Number of weighted output elements.
  final int valueCount;

  /// Width of every weighted output element.
  final int valueWidth;

  /// Fractional bits in every weighted output element.
  final int valueFractionBits;

  /// Creates a weighted online softmax state.
  OnlineSoftmaxWeightedState({
    required int scoreWidth,
    required int scoreFractionBits,
    required int normalizerWidth,
    required int normalizerFractionBits,
    required int valueCount,
    required int valueWidth,
    required int valueFractionBits,
    String name = 'onlineSoftmaxWeightedState',
  }) : this._(
          [
            OnlineSoftmaxState(
              scoreWidth: scoreWidth,
              scoreFractionBits: scoreFractionBits,
              normalizerWidth: normalizerWidth,
              normalizerFractionBits: normalizerFractionBits,
              name: 'scalar',
            ),
            LogicArray(
              [valueCount],
              valueWidth,
              name: 'weightedValues',
            ),
          ],
          valueCount: valueCount,
          valueWidth: valueWidth,
          valueFractionBits: valueFractionBits,
          name: name,
        );

  OnlineSoftmaxWeightedState._(
    List<Logic> elements, {
    required this.valueCount,
    required this.valueWidth,
    required this.valueFractionBits,
    required super.name,
  }) : super(elements) {
    if (valueCount < 1 ||
        valueWidth < 2 ||
        valueFractionBits < 0 ||
        valueFractionBits >= valueWidth) {
      throw ArgumentError('Weighted online softmax value format is invalid.');
    }
    scalar = elements[0] as OnlineSoftmaxState;
    weightedValues = elements[1] as LogicArray;
  }

  @override
  OnlineSoftmaxWeightedState clone({String? name}) =>
      OnlineSoftmaxWeightedState._(
        elements.map((element) => element.clone(name: element.name)).toList(),
        valueCount: valueCount,
        valueWidth: valueWidth,
        valueFractionBits: valueFractionBits,
        name: name ?? this.name,
      );
}

void _validateWeightedStates(
  OnlineSoftmaxWeightedState left,
  OnlineSoftmaxWeightedState right,
) {
  if (left.scalar.scoreWidth != right.scalar.scoreWidth ||
      left.scalar.scoreFractionBits != right.scalar.scoreFractionBits ||
      left.scalar.normalizerWidth != right.scalar.normalizerWidth ||
      left.scalar.normalizerFractionBits !=
          right.scalar.normalizerFractionBits ||
      left.valueCount != right.valueCount ||
      left.valueWidth != right.valueWidth ||
      left.valueFractionBits != right.valueFractionBits) {
    throw ArgumentError('Weighted online softmax state formats must match.');
  }
}

/// Merges two weighted online softmax states.
/// {@category Inference}
class OnlineSoftmaxWeightedMerge extends Module {
  /// Merged weighted state.
  late final OnlineSoftmaxWeightedState mergedState;

  /// Creates a weighted online state merge.
  OnlineSoftmaxWeightedMerge(
    OnlineSoftmaxWeightedState left,
    OnlineSoftmaxWeightedState right, {
    required int expWidth,
    required int expFractionBits,
    Exp2ApproximationFunctor exp2Implementation =
        lookupExp2ApproximationFunctor,
    InferenceMultiplierFunctor multiplierImplementation =
        nativeInferenceMultiplierFunctor,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
    super.name = 'online_softmax_weighted_merge',
  }) : super(
          definitionName: 'OnlineSoftmaxWeightedMerge_'
              'S${left.scalar.scoreWidth}F${left.scalar.scoreFractionBits}_'
              'N${left.scalar.normalizerWidth}'
              'F${left.scalar.normalizerFractionBits}_'
              'V${left.valueCount}W${left.valueWidth}'
              'F${left.valueFractionBits}_'
              'E${expWidth}F${expFractionBits}_'
              '${exp2Implementation.identity}_'
              '${multiplierImplementation.identity}_'
              '${roundingMode.name}_${overflowMode.name}',
        ) {
    _validateWeightedStates(left, right);
    left = addTypedInput('left', left);
    right = addTypedInput('right', right);
    final scalarMerge = OnlineSoftmaxMerge(
      left.scalar,
      right.scalar,
      expWidth: expWidth,
      expFractionBits: expFractionBits,
      exp2Implementation: exp2Implementation,
      roundingMode: roundingMode,
      name: '${name}_scalar_merge',
    );
    final leftScaleArray =
        LogicArray(const [1], expWidth, name: '${name}_left_scale');
    final rightScaleArray =
        LogicArray(const [1], expWidth, name: '${name}_right_scale');
    leftScaleArray.arrayElements.single <= scalarMerge.leftScale;
    rightScaleArray.arrayElements.single <= scalarMerge.rightScale;
    final scaledLeft = GroupScaleApply(
      left.weightedValues,
      leftScaleArray,
      groupSize: left.valueCount,
      fractionalBits: expFractionBits,
      outputWidth: left.valueWidth,
      signedScale: false,
      multiplierImplementation: multiplierImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_left_values',
    );
    final scaledRight = GroupScaleApply(
      right.weightedValues,
      rightScaleArray,
      groupSize: right.valueCount,
      fractionalBits: expFractionBits,
      outputWidth: right.valueWidth,
      signedScale: false,
      multiplierImplementation: multiplierImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_right_values',
    );

    final outputState = OnlineSoftmaxWeightedState(
      scoreWidth: left.scalar.scoreWidth,
      scoreFractionBits: left.scalar.scoreFractionBits,
      normalizerWidth: left.scalar.normalizerWidth,
      normalizerFractionBits: left.scalar.normalizerFractionBits,
      valueCount: left.valueCount,
      valueWidth: left.valueWidth,
      valueFractionBits: left.valueFractionBits,
      name: 'mergedState',
    );
    mergedState = addTypedOutput('mergedState', outputState.clone);
    mergedState.scalar.maximum <= scalarMerge.mergedState.maximum;
    mergedState.scalar.normalizer <= scalarMerge.mergedState.normalizer;
    mergedState.scalar.valid <= scalarMerge.mergedState.valid;
    var mergedOverflow = scalarMerge.mergedState.overflow |
        scaledLeft.overflowMask.or() |
        scaledLeft.underflowMask.or() |
        scaledRight.overflowMask.or() |
        scaledRight.underflowMask.or();
    mergedState.scalar.inexact <=
        scalarMerge.mergedState.inexact |
            scaledLeft.inexactMask.or() |
            scaledRight.inexactMask.or();
    mergedState.scalar.approximationError <=
        scalarMerge.mergedState.approximationError;

    for (var index = 0; index < left.valueCount; index++) {
      final calculationWidth = left.valueWidth + 1;
      final sum = (scaledLeft.scaledValues.arrayElements[index]
                  .signExtend(calculationWidth) +
              scaledRight.scaledValues.arrayElements[index]
                  .signExtend(calculationWidth))
          .getRange(0, calculationWidth);
      final narrowed = NumericNarrowing(
        sum,
        outputWidth: left.valueWidth,
        signed: true,
        overflowMode: overflowMode,
        name: '${name}_value_${index}_sum',
      );
      mergedState.weightedValues.arrayElements[index] <= narrowed.result;
      mergedOverflow =
          mergedOverflow | narrowed.overflowed | narrowed.underflowed;
    }
    mergedState.scalar.overflow <= mergedOverflow;
  }
}

/// Updates weighted online softmax state with one score/value pair.
/// {@category Inference}
class OnlineSoftmaxWeightedUpdate extends Module {
  /// Updated weighted state.
  late final OnlineSoftmaxWeightedState nextState;

  /// Creates a weighted one-score state update.
  OnlineSoftmaxWeightedUpdate(
    OnlineSoftmaxWeightedState state,
    Logic score,
    LogicArray value, {
    required int expWidth,
    required int expFractionBits,
    Logic? scoreValid,
    Exp2ApproximationFunctor exp2Implementation =
        lookupExp2ApproximationFunctor,
    InferenceMultiplierFunctor multiplierImplementation =
        nativeInferenceMultiplierFunctor,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
    super.name = 'online_softmax_weighted_update',
  }) : super(
          definitionName: 'OnlineSoftmaxWeightedUpdate_'
              'S${state.scalar.scoreWidth}_V${state.valueCount}_'
              'E${expWidth}F${expFractionBits}_'
              '${exp2Implementation.identity}_'
              '${multiplierImplementation.identity}_'
              '${roundingMode.name}_${overflowMode.name}_'
              'V${scoreValid == null ? 0 : 1}',
        ) {
    if (score.width != state.scalar.scoreWidth ||
        value.dimensions.length != 1 ||
        value.arrayElements.length != state.valueCount ||
        value.elementWidth != state.valueWidth) {
      throw ArgumentError(
        'Score and value must match the weighted state format.',
      );
    }
    final one = BigInt.one << state.scalar.normalizerFractionBits;
    if (one >= (BigInt.one << state.scalar.normalizerWidth)) {
      throw ArgumentError('Normalizer format cannot represent one.');
    }
    state = addTypedInput('state', state);
    score = addInput('score', score, width: score.width);
    value = addTypedInput('value', value);
    final localValid =
        scoreValid == null ? Const(1) : addInput('scoreValid', scoreValid);
    final singleton = OnlineSoftmaxWeightedState(
      scoreWidth: state.scalar.scoreWidth,
      scoreFractionBits: state.scalar.scoreFractionBits,
      normalizerWidth: state.scalar.normalizerWidth,
      normalizerFractionBits: state.scalar.normalizerFractionBits,
      valueCount: state.valueCount,
      valueWidth: state.valueWidth,
      valueFractionBits: state.valueFractionBits,
      name: '${name}_singleton',
    );
    singleton.scalar.maximum <= score;
    singleton.scalar.normalizer <=
        Const(one, width: state.scalar.normalizerWidth);
    singleton.scalar.valid <= localValid;
    singleton.scalar.overflow <= Const(0);
    singleton.scalar.inexact <= Const(0);
    singleton.scalar.approximationError <= Const(0);
    for (var index = 0; index < state.valueCount; index++) {
      singleton.weightedValues.arrayElements[index] <=
          mux(
            localValid,
            value.arrayElements[index],
            Const(0, width: state.valueWidth),
          );
    }
    final merge = OnlineSoftmaxWeightedMerge(
      state,
      singleton,
      expWidth: expWidth,
      expFractionBits: expFractionBits,
      exp2Implementation: exp2Implementation,
      multiplierImplementation: multiplierImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_merge',
    );
    final outputState = state.clone(name: 'nextState');
    nextState = addTypedOutput('nextState', outputState.clone);
    nextState.scalar.maximum <= merge.mergedState.scalar.maximum;
    nextState.scalar.normalizer <= merge.mergedState.scalar.normalizer;
    nextState.scalar.valid <= merge.mergedState.scalar.valid;
    nextState.scalar.overflow <= merge.mergedState.scalar.overflow;
    nextState.scalar.inexact <= merge.mergedState.scalar.inexact;
    nextState.scalar.approximationError <=
        merge.mergedState.scalar.approximationError;
    for (var index = 0; index < state.valueCount; index++) {
      nextState.weightedValues.arrayElements[index] <=
          merge.mergedState.weightedValues.arrayElements[index];
    }
  }
}

/// Divides a weighted softmax numerator by its normalization sum.
/// {@category Inference}
class OnlineSoftmaxNormalize extends Module {
  /// Normalized output values.
  late final LogicArray values;

  /// Input state contains no samples.
  Logic get invalidState => output('invalidState');

  /// Any arithmetic overflow or underflow was observed.
  Logic get overflow => output('overflow');

  /// Any approximation or scaling operation was inexact.
  Logic get inexact => output('inexact');

  /// Approximation input violated its configured contract.
  Logic get approximationError => output('approximationError');

  /// Creates fixed-point softmax output normalization.
  OnlineSoftmaxNormalize(
    OnlineSoftmaxWeightedState state, {
    required int reciprocalWidth,
    required int reciprocalFractionBits,
    required int outputWidth,
    PositiveApproximationFunctor reciprocalImplementation =
        lookupReciprocalApproximationFunctor,
    InferenceMultiplierFunctor multiplierImplementation =
        nativeInferenceMultiplierFunctor,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
    super.name = 'online_softmax_normalize',
  }) : super(
          definitionName: 'OnlineSoftmaxNormalize_'
              'N${state.scalar.normalizerWidth}'
              'F${state.scalar.normalizerFractionBits}_'
              'V${state.valueCount}W${state.valueWidth}_'
              'R${reciprocalWidth}F${reciprocalFractionBits}_'
              'O${outputWidth}_${reciprocalImplementation.identity}_'
              '${multiplierImplementation.identity}_'
              '${roundingMode.name}_${overflowMode.name}',
        ) {
    if (reciprocalImplementation.operation !=
        FixedPointApproximationOperation.reciprocal) {
      throw ArgumentError('A reciprocal approximation functor is required.');
    }
    if (state.scalar.normalizerWidth > 12) {
      throw ArgumentError(
        'Lookup reciprocal normalization supports normalizers through '
        '12 bits.',
      );
    }
    state = addTypedInput('state', state);
    final reciprocal = reciprocalImplementation(
      state.scalar.normalizer,
      inputFractionBits: state.scalar.normalizerFractionBits,
      outputWidth: reciprocalWidth,
      outputFractionBits: reciprocalFractionBits,
      minimumInputRaw: 1,
      maximumInputRaw: (1 << state.scalar.normalizerWidth) - 1,
      roundingMode: roundingMode,
      name: '${name}_reciprocal',
    );
    final scales = LogicArray(
      const [1],
      reciprocalWidth,
      name: '${name}_scale',
    );
    scales.arrayElements.single <= reciprocal.result;
    final normalized = GroupScaleApply(
      state.weightedValues,
      scales,
      groupSize: state.valueCount,
      fractionalBits: reciprocalFractionBits,
      outputWidth: outputWidth,
      activeMask: state.scalar.valid.replicate(state.valueCount),
      signedScale: false,
      multiplierImplementation: multiplierImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_values',
    );
    final outputValues = LogicArray(
      [state.valueCount],
      outputWidth,
      name: 'values',
    );
    values = addTypedOutput('values', outputValues.clone);
    for (var index = 0; index < state.valueCount; index++) {
      values.arrayElements[index] <=
          normalized.scaledValues.arrayElements[index];
    }
    addOutput('invalidState') <= ~state.scalar.valid;
    addOutput('overflow') <=
        state.scalar.overflow |
            normalized.overflowMask.or() |
            normalized.underflowMask.or() |
            (state.scalar.valid & reciprocal.status.overflow);
    addOutput('inexact') <=
        state.scalar.inexact |
            normalized.inexactMask.or() |
            (state.scalar.valid & reciprocal.status.inexact);
    addOutput('approximationError') <=
        state.scalar.approximationError |
            (state.scalar.valid &
                (reciprocal.status.invalidInput |
                    reciprocal.status.outOfRange));
  }
}
