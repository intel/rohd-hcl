// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// mixed_precision_dot_product.dart
// Masked mixed-width integer inference dot product.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';
import 'package:rohd_hcl/src/arithmetic/multiply_accumulate/dotproduct.dart';
import 'package:rohd_hcl/src/bit_operations/population_count/count.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/inference_signedness.dart';

String _signedIdentity(dynamic value) =>
    InferenceSignedness(value, name: 'identity').identity;

String _resultSignedIdentity(dynamic value) =>
    value == null ? 'derived' : _signedIdentity(value);

/// Computes a masked mixed-width integer dot product.
///
/// Operands may have different widths but must have the same lane count.
/// Products are accumulated at an internal lossless width before applying the
/// configured result narrowing and overflow policy.
/// {@category Inference}
class MixedPrecisionDotProduct extends Module {
  /// Number of multiplied lane pairs.
  final int laneCount;

  /// Width of every left operand.
  final int leftWidth;

  /// Width of every right operand.
  final int rightWidth;

  /// Width of [result].
  final int outputWidth;

  /// Static or runtime left-operand signedness.
  late final InferenceSignedness signedLeft;

  /// Static or runtime right-operand signedness.
  late final InferenceSignedness signedRight;

  /// Explicit static or runtime result signedness, when supplied.
  late final InferenceSignedness? signedResult;

  /// Overflow behavior applied to [result].
  final NumericOverflowMode overflowMode;

  /// Multiplier implementation used independently for every lane.
  final InferenceMultiplierFunctor multiplierImplementation;

  /// Dot-product result.
  Logic get result => output('result');

  /// High when the lossless result exceeds the positive output range.
  Logic get overflowed => output('overflowed');

  /// High when a signed lossless result is below the output minimum.
  Logic get underflowed => output('underflowed');

  /// Number of active products contributing to [result].
  Logic get activeProducts => output('activeProducts');

  /// Runtime interpretation selected for accumulation and [result].
  Logic get resultIsSigned => output('resultIsSigned');

  /// Creates a combinational mixed-precision dot product.
  MixedPrecisionDotProduct(
    LogicArray left,
    LogicArray right, {
    required this.outputWidth,
    Logic? activeMask,
    Logic? initialValue,
    dynamic signedLeft = false,
    dynamic signedRight = false,
    dynamic signedResult,
    this.overflowMode = NumericOverflowMode.saturate,
    this.multiplierImplementation = nativeInferenceMultiplierFunctor,
    super.name = 'mixed_precision_dot_product',
  })  : laneCount = left.arrayElements.length,
        leftWidth = left.elementWidth,
        rightWidth = right.elementWidth,
        super(
          definitionName: 'MixedPrecisionDotProduct_'
              'L${left.arrayElements.length}_A${left.elementWidth}_'
              'B${right.elementWidth}_O${outputWidth}_'
              'SA${_signedIdentity(signedLeft)}_'
              'SB${_signedIdentity(signedRight)}_'
              'SR${_resultSignedIdentity(signedResult)}_'
              '${overflowMode.name}_${multiplierImplementation.identity}_'
              'M${activeMask == null ? 0 : 1}_'
              'I${initialValue == null ? 0 : 1}',
        ) {
    if (left.dimensions.length != 1 ||
        right.dimensions.length != 1 ||
        laneCount < 1 ||
        right.arrayElements.length != laneCount) {
      throw ArgumentError(
        'Dot-product operands must be non-empty 1-D arrays of equal length.',
      );
    }
    if (outputWidth < 1) {
      throw ArgumentError.value(
          outputWidth, 'outputWidth', 'Must be positive.');
    }
    if (activeMask != null && activeMask.width != laneCount) {
      throw PortWidthMismatchException(activeMask, laneCount);
    }
    if (initialValue != null && initialValue.width != outputWidth) {
      throw PortWidthMismatchException(initialValue, outputWidth);
    }

    this.signedLeft = InferenceSignedness(signedLeft, name: 'signedLeft');
    this.signedRight = InferenceSignedness(signedRight, name: 'signedRight');
    this.signedResult = signedResult == null
        ? null
        : InferenceSignedness(signedResult, name: 'signedResult');
    left = addTypedInput('left', left);
    right = addTypedInput('right', right);
    final localMask = activeMask == null
        ? Const(-1, width: laneCount)
        : addInput('activeMask', activeMask, width: laneCount);
    final localInitial = initialValue == null
        ? Const(0, width: outputWidth)
        : addInput('initialValue', initialValue, width: outputWidth);
    final leftIsSigned = this.signedLeft.resolve(this);
    final rightIsSigned = this.signedRight.resolve(this);
    final resultSigned =
        this.signedResult?.resolve(this) ?? (leftIsSigned | rightIsSigned);
    final staticResultSigned = this.signedResult != null
        ? (this.signedResult!.isRuntime ? null : this.signedResult!.staticValue)
        : (!this.signedLeft.isRuntime && !this.signedRight.isRuntime
            ? this.signedLeft.staticValue || this.signedRight.staticValue
            : null);

    final maskedLeft = [
      for (var lane = 0; lane < laneCount; lane++)
        mux(
          localMask[lane],
          left.arrayElements[lane],
          Const(0, width: leftWidth),
        ).named('${name}_masked_left_$lane'),
    ];
    final dotProduct = GeneralDotProduct(
      maskedLeft,
      right.arrayElements,
      signedMultiplicand: this.signedLeft.childConfiguration(this),
      signedMultiplier: this.signedRight.childConfiguration(this),
      multiplierGen: multiplierImplementation.call,
      multiplierIdentity: multiplierImplementation.identity,
      name: '${name}_dot_product',
    );
    final calculationWidth = max(dotProduct.product.width, outputWidth) + 1;
    final dotProductValue = mux(
      resultSigned,
      dotProduct.product.signExtend(calculationWidth),
      dotProduct.product.zeroExtend(calculationWidth),
    );
    final initial = mux(
      resultSigned,
      localInitial.signExtend(calculationWidth),
      localInitial.zeroExtend(calculationWidth),
    );
    final sum = (dotProductValue + initial).getRange(0, calculationWidth);
    final resultOutput = addOutput('result', width: outputWidth);
    final overflowOutput = addOutput('overflowed');
    final underflowOutput = addOutput('underflowed');
    if (staticResultSigned != null) {
      final narrowed = NumericNarrowing(
        sum,
        outputWidth: outputWidth,
        signed: staticResultSigned,
        overflowMode: overflowMode,
        name: '${name}_narrow',
      );
      resultOutput <= narrowed.result;
      overflowOutput <= narrowed.overflowed;
      underflowOutput <= narrowed.underflowed;
    } else {
      final signedNarrow = NumericNarrowing(
        sum,
        outputWidth: outputWidth,
        signed: true,
        overflowMode: overflowMode,
        name: '${name}_signed_narrow',
      );
      final unsignedNarrow = NumericNarrowing(
        sum,
        outputWidth: outputWidth,
        overflowMode: overflowMode,
        name: '${name}_unsigned_narrow',
      );
      resultOutput <=
          mux(resultSigned, signedNarrow.result, unsignedNarrow.result);
      overflowOutput <=
          mux(
            resultSigned,
            signedNarrow.overflowed,
            unsignedNarrow.overflowed,
          );
      underflowOutput <= resultSigned & signedNarrow.underflowed;
    }
    addOutput('resultIsSigned') <= resultSigned;
    addOutput(
          'activeProducts',
          width: max(1, (laneCount + 1).log2Ceil),
        ) <=
        Count(localMask, name: '${name}_active_count').count;
  }
}
