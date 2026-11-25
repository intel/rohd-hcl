// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_inference_memory.dart
// Configurators for typed tensor scratchpads and masked storage banks.
//
// 2026 November 24
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures banked typed scratchpad storage with either scheduling boundary.
class TensorScratchpadConfigurator extends Configurator {
  /// Scheduling boundary.
  final boundaryKnob = ChoiceConfigKnob(InferenceConfiguratorBoundary.values,
      value: InferenceConfiguratorBoundary.actions);

  /// Number of words.
  final depthKnob = PositiveIntConfigKnob(value: 4);

  /// Bank count.
  final bankCountKnob = PositiveIntConfigKnob(value: 2);

  /// Read port count.
  final readPortsKnob = PositiveIntConfigKnob(value: 1);

  /// Write port count.
  final writePortsKnob = PositiveIntConfigKnob(value: 1);

  /// Elements per typed word.
  final lanesKnob = PositiveIntConfigKnob(value: 2);

  /// Stored element format.
  final elementKnob = InferenceFixedPointFormatKnob();

  /// Whether word elements are unpacked.
  final unpackedKnob = ToggleConfigKnob(value: false);

  /// Response tag width.
  final tagWidthKnob = PositiveIntConfigKnob(value: 4);

  /// Bank conflict arbitration.
  final conflictKnob = ChoiceConfigKnob(
      TensorScratchpadBankConflictPolicy.values,
      value: TensorScratchpadBankConflictPolicy.lowestPortWins);

  /// Address-to-bank mapping.
  final mappingKnob = ChoiceConfigKnob(TensorScratchpadBankMapping.values,
      value: TensorScratchpadBankMapping.lowAddressBits);

  /// Whether to use inferred SRAM instead of register-file storage.
  final sramKnob = ToggleConfigKnob(value: false);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'storage';
  @override
  String get name => 'Tensor Scratchpad';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Boundary': boundaryKnob,
        'Depth': depthKnob,
        'Banks': bankCountKnob,
        'Read Ports': readPortsKnob,
        'Write Ports': writePortsKnob,
        'Word Lanes': lanesKnob,
        'Element Format': elementKnob,
        'Unpacked Word': unpackedKnob,
        'Tag Width': tagWidthKnob,
        'Bank Conflict Policy': conflictKnob,
        'Bank Mapping': mappingKnob,
        'Inferred SRAM': sramKnob,
      };
  @override
  Module createModule() {
    final addressWidth = max(1, depthKnob.value.log2Ceil);
    final word =
        elementKnob.array(lanesKnob.value, unpacked: unpackedKnob.value);
    final reads = [
      for (var i = 0; i < readPortsKnob.value; i++)
        TensorScratchpadReadRequest(
            addressWidth: addressWidth, tagWidth: tagWidthKnob.value),
    ];
    final responses = [
      for (var i = 0; i < readPortsKnob.value; i++)
        TensorScratchpadReadResponse(data: word, tagWidth: tagWidthKnob.value),
    ];
    final writes = [
      for (var i = 0; i < writePortsKnob.value; i++)
        TensorScratchpadWriteRequest(data: word, addressWidth: addressWidth),
    ];
    final memory = sramKnob.value
        ? inferredSramArray<TypedLogicArray<Logic, LogicValue>>()
        : registerFileArray<TypedLogicArray<Logic, LogicValue>>();
    if (boundaryKnob.value == InferenceConfiguratorBoundary.readyValid) {
      return TensorScratchpad(
        clk: Logic(),
        reset: Logic(),
        readRequests: [for (final read in reads) ReadyValidInterface(read)],
        readResponses: [
          for (final response in responses) ReadyValidInterface(response)
        ],
        writeRequests: [for (final write in writes) ReadyValidInterface(write)],
        depth: depthKnob.value,
        bankCount: bankCountKnob.value,
        memoryFunctor: memory,
        bankConflictPolicy: conflictKnob.value,
        bankMapping: mappingKnob.value,
      );
    }
    return TensorScratchpadCore(
      clk: Logic(),
      reset: Logic(),
      readRequests: reads,
      readResponses: responses,
      writeRequests: writes,
      readEnable: Logic(width: readPortsKnob.value),
      writeEnable: Logic(width: writePortsKnob.value),
      consumeResponses: Logic(width: readPortsKnob.value),
      depth: depthKnob.value,
      bankCount: bankCountKnob.value,
      memoryFunctor: memory,
      bankConflictPolicy: conflictKnob.value,
      bankMapping: mappingKnob.value,
    );
  }
}

/// Configures the byte-masked single-bank memory transaction adapter.
class TensorMaskedSramBankConfigurator extends Configurator {
  /// Number of words; must be a power of two greater than one.
  final depthKnob = IntConfigKnob(value: 4, minValue: 2);

  /// Number of bytes in a word.
  final bytesKnob = PositiveIntConfigKnob(value: 2);

  /// Response tag width.
  final tagWidthKnob = PositiveIntConfigKnob(value: 4);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'storage';
  @override
  String get name => 'Tensor Masked SRAM Bank';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Depth': depthKnob,
        'Word Bytes': bytesKnob,
        'Tag Width': tagWidthKnob,
      };
  @override
  Module createModule() => TensorMaskedSramBank(
        clk: Logic(),
        reset: Logic(),
        depth: depthKnob.value,
        reads: ValidThenReadyInterface(TensorScratchpadReadRequest(
            addressWidth: depthKnob.value.log2Ceil,
            tagWidth: tagWidthKnob.value)),
        writes: ValidThenReadyInterface(ByteMaskedWriteRequest(
            addressWidth: depthKnob.value.log2Ceil,
            dataWidth: bytesKnob.value * 8)),
        responses: ReadyValidInterface(TensorScratchpadReadResponse<Logic>(
            data: Logic(width: bytesKnob.value * 8),
            tagWidth: tagWidthKnob.value)),
      );
}

/// Configures lane-wise masked accumulation and its protocol shell.
class TensorAccumulatingMemoryBankConfigurator extends Configurator {
  /// Scheduling boundary.
  final boundaryKnob = ChoiceConfigKnob(InferenceConfiguratorBoundary.values,
      value: InferenceConfiguratorBoundary.actions);

  /// Number of words; must be a power of two greater than one.
  final depthKnob = IntConfigKnob(value: 4, minValue: 2);

  /// Elements per word.
  final lanesKnob = PositiveIntConfigKnob(value: 2);

  /// Bytes per independently wrapping lane.
  final laneBytesKnob = PositiveIntConfigKnob(value: 1);

  /// Response tag width.
  final tagWidthKnob = PositiveIntConfigKnob(value: 4);
  @override
  ComponentCategory get category => ComponentCategory.inference;
  @override
  String get subcategory => 'storage';
  @override
  String get name => 'Tensor Accumulating Memory Bank';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Boundary': boundaryKnob,
        'Depth': depthKnob,
        'Word Lanes': lanesKnob,
        'Lane Bytes': laneBytesKnob,
        'Tag Width': tagWidthKnob,
      };
  @override
  Module createModule() {
    final addressWidth = depthKnob.value.log2Ceil;
    final laneWidth = laneBytesKnob.value * 8;
    final dataWidth = lanesKnob.value * laneWidth;
    final word = TypedLogicArray<Logic, LogicValue>(
        [lanesKnob.value], ({name}) => Logic(name: name, width: laneWidth));
    if (boundaryKnob.value == InferenceConfiguratorBoundary.readyValid) {
      return ReadyValidTensorAccumulatingMemoryBank(
        clk: Logic(),
        reset: Logic(),
        depth: depthKnob.value,
        laneWidth: laneWidth,
        writes: ReadyValidInterface(TensorAccumulatingWriteRequest(
            ByteMaskedWriteRequest(
                addressWidth: addressWidth, dataWidth: dataWidth))),
        reads: ReadyValidInterface(TensorScratchpadReadRequest(
            addressWidth: addressWidth, tagWidth: tagWidthKnob.value)),
        responses: ReadyValidInterface(TensorScratchpadReadResponse<Logic>(
            data: word, tagWidth: tagWidthKnob.value)),
      );
    }
    return TensorAccumulatingMemoryBank(
      clk: Logic(),
      reset: Logic(),
      depth: depthKnob.value,
      laneWidth: laneWidth,
      write: Logic(),
      writeAddress: Logic(width: addressWidth),
      writeData: word,
      writeMask: Logic(width: dataWidth ~/ 8),
      writeAccumulate: Logic(),
      read: Logic(),
      readAddress: Logic(width: addressWidth),
      readTag: Logic(width: tagWidthKnob.value),
      consumeResponse: Logic(),
    );
  }
}
