// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generate.dart
// Generate ROHD netlist JSON for each component in the registry.
// Used by CI to produce schematic pages in doc/api/schematics/.
//
// 2023 May 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';

void main() async {
  Directory('build').createSync(recursive: true);
  for (final configurator in componentRegistry) {
    final module = configurator.createModule();
    await module.build();

    final synthesizer = NetlistSynthesizer();
    final builder = SynthBuilder(module, synthesizer);
    final netlistJson = synthesizer.generateCombinedJson(builder, module);
    await File(
      'build/${module.definitionName}.rohd.json',
    ).writeAsString(netlistJson);
  }
}
