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

  test('every indexed source asset exists', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    for (final entry in moduleSourceAssets.entries) {
      expect(
        manifest.getAssetVariants(bundledSourceAssetPath(entry.value)),
        isNotEmpty,
        reason: '${entry.key} maps to unloadable asset ${entry.value}',
      );
    }
  });
}
