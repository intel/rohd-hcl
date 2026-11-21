// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_memory_building_blocks.dart
// Configurators for reusable RTL memory building blocks.
//
// 2026 November
// Author: ROHD-HCL contributors

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Replacement policy implementations available in the configurator.
enum ReplacementConfiguratorPolicy {
  /// Cycle among eligible entries.
  roundRobin,

  /// Approximate least-recent use for a power-of-two entry count.
  treePseudoLru,
}

/// Configures a standalone RTL replacement policy.
class ReplacementPolicyConfigurator extends Configurator {
  /// Policy implementation.
  final ChoiceConfigKnob<ReplacementConfiguratorPolicy> policyKnob =
      ChoiceConfigKnob(
    ReplacementConfiguratorPolicy.values,
    value: ReplacementConfiguratorPolicy.roundRobin,
    choiceLabels: const {
      ReplacementConfiguratorPolicy.roundRobin: 'Round robin',
      ReplacementConfiguratorPolicy.treePseudoLru: 'Tree pseudo-LRU',
    },
  );

  /// Number of entries managed by the policy.
  final IntConfigKnob entryCountKnob = PositiveIntConfigKnob(value: 4);

  /// Number of access ports.
  final IntConfigKnob accessCountKnob = NonNegativeIntConfigKnob(value: 1);

  /// Number of allocation ports.
  final IntConfigKnob allocationCountKnob = PositiveIntConfigKnob(value: 1);

  /// Number of deferred commit ports.
  final IntConfigKnob commitCountKnob = NonNegativeIntConfigKnob(value: 0);

  @override
  ComponentCategory get category => ComponentCategory.memory;
  @override
  String get subcategory => 'replacement';
  @override
  String get name => 'Replacement Policy';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Policy': policyKnob,
        'Entry Count': entryCountKnob,
        'Access Port Count': accessCountKnob,
        'Allocation Port Count': allocationCountKnob,
        'Deferred Commit Port Count': commitCountKnob,
      };

  @override
  Module createModule() {
    final count = entryCountKnob.value;
    final clk = Logic(name: 'clk');
    final reset = Logic(name: 'reset');
    final validMask = Logic(name: 'validMask', width: count);
    final eligibleMask = Logic(name: 'eligibleMask', width: count);
    final accesses = [
      for (var i = 0; i < accessCountKnob.value; i++)
        ReplacementAccessInterface(count),
    ];
    final allocations = [
      for (var i = 0; i < allocationCountKnob.value; i++)
        ReplacementAllocationInterface(count),
    ];
    final commits = [
      for (var i = 0; i < commitCountKnob.value; i++)
        ReplacementCommitInterface(count),
    ];
    return switch (policyKnob.value) {
      ReplacementConfiguratorPolicy.roundRobin => RoundRobinReplacement(
          clk: clk,
          reset: reset,
          validMask: validMask,
          eligibleMask: eligibleMask,
          accesses: accesses,
          allocations: allocations,
          commits: commits,
          entryCount: count,
        ),
      ReplacementConfiguratorPolicy.treePseudoLru => TreePseudoLruReplacement(
          clk: clk,
          reset: reset,
          validMask: validMask,
          eligibleMask: eligibleMask,
          accesses: accesses,
          allocations: allocations,
          commits: commits,
          entryCount: count,
        ),
    };
  }
}

class _InferredSramSchematic extends Module {
  _InferredSramSchematic({
    required int entryCount,
    required int addressWidth,
    required int dataWidth,
  }) : super(
          name: 'inferred_sram_example',
          definitionName:
              'InferredSramExample_E${entryCount}_A${addressWidth}_D$dataWidth',
        ) {
    final clk = addInput('clk', Logic());
    final reset = addInput('reset', Logic());
    final write = DataPortInterface<Logic>(dataWidth, addressWidth);
    final read = DataPortInterface<Logic>(dataWidth, addressWidth);
    write.en <= addInput('wr_en_0', Logic());
    write.addr <=
        addInput('wr_addr_0', Logic(width: addressWidth), width: addressWidth);
    write.data <=
        addInput('wr_data_0', Logic(width: dataWidth), width: dataWidth);
    read.en <= addInput('rd_en_0', Logic());
    read.addr <=
        addInput('rd_addr_0', Logic(width: addressWidth), width: addressWidth);
    InferredSram<Logic>(clk, reset, [write], [read], entryCount: entryCount);
    addOutput('rd_data_0', width: dataWidth) <= read.data;
  }
}

/// Configures the single-port, synchronous inferred SRAM.
///
/// The returned structural wrapper exposes the SRAM as a schematic cell.
class InferredSramConfigurator extends Configurator {
  /// Whether [module] is the structural wrapper produced by this configurator.
  static bool isConfiguredModule(Module module) =>
      module is _InferredSramSchematic;

  /// Number of words.
  final IntConfigKnob entryCountKnob = PositiveIntConfigKnob(value: 4);

  /// Address width in bits.
  final IntConfigKnob addressWidthKnob = PositiveIntConfigKnob(value: 2);

  /// Width of a word.
  final IntConfigKnob dataWidthKnob = PositiveIntConfigKnob(value: 8);

  @override
  ComponentCategory get category => ComponentCategory.memory;
  @override
  String get subcategory => 'storage';
  @override
  String get name => 'Inferred SRAM';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Entry Count': entryCountKnob,
        'Address Width': addressWidthKnob,
        'Data Width': dataWidthKnob,
      };

  @override
  Module createModule() => _InferredSramSchematic(
        entryCount: entryCountKnob.value,
        addressWidth: addressWidthKnob.value,
        dataWidth: dataWidthKnob.value,
      );
}
