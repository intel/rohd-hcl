// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generate.dart
// Generate ROHD netlist JSON for each component in the registry.
// Used by CI to produce schematic pages in doc/api/schematics/.
//
// 2023 May 09
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/component_config/components/component_registry.dart';
import 'package:rohd_hcl/src/component_config/configurator.dart';

const _netlistExtension = '.rohd.json';
const _maxFileNameBytes = 255;

/// Returns a length-limited basename without changing the hardware definition.
String netlistFileName(String definitionName, String configuratorType) {
  final name = utf8.encode('$definitionName$_netlistExtension').length <=
          _maxFileNameBytes
      ? definitionName
      : configuratorType;
  final fileName = '$name$_netlistExtension';
  if (utf8.encode(fileName).length > _maxFileNameBytes) {
    throw StateError('Netlist filename is too long: $fileName');
  }
  return fileName;
}

/// Generates netlists for [configurators] in [outputDirectory].
Future<void> generateNetlists(
    Iterable<Configurator> configurators, Directory outputDirectory) async {
  outputDirectory.createSync(recursive: true);
  final generatedNames = <String, String>{};
  for (final configurator in configurators) {
    final module = configurator.createModule();
    final fileName = netlistFileName(
        module.definitionName, configurator.runtimeType.toString());
    final previous = generatedNames[fileName];
    if (previous != null) {
      throw StateError('Netlist filename $fileName is used by both '
          '$previous and ${configurator.runtimeType}.');
    }
    generatedNames[fileName] = configurator.runtimeType.toString();
    await module.build();

    final synthesizer = NetlistSynthesizer();
    final builder = SynthBuilder(module, synthesizer);
    final netlistJson = synthesizer.generateCombinedJson(builder, module);
    await File('${outputDirectory.path}/$fileName').writeAsString(netlistJson);
  }
}

Future<void> main() => generateNetlists(componentRegistry, Directory('build'));
