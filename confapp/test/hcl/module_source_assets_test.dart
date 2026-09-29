// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// module_source_assets_test.dart
// Tests bundled source coverage for configurable modules.
//
// 2026 August 29
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:confapp/hcl/module_source_assets.dart';
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

  test('nondefault module implementations have indexed source assets', () {
    final variants = <({String name, Module module, String asset})>[
      (
        name: 'binary-to-one-hot direction',
        module: (OneHotConfigurator()..directionKnob.value = BinaryToOneHot)
            .createModule(),
        asset: 'rohd_src/encodings/binary_to_one_hot.dart',
      ),
      (
        name: 'tree one-hot-to-binary width',
        module:
            (OneHotConfigurator()..inputWidthKnob.value = 16).createModule(),
        asset: 'rohd_src/encodings/tree_one_hot_to_binary.dart',
      ),
      (
        name: 'rotate round-robin implementation',
        module: (RoundRobinArbiterConfigurator()
              ..implementationKnob.value = RotateRoundRobinArbiter)
            .createModule(),
        asset: 'rohd_src/arbiters/rotate_round_robin_arbiter.dart',
      ),
      (
        name: 'deserialize direction',
        module: (SerializationConfigurator()
              ..directionKnob.value = Deserializer)
            .createModule(),
        asset: 'rohd_src/serialization/serialization.dart',
      ),
      (
        name: 'left rotation',
        module: (RotateConfigurator()
              ..directionKnob.value = RotateDirection.left)
            .createModule(),
        asset: 'rohd_src/rotate.dart',
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
        asset: 'rohd_src/arithmetic/leading_digit_anticipate.dart',
      ),
      (
        name: 'leading-zero carry anticipator',
        module: (LeadingDigitAnticipateConfigurator()
              ..anticipator.value = LeadingZeroAnticipateCarry)
            .createModule(),
        asset: 'rohd_src/arithmetic/leading_digit_anticipate.dart',
      ),
      (
        name: 'compression-tree multiplier',
        module: (MultiplierConfigurator()
              ..multiplierSelectKnob.compressionTreeMultiplierKnob.value = true)
            .createModule(),
        asset: 'rohd_src/arithmetic/multiplier.dart',
      ),
      (
        name: 'gated counter',
        module: (CounterConfigurator()..clockGatingKnob.value = true)
            .createModule(),
        asset: 'rohd_src/summation/gated_counter.dart',
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
