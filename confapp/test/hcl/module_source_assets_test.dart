// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// module_source_assets_test.dart
// Tests bundled source coverage for configurable modules.
//
// 2026 August 29
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/module_source_assets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
// The test verifies every registry entry, which requires the internal registry.
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every configured component has an indexed source asset', () {
    for (final configurator in componentRegistry) {
      final module = configurator.createModule();
      expect(
        moduleSourceAsset(module),
        isNotNull,
        reason:
            '${configurator.name} creates ${module.runtimeType}, which has no '
            'ROHD source asset',
      );
    }
  });

  test('compute component sources are bundled', () async {
    final cases = <({Configurator config, String asset, String declaration})>[
      (
        config: ClockDividerConfigurator(),
        asset: 'rohd_src/clocking/generation/clock_divider.dart',
        declaration: 'class ClockDivider',
      ),
      (
        config: ParallelPrefixScanConfigurator(),
        asset:
            'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
        declaration: 'class ParallelPrefixScan',
      ),
      (
        config: SparseToDenseConfigurator(),
        asset: 'rohd_src/bit_operations/selection/sparse_to_dense.dart',
        declaration: 'class SparseToDense',
      ),
      for (final config in [
        BinaryToThermometerConfigurator(),
        ThermometerToBinaryConfigurator(),
      ])
        (
          config: config,
          asset: 'rohd_src/encodings/thermometer/thermometer_code.dart',
          declaration: 'class ${config.createModule().runtimeType}',
        ),
      for (final config in [
        FloatingPointClassifierConfigurator(),
        FloatingPointComparatorConfigurator(),
      ])
        (
          config: config,
          asset:
              'rohd_src/arithmetic/floating_point/floating_point_classification.dart',
          declaration: 'class ${config.createModule().runtimeType}',
        ),
    ];
    for (final item in cases) {
      expect(moduleSourceAsset(item.config.createModule()), item.asset);
      final source = await rootBundle.loadString('assets/${item.asset}');
      expect(source, contains(item.declaration), reason: item.config.name);
    }
    final canonicalizer =
        await rootBundle.loadString('assets/rohd_src/arithmetic/floating_point/'
            'explicit_j_bit_canonicalization.dart');
    expect(canonicalizer, contains('canonicalizeExplicitJBit'));
  });

  test('carry-save multiplier uses its implementation source asset', () {
    final module = CarrySaveMultiplierConfigurator().createModule();

    expect(module, isA<CarrySaveMultiplier>());
    expect(
      moduleSourceAsset(module),
      'rohd_src/arithmetic/multiplication/carry_save_multiplier.dart',
    );
  });

  test('ready/valid queue source is bundled', () async {
    final module = ReadyValidQueueConfigurator().createModule();
    final asset = moduleSourceAsset(module);
    expect(asset,
        'rohd_src/flow_control/ready_valid/queues/ready_valid_queue.dart');
    final source = await rootBundle.loadString('assets/$asset');
    expect(source, contains('class ReadyValidQueue'));
  });

  test('parallel associative memory source is bundled', () async {
    final module = ParallelAssociativeMemoryConfigurator().createModule();
    final asset = moduleSourceAsset(module);
    expect(
        asset, 'rohd_src/memory/associative/parallel_associative_memory.dart');
    final source = await rootBundle.loadString('assets/$asset');
    expect(source, contains('class ParallelAssociativeMemory'));
  });

  test('cache and memory building block sources are bundled', () async {
    final cases = <({Configurator config, String asset, String declaration})>[
      (
        // Verify the intentionally exposed experimental configurator.
        // ignore: experimental_member_use
        config: CacheConfigurator(),
        asset: 'rohd_src/memory/cache/cache.dart',
        declaration: 'class Cache<'
      ),
      (
        // Verify the intentionally exposed experimental configurator.
        // ignore: experimental_member_use
        config: MultiPortCacheConfigurator(),
        asset: 'rohd_src/memory/cache/cache.dart',
        declaration: 'class MultiPortCache<'
      ),
      (
        // Verify the intentionally exposed experimental configurator.
        // ignore: experimental_member_use
        config: SerializedCacheConfigurator(),
        asset: 'rohd_src/memory/cache/serialized_cache.dart',
        declaration: 'class SerializedCache<'
      ),
      (
        // Verify the intentionally exposed experimental configurator.
        // ignore: experimental_member_use
        config: CacheTransactionAdapterConfigurator(),
        asset: 'rohd_src/memory/cache/cache_transaction_adapter.dart',
        declaration: 'class CacheTransactionAdapter<'
      ),
      (
        // Verify the intentionally exposed experimental configurator.
        // ignore: experimental_member_use
        config: CacheSchedulerConfigurator(),
        asset: 'rohd_src/memory/cache/fixed_priority_cache_scheduler.dart',
        declaration: 'class FixedPriorityCacheScheduler'
      ),
      (
        config: ReplacementPolicyConfigurator(),
        asset: 'rohd_src/memory/replacement/round_robin_replacement.dart',
        declaration: 'class RoundRobinReplacement'
      ),
      (
        config: ReplacementPolicyConfigurator()
          ..policyKnob.value = ReplacementConfiguratorPolicy.treePseudoLru,
        asset: 'rohd_src/memory/replacement/tree_pseudo_lru_replacement.dart',
        declaration: 'class TreePseudoLruReplacement'
      ),
      (
        config: InferredSramConfigurator(),
        asset: 'rohd_src/memory/storage/inferred_sram.dart',
        declaration: 'class InferredSram<'
      ),
    ];
    for (final item in cases) {
      final asset = moduleSourceAsset(item.config.createModule());
      expect(asset, item.asset, reason: item.config.name);
      final source = await rootBundle.loadString('assets/$asset');
      expect(source, contains(item.declaration), reason: item.config.name);
    }
  });

  test('nondefault module implementations have indexed source assets', () {
    final variants = <({String name, Module module, String asset})>[
      (
        name: 'binary-to-one-hot direction',
        module: (OneHotConfigurator()..directionKnob.value = BinaryToOneHot)
            .createModule(),
        asset: 'rohd_src/encodings/one_hot/binary_to_one_hot.dart',
      ),
      (
        name: 'tree one-hot-to-binary width',
        module:
            (OneHotConfigurator()..inputWidthKnob.value = 16).createModule(),
        asset: 'rohd_src/encodings/one_hot/tree_one_hot_to_binary.dart',
      ),
      (
        name: 'rotate round-robin implementation',
        module: (RoundRobinArbiterConfigurator()
              ..implementationKnob.value = RotateRoundRobinArbiter)
            .createModule(),
        asset:
            'rohd_src/flow_control/arbitration/rotate_round_robin_arbiter.dart',
      ),
      (
        name: 'deserialize direction',
        module: (SerializationConfigurator()
              ..directionKnob.value = Deserializer)
            .createModule(),
        asset: 'rohd_src/dataflow/serialization/serialization.dart',
      ),
      (
        name: 'left rotation',
        module: (RotateConfigurator()
              ..directionKnob.value = RotateDirection.left)
            .createModule(),
        asset: 'rohd_src/bit_operations/shifting/rotate.dart',
      ),
      for (final direction in RotateDirection.values)
        (
          name: 'fixed ${direction.name} rotation',
          module: (RotateConfigurator()
                ..fixedKnob.value = true
                ..directionKnob.value = direction)
              .createModule(),
          asset: 'rohd_src/bit_operations/shifting/rotate.dart',
        ),
      for (final implementation in MuxImplementation.values)
        (
          name: '${implementation.name} multiplexer',
          module: (MuxConfigurator()..implementationKnob.value = implementation)
              .createModule(),
          asset: switch (implementation) {
            MuxImplementation.bitwise =>
              'rohd_src/bit_operations/selection/bitwise_mux.dart',
            MuxImplementation.oneHot =>
              'rohd_src/bit_operations/selection/one_hot_mux.dart',
            MuxImplementation.priority =>
              'rohd_src/bit_operations/selection/priority_mux.dart',
          },
        ),
      (
        name: 'XNOR popcount',
        module: (BitwisePopcountConfigurator()
              ..operationKnob.value = BitwisePopcountOperation.xnor)
            .createModule(),
        asset: 'rohd_src/bit_operations/population_count/xnor_popcount.dart',
      ),
      (
        name: 'CSR block',
        module: (CsrExampleConfigurator()
              ..boundaryKnob.value = CsrExampleBoundary.block)
            .createModule(),
        asset: 'rohd_src/memory/csr/csr_block.dart',
      ),
      (
        name: 'dual-path floating-point adder',
        module: (FloatingPointAdderConfigurator()
              ..dualPathAdderKnob.value = true)
            .createModule(),
        asset:
            'rohd_src/arithmetic/floating_point/floating_point_adder_dualpath.dart',
      ),
      (
        name: 'leading-zero anticipator',
        module: (LeadingDigitAnticipateConfigurator()
              ..anticipator.value = LeadingZeroAnticipate)
            .createModule(),
        asset:
            'rohd_src/arithmetic/normalization/leading_digit_anticipate.dart',
      ),
      (
        name: 'leading-zero carry anticipator',
        module: (LeadingDigitAnticipateConfigurator()
              ..anticipator.value = LeadingZeroAnticipateCarry)
            .createModule(),
        asset:
            'rohd_src/arithmetic/normalization/leading_digit_anticipate.dart',
      ),
      (
        name: 'compression-tree multiplier',
        module: (MultiplierConfigurator()
              ..multiplierSelectKnob.compressionTreeMultiplierKnob.value = true)
            .createModule(),
        asset: 'rohd_src/arithmetic/multiplication/multiplier.dart',
      ),
      (
        name: 'gated counter',
        module: (CounterConfigurator()..clockGatingKnob.value = true)
            .createModule(),
        asset: 'rohd_src/arithmetic/accumulation/gated_counter.dart',
      ),
      (
        name: 'compression-tree dot product',
        module: (DotProductConfigurator()
              ..implementationKnob.value =
                  DotProductImplementation.compressionTree)
            .createModule(),
        asset: 'rohd_src/arithmetic/multiply_accumulate/dotproduct.dart',
      ),
      (
        name: 'dual sign-magnitude adder',
        module: (SignMagnitudeAdderConfigurator()
              ..implementationKnob.value =
                  SignMagnitudeAdderImplementation.dual)
            .createModule(),
        asset: 'rohd_src/arithmetic/addition/sign_magnitude_adder.dart',
      ),
      (
        name: 'parallel-prefix priority encoder',
        module: (PriorityEncoderConfigurator()
              ..implementationKnob.implementationKnob.value =
                  ParallelPrefixPriorityEncoder)
            .createModule(),
        asset: 'rohd_src/encodings/priority/priority_encoder.dart',
      ),
      (
        name: 'parallel-prefix incrementer',
        module: (ParallelPrefixOperationConfigurator()
              ..operationKnob.value = ParallelPrefixOperation.increment)
            .createModule(),
        asset:
            'rohd_src/arithmetic/prefix_networks/parallel_prefix_operations.dart',
      ),
      (
        name: 'parity receiver',
        module: (ParityConfigurator()
              ..directionKnob.value = ParityDirection.receiver)
            .createModule(),
        asset: 'rohd_src/error_control/protection/parity.dart',
      ),
      (
        name: 'SPI sub gasket',
        module:
            (SpiConfigurator()..roleKnob.value = SpiRole.sub).createModule(),
        asset: 'rohd_src/interfaces/spi/endpoints/spi_sub.dart',
      ),
    ];

    for (final variant in variants) {
      expect(
        moduleSourceAsset(variant.module),
        variant.asset,
        reason: '${variant.name} creates ${variant.module.runtimeType}',
      );
    }
  });
}
