// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// group_scale_apply.dart
// Grouped fixed-point scaling and requantization for inference lanes.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';
import 'package:rohd_hcl/src/bit_operations/population_count/count.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/inference_signedness.dart';

String _scaleSignedIdentity(dynamic value) =>
    InferenceSignedness(value, name: 'identity').identity;

String _scaleOutputSignedIdentity(dynamic value) =>
    value == null ? 'derived' : _scaleSignedIdentity(value);

int _scaleGroupCount(int laneCount, int groupSize) {
  if (groupSize < 1) {
    throw ArgumentError.value(groupSize, 'groupSize', 'Must be positive.');
  }
  return (laneCount + groupSize - 1) ~/ groupSize;
}

/// Applies one fixed-point scale and optional zero point per lane group.
///
/// For lane `i`, scale index `i ~/ groupSize` is used:
///
/// ```text
/// rounded = round(value[i] * scale[group] / 2^fractionalBits)
/// result  = narrow(rounded + zeroPoint[group])
/// ```
///
/// Signedness may be static or selected by runtime one-bit controls. The
/// result exposes one overflow, underflow, and inexact bit per lane.
/// {@category Inference}
class GroupScaleApply extends Module {
  /// Number of physical data lanes.
  final int laneCount;

  /// Number of lanes sharing one scale.
  final int groupSize;

  /// Number of scale groups.
  final int groupCount;

  /// Number of fractional bits in each scale.
  final int fractionalBits;

  /// Width of each output lane.
  final int outputWidth;

  /// Static or runtime input-value signedness.
  late final InferenceSignedness signedValue;

  /// Static or runtime scale signedness.
  late final InferenceSignedness signedScale;

  /// Explicit static or runtime output signedness, when supplied.
  late final InferenceSignedness? signedOutput;

  /// Rounding policy applied after the fixed-point scale multiplication.
  final NumericRoundingMode roundingMode;

  /// Overflow behavior applied after adding the zero point.
  final NumericOverflowMode overflowMode;

  /// Multiplier implementation used independently for every lane.
  final InferenceMultiplierFunctor multiplierImplementation;

  /// Scaled and narrowed output lanes.
  late final LogicArray scaledValues;

  /// One overflow bit per lane.
  Logic get overflowMask => output('overflowMask');

  /// One underflow bit per lane.
  Logic get underflowMask => output('underflowMask');

  /// One inexact-rounding bit per lane.
  Logic get inexactMask => output('inexactMask');

  /// Number of active lanes.
  Logic get activeCount => output('activeCount');

  /// Runtime interpretation selected for output lanes.
  Logic get outputIsSigned => output('outputIsSigned');

  /// Creates grouped fixed-point scaling and requantization hardware.
  GroupScaleApply(
    LogicArray values,
    LogicArray scales, {
    required this.groupSize,
    required this.fractionalBits,
    required this.outputWidth,
    LogicArray? zeroPoints,
    Logic? activeMask,
    dynamic signedValue = true,
    dynamic signedScale = true,
    dynamic signedOutput,
    this.roundingMode = NumericRoundingMode.nearestEven,
    this.overflowMode = NumericOverflowMode.saturate,
    this.multiplierImplementation = nativeInferenceMultiplierFunctor,
    super.name = 'group_scale_apply',
  })  : laneCount = values.arrayElements.length,
        groupCount = _scaleGroupCount(
          values.arrayElements.length,
          groupSize,
        ),
        super(
          definitionName: 'GroupScaleApply_'
              'L${values.arrayElements.length}_G${groupSize}_'
              'V${values.elementWidth}_S${scales.elementWidth}_'
              'F${fractionalBits}_O${outputWidth}_'
              'SV${_scaleSignedIdentity(signedValue)}_'
              'SS${_scaleSignedIdentity(signedScale)}_'
              'SO${_scaleOutputSignedIdentity(signedOutput)}_'
              '${roundingMode.name}_${overflowMode.name}_'
              '${multiplierImplementation.identity}_'
              'Z${zeroPoints == null ? 0 : 1}_'
              'M${activeMask == null ? 0 : 1}',
        ) {
    if (values.dimensions.length != 1 ||
        scales.dimensions.length != 1 ||
        laneCount < 1 ||
        groupSize < 1 ||
        scales.arrayElements.length != groupCount) {
      throw ArgumentError(
        'Values and scales must be non-empty 1-D arrays with exactly one '
        'scale per configured lane group.',
      );
    }
    if (fractionalBits < 0 ||
        fractionalBits > values.elementWidth + scales.elementWidth) {
      throw ArgumentError.value(
        fractionalBits,
        'fractionalBits',
        'Must fit within the full product width.',
      );
    }
    if (outputWidth < 1) {
      throw ArgumentError.value(
          outputWidth, 'outputWidth', 'Must be positive.');
    }
    if (zeroPoints != null &&
        (zeroPoints.dimensions.length != 1 ||
            zeroPoints.arrayElements.length != groupCount)) {
      throw ArgumentError(
        'Zero points must contain exactly one 1-D element per scale group.',
      );
    }
    if (activeMask != null && activeMask.width != laneCount) {
      throw PortWidthMismatchException(activeMask, laneCount);
    }

    this.signedValue = InferenceSignedness(signedValue, name: 'signedValue');
    this.signedScale = InferenceSignedness(signedScale, name: 'signedScale');
    this.signedOutput = signedOutput == null
        ? null
        : InferenceSignedness(signedOutput, name: 'signedOutput');
    values = addTypedInput('values', values);
    scales = addTypedInput('scales', scales);
    if (zeroPoints != null) {
      zeroPoints = addTypedInput('zeroPoints', zeroPoints);
    }
    final localMask = activeMask == null
        ? Const(-1, width: laneCount)
        : addInput('activeMask', activeMask, width: laneCount);
    final valueIsSigned = this.signedValue.resolve(this);
    final scaleIsSigned = this.signedScale.resolve(this);
    final productIsSigned = valueIsSigned | scaleIsSigned;
    final outputSigned = this.signedOutput?.resolve(this) ?? productIsSigned;

    final results = LogicArray(
      [laneCount],
      outputWidth,
      name: 'scaledValues',
    );
    scaledValues = addTypedOutput('scaledValues', results.clone);
    final overflowBits = <Logic>[];
    final underflowBits = <Logic>[];
    final inexactBits = <Logic>[];

    for (var lane = 0; lane < laneCount; lane++) {
      final group = lane ~/ groupSize;
      final multiplier = multiplierImplementation(
        values.arrayElements[lane],
        scales.arrayElements[group],
        signedMultiplicand: this.signedValue.childConfiguration(this),
        signedMultiplier: this.signedScale.childConfiguration(this),
      );
      final zeroPoint =
          zeroPoints?.arrayElements[group] ?? Const(0, width: outputWidth);
      final calculationWidth = max(
            max(multiplier.product.width, zeroPoint.width),
            outputWidth,
          ) +
          2;
      final signedShift = NumericNarrowing(
        multiplier.product,
        outputWidth: calculationWidth,
        signed: true,
        shiftRight: fractionalBits,
        roundingMode: roundingMode,
        name: '${name}_lane_${lane}_signed_shift',
      );
      final unsignedShift = NumericNarrowing(
        multiplier.product,
        outputWidth: calculationWidth,
        shiftRight: fractionalBits,
        roundingMode: roundingMode,
        name: '${name}_lane_${lane}_unsigned_shift',
      );
      final shifted = mux(
        productIsSigned,
        signedShift.result,
        unsignedShift.result,
      );
      final shiftInexact = mux(
        productIsSigned,
        signedShift.inexact,
        unsignedShift.inexact,
      );
      final extendedZeroPoint = mux(
        outputSigned,
        zeroPoint.signExtend(calculationWidth),
        zeroPoint.zeroExtend(calculationWidth),
      );
      final sum = (shifted + extendedZeroPoint).getRange(0, calculationWidth);
      final signedNarrow = NumericNarrowing(
        sum,
        outputWidth: outputWidth,
        signed: true,
        overflowMode: overflowMode,
        name: '${name}_lane_${lane}_signed_narrow',
      );
      final unsignedNarrow = NumericNarrowing(
        sum,
        outputWidth: outputWidth,
        overflowMode: overflowMode,
        name: '${name}_lane_${lane}_unsigned_narrow',
      );
      final negativeUnsigned = productIsSigned & sum[-1];
      final unsignedResult = overflowMode == NumericOverflowMode.saturate
          ? mux(
              negativeUnsigned,
              Const(0, width: outputWidth),
              unsignedNarrow.result,
            )
          : unsignedNarrow.result;
      final laneResult = mux(
        outputSigned,
        signedNarrow.result,
        unsignedResult,
      );
      final laneOverflow = mux(
        outputSigned,
        signedNarrow.overflowed,
        ~negativeUnsigned & unsignedNarrow.overflowed,
      );
      final laneUnderflow = mux(
        outputSigned,
        signedNarrow.underflowed,
        negativeUnsigned,
      );
      scaledValues.arrayElements[lane] <=
          mux(
            localMask[lane],
            laneResult,
            Const(0, width: outputWidth),
          );
      overflowBits.add(localMask[lane] & laneOverflow);
      underflowBits.add(localMask[lane] & laneUnderflow);
      inexactBits.add(localMask[lane] & shiftInexact);
    }

    addOutput('overflowMask', width: laneCount) <= overflowBits.rconcat();
    addOutput('underflowMask', width: laneCount) <= underflowBits.rconcat();
    addOutput('inexactMask', width: laneCount) <= inexactBits.rconcat();
    addOutput(
          'activeCount',
          width: max(1, (laneCount + 1).log2Ceil),
        ) <=
        Count(localMask, name: '${name}_active_count').count;
    addOutput('outputIsSigned') <= outputSigned;
  }
}
