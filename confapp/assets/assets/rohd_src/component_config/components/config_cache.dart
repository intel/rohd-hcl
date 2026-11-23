// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_cache.dart
// Configurators for synthesizable cache components.
//
// 2026 November
// Author: ROHD-HCL contributors

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Replacement policy used by cache configurators.
@experimental
enum CacheConfiguratorReplacement {
  /// Rotate among eligible ways.
  roundRobin,

  /// Approximate least-recent use for a power-of-two way count.
  treePseudoLru,
}

CacheReplacement _replacement(CacheConfiguratorReplacement choice) =>
    switch (choice) {
      CacheConfiguratorReplacement.roundRobin => CacheReplacement.roundRobin,
      CacheConfiguratorReplacement.treePseudoLru =>
        CacheReplacement.treePseudoLru,
    };

mixin _CacheGeometry {
  /// Number of sets; must be a power of two.
  final IntConfigKnob setCountKnob = PositiveIntConfigKnob(value: 2);

  /// Number of ways per set.
  final IntConfigKnob waysPerSetKnob = PositiveIntConfigKnob(value: 2);

  /// Width of a block address.
  final IntConfigKnob addressWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of a data block.
  final IntConfigKnob dataWidthKnob = PositiveIntConfigKnob(value: 8);

  /// RTL replacement policy.
  final ChoiceConfigKnob<CacheConfiguratorReplacement> replacementKnob =
      ChoiceConfigKnob(
    CacheConfiguratorReplacement.values,
    value: CacheConfiguratorReplacement.roundRobin,
    choiceLabels: const {
      CacheConfiguratorReplacement.roundRobin: 'Round robin',
      CacheConfiguratorReplacement.treePseudoLru: 'Tree pseudo-LRU',
    },
  );

  Map<String, ConfigKnob<dynamic>> get _geometryKnobs => {
        'Set Count': setCountKnob,
        'Ways Per Set': waysPerSetKnob,
        'Block Address Width': addressWidthKnob,
        'Data Width': dataWidthKnob,
        'Replacement': replacementKnob,
      };
}

mixin _TransactionGeometry {
  /// Width of a block address.
  final IntConfigKnob addressWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Width of a block.
  final IntConfigKnob dataWidthKnob = PositiveIntConfigKnob(value: 8);

  /// Number of equally sized units selected by the update mask.
  final IntConfigKnob writeMaskWidthKnob = PositiveIntConfigKnob(value: 1);

  /// Width of the request token.
  final IntConfigKnob tokenWidthKnob = PositiveIntConfigKnob(value: 2);

  /// Width of stored line metadata.
  final IntConfigKnob metadataWidthKnob = PositiveIntConfigKnob(value: 2);

  /// Width of caller context.
  final IntConfigKnob contextWidthKnob = PositiveIntConfigKnob(value: 2);

  /// Width of the implementation-specific result.
  final IntConfigKnob resultWidthKnob = PositiveIntConfigKnob(value: 2);

  Map<String, ConfigKnob<dynamic>> get _transactionKnobs => {
        'Block Address Width': addressWidthKnob,
        'Data Width': dataWidthKnob,
        'Write Mask Width': writeMaskWidthKnob,
        'Token Width': tokenWidthKnob,
        'Metadata Width': metadataWidthKnob,
        'Context Width': contextWidthKnob,
        'Result Width': resultWidthKnob,
      };

  CacheTransactionPort<Logic, Logic, Logic, Logic> _transactionPort() =>
      CacheTransactionPort<Logic, Logic, Logic, Logic>(
        addressWidth: addressWidthKnob.value,
        tokenWidth: tokenWidthKnob.value,
        dataSchema: Logic(width: dataWidthKnob.value),
        writeMaskWidth: writeMaskWidthKnob.value,
        lineMetadataSchema: Logic(width: metadataWidthKnob.value),
        contextSchema: Logic(width: contextWidthKnob.value),
        resultSchema: Logic(width: resultWidthKnob.value),
      );
}

/// Configures the single-lookup, single-fill RTL cache.
@experimental
class CacheConfigurator extends Configurator with _CacheGeometry {
  /// Behavior of a lookup concurrent with a fill to the same block.
  final ChoiceConfigKnob<CacheReadDuringFill> readDuringFillKnob =
      ChoiceConfigKnob(
    CacheReadDuringFill.values,
    value: CacheReadDuringFill.oldData,
    choiceLabels: const {
      CacheReadDuringFill.oldData: 'Old data',
      CacheReadDuringFill.forward: 'Forward fill',
    },
  );

  @override
  ComponentCategory get category => ComponentCategory.memory;
  @override
  String get subcategory => 'cache';
  @override
  String get name => 'Cache (Experimental)';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ..._geometryKnobs,
        'Read During Fill': readDuringFillKnob,
      };

  @override
  Module createModule() => Cache<Logic>(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        lookup: CacheLookupPort<Logic>(
            addressWidth: addressWidthKnob.value,
            dataSchema: Logic(width: dataWidthKnob.value)),
        fill: CacheFillPort<Logic>(
            addressWidth: addressWidthKnob.value,
            dataSchema: Logic(width: dataWidthKnob.value)),
        setCount: setCountKnob.value,
        waysPerSet: waysPerSetKnob.value,
        replacement: _replacement(replacementKnob.value),
        readDuringFill: readDuringFillKnob.value,
      );
}

/// Configures the multiport RTL cache.
@experimental
class MultiPortCacheConfigurator extends Configurator with _CacheGeometry {
  /// Number of lookup ports.
  final IntConfigKnob lookupCountKnob = PositiveIntConfigKnob(value: 2);

  /// Number of fill ports.
  final IntConfigKnob fillCountKnob = PositiveIntConfigKnob(value: 2);

  /// Maximum fills selected per set in a cycle.
  final IntConfigKnob maxFillsPerSetKnob = PositiveIntConfigKnob(value: 1);

  /// Same-block lookup behavior during a fill.
  final ChoiceConfigKnob<CacheReadDuringFill> readDuringFillKnob =
      ChoiceConfigKnob(CacheReadDuringFill.values,
          value: CacheReadDuringFill.oldData);

  /// Eviction response concurrency.
  final ChoiceConfigKnob<CacheEvictionConcurrency> evictionConcurrencyKnob =
      ChoiceConfigKnob(CacheEvictionConcurrency.values,
          value: CacheEvictionConcurrency.parallel);

  @override
  ComponentCategory get category => ComponentCategory.memory;
  @override
  String get subcategory => 'cache';
  @override
  String get name => 'Multiport Cache (Experimental)';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ..._geometryKnobs,
        'Lookup Port Count': lookupCountKnob,
        'Fill Port Count': fillCountKnob,
        'Maximum Fills Per Set': maxFillsPerSetKnob,
        'Read During Fill': readDuringFillKnob,
        'Eviction Concurrency': evictionConcurrencyKnob,
      };

  @override
  Module createModule() => MultiPortCache<Logic>(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        lookups: [
          for (var i = 0; i < lookupCountKnob.value; i++)
            CacheLookupPort<Logic>(
                addressWidth: addressWidthKnob.value,
                dataSchema: Logic(width: dataWidthKnob.value)),
        ],
        fills: [
          for (var i = 0; i < fillCountKnob.value; i++)
            CacheFillPort<Logic>(
                addressWidth: addressWidthKnob.value,
                dataSchema: Logic(width: dataWidthKnob.value)),
        ],
        setCount: setCountKnob.value,
        waysPerSet: waysPerSetKnob.value,
        maxFillsPerSet: maxFillsPerSetKnob.value,
        replacement: _replacement(replacementKnob.value),
        readDuringFill: readDuringFillKnob.value,
        evictionConcurrency: evictionConcurrencyKnob.value,
      );
}

/// Configures the serialized transactional RTL cache with inferred SRAM data.
@experimental
class SerializedCacheConfigurator extends Configurator
    with _TransactionGeometry {
  /// Number of sets; must be a power of two.
  final IntConfigKnob setCountKnob = PositiveIntConfigKnob(value: 2);

  /// Number of ways per set.
  final IntConfigKnob waysPerSetKnob = PositiveIntConfigKnob(value: 2);

  /// Number of transactional request ports.
  final IntConfigKnob portCountKnob = PositiveIntConfigKnob(value: 1);

  /// RTL replacement policy.
  final ChoiceConfigKnob<CacheConfiguratorReplacement> replacementKnob =
      ChoiceConfigKnob(CacheConfiguratorReplacement.values,
          value: CacheConfiguratorReplacement.roundRobin);

  @override
  ComponentCategory get category => ComponentCategory.memory;
  @override
  String get subcategory => 'cache';
  @override
  String get name => 'Serialized Cache (Experimental)';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ..._transactionKnobs,
        'Set Count': setCountKnob,
        'Ways Per Set': waysPerSetKnob,
        'Transaction Port Count': portCountKnob,
        'Replacement': replacementKnob,
      };

  @override
  Module createModule() => SerializedCache<Logic, Logic, Logic, Logic>(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        ports: [
          for (var i = 0; i < portCountKnob.value; i++) _transactionPort()
        ],
        setCount: setCountKnob.value,
        waysPerSet: waysPerSetKnob.value,
        dataMemory: inferredSramArray<Logic>(),
        replacement: _replacement(replacementKnob.value),
      );
}

/// Configures a protocol-neutral RTL cache transaction adapter.
@experimental
class CacheTransactionAdapterConfigurator extends Configurator
    with _TransactionGeometry {
  /// Maximum number of outstanding request tokens.
  final IntConfigKnob maxOutstandingKnob = PositiveIntConfigKnob(value: 2);

  @override
  ComponentCategory get category => ComponentCategory.memory;
  @override
  String get subcategory => 'cache';
  @override
  String get name => 'Cache Transaction Adapter (Experimental)';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        ..._transactionKnobs,
        'Maximum Outstanding': maxOutstandingKnob,
      };

  @override
  Module createModule() {
    final port = _transactionPort();
    return CacheTransactionAdapter<Logic, Logic, Logic, Logic>(
      clk: Logic(name: 'clk'),
      reset: Logic(name: 'reset'),
      requests: IrrevocableReadyValidInterface(port.requests.data.clone()),
      responses: IrrevocableReadyValidInterface(port.responses.data.clone()),
      evictions: IrrevocableReadyValidInterface(port.evictions.data.clone()),
      cache: port,
      maxOutstanding: maxOutstandingKnob.value,
    );
  }
}

/// Configures a fixed-priority RTL cache resource scheduler.
@experimental
class CacheSchedulerConfigurator extends Configurator {
  /// Number of competing requests.
  final IntConfigKnob requestCountKnob = PositiveIntConfigKnob(value: 2);

  /// Capacity of each resource.
  final ListOfKnobsKnob capacitiesKnob = ListOfKnobsKnob(
    count: 1,
    generateKnob: (_) => PositiveIntConfigKnob(value: 1),
    name: 'Resource Capacities',
  );

  @override
  ComponentCategory get category => ComponentCategory.memory;
  @override
  String get subcategory => 'cache';
  @override
  String get name => 'Cache Scheduler (Experimental)';
  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Request Count': requestCountKnob,
        'Resource Capacities': capacitiesKnob,
      };

  @override
  Module createModule() => FixedPriorityCacheScheduler(
        clk: Logic(name: 'clk'),
        reset: Logic(name: 'reset'),
        ports: CacheSchedulerPorts(
            requestCount: requestCountKnob.value,
            capacities: [
              for (final knob in capacitiesKnob.knobs)
                (knob as IntConfigKnob).value,
            ]),
      );
}
