// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// scratchpad_fixed_point_attention.dart
// Fixed-point attention fed by packed rows from external scratchpads.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/accumulation/accumulator.dart';
import 'package:rohd_hcl/src/arithmetic/conversion/numeric_narrowing.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';
import 'package:rohd_hcl/src/inference/fixed_point_approximation.dart';
import 'package:rohd_hcl/src/inference/fixed_point_attention.dart';
import 'package:rohd_hcl/src/inference/fixed_point_attention_row_engine.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';
import 'package:rohd_hcl/src/inference/tensor_scratchpad.dart';
import 'package:rohd_hcl/src/interfaces/interface_port_helpers.dart';

/// Command for one fixed-point attention operation over contiguous KV rows.
/// {@category Inference}
class ScratchpadFixedPointAttentionCommand extends LogicStructure {
  /// Query vector.
  LogicArray get query => elements[0] as LogicArray;

  /// Address of the first packed key row.
  Logic get keyBaseAddress => elements[1];

  /// Address of the first packed value row.
  Logic get valueBaseAddress => elements[2];

  /// One validity bit per key/value position.
  Logic get keyMask => elements[3];

  /// One validity bit per query/key lane.
  Logic get laneMask => elements[4];

  /// Number of leading positions permitted by the causal mask.
  Logic get causalKeyCount => elements[5];

  /// Caller-selected transaction identity.
  Logic get requestId => elements[6];

  /// Number of physical sequence positions.
  final int sequenceLength;

  /// Number of query/key lanes.
  final int headDimension;

  /// Width of each query/key element.
  final int elementWidth;

  /// Width of key scratchpad addresses.
  final int keyAddressWidth;

  /// Width of value scratchpad addresses.
  final int valueAddressWidth;

  /// Width of [requestId].
  final int requestIdWidth;

  /// Width of [causalKeyCount].
  final int causalCountWidth;

  /// Creates a contiguous-row scratchpad attention command.
  ScratchpadFixedPointAttentionCommand({
    required this.sequenceLength,
    required this.headDimension,
    required this.elementWidth,
    required this.keyAddressWidth,
    required this.valueAddressWidth,
    this.requestIdWidth = 8,
    String name = 'scratchpadFixedPointAttentionCommand',
  })  : causalCountWidth = max(1, (sequenceLength + 1).log2Ceil),
        super(
          [
            LogicArray([headDimension], elementWidth, name: 'query'),
            Logic(name: 'keyBaseAddress', width: keyAddressWidth),
            Logic(name: 'valueBaseAddress', width: valueAddressWidth),
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
        elementWidth < 2 ||
        keyAddressWidth < 1 ||
        valueAddressWidth < 1 ||
        requestIdWidth < 1) {
      throw ArgumentError('Scratchpad attention command shape is invalid.');
    }
  }

  ScratchpadFixedPointAttentionCommand._clone(
    LogicStructure original, {
    required this.sequenceLength,
    required this.headDimension,
    required this.elementWidth,
    required this.keyAddressWidth,
    required this.valueAddressWidth,
    required this.requestIdWidth,
    required this.causalCountWidth,
    required String name,
  }) : super(
          original.elements
              .map((element) => element.clone(name: element.name))
              .toList(),
          name: name,
        );

  @override
  ScratchpadFixedPointAttentionCommand clone({String? name}) =>
      ScratchpadFixedPointAttentionCommand._clone(
        this,
        sequenceLength: sequenceLength,
        headDimension: headDimension,
        elementWidth: elementWidth,
        keyAddressWidth: keyAddressWidth,
        valueAddressWidth: valueAddressWidth,
        requestIdWidth: requestIdWidth,
        causalCountWidth: causalCountWidth,
        name: name ?? this.name,
      );
}

/// Result and memory status from scratchpad-backed fixed-point attention.
/// {@category Inference}
class ScratchpadFixedPointAttentionResult extends LogicStructure {
  /// Normalized attention output vector.
  LogicArray get values => elements[0] as LogicArray;

  /// Identity copied from the accepted command.
  Logic get requestId => elements[1];

  /// No key/value position was active.
  Logic get invalidInput => elements[2];

  /// Any score, softmax, or output arithmetic overflowed.
  Logic get overflow => elements[3];

  /// Any approximation or fixed-point rounding was inexact.
  Logic get inexact => elements[4];

  /// An approximation input violated its configured contract.
  Logic get approximationError => elements[5];

  /// A key or value scratchpad response reported an error.
  Logic get memoryError => elements[6];

  /// A scratchpad response tag did not match the requested row.
  Logic get protocolError => elements[7];

  /// A contiguous row address exceeded its configured address width.
  Logic get addressOverflow => elements[8];

  /// Number of output lanes.
  final int valueDimension;

  /// Width of each output lane.
  final int outputWidth;

  /// Width of [requestId].
  final int requestIdWidth;

  /// Creates a scratchpad-backed attention result.
  ScratchpadFixedPointAttentionResult({
    required this.valueDimension,
    required this.outputWidth,
    required this.requestIdWidth,
    String name = 'scratchpadFixedPointAttentionResult',
  }) : super(
          [
            LogicArray([valueDimension], outputWidth, name: 'values'),
            Logic(name: 'requestId', width: requestIdWidth),
            Logic(name: 'invalidInput'),
            Logic(name: 'overflow'),
            Logic(name: 'inexact'),
            Logic(name: 'approximationError'),
            Logic(name: 'memoryError'),
            Logic(name: 'protocolError'),
            Logic(name: 'addressOverflow'),
          ],
          name: name,
        ) {
    if (valueDimension < 1 || outputWidth < 2 || requestIdWidth < 1) {
      throw ArgumentError('Scratchpad attention result shape is invalid.');
    }
  }

  ScratchpadFixedPointAttentionResult._clone(
    LogicStructure original, {
    required this.valueDimension,
    required this.outputWidth,
    required this.requestIdWidth,
    required String name,
  }) : super(
          original.elements
              .map((element) => element.clone(name: element.name))
              .toList(),
          name: name,
        );

  @override
  ScratchpadFixedPointAttentionResult clone({String? name}) =>
      ScratchpadFixedPointAttentionResult._clone(
        this,
        valueDimension: valueDimension,
        outputWidth: outputWidth,
        requestIdWidth: requestIdWidth,
        name: name ?? this.name,
      );
}

/// Loads packed KV rows from scratchpads and runs fused fixed-point attention.
///
/// Key rows are packed least-significant lane first into
/// `headDimension * elementWidth` bits. Value rows use the same convention
/// with `valueDimension * valueWidth` bits. The loader permits one outstanding
/// request on each memory channel and waits for both rows before advancing.
/// Each completed row is submitted immediately to
/// [FixedPointAttentionRowEngine], allowing the following memory request to
/// overlap the accumulated online-softmax computation.
/// {@category Inference}
class ScratchpadFixedPointAttention extends Module {
  /// Number of physical sequence positions.
  final int sequenceLength;

  /// Number of query/key lanes.
  final int headDimension;

  /// Number of value/output lanes.
  final int valueDimension;

  /// Width of query and key elements.
  final int elementWidth;

  /// Width of value elements.
  final int valueWidth;

  /// Width of telemetry counters.
  final int counterWidth;

  /// High from command acceptance through result acceptance.
  Logic get busy => output('busy');

  /// High while key and value rows are being loaded.
  Logic get loading => output('loading');

  /// Row currently being loaded.
  Logic get loadIndex => output('loadIndex');

  /// Numeric query bytes accepted on commands.
  Logic get commandInputBytes => output('commandInputBytes');

  /// Packed key and value bytes returned by memory.
  Logic get memoryReadBytes => output('memoryReadBytes');

  /// Cycles spent loading KV rows.
  Logic get memoryLoadCycles => output('memoryLoadCycles');

  /// Loading cycles with at least one blocked read request.
  Logic get memoryRequestStallCycles => output('memoryRequestStallCycles');

  /// Number of KV rows accepted by the streaming compute engine.
  Logic get rowsAccepted => output('rowsAccepted');

  /// Active score multiplications performed by the compute core.
  Logic get scoreProducts => output('scoreProducts');

  /// Active key/value positions consumed by the compute core.
  Logic get activeValues => output('activeValues');

  /// Cycles from row-command acceptance through final-row acceptance.
  Logic get computeBusyCycles => output('computeBusyCycles');

  /// Compute cycles spent waiting for the next complete KV row.
  Logic get rowWaitCycles => output('rowWaitCycles');

  /// Cycles for which the completed result was blocked.
  Logic get outputStallCycles => output('outputStallCycles');

  /// Number of accepted result transactions.
  Logic get completedRequests => output('completedRequests');

  /// Score bytes avoided by fused online softmax.
  Logic get avoidedScoreWriteBytes => output('avoidedScoreWriteBytes');

  late final ReadyValidInterface<ScratchpadFixedPointAttentionCommand> _command;
  late final IrrevocableReadyValidInterface<TensorScratchpadReadRequest>
      _keyReadRequest;
  late final ReadyValidInterface<TensorScratchpadReadResponse> _keyReadResponse;
  late final IrrevocableReadyValidInterface<TensorScratchpadReadRequest>
      _valueReadRequest;
  late final ReadyValidInterface<TensorScratchpadReadResponse>
      _valueReadResponse;
  late final IrrevocableReadyValidInterface<ScratchpadFixedPointAttentionResult>
      _result;

  /// Creates a scratchpad-fed fixed-point attention engine.
  ScratchpadFixedPointAttention({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<ScratchpadFixedPointAttentionCommand> command,
    required ReadyValidInterface<TensorScratchpadReadRequest> keyReadRequest,
    required ReadyValidInterface<TensorScratchpadReadResponse> keyReadResponse,
    required ReadyValidInterface<TensorScratchpadReadRequest> valueReadRequest,
    required ReadyValidInterface<TensorScratchpadReadResponse>
        valueReadResponse,
    required ReadyValidInterface<ScratchpadFixedPointAttentionResult> result,
    required int valueDimension,
    required int valueWidth,
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
    this.counterWidth = 32,
    InferenceMultiplierFunctor multiplierImplementation =
        nativeInferenceMultiplierFunctor,
    Exp2ApproximationFunctor exp2Implementation =
        lookupExp2ApproximationFunctor,
    PositiveApproximationFunctor reciprocalImplementation =
        lookupReciprocalApproximationFunctor,
    NumericRoundingMode roundingMode = NumericRoundingMode.nearestEven,
    NumericOverflowMode overflowMode = NumericOverflowMode.saturate,
    super.name = 'scratchpad_fixed_point_attention',
  })  : sequenceLength = command.data.sequenceLength,
        headDimension = command.data.headDimension,
        valueDimension = valueDimension,
        elementWidth = command.data.elementWidth,
        valueWidth = valueWidth,
        super(
          definitionName: 'ScratchpadFixedPointAttention_'
              'S${command.data.sequenceLength}_'
              'H${command.data.headDimension}_V${valueDimension}_'
              'E${command.data.elementWidth}F${elementFractionBits}_'
              'D${valueWidth}F${valueFractionBits}_'
              'Q${scoreWidth}F${scoreFractionBits}_'
              'N${normalizerWidth}F${normalizerFractionBits}_'
              'X${expWidth}F${expFractionBits}_'
              'R${reciprocalWidth}F${reciprocalFractionBits}_'
              'O${outputWidth}_C$counterWidth',
        ) {
    final indexWidth = max(1, sequenceLength.log2Ceil);
    final keyWordWidth = headDimension * elementWidth;
    final valueWordWidth = valueDimension * valueWidth;
    if (valueDimension < 1 ||
        valueWidth < 2 ||
        counterWidth < 1 ||
        BigInt.from(sequenceLength) >
            (BigInt.one << command.data.keyAddressWidth) ||
        BigInt.from(sequenceLength) >
            (BigInt.one << command.data.valueAddressWidth) ||
        keyReadRequest.data.addressWidth != command.data.keyAddressWidth ||
        valueReadRequest.data.addressWidth != command.data.valueAddressWidth ||
        keyReadRequest.data.tagWidth != indexWidth ||
        valueReadRequest.data.tagWidth != indexWidth ||
        keyReadResponse.data.dataWidth != keyWordWidth ||
        valueReadResponse.data.dataWidth != valueWordWidth ||
        keyReadResponse.data.tagWidth != indexWidth ||
        valueReadResponse.data.tagWidth != indexWidth ||
        result.data.valueDimension != valueDimension ||
        result.data.outputWidth != outputWidth ||
        result.data.requestIdWidth != command.data.requestIdWidth) {
      throw ArgumentError(
          'Scratchpad attention command, memory, and result shapes mismatch.');
    }

    final localClk = addInput('clk', clk);
    final localReset = addInput('reset', reset);
    final localClear = clearCounters == null
        ? Const(0)
        : addInput('clearCounters', clearCounters);
    _command = addPairInterface(
      command,
      PairRole.consumer,
      uniquify: (original) => 'command_$original',
    );
    _keyReadRequest = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(keyReadRequest.data.clone()),
      keyReadRequest,
      PairRole.provider,
      uniquify: (original) => 'keyReadRequest_$original',
    );
    _keyReadResponse = addPairInterface(
      keyReadResponse,
      PairRole.consumer,
      uniquify: (original) => 'keyReadResponse_$original',
    );
    _valueReadRequest = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(valueReadRequest.data.clone()),
      valueReadRequest,
      PairRole.provider,
      uniquify: (original) => 'valueReadRequest_$original',
    );
    _valueReadResponse = addPairInterface(
      valueReadResponse,
      PairRole.consumer,
      uniquify: (original) => 'valueReadResponse_$original',
    );
    _result = addPairInterfaceFrom(
      IrrevocableReadyValidInterface(result.data.clone()),
      result,
      PairRole.provider,
      uniquify: (original) => 'result_$original',
    );

    final transactionActive = Logic(name: '${name}_transaction_active');
    final loadingRows = Logic(name: '${name}_loading_rows');
    final currentIndex = Logic(name: '${name}_load_index', width: indexWidth);
    final keyIssued = Logic(name: '${name}_key_issued');
    final valueIssued = Logic(name: '${name}_value_issued');
    final keyReceived = Logic(name: '${name}_key_received');
    final valueReceived = Logic(name: '${name}_value_received');
    final rowCommandPending = Logic(name: '${name}_row_command_pending');
    final storedQuery = LogicArray(
      [headDimension],
      elementWidth,
      name: '${name}_query',
    );
    final keyRow = LogicArray(
      [headDimension],
      elementWidth,
      name: '${name}_key_row',
    );
    final valueRow = LogicArray(
      [valueDimension],
      valueWidth,
      name: '${name}_value_row',
    );
    final keyRowError = Logic(name: '${name}_key_row_error');
    final valueRowError = Logic(name: '${name}_value_row_error');
    final keyRowProtocolError = Logic(name: '${name}_key_row_protocol_error');
    final valueRowProtocolError =
        Logic(name: '${name}_value_row_protocol_error');
    final storedKeyBase = Logic(
      name: '${name}_key_base',
      width: command.data.keyAddressWidth,
    );
    final storedValueBase = Logic(
      name: '${name}_value_base',
      width: command.data.valueAddressWidth,
    );
    final storedKeyMask =
        Logic(name: '${name}_key_mask', width: sequenceLength);
    final storedLaneMask =
        Logic(name: '${name}_lane_mask', width: headDimension);
    final storedCausalCount = Logic(
      name: '${name}_causal_count',
      width: command.data.causalCountWidth,
    );
    final storedRequestId = Logic(
      name: '${name}_request_id',
      width: command.data.requestIdWidth,
    );
    final memoryError = Logic(name: '${name}_memory_error');
    final protocolError = Logic(name: '${name}_protocol_error');
    final addressOverflow = Logic(name: '${name}_address_overflow');

    final keyAddressWidth = command.data.keyAddressWidth;
    final valueAddressWidth = command.data.valueAddressWidth;
    final keyExtendedAddress = (storedKeyBase.zeroExtend(keyAddressWidth + 1) +
            currentIndex.zeroExtend(keyAddressWidth + 1))
        .named('${name}_key_extended_address');
    final valueExtendedAddress =
        (storedValueBase.zeroExtend(valueAddressWidth + 1) +
                currentIndex.zeroExtend(valueAddressWidth + 1))
            .named('${name}_value_extended_address');
    final nextIndex = (currentIndex + Const(1, width: indexWidth))
        .named('${name}_next_load_index');
    final nextKeyExtendedAddress =
        (storedKeyBase.zeroExtend(keyAddressWidth + 1) +
                nextIndex.zeroExtend(keyAddressWidth + 1))
            .named('${name}_next_key_extended_address');
    final nextValueExtendedAddress =
        (storedValueBase.zeroExtend(valueAddressWidth + 1) +
                nextIndex.zeroExtend(valueAddressWidth + 1))
            .named('${name}_next_value_extended_address');
    final keyAddressOverflow = keyExtendedAddress[keyAddressWidth];
    final valueAddressOverflow = valueExtendedAddress[valueAddressWidth];
    final nextKeyAddressOverflow = nextKeyExtendedAddress[keyAddressWidth];
    final nextValueAddressOverflow =
        nextValueExtendedAddress[valueAddressWidth];
    final prefetchNextRow = Logic(name: '${name}_prefetch_next_row');
    final keyRequestValid = (loadingRows & ~keyIssued & ~keyAddressOverflow) |
        (prefetchNextRow & ~nextKeyAddressOverflow);
    final valueRequestValid =
        (loadingRows & ~valueIssued & ~valueAddressOverflow) |
            (prefetchNextRow & ~nextValueAddressOverflow);
    final keyResponseAccepted = _keyReadResponse.accepted;
    final valueResponseAccepted = _valueReadResponse.accepted;
    final keyComplete = keyReceived | keyAddressOverflow;
    final valueComplete = valueReceived | valueAddressOverflow;
    final lastRow = currentIndex.eq(sequenceLength - 1);

    _keyReadRequest.valid <= keyRequestValid;
    _keyReadRequest.data.address <=
        mux(
          prefetchNextRow,
          nextKeyExtendedAddress.getRange(0, keyAddressWidth),
          keyExtendedAddress.getRange(0, keyAddressWidth),
        );
    _keyReadRequest.data.tag <= mux(prefetchNextRow, nextIndex, currentIndex);
    _valueReadRequest.valid <= valueRequestValid;
    _valueReadRequest.data.address <=
        mux(
          prefetchNextRow,
          nextValueExtendedAddress.getRange(0, valueAddressWidth),
          valueExtendedAddress.getRange(0, valueAddressWidth),
        );
    _valueReadRequest.data.tag <= mux(prefetchNextRow, nextIndex, currentIndex);
    _keyReadResponse.ready <= loadingRows & keyIssued & ~keyReceived;
    _valueReadResponse.ready <= loadingRows & valueIssued & ~valueReceived;

    final rowCommand = FixedPointAttentionRowCommand(
      headDimension: headDimension,
      elementWidth: elementWidth,
      requestIdWidth: command.data.requestIdWidth,
      name: '${name}_row_command',
    );
    final rowInput = FixedPointAttentionRow(
      headDimension: headDimension,
      valueDimension: valueDimension,
      elementWidth: elementWidth,
      valueWidth: valueWidth,
      name: '${name}_row',
    );
    final rowResultSchema = FixedPointAttentionResult(
      valueDimension: valueDimension,
      outputWidth: outputWidth,
      requestIdWidth: command.data.requestIdWidth,
      name: '${name}_row_result',
    );
    final loadCompute = Logic(name: '${name}_load_compute');
    final writeComputeRow = Logic(name: '${name}_write_compute_row');
    final retireCompute = Logic(name: '${name}_retire_compute');
    for (var lane = 0; lane < headDimension; lane++) {
      rowCommand.query.arrayElements[lane] <= storedQuery.arrayElements[lane];
      rowInput.key.arrayElements[lane] <= keyRow.arrayElements[lane];
    }
    for (var lane = 0; lane < valueDimension; lane++) {
      rowInput.values.arrayElements[lane] <= valueRow.arrayElements[lane];
    }
    rowCommand.laneMask <= storedLaneMask;
    rowCommand.requestId <= storedRequestId;
    final rowHasError = keyAddressOverflow |
        valueAddressOverflow |
        keyRowError |
        valueRowError |
        keyRowProtocolError |
        valueRowProtocolError;
    final rowActive = storedKeyMask[currentIndex] &
        currentIndex.zeroExtend(storedCausalCount.width).lt(storedCausalCount) &
        storedLaneMask.or() &
        ~rowHasError;
    final rowOffered =
        loadingRows & keyComplete & valueComplete & ~rowCommandPending;
    rowInput.active <= rowActive;
    rowInput.last <= lastRow;
    final core = FixedPointAttentionRowCore(
      clk: localClk,
      reset: localReset,
      clearCounters: localClear,
      command: rowCommand,
      rows: rowInput,
      resultSchema: rowResultSchema,
      load: loadCompute,
      writeRow: writeComputeRow,
      retire: retireCompute,
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
      counterWidth: counterWidth,
      multiplierImplementation: multiplierImplementation,
      exp2Implementation: exp2Implementation,
      reciprocalImplementation: reciprocalImplementation,
      roundingMode: roundingMode,
      overflowMode: overflowMode,
      name: '${name}_core',
    );
    loadCompute <= rowCommandPending & core.canLoad;
    writeComputeRow <= rowOffered & core.canWriteRow;
    retireCompute <= core.resultValid & _result.ready;
    prefetchNextRow <= writeComputeRow & ~lastRow;
    final rowResult = core.result;

    _command.ready <= ~transactionActive;
    _result.valid <= core.resultValid;
    for (var lane = 0; lane < valueDimension; lane++) {
      _result.data.values.arrayElements[lane] <=
          rowResult.values.arrayElements[lane];
    }
    _result.data.requestId <= rowResult.requestId;
    _result.data.invalidInput <= rowResult.invalidInput;
    _result.data.overflow <= rowResult.overflow;
    _result.data.inexact <= rowResult.inexact;
    _result.data.approximationError <= rowResult.approximationError;
    _result.data.memoryError <= memoryError;
    _result.data.protocolError <= protocolError;
    _result.data.addressOverflow <= addressOverflow;
    addOutput('busy') <= transactionActive;
    addOutput('loading') <= loadingRows;
    addOutput('loadIndex', width: indexWidth) <= currentIndex;

    final commandAccepted = _command.accepted;
    final resultAccepted = _result.accepted;
    final rowCommandAccepted = loadCompute;
    final rowAccepted = writeComputeRow;
    final keyPrefetchAccepted =
        prefetchNextRow & ~nextKeyAddressOverflow & _keyReadRequest.ready;
    final valuePrefetchAccepted =
        prefetchNextRow & ~nextValueAddressOverflow & _valueReadRequest.ready;
    final keyTagMismatch =
        keyResponseAccepted & _keyReadResponse.data.tag.neq(currentIndex);
    final valueTagMismatch =
        valueResponseAccepted & _valueReadResponse.data.tag.neq(currentIndex);
    final memoryErrorThisCycle =
        (keyResponseAccepted & _keyReadResponse.data.error) |
            (valueResponseAccepted & _valueReadResponse.data.error);
    final protocolErrorThisCycle = keyTagMismatch | valueTagMismatch;

    Sequential(localClk, reset: localReset, resetValues: {
      transactionActive: 0,
      loadingRows: 0,
      currentIndex: 0,
      keyIssued: 0,
      valueIssued: 0,
      keyReceived: 0,
      valueReceived: 0,
      rowCommandPending: 0,
      keyRowError: 0,
      valueRowError: 0,
      keyRowProtocolError: 0,
      valueRowProtocolError: 0,
      storedKeyBase: 0,
      storedValueBase: 0,
      storedKeyMask: 0,
      storedLaneMask: 0,
      storedCausalCount: 0,
      storedRequestId: 0,
      memoryError: 0,
      protocolError: 0,
      addressOverflow: 0,
      for (final lane in storedQuery.arrayElements) lane: 0,
      for (final lane in keyRow.arrayElements) lane: 0,
      for (final lane in valueRow.arrayElements) lane: 0,
    }, [
      If(resultAccepted, then: [transactionActive < 0]),
      If(commandAccepted, then: [
        transactionActive < 1,
        loadingRows < 1,
        currentIndex < 0,
        keyIssued < 0,
        valueIssued < 0,
        keyReceived < 0,
        valueReceived < 0,
        rowCommandPending < 1,
        keyRowError < 0,
        valueRowError < 0,
        keyRowProtocolError < 0,
        valueRowProtocolError < 0,
        storedKeyBase < _command.data.keyBaseAddress,
        storedValueBase < _command.data.valueBaseAddress,
        storedKeyMask < _command.data.keyMask,
        storedLaneMask < _command.data.laneMask,
        storedCausalCount < _command.data.causalKeyCount,
        storedRequestId < _command.data.requestId,
        memoryError < 0,
        protocolError < 0,
        addressOverflow < 0,
        for (var lane = 0; lane < headDimension; lane++)
          storedQuery.arrayElements[lane] <
              _command.data.query.arrayElements[lane],
        for (final lane in keyRow.arrayElements) lane < 0,
        for (final lane in valueRow.arrayElements) lane < 0,
      ]),
      If(_keyReadRequest.accepted, then: [keyIssued < 1]),
      If(_valueReadRequest.accepted, then: [valueIssued < 1]),
      If(keyResponseAccepted, then: [
        keyReceived < 1,
        keyRowError < _keyReadResponse.data.error,
        keyRowProtocolError < keyTagMismatch,
        for (var lane = 0; lane < headDimension; lane++)
          keyRow.arrayElements[lane] <
              _keyReadResponse.data.data.slice(
                (lane + 1) * elementWidth - 1,
                lane * elementWidth,
              ),
      ]),
      If(valueResponseAccepted, then: [
        valueReceived < 1,
        valueRowError < _valueReadResponse.data.error,
        valueRowProtocolError < valueTagMismatch,
        for (var lane = 0; lane < valueDimension; lane++)
          valueRow.arrayElements[lane] <
              _valueReadResponse.data.data.slice(
                (lane + 1) * valueWidth - 1,
                lane * valueWidth,
              ),
      ]),
      If(memoryErrorThisCycle, then: [memoryError < 1]),
      If(protocolErrorThisCycle, then: [protocolError < 1]),
      If(rowAccepted, then: [
        addressOverflow <
            addressOverflow | keyAddressOverflow | valueAddressOverflow,
        If(lastRow, then: [
          loadingRows < 0,
        ], orElse: [
          currentIndex < currentIndex + 1,
          keyIssued < keyPrefetchAccepted,
          valueIssued < valuePrefetchAccepted,
          keyReceived < 0,
          valueReceived < 0,
          keyRowError < 0,
          valueRowError < 0,
          keyRowProtocolError < 0,
          valueRowProtocolError < 0,
          for (final lane in keyRow.arrayElements) lane < 0,
          for (final lane in valueRow.arrayElements) lane < 0,
        ]),
      ]),
      If(rowCommandAccepted, then: [rowCommandPending < 0]),
    ]);

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

    final queryBytes = (headDimension * elementWidth + 7) ~/ 8;
    final keyBytes = (keyWordWidth + 7) ~/ 8;
    final valueBytes = (valueWordWidth + 7) ~/ 8;
    final readByteAmountWidth = max(1, (keyBytes + valueBytes + 1).log2Ceil);
    final readBytesThisCycle = (mux(
              keyResponseAccepted,
              Logic.from(Const(keyBytes, width: readByteAmountWidth)),
              Logic.from(Const(0, width: readByteAmountWidth)),
            ) +
            mux(
              valueResponseAccepted,
              Logic.from(Const(valueBytes, width: readByteAmountWidth)),
              Logic.from(Const(0, width: readByteAmountWidth)),
            ))
        .named('${name}_read_bytes_this_cycle');
    addOutput('commandInputBytes', width: counterWidth) <=
        counter(
          'command_input_bytes',
          amount: Const(
            queryBytes,
            width: max(1, (queryBytes + 1).log2Ceil),
          ),
          enable: commandAccepted,
        );
    addOutput('memoryReadBytes', width: counterWidth) <=
        counter(
          'memory_read_bytes',
          amount: readBytesThisCycle,
          enable: keyResponseAccepted | valueResponseAccepted,
        );
    addOutput('memoryLoadCycles', width: counterWidth) <=
        counter(
          'memory_load_cycles',
          amount: Const(1),
          enable: loadingRows,
        );
    addOutput('memoryRequestStallCycles', width: counterWidth) <=
        counter(
          'memory_request_stall_cycles',
          amount: Const(1),
          enable: (_keyReadRequest.valid & ~_keyReadRequest.ready) |
              (_valueReadRequest.valid & ~_valueReadRequest.ready),
        );
    addOutput('rowsAccepted', width: counterWidth) <= core.rowsAccepted;
    addOutput('scoreProducts', width: counterWidth) <= core.scoreProducts;
    addOutput('activeValues', width: counterWidth) <= core.activeValues;
    addOutput('computeBusyCycles', width: counterWidth) <= core.busyCycles;
    addOutput('rowWaitCycles', width: counterWidth) <= core.rowWaitCycles;
    addOutput('outputStallCycles', width: counterWidth) <=
        core.outputStallCycles;
    addOutput('completedRequests', width: counterWidth) <=
        core.completedRequests;
    addOutput('avoidedScoreWriteBytes', width: counterWidth) <=
        core.avoidedScoreWriteBytes;
  }
}
