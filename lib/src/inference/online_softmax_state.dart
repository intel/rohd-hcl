// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// online_softmax_state.dart
// Mergeable online fixed-point softmax normalization state.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';
import 'package:rohd_hcl/src/inference/fixed_point_approximation.dart';
import 'package:rohd_hcl/src/inference/group_scale_apply.dart';
import 'package:rohd_hcl/src/inference/vector_reduce.dart';

/// Mergeable maximum and normalization sum for online softmax.
///
/// [maximum] is a signed fixed-point score. [normalizer] is an unsigned
/// fixed-point sum relative to [maximum].
/// {@category Inference}
class OnlineSoftmaxState extends LogicStructure {
  /// Running signed maximum score.
  late final Logic maximum;

  /// Running unsigned normalization sum.
  late final Logic normalizer;

  /// Whether this state contains at least one score.
  late final Logic valid;

  /// Whether arithmetic saturation occurred while producing this state.
  late final Logic overflow;

  /// Whether any approximation or fixed-point rescaling was inexact.
  late final Logic inexact;

  /// Whether an approximation input violated its configured contract.
  late final Logic approximationError;

  /// Width of [maximum].
  final int scoreWidth;

  /// Fractional bits in [maximum].
  final int scoreFractionBits;

  /// Width of [normalizer].
  final int normalizerWidth;

  /// Fractional bits in [normalizer].
  final int normalizerFractionBits;

  /// Creates an online softmax state shape.
  OnlineSoftmaxState({
    required int scoreWidth,
    required int scoreFractionBits,
    required int normalizerWidth,
    required int normalizerFractionBits,
    String name = 'onlineSoftmaxState',
  }) : this._(
          [
            Logic(name: 'maximum', width: scoreWidth),
            Logic(name: 'normalizer', width: normalizerWidth),
            Logic(name: 'valid'),
            Logic(name: 'overflow'),
            Logic(name: 'inexact'),
            Logic(name: 'approximationError'),
          ],
          scoreWidth: scoreWidth,
          scoreFractionBits: scoreFractionBits,
          normalizerWidth: normalizerWidth,
          normalizerFractionBits: normalizerFractionBits,
          name: name,
        );

  OnlineSoftmaxState._(
    List<Logic> elements, {
    required this.scoreWidth,
    required this.scoreFractionBits,
    required this.normalizerWidth,
    required this.normalizerFractionBits,
    required super.name,
  }) : super(elements) {
    if (scoreWidth < 2 ||
        scoreFractionBits < 0 ||
        scoreFractionBits >= scoreWidth ||
        normalizerWidth < 2 ||
        normalizerFractionBits < 0 ||
        normalizerFractionBits >= normalizerWidth) {
      throw ArgumentError('Online softmax state formats are invalid.');
    }
    maximum = elements[0];
    normalizer = elements[1];
    valid = elements[2];
    overflow = elements[3];
    inexact = elements[4];
    approximationError = elements[5];
  }

  @override
  OnlineSoftmaxState clone({String? name}) => OnlineSoftmaxState._(
        elements.map((element) => element.clone(name: element.name)).toList(),
        scoreWidth: scoreWidth,
        scoreFractionBits: scoreFractionBits,
        normalizerWidth: normalizerWidth,
        normalizerFractionBits: normalizerFractionBits,
        name: name ?? this.name,
      );
}

void _validateSoftmaxStatePair(
  OnlineSoftmaxState left,
  OnlineSoftmaxState right,
) {
  if (left.scoreWidth != right.scoreWidth ||
      left.scoreFractionBits != right.scoreFractionBits ||
      left.normalizerWidth != right.normalizerWidth ||
      left.normalizerFractionBits != right.normalizerFractionBits) {
    throw ArgumentError('Online softmax state formats must match.');
  }
  if (left.scoreWidth + 1 > 12) {
    throw ArgumentError(
      'The lookup Exp2 implementation supports score widths through 11 bits.',
    );
  }
}

Logic _signedGreaterThan(Logic left, Logic right) {
  if (left.width != right.width) {
    throw PortWidthMismatchException(right, left.width);
  }
  final signBias = Const(
    BigInt.one << (left.width - 1),
    width: left.width,
  );
  return (left ^ signBias).gt(right ^ signBias);
}

/// Merges two independently accumulated online softmax states.
///
/// The merge is equivalent to concatenating the samples represented by both
/// states, subject to the configured fixed-point approximation and rounding.
/// {@category Inference}
class OnlineSoftmaxMerge extends Module {
  /// `2^x` implementation used to rescale each normalization sum.
  final Exp2ApproximationFunctor exp2Implementation;

  /// Width of each exponential scale.
  final int expWidth;

  /// Fractional bits in each exponential scale.
  final int expFractionBits;

  /// Rounding used by exponent approximation and normalizer rescaling.
  final NumericRoundingMode roundingMode;

  /// Merged online state.
  late final OnlineSoftmaxState mergedState;

  /// Effective scale applied to the left normalization sum.
  Logic get leftScale => output('leftScale');

  /// Effective scale applied to the right normalization sum.
  Logic get rightScale => output('rightScale');

  /// Creates a combinational online softmax-state merge.
  OnlineSoftmaxMerge(
    OnlineSoftmaxState left,
    OnlineSoftmaxState right, {
    required this.expWidth,
    required this.expFractionBits,
    this.exp2Implementation = lookupExp2ApproximationFunctor,
    this.roundingMode = NumericRoundingMode.nearestEven,
    super.name = 'online_softmax_merge',
  }) : super(
          definitionName: 'OnlineSoftmaxMerge_'
              'S${left.scoreWidth}F${left.scoreFractionBits}_'
              'N${left.normalizerWidth}F${left.normalizerFractionBits}_'
              'E${expWidth}F${expFractionBits}_'
              '${exp2Implementation.identity}_${roundingMode.name}',
        ) {
    _validateSoftmaxStatePair(left, right);
    if (expWidth < 2 ||
        expFractionBits < 0 ||
        expFractionBits >= expWidth ||
        expFractionBits >= left.normalizerWidth) {
      throw ArgumentError('Online softmax exponential format is invalid.');
    }
    left = addTypedInput('left', left);
    right = addTypedInput('right', right);

    final leftGreater = _signedGreaterThan(left.maximum, right.maximum);
    final bothMaximum = mux(leftGreater, left.maximum, right.maximum);
    final differenceWidth = left.scoreWidth + 1;
    final extendedMaximum = bothMaximum.signExtend(differenceWidth);
    final leftDifference =
        (left.maximum.signExtend(differenceWidth) - extendedMaximum)
            .getRange(0, differenceWidth);
    final rightDifference =
        (right.maximum.signExtend(differenceWidth) - extendedMaximum)
            .getRange(0, differenceWidth);
    final minimumDifference = -(1 << (differenceWidth - 1));
    final leftExp = exp2Implementation(
      leftDifference,
      inputFractionBits: left.scoreFractionBits,
      outputWidth: expWidth,
      outputFractionBits: expFractionBits,
      minimumInputRaw: minimumDifference,
      maximumInputRaw: 0,
      roundingMode: roundingMode,
      name: '${name}_left_exp',
    );
    final rightExp = exp2Implementation(
      rightDifference,
      inputFractionBits: right.scoreFractionBits,
      outputWidth: expWidth,
      outputFractionBits: expFractionBits,
      minimumInputRaw: minimumDifference,
      maximumInputRaw: 0,
      roundingMode: roundingMode,
      name: '${name}_right_exp',
    );
    final sums = LogicArray(
      const [2],
      left.normalizerWidth,
      name: '${name}_sums',
    );
    sums.arrayElements[0] <= left.normalizer;
    sums.arrayElements[1] <= right.normalizer;
    final scales = LogicArray(
      const [2],
      expWidth,
      name: '${name}_scales',
    );
    scales.arrayElements[0] <= leftExp.result;
    scales.arrayElements[1] <= rightExp.result;
    final rescaled = GroupScaleApply(
      sums,
      scales,
      groupSize: 1,
      fractionalBits: expFractionBits,
      outputWidth: left.normalizerWidth,
      signedValue: false,
      signedScale: false,
      signedOutput: false,
      roundingMode: roundingMode,
      name: '${name}_rescale',
    );
    final combined = VectorReduce(
      rescaled.scaledValues,
      operation: InferenceVectorReduction.sum,
      outputWidth: left.normalizerWidth,
      name: '${name}_normalizer_sum',
    );
    final bothValid = left.valid & right.valid;
    final anyValid = left.valid | right.valid;
    final oneScale = Const(
      BigInt.one << expFractionBits,
      width: expWidth,
    );
    final effectiveLeftScale = mux(
      left.valid,
      mux(right.valid, leftExp.result, oneScale),
      Const(0, width: expWidth),
    );
    final effectiveRightScale = mux(
      right.valid,
      mux(left.valid, rightExp.result, oneScale),
      Const(0, width: expWidth),
    );
    addOutput('leftScale', width: expWidth) <= effectiveLeftScale;
    addOutput('rightScale', width: expWidth) <= effectiveRightScale;
    final selectedMaximum = mux(
      left.valid,
      mux(right.valid, bothMaximum, left.maximum),
      right.maximum,
    );
    final selectedNormalizer = mux(
      left.valid,
      mux(right.valid, combined.result, left.normalizer),
      right.normalizer,
    );
    final bothOverflow = left.overflow |
        right.overflow |
        rescaled.overflowMask.or() |
        combined.overflowed |
        leftExp.status.overflow |
        rightExp.status.overflow;
    final bothInexact = left.inexact |
        right.inexact |
        rescaled.inexactMask.or() |
        leftExp.status.inexact |
        rightExp.status.inexact;
    final bothApproximationError = left.approximationError |
        right.approximationError |
        leftExp.status.invalidInput |
        rightExp.status.invalidInput |
        leftExp.status.outOfRange |
        rightExp.status.outOfRange;
    final selectedOverflow = mux(
      bothValid,
      bothOverflow,
      mux(left.valid, left.overflow, right.overflow),
    );
    final selectedInexact = mux(
      bothValid,
      bothInexact,
      mux(left.valid, left.inexact, right.inexact),
    );
    final selectedApproximationError = mux(
      bothValid,
      bothApproximationError,
      mux(
        left.valid,
        left.approximationError,
        right.approximationError,
      ),
    );

    final outputState = OnlineSoftmaxState(
      scoreWidth: left.scoreWidth,
      scoreFractionBits: left.scoreFractionBits,
      normalizerWidth: left.normalizerWidth,
      normalizerFractionBits: left.normalizerFractionBits,
      name: 'mergedState',
    );
    mergedState = addTypedOutput('mergedState', outputState.clone);
    mergedState.maximum <=
        mux(
          anyValid,
          selectedMaximum,
          Const(0, width: left.scoreWidth),
        );
    mergedState.normalizer <=
        mux(
          anyValid,
          selectedNormalizer,
          Const(0, width: left.normalizerWidth),
        );
    mergedState.valid <= anyValid;
    mergedState.overflow <= anyValid & selectedOverflow;
    mergedState.inexact <= anyValid & selectedInexact;
    mergedState.approximationError <= anyValid & selectedApproximationError;
  }
}

/// Updates an online softmax state with one fixed-point score.
/// {@category Inference}
class OnlineSoftmaxUpdate extends Module {
  /// Updated state.
  late final OnlineSoftmaxState nextState;

  /// Creates a one-score online state update.
  OnlineSoftmaxUpdate(
    OnlineSoftmaxState state,
    Logic score, {
    required int expWidth,
    required int expFractionBits,
    Logic? scoreValid,
    Exp2ApproximationFunctor exp2Implementation =
        lookupExp2ApproximationFunctor,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    super.name = 'online_softmax_update',
  }) : super(
          definitionName: 'OnlineSoftmaxUpdate_'
              'S${state.scoreWidth}F${state.scoreFractionBits}_'
              'N${state.normalizerWidth}F${state.normalizerFractionBits}_'
              'E${expWidth}F${expFractionBits}_'
              '${exp2Implementation.identity}_${roundingMode.name}_'
              'V${scoreValid == null ? 0 : 1}',
        ) {
    if (score.width != state.scoreWidth) {
      throw PortWidthMismatchException(score, state.scoreWidth);
    }
    final one = BigInt.one << state.normalizerFractionBits;
    if (one >= (BigInt.one << state.normalizerWidth)) {
      throw ArgumentError(
        'Normalizer format cannot represent the value one.',
      );
    }
    state = addTypedInput('state', state);
    score = addInput('score', score, width: score.width);
    final localValid =
        scoreValid == null ? Const(1) : addInput('scoreValid', scoreValid);
    final singleton = OnlineSoftmaxState(
      scoreWidth: state.scoreWidth,
      scoreFractionBits: state.scoreFractionBits,
      normalizerWidth: state.normalizerWidth,
      normalizerFractionBits: state.normalizerFractionBits,
      name: '${name}_singleton',
    );
    singleton.maximum <= score;
    singleton.normalizer <= Const(one, width: state.normalizerWidth);
    singleton.valid <= localValid;
    singleton.overflow <= Const(0);
    singleton.inexact <= Const(0);
    singleton.approximationError <= Const(0);
    final merge = OnlineSoftmaxMerge(
      state,
      singleton,
      expWidth: expWidth,
      expFractionBits: expFractionBits,
      exp2Implementation: exp2Implementation,
      roundingMode: roundingMode,
      name: '${name}_merge',
    );
    final outputState = OnlineSoftmaxState(
      scoreWidth: state.scoreWidth,
      scoreFractionBits: state.scoreFractionBits,
      normalizerWidth: state.normalizerWidth,
      normalizerFractionBits: state.normalizerFractionBits,
      name: 'nextState',
    );
    nextState = addTypedOutput('nextState', outputState.clone);
    nextState.maximum <= merge.mergedState.maximum;
    nextState.normalizer <= merge.mergedState.normalizer;
    nextState.valid <= merge.mergedState.valid;
    nextState.overflow <= merge.mergedState.overflow;
    nextState.inexact <= merge.mergedState.inexact;
    nextState.approximationError <= merge.mergedState.approximationError;
  }
}
