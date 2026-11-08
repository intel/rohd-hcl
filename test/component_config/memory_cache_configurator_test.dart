// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// memory_cache_configurator_test.dart
// Tests RTL memory and cache configurators and their schematic netlists.
//
// 2026 November
// Author: ROHD-HCL contributors

import 'dart:convert';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';
import 'package:test/test.dart';

void main() {
  test('RTL memory components are registered and generate schematic netlists',
      () async {
    final variants = <({Configurator config, Type? type})>[
      (config: CacheConfigurator(), type: Cache<Logic>),
      (config: MultiPortCacheConfigurator(), type: MultiPortCache<Logic>),
      (
        config: SerializedCacheConfigurator(),
        type: SerializedCache<Logic, Logic, Logic, Logic>
      ),
      (
        config: CacheTransactionAdapterConfigurator(),
        type: CacheTransactionAdapter<Logic, Logic, Logic, Logic>
      ),
      (config: CacheSchedulerConfigurator(), type: FixedPriorityCacheScheduler),
      (config: ReplacementPolicyConfigurator(), type: RoundRobinReplacement),
      (
        config: ReplacementPolicyConfigurator()
          ..policyKnob.value = ReplacementConfiguratorPolicy.treePseudoLru,
        type: TreePseudoLruReplacement
      ),
      (config: InferredSramConfigurator(), type: null),
    ];
    for (final variant in variants) {
      final config = variant.config;
      final restored = componentRegistry.singleWhere(
        (candidate) => candidate.runtimeType == config.runtimeType,
      )..loadJson(config.toJson());
      expect(restored.toJson(), config.toJson(), reason: config.name);
      final module = restored.createModule();
      if (variant.type != null) {
        expect(module.runtimeType, variant.type, reason: config.name);
      }
      await module.build();
      final sv = module.dumpSystemVerilog();
      expect(sv, contains('module '), reason: config.name);
      final netlist = jsonDecode(NetlistSynthesizer().synthesizeToJson(module))
          as Map<String, dynamic>;
      final modules = netlist['modules'] as Map<String, dynamic>;
      expect(modules, contains(module.definitionName), reason: config.name);
      if (config is InferredSramConfigurator ||
          config is SerializedCacheConfigurator) {
        expect(sv, contains('module InferredSram_'), reason: config.name);
        final root = modules[module.definitionName] as Map<String, dynamic>;
        final cells = root['cells'] as Map<String, dynamic>;
        expect(
            cells.values.any((cell) => (cell as Map<String, dynamic>)['type']
                .toString()
                .startsWith('InferredSram_')),
            isTrue,
            reason: '${config.name} must show the SRAM as a cell');
      }
      expect(
          config.knobs.keys
              .where((name) => name.toLowerCase().contains('behavioral')),
          isEmpty,
          reason: config.name);
    }
  });

  test('non-default geometry, options and JSON round-trip', () {
    final cache = CacheConfigurator()
      ..setCountKnob.value = 4
      ..waysPerSetKnob.value = 4
      ..addressWidthKnob.value = 12
      ..dataWidthKnob.value = 16
      ..replacementKnob.value = CacheConfiguratorReplacement.treePseudoLru
      ..readDuringFillKnob.value = CacheReadDuringFill.forward;
    final restored = CacheConfigurator()..loadJson(cache.toJson());
    final module = restored.createModule() as Cache<Logic>;
    expect(restored.toJson(), cache.toJson());
    expect(module.setCount, 4);
    expect(module.waysPerSet, 4);
    expect(module.replacement, CacheReplacement.treePseudoLru);
    expect(module.readDuringFill, CacheReadDuringFill.forward);
    expect(module.input('lookup_address').width, 12);
    expect(module.input('fill_data').width, 16);

    final multi = MultiPortCacheConfigurator()
      ..lookupCountKnob.value = 3
      ..fillCountKnob.value = 2
      ..maxFillsPerSetKnob.value = 2
      ..evictionConcurrencyKnob.value = CacheEvictionConcurrency.oneAtATime;
    final multiRestored = MultiPortCacheConfigurator()
      ..loadJson(multi.toJson());
    final multiModule = multiRestored.createModule() as MultiPortCache<Logic>;
    expect(multiRestored.toJson(), multi.toJson());
    expect(multiModule.maxFillsPerSet, 2);
    expect(multiModule.inputs.keys, contains('lookup_2_address'));
    expect(multiModule.inputs.keys, contains('fill_1_address'));

    final serialized = SerializedCacheConfigurator()
      ..portCountKnob.value = 2
      ..dataWidthKnob.value = 16
      ..writeMaskWidthKnob.value = 2
      ..tokenWidthKnob.value = 3;
    final serializedRestored = SerializedCacheConfigurator()
      ..loadJson(serialized.toJson());
    final serializedModule = serializedRestored.createModule()
        as SerializedCache<Logic, Logic, Logic, Logic>;
    expect(serializedRestored.toJson(), serialized.toJson());
    expect(serializedModule.ports, hasLength(2));
    expect(serializedModule.ports.first.requests.data.writeMask.width, 2);
    expect(serializedModule.ports.first.requests.data.token.width, 3);

    final adapter = CacheTransactionAdapterConfigurator()
      ..dataWidthKnob.value = 16
      ..writeMaskWidthKnob.value = 2
      ..maxOutstandingKnob.value = 3;
    final adapterRestored = CacheTransactionAdapterConfigurator()
      ..loadJson(adapter.toJson());
    final adapterModule = adapterRestored.createModule()
        as CacheTransactionAdapter<Logic, Logic, Logic, Logic>;
    expect(adapterRestored.toJson(), adapter.toJson());
    expect(adapterModule.maxOutstanding, 3);
    expect(adapterModule.cache.requests.data.writeMask.width, 2);

    final scheduler = CacheSchedulerConfigurator()
      ..requestCountKnob.value = 3
      ..capacitiesKnob.count = 2;
    (scheduler.capacitiesKnob.knobs[1] as IntConfigKnob).value = 3;
    final schedulerRestored = CacheSchedulerConfigurator()
      ..loadJson(scheduler.toJson());
    expect(schedulerRestored.toJson(), scheduler.toJson());
    final scheduling = schedulerRestored.createModule();
    expect(scheduling.input('available_1').width, 2);
    expect(scheduling.input('request_2_valid').width, 1);

    final replacement = ReplacementPolicyConfigurator()
      ..entryCountKnob.value = 8
      ..accessCountKnob.value = 2
      ..allocationCountKnob.value = 2
      ..commitCountKnob.value = 1;
    final policy = replacement.createModule() as ReplacementPolicy;
    expect(policy.entryCount, 8);
    expect(policy.inputs.keys, contains('commit_0_en'));
    expect(policy.outputs.keys, contains('allocation_1_index'));

    final sram = InferredSramConfigurator()
      ..entryCountKnob.value = 6
      ..addressWidthKnob.value = 3
      ..dataWidthKnob.value = 16;
    final memory = sram.createModule();
    expect(memory.input('wr_addr_0').width, 3);
    expect(memory.output('rd_data_0').width, 16);
  });

  test('invalid cross-knob geometry is rejected', () {
    expect(() => (CacheConfigurator()..setCountKnob.value = 3).createModule(),
        throwsArgumentError);
    expect(
        () => (MultiPortCacheConfigurator()..maxFillsPerSetKnob.value = 3)
            .createModule(),
        throwsArgumentError);
    expect(
        () => (SerializedCacheConfigurator()..writeMaskWidthKnob.value = 3)
            .createModule(),
        throwsArgumentError);
    expect(
        () => (CacheSchedulerConfigurator()..capacitiesKnob.count = 0)
            .createModule(),
        throwsArgumentError);
    expect(
        () => (ReplacementPolicyConfigurator()
              ..policyKnob.value = ReplacementConfiguratorPolicy.treePseudoLru
              ..entryCountKnob.value = 3)
            .createModule(),
        throwsArgumentError);
    expect(
        () => (InferredSramConfigurator()..entryCountKnob.value = 5)
            .createModule(),
        throwsArgumentError);
  });
}
