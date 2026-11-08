// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generate_netlists_test.dart
// Tests documentation netlist filename selection and generation.
//
// 2026 November
// Author: ROHD-HCL contributors

import 'dart:convert';
import 'dart:io';

import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

import '../../gen/generate.dart' as generator;

void main() {
  test('netlist filenames preserve short names and respect byte limits', () {
    expect(generator.netlistFileName('Fifo', 'FifoConfigurator'),
        'Fifo.rohd.json');
    final longest = 'a' * 245;
    expect(generator.netlistFileName(longest, 'ExampleConfigurator'),
        '$longest.rohd.json');
    expect(generator.netlistFileName('${longest}a', 'ExampleConfigurator'),
        'ExampleConfigurator.rohd.json');
    expect(generator.netlistFileName('é' * 123, 'ExampleConfigurator'),
        'ExampleConfigurator.rohd.json');
    expect(() => generator.netlistFileName('a' * 246, 'b' * 246),
        throwsStateError);
  });

  test('long cache names generate distinct netlists with original module names',
      () async {
    final output = await Directory.systemTemp.createTemp('hcl-netlists-');
    addTearDown(() => output.delete(recursive: true));
    final configurators = <Configurator>[
      SerializedCacheConfigurator(),
      CacheTransactionAdapterConfigurator(),
    ];
    await generator.generateNetlists(configurators, output);

    final files = output.listSync().whereType<File>().toList();
    expect(files, hasLength(configurators.length));
    for (final config in configurators) {
      final definitionName = config.createModule().definitionName;
      final name = generator.netlistFileName(
          definitionName, config.runtimeType.toString());
      expect(utf8.encode(name).length, lessThanOrEqualTo(255));
      expect(name, '${config.runtimeType}.rohd.json');
      final json = jsonDecode(await File('${output.path}/$name').readAsString())
          as Map<String, dynamic>;
      expect(json['modules'] as Map<String, dynamic>, contains(definitionName));
    }
  });

  test('duplicate output filenames fail rather than overwrite', () async {
    final output = await Directory.systemTemp.createTemp('hcl-netlists-');
    addTearDown(() => output.delete(recursive: true));
    await expectLater(
        generator.generateNetlists(
            [SerializedCacheConfigurator(), SerializedCacheConfigurator()],
            output),
        throwsStateError);
  });
}
