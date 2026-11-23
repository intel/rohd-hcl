// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// inference_primitives_icarus_test.dart
// Tests for Inference Primitives Icarus.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('inference primitives compile in Icarus', () async {
    final left = _lanes(4, 4, 'left');
    final right = _lanes(4, 3, 'right');
    final dotProduct = MixedPrecisionDotProduct(
      left,
      right,
      outputWidth: 12,
      activeMask: Logic(width: 4),
      signedLeft: true,
    );
    final compressionDotProduct = MixedPrecisionDotProduct(
      _lanes(4, 4, 'compressionLeft'),
      _lanes(4, 3, 'compressionRight'),
      outputWidth: 12,
      multiplierImplementation: compressionTreeInferenceMultiplierFunctor(),
    );
    final groupScale = GroupScaleApply(
      _lanes(4, 8, 'scaleValues'),
      _lanes(2, 8, 'scales'),
      groupSize: 2,
      fractionalBits: 8,
      outputWidth: 8,
      activeMask: Logic(width: 4),
      signedValue: Logic(name: 'scaleSignedValue'),
      signedScale: false,
      signedOutput: Logic(name: 'scaleSignedOutput'),
    );
    final exp2 = Exp2Approximation(
      Logic(width: 5),
      inputFractionBits: 2,
      outputWidth: 10,
      outputFractionBits: 8,
    );
    final reciprocal = ReciprocalApproximation(
      Logic(width: 6),
      inputFractionBits: 3,
      outputWidth: 12,
      outputFractionBits: 8,
    );
    final reciprocalSqrt = ReciprocalSqrtApproximation(
      Logic(width: 6),
      inputFractionBits: 3,
      outputWidth: 12,
      outputFractionBits: 8,
    );
    final softmaxMerge = OnlineSoftmaxMerge(
      OnlineSoftmaxState(
        scoreWidth: 5,
        scoreFractionBits: 2,
        normalizerWidth: 12,
        normalizerFractionBits: 8,
        name: 'leftSoftmaxState',
      ),
      OnlineSoftmaxState(
        scoreWidth: 5,
        scoreFractionBits: 2,
        normalizerWidth: 12,
        normalizerFractionBits: 8,
        name: 'rightSoftmaxState',
      ),
      expWidth: 10,
      expFractionBits: 8,
    );
    final weightedMerge = OnlineSoftmaxWeightedMerge(
      _weightedState('leftWeightedState'),
      _weightedState('rightWeightedState'),
      expWidth: 8,
      expFractionBits: 4,
    );
    final weightedNormalize = OnlineSoftmaxNormalize(
      _weightedState('normalizeState'),
      reciprocalWidth: 8,
      reciprocalFractionBits: 4,
      outputWidth: 8,
    );
    final rmsNorm = RmsNorm(
      _lanes(4, 8, 'rmsValues'),
      _lanes(4, 8, 'rmsWeights'),
      valueFractionBits: 2,
      weightFractionBits: 4,
      meanSquareWidth: 8,
      countReciprocalWidth: 8,
      countReciprocalFractionBits: 4,
      inverseRmsWidth: 8,
      inverseRmsFractionBits: 4,
      outputWidth: 8,
      epsilonRaw: 1,
      activeMask: Logic(width: 4),
    );
    final attentionRequest = ReadyValidInterface(
      FixedPointAttentionRequest(
        sequenceLength: 2,
        headDimension: 2,
        valueDimension: 2,
        elementWidth: 4,
        valueWidth: 8,
        requestIdWidth: 2,
      ),
    );
    final attentionResult = ReadyValidInterface(
      FixedPointAttentionResult(
        valueDimension: 2,
        outputWidth: 8,
        requestIdWidth: 2,
      ),
    );
    final attention = FixedPointAttention(
      clk: Logic(),
      reset: Logic(),
      upstream: attentionRequest,
      downstream: attentionResult,
      elementFractionBits: 0,
      valueFractionBits: 0,
      scoreWidth: 6,
      scoreFractionBits: 0,
      normalizerWidth: 8,
      normalizerFractionBits: 4,
      expWidth: 8,
      expFractionBits: 4,
      reciprocalWidth: 8,
      reciprocalFractionBits: 4,
      outputWidth: 8,
      counterWidth: 16,
    );
    final addressCommand = ReadyValidInterface(
      TensorAddressCommand(
        addressWidth: 8,
        mWidth: 2,
        nWidth: 2,
        kWidth: 2,
        commandIdWidth: 2,
      ),
    );
    final addressBeat = ReadyValidInterface(
      TensorAddressBeat(
        addressWidth: 8,
        mWidth: 2,
        nWidth: 2,
        kWidth: 2,
        commandIdWidth: 2,
      ),
    );
    final addressGenerator = TensorStridedAddressGenerator(
      clk: Logic(),
      reset: Logic(),
      upstream: addressCommand,
      downstream: addressBeat,
      counterWidth: 16,
    );
    final scratchpadReadRequest = ReadyValidInterface(
      TensorScratchpadReadRequest(
        addressWidth: 3,
        tagWidth: 2,
      ),
    );
    final scratchpadReadResponse = ReadyValidInterface(
      TensorScratchpadReadResponse(
        dataWidth: 8,
        tagWidth: 2,
      ),
    );
    final scratchpadWriteRequest = ReadyValidInterface(
      TensorScratchpadWriteRequest(
        addressWidth: 3,
        dataWidth: 8,
      ),
    );
    final scratchpad = TensorScratchpad(
      clk: Logic(),
      reset: Logic(),
      readRequests: [scratchpadReadRequest],
      readResponses: [scratchpadReadResponse],
      writeRequests: [scratchpadWriteRequest],
      depth: 6,
      bankCount: 2,
    );
    final dmaCommand = ReadyValidInterface(
      TensorDmaCommand(
        sourceAddressWidth: 8,
        destinationAddressWidth: 8,
        mWidth: 2,
        nWidth: 2,
        kWidth: 2,
        commandIdWidth: 3,
      ),
    );
    final dmaReadRequest = ReadyValidInterface(
      TensorScratchpadReadRequest(
        addressWidth: 8,
        tagWidth: 3,
        name: 'dmaReadRequest',
      ),
    );
    final dmaReadResponse = ReadyValidInterface(
      TensorScratchpadReadResponse(
        dataWidth: 8,
        tagWidth: 3,
        name: 'dmaReadResponse',
      ),
    );
    final dmaWriteRequest = ReadyValidInterface(
      TensorScratchpadWriteRequest(
        addressWidth: 8,
        dataWidth: 8,
        name: 'dmaWriteRequest',
      ),
    );
    final dmaCompletion = ReadyValidInterface(
      TensorDmaCompletion(
        commandIdWidth: 3,
        countWidth: tensorDmaCountWidth(mWidth: 2, nWidth: 2, kWidth: 2),
      ),
    );
    final dma = TensorDmaEngine(
      clk: Logic(),
      reset: Logic(),
      command: dmaCommand,
      sourceReadRequest: dmaReadRequest,
      sourceReadResponse: dmaReadResponse,
      destinationWriteRequest: dmaWriteRequest,
      completion: dmaCompletion,
      sourceDepth: 128,
      destinationDepth: 128,
      counterWidth: 16,
    );
    final bufferedTileFormat = InferenceNumericFormat.signedInteger(8);
    final tileBuffer = tensorPingPongBuffer(
      clk: Logic(),
      reset: Logic(),
      upstream: ReadyValidInterface(
        inferenceLogicTensorTile(
          rowCount: 2,
          columnCount: 2,
          format: bufferedTileFormat,
          name: 'bufferUpstreamTile',
        ),
      ),
      downstream: ReadyValidInterface(
        inferenceLogicTensorTile(
          rowCount: 2,
          columnCount: 2,
          format: bufferedTileFormat,
          name: 'bufferDownstreamTile',
        ),
      ),
    );
    final reduce = VectorReduce(
      _lanes(4, 4, 'reduceLanes'),
      operation: InferenceVectorReduction.maximum,
      activeMask: Logic(width: 4),
      signed: true,
    );
    final iterator = TensorTileIterator(
      clk: Logic(),
      reset: Logic(),
      start: Logic(),
      advance: Logic(),
      mTiles: Logic(width: 3),
      nTiles: Logic(width: 3),
      kTiles: Logic(width: 3),
    );
    final tile = inferenceLogicTensorTile(
      rowCount: 2,
      columnCount: 2,
      format: InferenceNumericFormat.signedInteger(8),
      name: 'tileInput',
    );
    final tilePassThrough = _TensorTilePassThrough(tile);
    final transposeInput = inferenceLogicTensorTile(
      rowCount: 2,
      columnCount: 3,
      format: InferenceNumericFormat.unsignedInteger(8),
      name: 'transposeInput',
    );
    final tileTranspose =
        TensorTileTranspose<Logic, LogicValue>(transposeInput);
    final untilerInput = ReadyValidInterface(
      inferenceLogicTensorTile(
        rowCount: 2,
        columnCount: 2,
        format: InferenceNumericFormat.unsignedInteger(8),
        name: 'untilerInput',
      ),
    );
    final untilerOutput = ReadyValidInterface(
      Frame(
        InferenceTensorStreamElement(
          Logic(name: 'untilerElement', width: 8),
          rowCount: 2,
          columnCount: 2,
        ),
      ),
    );
    final untiler = TensorTileUntiler<Logic, LogicValue>(
      clk: Logic(),
      reset: Logic(),
      upstream: untilerInput,
      downstream: untilerOutput,
    );
    final tilerInput = ReadyValidInterface(
      Frame(
        InferenceTensorStreamElement(
          Logic(name: 'tilerElement', width: 8),
          rowCount: 2,
          columnCount: 2,
        ),
      ),
    );
    final tilerOutput = ReadyValidInterface(
      inferenceLogicTensorTile(
        rowCount: 2,
        columnCount: 2,
        format: InferenceNumericFormat.unsignedInteger(8),
        name: 'tilerOutput',
      ),
    );
    final tiler = TensorTileTiler<Logic, LogicValue>(
      clk: Logic(),
      reset: Logic(),
      upstream: tilerInput,
      downstream: tilerOutput,
    );

    for (final (module, name) in [
      (dotProduct, 'dot_product'),
      (compressionDotProduct, 'compression_dot_product'),
      (groupScale, 'group_scale'),
      (exp2, 'exp2'),
      (reciprocal, 'reciprocal'),
      (reciprocalSqrt, 'reciprocal_sqrt'),
      (softmaxMerge, 'softmax_merge'),
      (weightedMerge, 'weighted_softmax_merge'),
      (weightedNormalize, 'weighted_softmax_normalize'),
      (rmsNorm, 'rms_norm'),
      (attention, 'fixed_point_attention'),
      (addressGenerator, 'tensor_address_generator'),
      (scratchpad, 'tensor_scratchpad'),
      (dma, 'tensor_dma'),
      (tileBuffer, 'tensor_tile_buffer'),
      (reduce, 'reduce'),
      (iterator, 'iterator'),
      (tilePassThrough, 'tensor_tile'),
      (tileTranspose, 'tensor_tile_transpose'),
      (untiler, 'tensor_tile_untiler'),
      (tiler, 'tensor_tile_tiler'),
    ]) {
      await _expectCompiles(module, name);
    }
  });
}

Future<void> _expectCompiles(Module module, String name) async {
  await module.build();
  final directory = Directory.systemTemp.createTempSync('rohd_hcl_inference_');
  final path = '${directory.path}/$name.sv';
  try {
    File(path).writeAsStringSync(module.dumpSystemVerilog());
    final result = Process.runSync('iverilog', ['-g2012', '-tnull', path]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  } finally {
    directory.deleteSync(recursive: true);
  }
}

LogicArray _lanes(int count, int width, String name) =>
    LogicArray([count], width, name: name);

OnlineSoftmaxWeightedState _weightedState(String name) =>
    OnlineSoftmaxWeightedState(
      scoreWidth: 5,
      scoreFractionBits: 2,
      normalizerWidth: 8,
      normalizerFractionBits: 4,
      valueCount: 2,
      valueWidth: 8,
      valueFractionBits: 4,
      name: name,
    );

class _TensorTilePassThrough extends Module {
  _TensorTilePassThrough(InferenceTensorTile<Logic, LogicValue> inputTile)
      : super(definitionName: 'InferenceTensorTilePassThrough') {
    inputTile = addTypedInput('inputTile', inputTile);
    final outputTile = addTypedOutput('outputTile', inputTile.clone);
    for (var index = 0; index < inputTile.data.arrayElements.length; index++) {
      outputTile.data.arrayElements[index] <=
          inputTile.data.arrayElements[index];
    }

    outputTile.rowMask <= inputTile.rowMask;
    outputTile.columnMask <= inputTile.columnMask;
  }
}
