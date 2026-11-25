// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_attention.dart
// Streaming fused fixed-point attention experiment.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/accumulation/accumulator.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';
import 'package:rohd_hcl/src/bit_operations/population_count/count.dart';
import 'package:rohd_hcl/src/flow_control/attachments/directional_attachments.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/fixed_point_approximation.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/mixed_precision_dot_product.dart';
import 'package:rohd_hcl/src/inference/online_softmax_weighted_state.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// One complete fixed-point attention request.
/// {@category Inference}
class FixedPointAttentionRequest extends LogicStructure {
  /// Query vector.
  late final LogicArray query;

  /// Key vectors indexed by sequence position then head lane.
  late final LogicArray keys;

  /// Value vectors indexed by sequence position then output lane.
  late final LogicArray values;

  /// One validity bit per key/value position.
  late final Logic keyMask;

  /// One validity bit per query/key head lane.
  late final Logic laneMask;

  /// Number of leading sequence positions permitted by the causal mask.
  late final Logic causalKeyCount;

  /// Caller-selected transaction identity.
  late final Logic requestId;

  /// Number of physical sequence positions.
  final int sequenceLength;

  /// Number of query/key lanes.
  final int headDimension;

  /// Number of output value lanes.
  final int valueDimension;

  /// Width of every query and key element.
  final int elementWidth;

  /// Width of every value element.
  final int valueWidth;

  /// Width of [requestId].
  final int requestIdWidth;

  /// Width of [causalKeyCount].
  final int causalCountWidth;

  /// Creates a fixed-point attention request shape.
  FixedPointAttentionRequest({
    required this.sequenceLength,
    required this.headDimension,
    required this.valueDimension,
    required this.elementWidth,
    required this.valueWidth,
    this.requestIdWidth = 8,
    String name = 'fixedPointAttentionRequest',
  })  : causalCountWidth = max(1, (sequenceLength + 1).log2Ceil),
        super(
          [
            LogicArray(
              [headDimension],
              elementWidth,
              name: 'query',
            ),
            LogicArray(
              [sequenceLength, headDimension],
              elementWidth,
              name: 'keys',
            ),
            LogicArray(
              [sequenceLength, valueDimension],
              valueWidth,
              name: 'values',
            ),
            Logic(name: 'keyMask', width: sequenceLength),
            Logic(name: 'laneMask', width: headDimension),
            Logic(
              name: 'causalKeyCount',
              width: max(1, (sequenceLength + 1).log2Ceil),
            ),
            Logic(name: 'requestId', width: requestIdWidth),
          ],
          name: name,
        ) {
    if (sequenceLength < 1 ||
        headDimension < 1 ||
        valueDimension < 1 ||
        elementWidth < 2 ||
        valueWidth < 2 ||
        requestIdWidth < 1) {
      throw ArgumentError(
          'Attention request dimensions and widths are invalid.');
    }
    query = elements[0] as LogicArray;
    keys = elements[1] as LogicArray;
    values = elements[2] as LogicArray;
    keyMask = elements[3];
    laneMask = elements[4];
    causalKeyCount = elements[5];
    requestId = elements[6];
  }

  FixedPointAttentionRequest._(
    List<Logic> elements, {
    required this.sequenceLength,
    required this.headDimension,
    required this.valueDimension,
    required this.elementWidth,
    required this.valueWidth,
    required this.requestIdWidth,
    required this.causalCountWidth,
    required String name,
  }) : super(elements, name: name) {
    query = elements[0] as LogicArray;
    keys = elements[1] as LogicArray;
    values = elements[2] as LogicArray;
    keyMask = elements[3];
    laneMask = elements[4];
    causalKeyCount = elements[5];
    requestId = elements[6];
  }

  @override
  FixedPointAttentionRequest clone({String? name}) =>
      FixedPointAttentionRequest._(
        elements.map((element) => element.clone(name: element.name)).toList(),
        sequenceLength: sequenceLength,
        headDimension: headDimension,
        valueDimension: valueDimension,
        elementWidth: elementWidth,
        valueWidth: valueWidth,
        requestIdWidth: requestIdWidth,
        causalCountWidth: causalCountWidth,
        name: name ?? this.name,
      );
}

/// Retained output from one fixed-point attention request.
/// {@category Inference}
class FixedPointAttentionResult extends LogicStructure {
  /// Normalized attention output vector.
  late final LogicArray values;

  /// Identity copied from the accepted request.
  late final Logic requestId;

  /// No key/value position was active.
  late final Logic invalidInput;

  /// Any score, softmax, or output arithmetic overflowed.
  late final Logic overflow;

  /// Any approximation or fixed-point rounding was inexact.
  late final Logic inexact;

  /// An approximation input violated its configured contract.
  late final Logic approximationError;

  /// Number of output lanes.
  final int valueDimension;

  /// Width of each output lane.
  final int outputWidth;

  /// Width of [requestId].
  final int requestIdWidth;

  /// Creates a fixed-point attention result shape.
  FixedPointAttentionResult({
    required this.valueDimension,
    required this.outputWidth,
    required this.requestIdWidth,
    String name = 'fixedPointAttentionResult',
  }) : super(
          [
            LogicArray(
              [valueDimension],
              outputWidth,
              name: 'values',
            ),
            Logic(name: 'requestId', width: requestIdWidth),
            Logic(name: 'invalidInput'),
            Logic(name: 'overflow'),
            Logic(name: 'inexact'),
            Logic(name: 'approximationError'),
          ],
          name: name,
        ) {
    values = elements[0] as LogicArray;
    requestId = elements[1];
    invalidInput = elements[2];
    overflow = elements[3];
    inexact = elements[4];
    approximationError = elements[5];
  }

  FixedPointAttentionResult._(
    List<Logic> elements, {
    required this.valueDimension,
    required this.outputWidth,
    required this.requestIdWidth,
    required String name,
  }) : super(elements, name: name) {
    values = elements[0] as LogicArray;
    requestId = elements[1];
    invalidInput = elements[2];
    overflow = elements[3];
    inexact = elements[4];
    approximationError = elements[5];
  }

  @override
  FixedPointAttentionResult clone({String? name}) =>
      FixedPointAttentionResult._(
        elements.map((element) => element.clone(name: element.name)).toList(),
        valueDimension: valueDimension,
        outputWidth: outputWidth,
        requestIdWidth: requestIdWidth,
        name: name ?? this.name,
      );
}

/// Streaming fused fixed-point attention over one query and a bounded KV tile.
///
/// The module captures one complete request, processes one key/value position
/// per busy cycle, and retains the normalized output until retirement. Score
/// values are consumed directly by online softmax and are never materialized
/// in an intermediate score memory.
///
/// Assert `load` only when [canLoad] is high. The result becomes available
/// exactly [sequenceLength] cycles after the load edge, regardless of masks.
/// With `retire` omitted it is consumed on the following edge; a scheduler may
/// instead withhold retirement to retain it. Retirement and the next load may
/// share an edge. Synchronous reset abandons the captured request and result.
/// {@category Inference}
class FixedPointAttentionCore extends Module {
  /// New loads are legal only while this is high.
  Logic get canLoad => output('canLoad');

  /// Whether a retained result is available for retirement.
  Logic get resultValid => output('resultValid');

  /// Number of physical sequence positions.
  final int sequenceLength;

  /// Number of query/key lanes.
  final int headDimension;

  /// Number of output value lanes.
  final int valueDimension;

  /// Width of query/key elements.
  final int elementWidth;

  /// Fractional bits in query/key elements.
  final int elementFractionBits;

  /// Width of value elements and weighted numerator elements.
  final int valueWidth;

  /// Fractional bits in value elements.
  final int valueFractionBits;

  /// Width of each narrowed score.
  final int scoreWidth;

  /// Fractional bits in each narrowed score.
  final int scoreFractionBits;

  /// Width of the online softmax normalization sum.
  final int normalizerWidth;

  /// Fractional bits in the online softmax normalization sum.
  final int normalizerFractionBits;

  /// Width of each exponential scale.
  final int expWidth;

  /// Fractional bits in each exponential scale.
  final int expFractionBits;

  /// Width of the final reciprocal.
  final int reciprocalWidth;

  /// Fractional bits in the final reciprocal.
  final int reciprocalFractionBits;

  /// Width of each output lane.
  final int outputWidth;

  /// Width of every telemetry counter.
  final int counterWidth;

  /// Multiplier implementation used by score and value arithmetic.
  final InferenceMultiplierFunctor multiplierImplementation;

  /// Exponential implementation used by online softmax.
  final Exp2ApproximationFunctor exp2Implementation;

  /// Reciprocal implementation used by final normalization.
  final PositiveApproximationFunctor reciprocalImplementation;

  /// Rounding policy used throughout the fixed-point pipeline.
  final NumericRoundingMode roundingMode;

  /// Overflow policy used throughout the fixed-point pipeline.
  final NumericOverflowMode overflowMode;

  /// Captured-request input schema.
  late final FixedPointAttentionRequest request;

  /// Retained complete attention results.
  late final FixedPointAttentionResult result;

  /// High while one captured request is being processed.
  Logic get busy => output('busy');

  /// Current key/value sequence index.
  Logic get currentKey => output('currentKey');

  /// Number of active score multiplications.
  Logic get scoreProducts => output('scoreProducts');

  /// Number of active key/value positions consumed.
  Logic get activeValues => output('activeValues');

  /// Numeric query, key, and value bytes accepted.
  Logic get inputBytes => output('inputBytes');

  /// Score bytes not written because softmax is fused.
  Logic get avoidedScoreWriteBytes => output('avoidedScoreWriteBytes');

  /// Busy processing cycles.
  Logic get busyCycles => output('busyCycles');

  /// Cycles for which a valid output was stalled.
  Logic get outputStallCycles => output('outputStallCycles');

  /// Number of completed result transactions.
  Logic get completedRequests => output('completedRequests');

  /// Creates a fixed-point fused attention engine.
  FixedPointAttentionCore({
    required Logic clk,
    required Logic reset,
    required FixedPointAttentionRequest request,
    required FixedPointAttentionResult resultSchema,
    required Logic load,
    required this.elementFractionBits,
    required this.valueFractionBits,
    required this.scoreWidth,
    required this.scoreFractionBits,
    required this.normalizerWidth,
    required this.normalizerFractionBits,
    required this.expWidth,
    required this.expFractionBits,
    required this.reciprocalWidth,
    required this.reciprocalFractionBits,
    required this.outputWidth,
    Logic? retire,
    Logic? clearCounters,
    this.counterWidth = 32,
    this.multiplierImplementation = nativeInferenceMultiplierFunctor,
    this.exp2Implementation = lookupExp2ApproximationFunctor,
    this.reciprocalImplementation = lookupReciprocalApproximationFunctor,
    this.roundingMode = NumericRoundingMode.nearestEven,
    this.overflowMode = NumericOverflowMode.saturate,
    super.name = 'fixed_point_attention_core',
  })  : sequenceLength = request.sequenceLength,
        headDimension = request.headDimension,
        valueDimension = request.valueDimension,
        elementWidth = request.elementWidth,
        valueWidth = request.valueWidth,
        super(
          definitionName: 'FixedPointAttentionCore_'
              'S${request.sequenceLength}_'
              'H${request.headDimension}_'
              'V${request.valueDimension}_'
              'E${request.elementWidth}F${elementFractionBits}_'
              'D${request.valueWidth}F${valueFractionBits}_'
              'Q${scoreWidth}F${scoreFractionBits}_'
              'N${normalizerWidth}F${normalizerFractionBits}_'
              'X${expWidth}F${expFractionBits}_'
              'R${reciprocalWidth}F${reciprocalFractionBits}_'
              'O${outputWidth}_C${counterWidth}_'
              '${multiplierImplementation.identity}_'
              '${exp2Implementation.identity}_'
              '${reciprocalImplementation.identity}_'
              '${roundingMode.name}_${overflowMode.name}',
        ) {
    _validateInterfaces(request, resultSchema);
    final scoreShiftRight = elementFractionBits * 2 - scoreFractionBits;
    if (elementFractionBits < 0 ||
        elementFractionBits >= elementWidth ||
        valueFractionBits < 0 ||
        valueFractionBits >= valueWidth ||
        scoreShiftRight < 0 ||
        scoreWidth < 2 ||
        normalizerWidth < 2 ||
        normalizerWidth > 12 ||
        normalizerFractionBits < 0 ||
        normalizerFractionBits >= normalizerWidth ||
        expWidth < 2 ||
        expFractionBits < 0 ||
        expFractionBits >= expWidth ||
        reciprocalWidth < 2 ||
        reciprocalFractionBits < 0 ||
        reciprocalFractionBits >= reciprocalWidth ||
        outputWidth < 2 ||
        counterWidth < 1) {
      throw ArgumentError('Fixed-point attention formats are invalid.');
    }
    if (reciprocalImplementation.operation !=
        FixedPointApproximationOperation.reciprocal) {
      throw ArgumentError('Attention normalization requires reciprocal.');
    }

    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localClear = clearCounters == null
        ? Const(0)
        : addInput('clearCounters', clearCounters);
    this.request =
        addTypedInput<FixedPointAttentionRequest>('request', request);
    result = addTypedPayloadOutput(this, 'result', resultSchema);
    final localLoad = addInput('load', load);
    final localRetire = addInput('retire', retire ?? Const(1));

    final indexWidth = max(1, sequenceLength.log2Ceil);
    final processing = Logic(name: '${name}_processing');
    final index = Logic(name: '${name}_index', width: indexWidth);
    final outputValid = Logic(name: '${name}_output_valid');
    final storedQuery = LogicArray(
      [headDimension],
      elementWidth,
      name: '${name}_query',
    );
    final storedKeys = LogicArray(
      [sequenceLength, headDimension],
      elementWidth,
      name: '${name}_keys',
    );
    final storedValues = LogicArray(
      [sequenceLength, valueDimension],
      valueWidth,
      name: '${name}_values',
    );
    final storedKeyMask =
        Logic(name: '${name}_key_mask', width: sequenceLength);
    final storedLaneMask =
        Logic(name: '${name}_lane_mask', width: headDimension);
    final storedCausalCount = Logic(
      name: '${name}_causal_count',
      width: this.request.causalCountWidth,
    );
    final outputValues = LogicArray(
      [valueDimension],
      outputWidth,
      name: '${name}_output_values',
    );
    final outputRequestId = Logic(
      name: '${name}_output_request_id',
      width: this.request.requestIdWidth,
    );
    final outputInvalid = Logic(name: '${name}_output_invalid');
    final outputOverflow = Logic(name: '${name}_output_overflow');
    final outputInexact = Logic(name: '${name}_output_inexact');
    final outputApproximationError =
        Logic(name: '${name}_output_approximation_error');
    final state = OnlineSoftmaxWeightedState(
      scoreWidth: scoreWidth,
      scoreFractionBits: scoreFractionBits,
      normalizerWidth: normalizerWidth,
      normalizerFractionBits: normalizerFractionBits,
      valueCount: valueDimension,
      valueWidth: valueWidth,
      valueFractionBits: valueFractionBits,
      name: '${name}_state',
    );

    final selectedKey = LogicArray(
      [headDimension],
      elementWidth,
      name: '${name}_selected_key',
    );
    for (var lane = 0; lane < headDimension; lane++) {
      selectedKey.arrayElements[lane] <=
          [
            for (var position = 0; position < sequenceLength; position++)
              storedKeys.at([position, lane]),
          ].selectIndex(index);
    }
    final selectedValue = LogicArray(
      [valueDimension],
      valueWidth,
      name: '${name}_selected_value',
    );
    for (var lane = 0; lane < valueDimension; lane++) {
      selectedValue.arrayElements[lane] <=
          [
            for (var position = 0; position < sequenceLength; position++)
              storedValues.at([position, lane]),
          ].selectIndex(index);
    }
    final selectedKeyMask =
        sequenceLength == 1 ? storedKeyMask : storedKeyMask[index];
    final positionActive = selectedKeyMask &
        index.zeroExtend(storedCausalCount.width).lt(storedCausalCount) &
        storedLaneMask.or();
    final scoreAccumulatorWidth = elementWidth * 2 + headDimension.log2Ceil;
    final scoreDotProduct = MixedPrecisionDotProduct(
      storedQuery,
      selectedKey,
      outputWidth: scoreAccumulatorWidth,
      activeMask: storedLaneMask,
      signedLeft: true,
      signedRight: true,
      signedResult: true,
      multiplierImplementation: multiplierImplementation,
      name: '${name}_score',
    );
    final scoreNarrow = NumericNarrowing(
      scoreDotProduct.result,
      outputWidth: scoreWidth,
      signed: true,
      shiftRight: scoreShiftRight,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_score_narrow',
    );
    final update = OnlineSoftmaxWeightedUpdate(
      state,
      scoreNarrow.result,
      selectedValue,
      scoreValid: processing & positionActive,
      expWidth: expWidth,
      expFractionBits: expFractionBits,
      exp2Implementation: exp2Implementation,
      multiplierImplementation: multiplierImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_softmax_update',
    );
    final updatedState = OnlineSoftmaxWeightedState(
      scoreWidth: scoreWidth,
      scoreFractionBits: scoreFractionBits,
      normalizerWidth: normalizerWidth,
      normalizerFractionBits: normalizerFractionBits,
      valueCount: valueDimension,
      valueWidth: valueWidth,
      valueFractionBits: valueFractionBits,
      name: '${name}_updated_state',
    );
    updatedState.scalar.maximum <= update.nextState.scalar.maximum;
    updatedState.scalar.normalizer <= update.nextState.scalar.normalizer;
    updatedState.scalar.valid <= update.nextState.scalar.valid;
    updatedState.scalar.overflow <=
        update.nextState.scalar.overflow |
            (processing &
                positionActive &
                (scoreNarrow.overflowed | scoreNarrow.underflowed));
    updatedState.scalar.inexact <=
        update.nextState.scalar.inexact |
            (processing & positionActive & scoreNarrow.inexact);
    updatedState.scalar.approximationError <=
        update.nextState.scalar.approximationError;
    for (var lane = 0; lane < valueDimension; lane++) {
      updatedState.weightedValues.arrayElements[lane] <=
          update.nextState.weightedValues.arrayElements[lane];
    }
    final normalize = OnlineSoftmaxNormalize(
      updatedState,
      reciprocalWidth: reciprocalWidth,
      reciprocalFractionBits: reciprocalFractionBits,
      outputWidth: outputWidth,
      reciprocalImplementation: reciprocalImplementation,
      multiplierImplementation: multiplierImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_normalize',
    );

    final inputAccepted = localLoad;
    final outputAccepted = outputValid & localRetire;
    final lastPosition = index.eq(sequenceLength - 1);
    addOutput('canLoad') <= ~processing & (~outputValid | localRetire);
    addOutput('resultValid') <= outputValid;
    for (var lane = 0; lane < valueDimension; lane++) {
      result.values.arrayElements[lane] <= outputValues.arrayElements[lane];
    }
    result.requestId <= outputRequestId;
    result.invalidInput <= outputInvalid;
    result.overflow <= outputOverflow;
    result.inexact <= outputInexact;
    result.approximationError <= outputApproximationError;
    addOutput('busy') <= processing;
    addOutput('currentKey', width: indexWidth) <= index;

    Sequential(localClk, reset: localReset, resetValues: {
      processing: 0,
      index: 0,
      outputValid: 0,
      storedKeyMask: 0,
      storedLaneMask: 0,
      storedCausalCount: 0,
      outputRequestId: 0,
      outputInvalid: 0,
      outputOverflow: 0,
      outputInexact: 0,
      outputApproximationError: 0,
      state.scalar.maximum: 0,
      state.scalar.normalizer: 0,
      state.scalar.valid: 0,
      state.scalar.overflow: 0,
      state.scalar.inexact: 0,
      state.scalar.approximationError: 0,
      for (final lane in storedQuery.arrayElements) lane: 0,
      for (final lane in storedKeys.arrayElements) lane: 0,
      for (final lane in storedValues.arrayElements) lane: 0,
      for (final lane in state.weightedValues.arrayElements) lane: 0,
      for (final lane in outputValues.arrayElements) lane: 0,
    }, [
      If(outputAccepted, then: [outputValid < 0]),
      If(inputAccepted, then: [
        processing < 1,
        index < 0,
        outputRequestId < this.request.requestId,
        storedKeyMask < this.request.keyMask,
        storedLaneMask < this.request.laneMask,
        storedCausalCount < this.request.causalKeyCount,
        for (var lane = 0; lane < headDimension; lane++)
          storedQuery.arrayElements[lane] <
              this.request.query.arrayElements[lane],
        for (var lane = 0; lane < storedKeys.arrayElements.length; lane++)
          storedKeys.arrayElements[lane] <
              this.request.keys.arrayElements[lane],
        for (var lane = 0; lane < storedValues.arrayElements.length; lane++)
          storedValues.arrayElements[lane] <
              this.request.values.arrayElements[lane],
        state.scalar.maximum < 0,
        state.scalar.normalizer < 0,
        state.scalar.valid < 0,
        state.scalar.overflow < 0,
        state.scalar.inexact < 0,
        state.scalar.approximationError < 0,
        for (final lane in state.weightedValues.arrayElements) lane < 0,
      ]),
      If(processing, then: [
        state.scalar.maximum < updatedState.scalar.maximum,
        state.scalar.normalizer < updatedState.scalar.normalizer,
        state.scalar.valid < updatedState.scalar.valid,
        state.scalar.overflow < updatedState.scalar.overflow,
        state.scalar.inexact < updatedState.scalar.inexact,
        state.scalar.approximationError <
            updatedState.scalar.approximationError,
        for (var lane = 0; lane < valueDimension; lane++)
          state.weightedValues.arrayElements[lane] <
              updatedState.weightedValues.arrayElements[lane],
        If(lastPosition, then: [
          processing < 0,
          outputValid < 1,
          for (var lane = 0; lane < valueDimension; lane++)
            outputValues.arrayElements[lane] <
                normalize.values.arrayElements[lane],
          outputInvalid < normalize.invalidState,
          outputOverflow < normalize.overflow,
          outputInexact < normalize.inexact,
          outputApproximationError < normalize.approximationError,
          index < 0,
        ], orElse: [
          index < index + 1,
        ]),
      ]),
    ]);

    final activeLaneCount =
        Count(storedLaneMask, name: '${name}_active_lanes').count;
    final inputTensorBits = headDimension * elementWidth +
        sequenceLength * headDimension * elementWidth +
        sequenceLength * valueDimension * valueWidth;
    final inputTensorBytes = (inputTensorBits + 7) ~/ 8;
    final scoreBytes = (scoreWidth + 7) ~/ 8;

    Logic counter(
      String counterName, {
      required Logic amount,
      required Logic enable,
    }) =>
        Accumulator(
          amount,
          clk: localClk,
          reset: localReset,
          clear: localClear,
          enable: enable,
          width: counterWidth,
          saturates: true,
          name: '${name}_$counterName',
        ).value;

    addOutput('scoreProducts', width: counterWidth) <=
        counter(
          'score_products',
          amount: activeLaneCount,
          enable: processing & positionActive,
        );
    addOutput('activeValues', width: counterWidth) <=
        counter(
          'active_values',
          amount: Const(1),
          enable: processing & positionActive,
        );
    addOutput('inputBytes', width: counterWidth) <=
        counter(
          'input_bytes',
          amount: Const(
            inputTensorBytes,
            width: max(1, (inputTensorBytes + 1).log2Ceil),
          ),
          enable: inputAccepted,
        );
    addOutput('avoidedScoreWriteBytes', width: counterWidth) <=
        counter(
          'avoided_score_write_bytes',
          amount: Const(
            scoreBytes,
            width: max(1, (scoreBytes + 1).log2Ceil),
          ),
          enable: processing & positionActive,
        );
    addOutput('busyCycles', width: counterWidth) <=
        counter(
          'busy_cycles',
          amount: Const(1),
          enable: processing,
        );
    addOutput('outputStallCycles', width: counterWidth) <=
        counter(
          'output_stall_cycles',
          amount: Const(1),
          enable: outputValid & ~localRetire,
        );
    addOutput('completedRequests', width: counterWidth) <=
        counter(
          'completed_requests',
          amount: Const(1),
          enable: outputAccepted,
        );
  }

  void _validateInterfaces(
    FixedPointAttentionRequest request,
    FixedPointAttentionResult resultSchema,
  ) {
    if (request.sequenceLength < 1 ||
        request.headDimension < 1 ||
        request.valueDimension < 1 ||
        resultSchema.valueDimension != request.valueDimension ||
        resultSchema.outputWidth != outputWidth ||
        resultSchema.requestIdWidth != request.requestIdWidth) {
      throw ArgumentError('Attention request and result shapes do not match.');
    }
  }
}

/// Ready/valid adapter around [FixedPointAttentionCore].
///
/// The action core owns arithmetic and retained results. Directional
/// attachments translate request acceptance and result retirement.
/// {@category Inference}
class FixedPointAttention extends Module {
  late final FixedPointAttentionCore _core;

  /// Registered ready/valid request boundary.
  late final ReadyValidInterface<FixedPointAttentionRequest> upstream;

  /// Registered ready/valid result boundary.
  late final ReadyValidInterface<FixedPointAttentionResult> downstream;

  /// See [FixedPointAttentionCore.sequenceLength].
  int get sequenceLength => _core.sequenceLength;

  /// See [FixedPointAttentionCore.headDimension].
  int get headDimension => _core.headDimension;

  /// See [FixedPointAttentionCore.valueDimension].
  int get valueDimension => _core.valueDimension;

  /// See [FixedPointAttentionCore.elementWidth].
  int get elementWidth => _core.elementWidth;

  /// See [FixedPointAttentionCore.elementFractionBits].
  int get elementFractionBits => _core.elementFractionBits;

  /// See [FixedPointAttentionCore.valueWidth].
  int get valueWidth => _core.valueWidth;

  /// See [FixedPointAttentionCore.valueFractionBits].
  int get valueFractionBits => _core.valueFractionBits;

  /// See [FixedPointAttentionCore.scoreWidth].
  int get scoreWidth => _core.scoreWidth;

  /// See [FixedPointAttentionCore.scoreFractionBits].
  int get scoreFractionBits => _core.scoreFractionBits;

  /// See [FixedPointAttentionCore.normalizerWidth].
  int get normalizerWidth => _core.normalizerWidth;

  /// See [FixedPointAttentionCore.normalizerFractionBits].
  int get normalizerFractionBits => _core.normalizerFractionBits;

  /// See [FixedPointAttentionCore.expWidth].
  int get expWidth => _core.expWidth;

  /// See [FixedPointAttentionCore.expFractionBits].
  int get expFractionBits => _core.expFractionBits;

  /// See [FixedPointAttentionCore.reciprocalWidth].
  int get reciprocalWidth => _core.reciprocalWidth;

  /// See [FixedPointAttentionCore.reciprocalFractionBits].
  int get reciprocalFractionBits => _core.reciprocalFractionBits;

  /// See [FixedPointAttentionCore.outputWidth].
  int get outputWidth => _core.outputWidth;

  /// See [FixedPointAttentionCore.counterWidth].
  int get counterWidth => _core.counterWidth;

  /// See [FixedPointAttentionCore.multiplierImplementation].
  InferenceMultiplierFunctor get multiplierImplementation =>
      _core.multiplierImplementation;

  /// See [FixedPointAttentionCore.exp2Implementation].
  Exp2ApproximationFunctor get exp2Implementation => _core.exp2Implementation;

  /// See [FixedPointAttentionCore.reciprocalImplementation].
  PositiveApproximationFunctor get reciprocalImplementation =>
      _core.reciprocalImplementation;

  /// See [FixedPointAttentionCore.roundingMode].
  NumericRoundingMode get roundingMode => _core.roundingMode;

  /// See [FixedPointAttentionCore.overflowMode].
  NumericOverflowMode get overflowMode => _core.overflowMode;

  /// See [FixedPointAttentionCore.busy].
  Logic get busy => output('busy');

  /// See [FixedPointAttentionCore.currentKey].
  Logic get currentKey => output('currentKey');

  /// See [FixedPointAttentionCore.scoreProducts].
  Logic get scoreProducts => output('scoreProducts');

  /// See [FixedPointAttentionCore.activeValues].
  Logic get activeValues => output('activeValues');

  /// See [FixedPointAttentionCore.inputBytes].
  Logic get inputBytes => output('inputBytes');

  /// See [FixedPointAttentionCore.avoidedScoreWriteBytes].
  Logic get avoidedScoreWriteBytes => output('avoidedScoreWriteBytes');

  /// See [FixedPointAttentionCore.busyCycles].
  Logic get busyCycles => output('busyCycles');

  /// See [FixedPointAttentionCore.outputStallCycles].
  Logic get outputStallCycles => output('outputStallCycles');

  /// See [FixedPointAttentionCore.completedRequests].
  Logic get completedRequests => output('completedRequests');

  /// Attaches ready/valid transport to bounded fixed-point attention.
  FixedPointAttention({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<FixedPointAttentionRequest> upstream,
    required ReadyValidInterface<FixedPointAttentionResult> downstream,
    required int elementFractionBits,
    required int valueFractionBits,
    required int scoreWidth,
    required int scoreFractionBits,
    required int normalizerWidth,
    required int normalizerFractionBits,
    required int expWidth,
    required int expFractionBits,
    required int reciprocalWidth,
    required int reciprocalFractionBits,
    required int outputWidth,
    Logic? clearCounters,
    int counterWidth = 32,
    InferenceMultiplierFunctor multiplierImplementation =
        nativeInferenceMultiplierFunctor,
    Exp2ApproximationFunctor exp2Implementation =
        lookupExp2ApproximationFunctor,
    PositiveApproximationFunctor reciprocalImplementation =
        lookupReciprocalApproximationFunctor,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
    super.name = 'fixed_point_attention',
  }) : super(
          definitionName: 'FixedPointAttention_'
              'S${upstream.data.sequenceLength}_'
              'H${upstream.data.headDimension}_'
              'V${upstream.data.valueDimension}_'
              'E${upstream.data.elementWidth}F${elementFractionBits}_'
              'D${upstream.data.valueWidth}F${valueFractionBits}_'
              'Q${scoreWidth}F${scoreFractionBits}_'
              'N${normalizerWidth}F${normalizerFractionBits}_'
              'X${expWidth}F${expFractionBits}_'
              'R${reciprocalWidth}F${reciprocalFractionBits}_'
              'O${outputWidth}_C${counterWidth}_'
              '${multiplierImplementation.identity}_'
              '${exp2Implementation.identity}_'
              '${reciprocalImplementation.identity}_'
              '${roundingMode.name}_${overflowMode.name}',
        ) {
    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localClear = clearCounters == null
        ? Const(0)
        : addInput('clearCounters', clearCounters);
    this.upstream = addPairInterface(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    this.downstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(downstream.data.clone()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final load = Logic(name: '${name}_load');
    final retire = Logic(name: '${name}_retire');
    final payload = cloneTypedPayload(this.upstream.data);
    _core = FixedPointAttentionCore(
      clk: localClk,
      reset: localReset,
      request: payload,
      resultSchema: this.downstream.data,
      load: load,
      retire: retire,
      elementFractionBits: elementFractionBits,
      valueFractionBits: valueFractionBits,
      scoreWidth: scoreWidth,
      scoreFractionBits: scoreFractionBits,
      normalizerWidth: normalizerWidth,
      normalizerFractionBits: normalizerFractionBits,
      expWidth: expWidth,
      expFractionBits: expFractionBits,
      reciprocalWidth: reciprocalWidth,
      reciprocalFractionBits: reciprocalFractionBits,
      outputWidth: outputWidth,
      clearCounters: localClear,
      counterWidth: counterWidth,
      multiplierImplementation: multiplierImplementation,
      exp2Implementation: exp2Implementation,
      reciprocalImplementation: reciprocalImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_core',
    );
    ReadyValidIngressAttachmentPolicy<FixedPointAttentionRequest>(
      supportsSameCycleReplacement: true,
    ).attach(
      upstream: this.upstream,
      canAccept: _core.canLoad,
      accept: load,
      payload: payload,
    );
    ReadyValidEgressAttachmentPolicy<FixedPointAttentionResult>().attach(
      downstream: this.downstream,
      offerValid: _core.resultValid,
      payload: _core.result,
      transfer: retire,
    );
    for (final port in [
      'busy',
      'currentKey',
      'scoreProducts',
      'activeValues',
      'inputBytes',
      'avoidedScoreWriteBytes',
      'busyCycles',
      'outputStallCycles',
      'completedRequests',
    ]) {
      final signal = _core.output(port);
      addOutput(port, width: signal.width) <= signal;
    }
  }
}

/// Pure-Dart result from materialized fixed-point base-2 attention.
@immutable
class FixedPointAttentionReferenceResult {
  /// Quantized output lanes.
  final List<int> values;

  /// Materialized quantized score for every active position.
  final List<int> scores;

  /// Whether no position was active.
  final bool invalidInput;

  /// Creates an immutable reference result.
  const FixedPointAttentionReferenceResult({
    required this.values,
    required this.scores,
    required this.invalidInput,
  });
}

/// Evaluates materialized base-2 fixed-point attention in software.
FixedPointAttentionReferenceResult evaluateFixedPointAttention({
  required List<int> query,
  required List<List<int>> keys,
  required List<List<int>> values,
  required List<bool> keyMask,
  required List<bool> laneMask,
  required int causalKeyCount,
  required int inputFractionBits,
  required int scoreFractionBits,
  required int outputFractionBits,
}) {
  if (keys.length != values.length ||
      keys.length != keyMask.length ||
      query.length != laneMask.length ||
      keys.any((key) => key.length != query.length) ||
      values.isEmpty ||
      values.any((value) => value.length != values.first.length)) {
    throw ArgumentError('Attention reference shapes do not match.');
  }
  final active = <int>[];
  final scores = <int>[];
  final scoreScale = pow(2, scoreFractionBits - 2 * inputFractionBits);
  for (var position = 0; position < keys.length; position++) {
    if (!keyMask[position] ||
        position >= causalKeyCount ||
        !laneMask.contains(true)) {
      continue;
    }
    var dot = 0;
    for (var lane = 0; lane < query.length; lane++) {
      if (laneMask[lane]) {
        dot += query[lane] * keys[position][lane];
      }
    }
    active.add(position);
    scores.add((dot * scoreScale).round());
  }
  if (active.isEmpty) {
    return FixedPointAttentionReferenceResult(
      values: List<int>.filled(values.first.length, 0),
      scores: const [],
      invalidInput: true,
    );
  }
  final maximum = scores.reduce(max);
  final weights = [
    for (final score in scores)
      pow(2, (score - maximum) / pow(2, scoreFractionBits)).toDouble(),
  ];
  final normalizer = weights.reduce((left, right) => left + right);
  final result = <int>[];
  for (var lane = 0; lane < values.first.length; lane++) {
    var numerator = 0.0;
    for (var item = 0; item < active.length; item++) {
      numerator += weights[item] * values[active[item]][lane];
    }
    result.add(
      (numerator / normalizer * pow(2, outputFractionBits)).round(),
    );
  }
  return FixedPointAttentionReferenceResult(
    values: List<int>.unmodifiable(result),
    scores: List<int>.unmodifiable(scores),
    invalidInput: false,
  );
}
