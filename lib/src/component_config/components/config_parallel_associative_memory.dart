// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_parallel_associative_memory.dart
// Configurator for parallel associative memory.
//
// 2026 November 5
// Author: GitHub Copilot

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures a parallel associative memory with scalar keys.
class ParallelAssociativeMemoryConfigurator extends Configurator {
  /// Number of searchable entries.
  final IntConfigKnob entryCountKnob = PositiveIntConfigKnob(value: 8);

  /// Key width in bits.
  final IntConfigKnob keyWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Number of indexed update ports.
  final IntConfigKnob updateCountKnob = NonNegativeIntConfigKnob(value: 1);

  /// Number of lookup ports.
  final IntConfigKnob lookupCountKnob = PositiveIntConfigKnob(value: 1);

  /// Whether to expose valid-entry status.
  final ToggleConfigKnob validTrackingKnob = ToggleConfigKnob(value: false);

  @override
  ComponentCategory get category => ComponentCategory.memory;
  @override
  String get subcategory => 'associative';
  @override
  String get name => 'Parallel Associative Memory';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Entry Count': entryCountKnob,
        'Key Width': keyWidthKnob,
        'Update Port Count': updateCountKnob,
        'Lookup Port Count': lookupCountKnob,
        'Enable Valid Tracking': validTrackingKnob,
      };

  @override
  Module createModule() {
    final indexWidth = max(1, entryCountKnob.value.log2Ceil);
    return ParallelAssociativeMemory(
      clk: Logic(name: 'clk'),
      reset: Logic(name: 'reset'),
      updates: [
        for (var i = 0; i < updateCountKnob.value; i++)
          AssociativeUpdatePortInterface(
              keyWidth: keyWidthKnob.value, indexWidth: indexWidth),
      ],
      lookups: [
        for (var i = 0; i < lookupCountKnob.value; i++)
          AssociativeLookupPortInterface(
              keyWidth: keyWidthKnob.value, indexWidth: indexWidth),
      ],
      entryCount: entryCountKnob.value,
      contract: const AssociativeMemoryContract(
        lookupLatency: 0,
        updateLatency: 0,
        duplicateKeyPolicy: AssociativeDuplicateKeyPolicy.allow,
        matchSelection: AssociativeMatchSelection.lowestIndex,
        resultShape: AssociativeResultShape.selectedIndex,
        lookupUpdatePolicy: AssociativeLookupUpdatePolicy.lookupAfterUpdate,
        updateCollisionPolicy: AssociativeUpdateCollisionPolicy.highestPortWins,
        resetBehavior: AssociativeMemoryResetBehavior.clearValidity,
        implementationKind: AssociativeMemoryImplementationKind.synthesizable,
      ),
      enableValidTracking: validTrackingKnob.value,
    );
  }
}
