// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generate_family_documentation.dart
// Generates API documentation with documentation-only family indexes.
//
// 2026 November 18
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';
import 'dart:io';

const _families = <String, (String, String)>{
  'arithmetic': ('arithmetic/arithmetic.dart', ''),
  'binary_math': ('binary_math/binary_math.dart', ''),
  'bit_operations': (
    'bit_operations/bit_operations.dart',
    'PriorityMuxImplementation',
  ),
  'clocking': ('clocking/clocking.dart', ''),
  'component_config': ('component_config/component_config.dart', ''),
  'dataflow': ('dataflow/dataflow.dart', ''),
  'encodings': ('encodings/encodings.dart', ''),
  'error_control': ('error_control/error_control.dart', ''),
  'flow_control': ('flow_control/flow_control.dart', ''),
  'interfaces': (
    'interfaces/interfaces.dart',
    'SpiMainImplementation, SpiSubImplementation',
  ),
  'memories': (
    'memory/memories.dart',
    'AssociativeMatchSelectorImplementation, AssociativeMatcherImplementation, '
        'SynchronousAssociativeLookupPortInterfaceImplementation',
  ),
  'models': ('models/models.dart', ''),
};

Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent.absolute;
  final configFile = File('${root.path}/.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    stderr.writeln(
        'Resolve package dependencies before generating documentation.');
    exitCode = 1;
    return;
  }
  final temporary = await Directory.systemTemp.createTemp('rohd_hcl_dartdoc_');
  try {
    final lib = Directory('${root.path}/lib');
    await for (final entity in lib.list(recursive: true, followLinks: false)) {
      final relative = entity.path.substring(lib.path.length);
      final destination = '${temporary.path}/lib$relative';
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        await Directory(destination).parent.create(recursive: true);
        await entity.copy(destination);
      } else {
        throw FileSystemException('Unexpected link in lib', entity.path);
      }
    }

    for (final name in ['pubspec.yaml', 'README.md', 'LICENSE']) {
      final file = File('${root.path}/$name');
      if (file.existsSync()) {
        await file.copy('${temporary.path}/$name');
      }
    }
    await File('${root.path}/dartdoc_options.yaml')
        .copy('${temporary.path}/dartdoc_options.yaml');

    final config = jsonDecode(await configFile.readAsString()) as Map;
    for (final package in config['packages'] as List) {
      final entry = package as Map;
      entry['rootUri'] = entry['name'] == 'rohd_hcl'
          ? temporary.uri.toString()
          : configFile.uri.resolve(entry['rootUri'] as String).toString();
    }
    await Directory('${temporary.path}/.dart_tool').create();
    await File('${temporary.path}/.dart_tool/package_config.json')
        .writeAsString(jsonEncode(config));

    for (final entry in _families.entries) {
      final (path, hidden) = entry.value;
      await File('${temporary.path}/lib/${entry.key}.dart').writeAsString('''
/// Documentation-only family index. Import `package:rohd_hcl/rohd_hcl.dart`.
library;

export 'src/$path'${hidden.isEmpty ? '' : ' hide $hidden'};
''');
    }
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['doc', '--output', '${root.path}/doc/api'],
      workingDirectory: temporary.path,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exitCode = result.exitCode;
  } finally {
    await temporary.delete(recursive: true);
  }
}
