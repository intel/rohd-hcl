// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_inference_attention.dart
// Configurators for bounded, row-streamed, and scratchpad-fed attention.
//
// 2026 November 24
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures bounded attention and its optional protocol attachment.
class FixedPointAttentionConfigurator extends Configurator {
  /// Scheduling boundary.
  final boundaryKnob = ChoiceConfigKnob(InferenceConfiguratorBoundary.values,
      value: InferenceConfiguratorBoundary.actions);

  /// Number of stored KV positions.
  final sequenceLengthKnob = PositiveIntConfigKnob(value: 2);

  /// Query/key vector length.
  final headDimensionKnob = PositiveIntConfigKnob(value: 2);

  /// Value vector length.
  final valueDimensionKnob = PositiveIntConfigKnob(value: 2);

  /// Named definitions shared by explicitly selected arithmetic roles.
  final formatsKnob = AttentionNumericFormatsKnob();

  /// Selected query/key element format.
  InferenceFixedPointFormatKnob get elementKnob =>
      formatsKnob.formatFor(AttentionFormatRole.queryKey);

  /// Value element format.
  InferenceFixedPointFormatKnob get valueKnob =>
      formatsKnob.formatFor(AttentionFormatRole.value);

  /// Score format.
  InferenceFixedPointFormatKnob get scoreKnob =>
      formatsKnob.formatFor(AttentionFormatRole.score);

  /// Normalization sum format.
  InferenceFixedPointFormatKnob get normalizerKnob =>
      formatsKnob.formatFor(AttentionFormatRole.normalizer);

  /// Exponential scale format.
  InferenceFixedPointFormatKnob get expKnob =>
      formatsKnob.formatFor(AttentionFormatRole.exponential);

  /// Reciprocal scale format.
  InferenceFixedPointFormatKnob get reciprocalKnob =>
      formatsKnob.formatFor(AttentionFormatRole.reciprocal);

  /// Result element width.
  final outputWidthKnob = PositiveIntConfigKnob(value: 6);

  /// Request identifier width.
  final requestIdWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Statistics counter width.
  final counterWidthKnob = PositiveIntConfigKnob(value: 16);

  /// Whether results retire automatically on the next cycle.
  final automaticRetireKnob = ToggleConfigKnob(value: false);

  /// Whether to expose counter clearing.
  final clearCountersKnob = ToggleConfigKnob(value: false);

  /// Fixed-point rounding policy.
  final roundingKnob = ChoiceConfigKnob(NumericRoundingMode.values,
      value: NumericRoundingMode.nearestEven);

  /// Fixed-point overflow policy.
  final overflowKnob = ChoiceConfigKnob(NumericOverflowMode.values,
      value: NumericOverflowMode.saturate);

  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'attention';
  @override
  String get name => 'Fixed-Point Attention';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs {
    formatsKnob.refreshChoices();
    return {
      'Boundary': boundaryKnob,
      'Sequence Length': sequenceLengthKnob,
      'Head Dimension': headDimensionKnob,
      'Value Dimension': valueDimensionKnob,
      'Numeric Formats': formatsKnob,
      'Output Width': outputWidthKnob,
      'Request ID Width': requestIdWidthKnob,
      'Counter Width': counterWidthKnob,
      'Clear Counters': clearCountersKnob,
      if (boundaryKnob.value == InferenceConfiguratorBoundary.actions)
        'Automatic Retirement': automaticRetireKnob,
      'Rounding': roundingKnob,
      'Overflow': overflowKnob,
    };
  }

  /// Creates the shared result schema for bounded and row attention.
  FixedPointAttentionResult resultSchema() => FixedPointAttentionResult(
        valueDimension: valueDimensionKnob.value,
        outputWidth: outputWidthKnob.value,
        requestIdWidth: requestIdWidthKnob.value,
      );

  @override
  void loadJson(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final savedKnobs = decoded['knobs'] as Map<String, dynamic>;
    const legacyRoles = {
      'Query/Key Format': AttentionFormatRole.queryKey,
      'Value Format': AttentionFormatRole.value,
      'Score Format': AttentionFormatRole.score,
      'Normalizer Format': AttentionFormatRole.normalizer,
      'Exponential Format': AttentionFormatRole.exponential,
      'Reciprocal Format': AttentionFormatRole.reciprocal,
    };
    if (!savedKnobs.containsKey('Numeric Formats') &&
        legacyRoles.keys.any(savedKnobs.containsKey)) {
      final migrated = AttentionNumericFormatsKnob();
      for (final entry in legacyRoles.entries) {
        migrated.formatFor(entry.value).loadJson(
              savedKnobs.containsKey(entry.key)
                  ? savedKnobs.remove(entry.key) as Map<String, dynamic>
                  : formatsKnob.formatFor(entry.value).toJson(),
            );
      }
      savedKnobs['Numeric Formats'] = migrated.toJson();
      super.loadJson(jsonEncode(decoded));
    } else {
      super.loadJson(json);
    }
  }

  @override
  Module createModule() {
    final request = FixedPointAttentionRequest(
      sequenceLength: sequenceLengthKnob.value,
      headDimension: headDimensionKnob.value,
      valueDimension: valueDimensionKnob.value,
      elementWidth: elementKnob.widthKnob.value,
      valueWidth: valueKnob.widthKnob.value,
      requestIdWidth: requestIdWidthKnob.value,
    );
    if (boundaryKnob.value == InferenceConfiguratorBoundary.readyValid) {
      return FixedPointAttention(
        clk: Logic(),
        reset: Logic(),
        upstream: ReadyValidInterface(request),
        downstream: ReadyValidInterface(resultSchema()),
        elementFractionBits: elementKnob.fractionBitsKnob.value,
        valueFractionBits: valueKnob.fractionBitsKnob.value,
        scoreWidth: scoreKnob.widthKnob.value,
        scoreFractionBits: scoreKnob.fractionBitsKnob.value,
        normalizerWidth: normalizerKnob.widthKnob.value,
        normalizerFractionBits: normalizerKnob.fractionBitsKnob.value,
        expWidth: expKnob.widthKnob.value,
        expFractionBits: expKnob.fractionBitsKnob.value,
        reciprocalWidth: reciprocalKnob.widthKnob.value,
        reciprocalFractionBits: reciprocalKnob.fractionBitsKnob.value,
        outputWidth: outputWidthKnob.value,
        counterWidth: counterWidthKnob.value,
        clearCounters: clearCountersKnob.value ? Logic() : null,
        roundingMode: roundingKnob.value,
        overflowMode: overflowKnob.value,
      );
    }
    return FixedPointAttentionCore(
      clk: Logic(),
      reset: Logic(),
      request: request,
      resultSchema: resultSchema(),
      load: Logic(),
      retire: automaticRetireKnob.value ? null : Logic(),
      elementFractionBits: elementKnob.fractionBitsKnob.value,
      valueFractionBits: valueKnob.fractionBitsKnob.value,
      scoreWidth: scoreKnob.widthKnob.value,
      scoreFractionBits: scoreKnob.fractionBitsKnob.value,
      normalizerWidth: normalizerKnob.widthKnob.value,
      normalizerFractionBits: normalizerKnob.fractionBitsKnob.value,
      expWidth: expKnob.widthKnob.value,
      expFractionBits: expKnob.fractionBitsKnob.value,
      reciprocalWidth: reciprocalKnob.widthKnob.value,
      reciprocalFractionBits: reciprocalKnob.fractionBitsKnob.value,
      outputWidth: outputWidthKnob.value,
      counterWidth: counterWidthKnob.value,
      clearCounters: clearCountersKnob.value ? Logic() : null,
      roundingMode: roundingKnob.value,
      overflowMode: overflowKnob.value,
    );
  }
}

/// Configures scheduled row attention and its existing transport shell.
class FixedPointAttentionRowConfigurator
    extends FixedPointAttentionConfigurator {
  @override
  String get name => 'Fixed-Point Row Attention';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs =>
      super.knobs..remove('Sequence Length');
  @override
  Module createModule() {
    final command = FixedPointAttentionRowCommand(
        headDimension: headDimensionKnob.value,
        elementWidth: elementKnob.widthKnob.value,
        requestIdWidth: requestIdWidthKnob.value);
    final rows = FixedPointAttentionRow(
        headDimension: headDimensionKnob.value,
        valueDimension: valueDimensionKnob.value,
        elementWidth: elementKnob.widthKnob.value,
        valueWidth: valueKnob.widthKnob.value);
    if (boundaryKnob.value == InferenceConfiguratorBoundary.readyValid) {
      return FixedPointAttentionRowEngine(
        clk: Logic(),
        reset: Logic(),
        command: ReadyValidInterface(command),
        rows: ReadyValidInterface(rows),
        result: ReadyValidInterface(resultSchema()),
        elementFractionBits: elementKnob.fractionBitsKnob.value,
        valueFractionBits: valueKnob.fractionBitsKnob.value,
        scoreWidth: scoreKnob.widthKnob.value,
        scoreFractionBits: scoreKnob.fractionBitsKnob.value,
        normalizerWidth: normalizerKnob.widthKnob.value,
        normalizerFractionBits: normalizerKnob.fractionBitsKnob.value,
        expWidth: expKnob.widthKnob.value,
        expFractionBits: expKnob.fractionBitsKnob.value,
        reciprocalWidth: reciprocalKnob.widthKnob.value,
        reciprocalFractionBits: reciprocalKnob.fractionBitsKnob.value,
        outputWidth: outputWidthKnob.value,
        counterWidth: counterWidthKnob.value,
        clearCounters: clearCountersKnob.value ? Logic() : null,
        roundingMode: roundingKnob.value,
        overflowMode: overflowKnob.value,
      );
    }
    return FixedPointAttentionRowCore(
      clk: Logic(),
      reset: Logic(),
      command: command,
      rows: rows,
      resultSchema: resultSchema(),
      load: Logic(),
      writeRow: Logic(),
      retire: automaticRetireKnob.value ? null : Logic(),
      elementFractionBits: elementKnob.fractionBitsKnob.value,
      valueFractionBits: valueKnob.fractionBitsKnob.value,
      scoreWidth: scoreKnob.widthKnob.value,
      scoreFractionBits: scoreKnob.fractionBitsKnob.value,
      normalizerWidth: normalizerKnob.widthKnob.value,
      normalizerFractionBits: normalizerKnob.fractionBitsKnob.value,
      expWidth: expKnob.widthKnob.value,
      expFractionBits: expKnob.fractionBitsKnob.value,
      reciprocalWidth: reciprocalKnob.widthKnob.value,
      reciprocalFractionBits: reciprocalKnob.fractionBitsKnob.value,
      outputWidth: outputWidthKnob.value,
      counterWidth: counterWidthKnob.value,
      clearCounters: clearCountersKnob.value ? Logic() : null,
      roundingMode: roundingKnob.value,
      overflowMode: overflowKnob.value,
    );
  }
}

/// Configures attention with external typed scratchpad memory transactions.
class ScratchpadFixedPointAttentionConfigurator
    extends FixedPointAttentionConfigurator {
  /// Key and value address width.
  final addressWidthKnob = PositiveIntConfigKnob(value: 4);
  @override
  String get name => 'Scratchpad Fixed-Point Attention';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => (super.knobs
    ..remove('Boundary')
    ..remove('Automatic Retirement'))
    ..['Memory Address Width'] = addressWidthKnob;
  @override
  Module createModule() {
    final tagWidth = max(1, sequenceLengthKnob.value.log2Ceil);
    ReadyValidInterface<TensorScratchpadReadRequest> readRequest() =>
        ReadyValidInterface(TensorScratchpadReadRequest(
            addressWidth: addressWidthKnob.value, tagWidth: tagWidth));
    ReadyValidInterface<TensorScratchpadReadResponse<Logic>> response(
            int lanes, int width) =>
        ReadyValidInterface(TensorScratchpadReadResponse<Logic>(
            data: TypedLogicArray<Logic, LogicValue>(
                [lanes], ({name}) => Logic(name: name, width: width)),
            tagWidth: tagWidth));
    return ScratchpadFixedPointAttention(
      clk: Logic(),
      reset: Logic(),
      command: ReadyValidInterface(ScratchpadFixedPointAttentionCommand(
          sequenceLength: sequenceLengthKnob.value,
          headDimension: headDimensionKnob.value,
          elementWidth: elementKnob.widthKnob.value,
          keyAddressWidth: addressWidthKnob.value,
          valueAddressWidth: addressWidthKnob.value,
          requestIdWidth: requestIdWidthKnob.value)),
      keyReadRequest: readRequest(),
      valueReadRequest: readRequest(),
      keyReadResponse:
          response(headDimensionKnob.value, elementKnob.widthKnob.value),
      valueReadResponse:
          response(valueDimensionKnob.value, valueKnob.widthKnob.value),
      result: ReadyValidInterface(ScratchpadFixedPointAttentionResult(
          valueDimension: valueDimensionKnob.value,
          outputWidth: outputWidthKnob.value,
          requestIdWidth: requestIdWidthKnob.value)),
      valueDimension: valueDimensionKnob.value,
      valueWidth: valueKnob.widthKnob.value,
      elementFractionBits: elementKnob.fractionBitsKnob.value,
      valueFractionBits: valueKnob.fractionBitsKnob.value,
      scoreWidth: scoreKnob.widthKnob.value,
      scoreFractionBits: scoreKnob.fractionBitsKnob.value,
      normalizerWidth: normalizerKnob.widthKnob.value,
      normalizerFractionBits: normalizerKnob.fractionBitsKnob.value,
      expWidth: expKnob.widthKnob.value,
      expFractionBits: expKnob.fractionBitsKnob.value,
      reciprocalWidth: reciprocalKnob.widthKnob.value,
      reciprocalFractionBits: reciprocalKnob.fractionBitsKnob.value,
      outputWidth: outputWidthKnob.value,
      counterWidth: counterWidthKnob.value,
      clearCounters: clearCountersKnob.value ? Logic() : null,
      roundingMode: roundingKnob.value,
      overflowMode: overflowKnob.value,
    );
  }
}
