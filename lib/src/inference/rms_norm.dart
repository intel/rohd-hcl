// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// rms_norm.dart
// Fixed-point root-mean-square normalization.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';
import 'package:rohd_hcl/src/bit_operations/population_count/count.dart';
import 'package:rohd_hcl/src/inference/fixed_point_approximation.dart';
import 'package:rohd_hcl/src/inference/group_scale_apply.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/mixed_precision_dot_product.dart';

/// Status associated with one RMS normalization result.
class RmsNormStatus extends LogicStructure {
  /// No input lane was active.
  late final Logic invalidInput;

  /// A reciprocal approximation input violated its configured contract.
  late final Logic approximationError;

  /// Any scalar or lane result overflowed or underflowed.
  late final Logic overflow;

  /// Any approximation or narrowing operation was inexact.
  late final Logic inexact;

  /// One overflow bit per output lane.
  late final Logic laneOverflowMask;

  /// One underflow bit per output lane.
  late final Logic laneUnderflowMask;

  /// Creates RMS normalization status signals.
  RmsNormStatus({
    required int laneCount,
    String name = 'rmsNormStatus',
  }) : this._(
          [
            Logic(name: 'invalidInput'),
            Logic(name: 'approximationError'),
            Logic(name: 'overflow'),
            Logic(name: 'inexact'),
            Logic(name: 'laneOverflowMask', width: laneCount),
            Logic(name: 'laneUnderflowMask', width: laneCount),
          ],
          laneCount: laneCount,
          name: name,
        );

  RmsNormStatus._(
    List<Logic> elements, {
    required this.laneCount,
    required super.name,
  }) : super(elements) {
    invalidInput = elements[0];
    approximationError = elements[1];
    overflow = elements[2];
    inexact = elements[3];
    laneOverflowMask = elements[4];
    laneUnderflowMask = elements[5];
  }

  /// Number of output lanes covered by the lane masks.
  final int laneCount;

  @override
  RmsNormStatus clone({String? name}) => RmsNormStatus._(
        elements.map((element) => element.clone(name: element.name)).toList(),
        laneCount: laneCount,
        name: name ?? this.name,
      );
}

/// Fixed-point RMS normalization over a masked lane vector.
///
/// Active lanes compute:
///
/// ```text
/// meanSquare = sum(value[i]^2) / activeCount + epsilon
/// output[i]  = value[i] * rsqrt(meanSquare) * weight[i]
/// ```
///
/// Inactive outputs are zero. All fixed-point formats and intermediate widths
/// are explicit.
/// {@category Inference}
class RmsNorm extends Module {
  /// Number of physical lanes.
  final int laneCount;

  /// Fractional bits in input and output values.
  final int valueFractionBits;

  /// Fractional bits in per-lane weights.
  final int weightFractionBits;

  /// Width of the quantized mean-square value.
  final int meanSquareWidth;

  /// Width of the reciprocal active-count scale.
  final int countReciprocalWidth;

  /// Fractional bits in the reciprocal active-count scale.
  final int countReciprocalFractionBits;

  /// Width of the inverse-RMS scale.
  final int inverseRmsWidth;

  /// Fractional bits in the inverse-RMS scale.
  final int inverseRmsFractionBits;

  /// Width of every final output lane.
  final int outputWidth;

  /// Raw epsilon in the mean-square fixed-point format.
  final int epsilonRaw;

  /// Multiplier implementation used by every product.
  final InferenceMultiplierFunctor multiplierImplementation;

  /// Reciprocal implementation used for active-count division.
  final PositiveApproximationFunctor reciprocalImplementation;

  /// Reciprocal-square-root implementation used for normalization.
  final PositiveApproximationFunctor reciprocalSqrtImplementation;

  /// Rounding policy applied by all fixed-point rescaling.
  final NumericRoundingMode roundingMode;

  /// Overflow policy applied to intermediate and final values.
  final NumericOverflowMode overflowMode;

  /// Normalized output lanes.
  late final LogicArray normalizedValues;

  /// Quantized mean square including epsilon.
  Logic get meanSquare => output('meanSquare');

  /// Quantized reciprocal root of [meanSquare].
  Logic get inverseRms => output('inverseRms');

  /// Number of active lanes included in the mean.
  Logic get activeCount => output('activeCount');

  /// Status associated with [normalizedValues].
  late final RmsNormStatus status;

  /// Creates fixed-point RMS normalization hardware.
  RmsNorm(
    LogicArray values,
    LogicArray weights, {
    required this.valueFractionBits,
    required this.weightFractionBits,
    required this.meanSquareWidth,
    required this.countReciprocalWidth,
    required this.countReciprocalFractionBits,
    required this.inverseRmsWidth,
    required this.inverseRmsFractionBits,
    required this.outputWidth,
    required this.epsilonRaw,
    Logic? activeMask,
    dynamic signedWeights = true,
    this.multiplierImplementation = nativeInferenceMultiplierFunctor,
    this.reciprocalImplementation = lookupReciprocalApproximationFunctor,
    this.reciprocalSqrtImplementation =
        lookupReciprocalSqrtApproximationFunctor,
    this.roundingMode = NumericRoundingMode.nearestEven,
    this.overflowMode = NumericOverflowMode.saturate,
    super.name = 'rms_norm',
  })  : laneCount = values.arrayElements.length,
        super(
          definitionName: 'RmsNorm_'
              'L${values.arrayElements.length}_V${values.elementWidth}'
              'F${valueFractionBits}_W${weights.elementWidth}'
              'F${weightFractionBits}_M${meanSquareWidth}_'
              'C${countReciprocalWidth}F${countReciprocalFractionBits}_'
              'R${inverseRmsWidth}F${inverseRmsFractionBits}_'
              'O${outputWidth}_E${epsilonRaw}_'
              '${multiplierImplementation.identity}_'
              '${reciprocalImplementation.identity}_'
              '${reciprocalSqrtImplementation.identity}_'
              '${roundingMode.name}_${overflowMode.name}_'
              'M${activeMask == null ? 0 : 1}',
        ) {
    if (values.dimensions.length != 1 ||
        weights.dimensions.length != 1 ||
        laneCount < 1 ||
        weights.arrayElements.length != laneCount) {
      throw ArgumentError(
        'Values and weights must be non-empty equal-length 1-D arrays.',
      );
    }
    if (valueFractionBits < 0 ||
        valueFractionBits >= values.elementWidth ||
        weightFractionBits < 0 ||
        weightFractionBits >= weights.elementWidth ||
        meanSquareWidth < 2 * valueFractionBits + 1 ||
        meanSquareWidth > 12 ||
        countReciprocalWidth < 2 ||
        countReciprocalFractionBits < 0 ||
        countReciprocalFractionBits >= countReciprocalWidth ||
        inverseRmsWidth < 2 ||
        inverseRmsFractionBits < 0 ||
        inverseRmsFractionBits >= inverseRmsWidth ||
        outputWidth < 2) {
      throw ArgumentError('RMS normalization fixed-point formats are invalid.');
    }
    if (epsilonRaw < 1 || epsilonRaw >= (1 << meanSquareWidth)) {
      throw ArgumentError.value(
        epsilonRaw,
        'epsilonRaw',
        'Must be positive and fit the mean-square format.',
      );
    }
    if (activeMask != null && activeMask.width != laneCount) {
      throw PortWidthMismatchException(activeMask, laneCount);
    }
    if (reciprocalImplementation.operation !=
            FixedPointApproximationOperation.reciprocal ||
        reciprocalSqrtImplementation.operation !=
            FixedPointApproximationOperation.reciprocalSquareRoot) {
      throw ArgumentError(
        'RMS normalization requires reciprocal and reciprocal-square-root '
        'approximation functors.',
      );
    }

    values = addTypedInput('values', values);
    weights = addTypedInput('weights', weights);
    final localMask = activeMask == null
        ? Const(-1, width: laneCount)
        : addInput('activeMask', activeMask, width: laneCount);
    final count = Count(localMask, name: '${name}_active_count').count;
    addOutput('activeCount', width: count.width) <= count;

    final squareSumWidth = values.elementWidth * 2 + laneCount.log2Ceil;
    final squareSum = MixedPrecisionDotProduct(
      values,
      values,
      outputWidth: squareSumWidth,
      activeMask: localMask,
      signedLeft: true,
      signedRight: true,
      signedResult: false,
      multiplierImplementation: multiplierImplementation,
      name: '${name}_square_sum',
    );
    final countReciprocal = reciprocalImplementation(
      count,
      inputFractionBits: 0,
      outputWidth: countReciprocalWidth,
      outputFractionBits: countReciprocalFractionBits,
      minimumInputRaw: 1,
      maximumInputRaw: laneCount,
      roundingMode: roundingMode,
      name: '${name}_count_reciprocal',
    );
    final squareSumArray = LogicArray(
      const [1],
      squareSumWidth,
      name: '${name}_square_sum_value',
    );
    squareSumArray.arrayElements.single <= squareSum.result;
    final countScaleArray = LogicArray(
      const [1],
      countReciprocalWidth,
      name: '${name}_count_scale',
    );
    countScaleArray.arrayElements.single <= countReciprocal.result;
    final meanScale = GroupScaleApply(
      squareSumArray,
      countScaleArray,
      groupSize: 1,
      fractionalBits: countReciprocalFractionBits,
      outputWidth: meanSquareWidth,
      signedValue: false,
      signedScale: false,
      signedOutput: false,
      multiplierImplementation: multiplierImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_mean',
    );
    final meanWithEpsilon = (meanScale.scaledValues.arrayElements.single
                .zeroExtend(meanSquareWidth + 1) +
            Const(epsilonRaw, width: meanSquareWidth + 1))
        .getRange(0, meanSquareWidth + 1);
    final epsilonNarrow = NumericNarrowing(
      meanWithEpsilon,
      outputWidth: meanSquareWidth,
      overflowMode: overflowMode,
      name: '${name}_epsilon',
    );
    addOutput('meanSquare', width: meanSquareWidth) <= epsilonNarrow.result;

    final inverse = reciprocalSqrtImplementation(
      meanSquare,
      inputFractionBits: 2 * valueFractionBits,
      outputWidth: inverseRmsWidth,
      outputFractionBits: inverseRmsFractionBits,
      minimumInputRaw: 1,
      maximumInputRaw: (1 << meanSquareWidth) - 1,
      roundingMode: roundingMode,
      name: '${name}_inverse_rms',
    );
    addOutput('inverseRms', width: inverseRmsWidth) <= inverse.result;
    final normalizedIntermediateWidth = max(
      outputWidth,
      values.elementWidth + 2,
    );
    final normalized = GroupScaleApply(
      values,
      inverseRms,
      groupSize: laneCount,
      fractionalBits: inverseRmsFractionBits,
      outputWidth: normalizedIntermediateWidth,
      activeMask: localMask,
      signedScale: false,
      multiplierImplementation: multiplierImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_normalize',
    );
    final weighted = GroupScaleApply(
      normalized.scaledValues,
      weights,
      groupSize: 1,
      fractionalBits: weightFractionBits,
      outputWidth: outputWidth,
      activeMask: localMask,
      signedScale: signedWeights,
      signedOutput: true,
      multiplierImplementation: multiplierImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_weights',
    );
    final outputValues = LogicArray(
      [laneCount],
      outputWidth,
      name: 'normalizedValues',
    );
    normalizedValues = addTypedOutput('normalizedValues', outputValues.clone);
    for (var lane = 0; lane < laneCount; lane++) {
      normalizedValues.arrayElements[lane] <=
          weighted.scaledValues.arrayElements[lane];
    }

    final internalStatus = RmsNormStatus(
      laneCount: laneCount,
      name: '${name}_internal_status',
    );
    internalStatus.invalidInput <= ~count.or();
    internalStatus.approximationError <=
        (countReciprocal.status.invalidInput |
                countReciprocal.status.outOfRange) |
            (inverse.status.invalidInput | inverse.status.outOfRange);
    internalStatus.laneOverflowMask <= weighted.overflowMask;
    internalStatus.laneUnderflowMask <= weighted.underflowMask;
    internalStatus.overflow <=
        squareSum.overflowed |
            squareSum.underflowed |
            meanScale.overflowMask.or() |
            meanScale.underflowMask.or() |
            epsilonNarrow.overflowed |
            inverse.status.overflow |
            normalized.overflowMask.or() |
            normalized.underflowMask.or() |
            weighted.overflowMask.or() |
            weighted.underflowMask.or();
    internalStatus.inexact <=
        countReciprocal.status.inexact |
            meanScale.inexactMask.or() |
            epsilonNarrow.inexact |
            inverse.status.inexact |
            normalized.inexactMask.or() |
            weighted.inexactMask.or();
    status = addTypedOutput('status', internalStatus.clone);
    status <= internalStatus;
  }
}
