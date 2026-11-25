// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fixed_point_attention_row_engine.dart
// Row-streaming fixed-point attention compute engine.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/accumulation/accumulator.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';
import 'package:rohd_hcl/src/bit_operations/population_count/count.dart';
import 'package:rohd_hcl/src/flow_control/attachments/directional_attachments.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/fixed_point_approximation.dart';
import 'package:rohd_hcl/src/inference/fixed_point_attention.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/mixed_precision_dot_product.dart';
import 'package:rohd_hcl/src/inference/online_softmax_weighted_state.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// Query and transaction metadata for row-streaming fixed-point attention.
/// {@category Inference}
class FixedPointAttentionRowCommand extends LogicStructure {
  /// Query vector.
  LogicArray get query => elements[0] as LogicArray;

  /// One validity bit per query/key lane.
  Logic get laneMask => elements[1];

  /// Caller-selected transaction identity.
  Logic get requestId => elements[2];

  /// Number of query/key lanes.
  final int headDimension;

  /// Width of every query/key element.
  final int elementWidth;

  /// Width of [requestId].
  final int requestIdWidth;

  /// Creates a row-streaming attention command.
  FixedPointAttentionRowCommand({
    required this.headDimension,
    required this.elementWidth,
    this.requestIdWidth = 8,
    String name = 'fixedPointAttentionRowCommand',
  }) : super(
          [
            LogicArray([headDimension], elementWidth, name: 'query'),
            Logic(name: 'laneMask', width: headDimension),
            Logic(name: 'requestId', width: requestIdWidth),
          ],
          name: name,
        ) {
    if (headDimension < 1 || elementWidth < 2 || requestIdWidth < 1) {
      throw ArgumentError('Attention row command shape is invalid.');
    }
  }

  FixedPointAttentionRowCommand._clone(
    LogicStructure original, {
    required this.headDimension,
    required this.elementWidth,
    required this.requestIdWidth,
    required String name,
  }) : super(
          original.elements
              .map((element) => element.clone(name: element.name))
              .toList(),
          name: name,
        );

  @override
  FixedPointAttentionRowCommand clone({String? name}) =>
      FixedPointAttentionRowCommand._clone(
        this,
        headDimension: headDimension,
        elementWidth: elementWidth,
        requestIdWidth: requestIdWidth,
        name: name ?? this.name,
      );
}

/// One key/value row consumed by row-streaming fixed-point attention.
/// {@category Inference}
class FixedPointAttentionRow extends LogicStructure {
  /// Key vector for this sequence position.
  LogicArray get key => elements[0] as LogicArray;

  /// Value vector for this sequence position.
  LogicArray get values => elements[1] as LogicArray;

  /// Whether this row contributes to attention.
  Logic get active => elements[2];

  /// Whether this is the final physical row of the command.
  Logic get last => elements[3];

  /// Number of key lanes.
  final int headDimension;

  /// Number of value lanes.
  final int valueDimension;

  /// Width of every key element.
  final int elementWidth;

  /// Width of every value element.
  final int valueWidth;

  /// Creates one streamed key/value row.
  FixedPointAttentionRow({
    required this.headDimension,
    required this.valueDimension,
    required this.elementWidth,
    required this.valueWidth,
    String name = 'fixedPointAttentionRow',
  }) : super(
          [
            LogicArray([headDimension], elementWidth, name: 'key'),
            LogicArray([valueDimension], valueWidth, name: 'values'),
            Logic(name: 'active'),
            Logic(name: 'last'),
          ],
          name: name,
        ) {
    if (headDimension < 1 ||
        valueDimension < 1 ||
        elementWidth < 2 ||
        valueWidth < 2) {
      throw ArgumentError('Attention row shape is invalid.');
    }
  }

  FixedPointAttentionRow._clone(
    LogicStructure original, {
    required this.headDimension,
    required this.valueDimension,
    required this.elementWidth,
    required this.valueWidth,
    required String name,
  }) : super(
          original.elements
              .map((element) => element.clone(name: element.name))
              .toList(),
          name: name,
        );

  @override
  FixedPointAttentionRow clone({String? name}) => FixedPointAttentionRow._clone(
        this,
        headDimension: headDimension,
        valueDimension: valueDimension,
        elementWidth: elementWidth,
        valueWidth: valueWidth,
        name: name ?? this.name,
      );
}

/// Computes fused fixed-point attention from an accepted command and KV rows.
///
/// Rows may arrive with arbitrary gaps. Each accepted active row updates the
/// online-softmax state without materializing a score array. The accepted row
/// carrying [FixedPointAttentionRow.last] finalizes and retains the result.
///
/// Drive `load` only when [canLoad] is high, and `writeRow` only when
/// [canWriteRow] is high. For cycle-accurate use, submit consecutive rows
/// after loading the command. [resultValid] asserts immediately after writing
/// the final row, including a singleton active row. With `retire` omitted the
/// result is consumed on the next edge, which may also load the next command.
/// Synchronous reset discards partial rows and any retained result.
/// {@category Inference}
class FixedPointAttentionRowCore extends Module {
  /// Whether a new query command may be loaded.
  Logic get canLoad => output('canLoad');

  /// Whether a row may be submitted.
  Logic get canWriteRow => output('canWriteRow');

  /// Whether a retained result may be retired.
  Logic get resultValid => output('resultValid');

  /// Number of query/key lanes.
  final int headDimension;

  /// Number of output value lanes.
  final int valueDimension;

  /// Width of query/key elements.
  final int elementWidth;

  /// Width of value elements.
  final int valueWidth;

  /// Width of every telemetry counter.
  final int counterWidth;

  /// High after command acceptance and before final-row acceptance.
  Logic get processing => output('processing');

  /// Number of accepted rows.
  Logic get rowsAccepted => output('rowsAccepted');

  /// Number of active score products.
  Logic get scoreProducts => output('scoreProducts');

  /// Number of active rows.
  Logic get activeValues => output('activeValues');

  /// Score bytes not written because online softmax is fused.
  Logic get avoidedScoreWriteBytes => output('avoidedScoreWriteBytes');

  /// Cycles in the row-processing phase, including input waits.
  Logic get busyCycles => output('busyCycles');

  /// Processing cycles without an accepted row.
  Logic get rowWaitCycles => output('rowWaitCycles');

  /// Cycles for which the retained result was stalled.
  Logic get outputStallCycles => output('outputStallCycles');

  /// Number of accepted result transactions.
  Logic get completedRequests => output('completedRequests');

  late final FixedPointAttentionRowCommand _command;
  late final FixedPointAttentionRow _rows;

  /// Retained attention result.
  late final FixedPointAttentionResult result;

  /// Creates a row-streaming fixed-point attention engine.
  FixedPointAttentionRowCore({
    required Logic clk,
    required Logic reset,
    required FixedPointAttentionRowCommand command,
    required FixedPointAttentionRow rows,
    required FixedPointAttentionResult resultSchema,
    required Logic load,
    required Logic writeRow,
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
    Logic? retire,
    Logic? clearCounters,
    this.counterWidth = 32,
    InferenceMultiplierFunctor multiplierImplementation =
        nativeInferenceMultiplierFunctor,
    Exp2ApproximationFunctor exp2Implementation =
        lookupExp2ApproximationFunctor,
    PositiveApproximationFunctor reciprocalImplementation =
        lookupReciprocalApproximationFunctor,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
    super.name = 'fixed_point_attention_row_core',
  })  : headDimension = command.headDimension,
        valueDimension = rows.valueDimension,
        elementWidth = command.elementWidth,
        valueWidth = rows.valueWidth,
        super(
          definitionName: 'FixedPointAttentionRowCore_'
              'H${command.headDimension}_V${rows.valueDimension}_'
              'E${command.elementWidth}F${elementFractionBits}_'
              'D${rows.valueWidth}F${valueFractionBits}_'
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
    if (rows.headDimension != headDimension ||
        rows.elementWidth != elementWidth ||
        resultSchema.valueDimension != valueDimension ||
        resultSchema.outputWidth != outputWidth ||
        resultSchema.requestIdWidth != command.requestIdWidth) {
      throw ArgumentError('Attention row interfaces do not match.');
    }

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
      throw ArgumentError('Fixed-point attention row formats are invalid.');
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
    _command = addTypedInput<FixedPointAttentionRowCommand>('command', command);
    _rows = addTypedInput<FixedPointAttentionRow>('rows', rows);
    result = addTypedPayloadOutput(this, 'result', resultSchema);
    final localLoad = addInput('load', load);
    final localWriteRow = addInput('writeRow', writeRow);
    final localRetire = addInput('retire', retire ?? Const(1));

    final processingRows = Logic(name: '${name}_processing');
    final outputValid = Logic(name: '${name}_output_valid');
    final storedQuery = LogicArray(
      [headDimension],
      elementWidth,
      name: '${name}_query',
    );
    final storedLaneMask =
        Logic(name: '${name}_lane_mask', width: headDimension);
    final outputValues = LogicArray(
      [valueDimension],
      outputWidth,
      name: '${name}_output_values',
    );
    final outputRequestId = Logic(
      name: '${name}_output_request_id',
      width: command.requestIdWidth,
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
    final rowAccepted = localWriteRow;
    final positionActive = _rows.active & storedLaneMask.or();
    final scoreAccumulatorWidth = elementWidth * 2 + headDimension.log2Ceil;
    final scoreDotProduct = MixedPrecisionDotProduct(
      storedQuery,
      _rows.key,
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
      _rows.values,
      scoreValid: rowAccepted & positionActive,
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
            (rowAccepted &
                positionActive &
                (scoreNarrow.overflowed | scoreNarrow.underflowed));
    updatedState.scalar.inexact <=
        update.nextState.scalar.inexact |
            (rowAccepted & positionActive & scoreNarrow.inexact);
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

    final commandAccepted = localLoad;
    final resultAccepted = outputValid & localRetire;
    addOutput('canLoad') <= ~processingRows & (~outputValid | localRetire);
    addOutput('canWriteRow') <= processingRows;
    addOutput('resultValid') <= outputValid;
    for (var lane = 0; lane < valueDimension; lane++) {
      result.values.arrayElements[lane] <= outputValues.arrayElements[lane];
    }
    result.requestId <= outputRequestId;
    result.invalidInput <= outputInvalid;
    result.overflow <= outputOverflow;
    result.inexact <= outputInexact;
    result.approximationError <= outputApproximationError;
    addOutput('processing') <= processingRows;

    Sequential(localClk, reset: localReset, resetValues: {
      processingRows: 0,
      outputValid: 0,
      storedLaneMask: 0,
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
      for (final lane in state.weightedValues.arrayElements) lane: 0,
      for (final lane in outputValues.arrayElements) lane: 0,
    }, [
      If(resultAccepted, then: [outputValid < 0]),
      If(commandAccepted, then: [
        processingRows < 1,
        outputRequestId < _command.requestId,
        storedLaneMask < _command.laneMask,
        for (var lane = 0; lane < headDimension; lane++)
          storedQuery.arrayElements[lane] < _command.query.arrayElements[lane],
        state.scalar.maximum < 0,
        state.scalar.normalizer < 0,
        state.scalar.valid < 0,
        state.scalar.overflow < 0,
        state.scalar.inexact < 0,
        state.scalar.approximationError < 0,
        for (final lane in state.weightedValues.arrayElements) lane < 0,
      ]),
      If(rowAccepted, then: [
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
        If(_rows.last, then: [
          processingRows < 0,
          outputValid < 1,
          for (var lane = 0; lane < valueDimension; lane++)
            outputValues.arrayElements[lane] <
                normalize.values.arrayElements[lane],
          outputInvalid < normalize.invalidState,
          outputOverflow < normalize.overflow,
          outputInexact < normalize.inexact,
          outputApproximationError < normalize.approximationError,
        ]),
      ]),
    ]);

    final activeLaneCount =
        Count(storedLaneMask, name: '${name}_active_lanes').count;
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

    addOutput('rowsAccepted', width: counterWidth) <=
        counter(
          'rows_accepted',
          amount: Const(1),
          enable: rowAccepted,
        );
    addOutput('scoreProducts', width: counterWidth) <=
        counter(
          'score_products',
          amount: activeLaneCount,
          enable: rowAccepted & positionActive,
        );
    addOutput('activeValues', width: counterWidth) <=
        counter(
          'active_values',
          amount: Const(1),
          enable: rowAccepted & positionActive,
        );
    final scoreBytes = (scoreWidth + 7) ~/ 8;
    addOutput('avoidedScoreWriteBytes', width: counterWidth) <=
        counter(
          'avoided_score_write_bytes',
          amount: Const(
            scoreBytes,
            width: max(1, (scoreBytes + 1).log2Ceil),
          ),
          enable: rowAccepted & positionActive,
        );
    addOutput('busyCycles', width: counterWidth) <=
        counter(
          'busy_cycles',
          amount: Const(1),
          enable: processingRows,
        );
    addOutput('rowWaitCycles', width: counterWidth) <=
        counter(
          'row_wait_cycles',
          amount: Const(1),
          enable: processingRows & ~rowAccepted,
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
          enable: resultAccepted,
        );
  }
}

/// Ready/valid adapter around [FixedPointAttentionRowCore].
///
/// Independent ingress attachments load queries and submit rows. The egress
/// attachment retires the retained result; no arithmetic is duplicated here.
/// {@category Inference}
class FixedPointAttentionRowEngine extends Module {
  late final FixedPointAttentionRowCore _core;

  /// See [FixedPointAttentionRowCore.headDimension].
  int get headDimension => _core.headDimension;

  /// See [FixedPointAttentionRowCore.valueDimension].
  int get valueDimension => _core.valueDimension;

  /// See [FixedPointAttentionRowCore.elementWidth].
  int get elementWidth => _core.elementWidth;

  /// See [FixedPointAttentionRowCore.valueWidth].
  int get valueWidth => _core.valueWidth;

  /// See [FixedPointAttentionRowCore.counterWidth].
  int get counterWidth => _core.counterWidth;

  /// See [FixedPointAttentionRowCore.processing].
  Logic get processing => output('processing');

  /// See [FixedPointAttentionRowCore.rowsAccepted].
  Logic get rowsAccepted => output('rowsAccepted');

  /// See [FixedPointAttentionRowCore.scoreProducts].
  Logic get scoreProducts => output('scoreProducts');

  /// See [FixedPointAttentionRowCore.activeValues].
  Logic get activeValues => output('activeValues');

  /// See [FixedPointAttentionRowCore.avoidedScoreWriteBytes].
  Logic get avoidedScoreWriteBytes => output('avoidedScoreWriteBytes');

  /// See [FixedPointAttentionRowCore.busyCycles].
  Logic get busyCycles => output('busyCycles');

  /// See [FixedPointAttentionRowCore.rowWaitCycles].
  Logic get rowWaitCycles => output('rowWaitCycles');

  /// See [FixedPointAttentionRowCore.outputStallCycles].
  Logic get outputStallCycles => output('outputStallCycles');

  /// See [FixedPointAttentionRowCore.completedRequests].
  Logic get completedRequests => output('completedRequests');

  /// Attaches independent query, row, and result protocols to the action core.
  FixedPointAttentionRowEngine({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<FixedPointAttentionRowCommand> command,
    required ReadyValidInterface<FixedPointAttentionRow> rows,
    required ReadyValidInterface<FixedPointAttentionResult> result,
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
    super.name = 'fixed_point_attention_row_engine',
  }) : super(
          definitionName: 'FixedPointAttentionRowEngine_'
              'H${command.data.headDimension}_V${rows.data.valueDimension}_'
              'E${command.data.elementWidth}F${elementFractionBits}_'
              'D${rows.data.valueWidth}F${valueFractionBits}_'
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
    final localCommand = addPairInterface(command, PairRole.consumer,
        uniquify: (original) => 'command_$original');
    final localRows = addPairInterface(rows, PairRole.consumer,
        uniquify: (original) => 'rows_$original');
    final localResult = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(result.data.clone()),
      result,
      PairRole.provider,
      uniquify: (original) => 'result_$original',
    );
    final load = Logic(name: '${name}_load');
    final writeRow = Logic(name: '${name}_write_row');
    final retire = Logic(name: '${name}_retire');
    final queryPayload = cloneTypedPayload(localCommand.data);
    final rowPayload = cloneTypedPayload(localRows.data);
    _core = FixedPointAttentionRowCore(
      clk: localClk,
      reset: localReset,
      command: queryPayload,
      rows: rowPayload,
      resultSchema: localResult.data,
      load: load,
      writeRow: writeRow,
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
    ReadyValidIngressAttachmentPolicy<FixedPointAttentionRowCommand>(
      supportsSameCycleReplacement: true,
    ).attach(
      upstream: localCommand,
      canAccept: _core.canLoad,
      accept: load,
      payload: queryPayload,
    );
    ReadyValidIngressAttachmentPolicy<FixedPointAttentionRow>(
      supportsSameCycleReplacement: false,
    ).attach(
      upstream: localRows,
      canAccept: _core.canWriteRow,
      accept: writeRow,
      payload: rowPayload,
    );
    ReadyValidEgressAttachmentPolicy<FixedPointAttentionResult>().attach(
      downstream: localResult,
      offerValid: _core.resultValid,
      payload: _core.result,
      transfer: retire,
    );
    for (final port in [
      'processing',
      'rowsAccepted',
      'scoreProducts',
      'activeValues',
      'avoidedScoreWriteBytes',
      'busyCycles',
      'rowWaitCycles',
      'outputStallCycles',
      'completedRequests',
    ]) {
      final signal = _core.output(port);
      addOutput(port, width: signal.width) <= signal;
    }
  }
}
