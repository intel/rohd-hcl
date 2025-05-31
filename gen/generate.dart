// Copyright (C) 2023-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generate.dart
// Generate a series of examples for documentation.
//
// Call a generator to create an instance of your component for
// schematic viewing.
//
// 2023 May 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';

import 'package:rohd_hcl/src/component_config/components/component_registry.dart';

void main() async {
  Directory('build').createSync(recursive: true);
  for (final configurator in componentRegistry) {
    final sv = await configurator.generateSV();
    final name = configurator.createModule().definitionName;
    File('build/$name.sv').writeAsStringSync(sv);
  }
}
