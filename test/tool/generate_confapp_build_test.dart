// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generate_confapp_build_test.dart
// Tests generation of the standalone Confapp build manifest.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory fixture;
  late String packages;

  setUp(() async {
    packages = File('.dart_tool/package_config.json').absolute.path;
    fixture = await Directory.systemTemp.createTemp('confapp_build_test_');
    await Directory('${fixture.path}/tool').create();
    await Directory('${fixture.path}/confapp').create();
    await Directory('${fixture.path}/output/assets/rohd_src/nested')
        .create(recursive: true);
    await File('tool/generate_confapp_build.dart')
        .copy('${fixture.path}/tool/generate_confapp_build.dart');
    await File('${fixture.path}/pubspec.yaml').writeAsString('''
name: rohd_hcl
dependency_overrides:
  ignored_root_override: any
''');
    await File('${fixture.path}/pubspec_overrides.yaml').writeAsString('''
workspace:
  - confapp
dependency_overrides:
  rohd:
    path: ../local-rohd
''');
    await File('${fixture.path}/confapp/pubspec.yaml').writeAsString('''
name: confapp
resolution: workspace
dependencies:
  rohd_hcl: ^0.3.0
  local_dependency:
    path: ../local dependency#1
dev_dependencies:
  test: any
flutter:
  assets:
    - assets/icon.png
''');
    await File('${fixture.path}/confapp/pubspec_overrides.yaml')
        .writeAsString('''
resolution: workspace
dependency_overrides:
  viewer:
    path: ../../local-viewer
  local_git:
    git: ../../local-git
''');
  });

  tearDown(() async {
    await fixture.delete(recursive: true);
  });

  Future<ProcessResult> generate() => Process.run(
        Platform.resolvedExecutable,
        [
          '--packages=$packages',
          '${fixture.path}/tool/generate_confapp_build.dart',
          '${fixture.path}/output',
        ],
      );

  test('generates a standalone manifest with rebased workspace overrides',
      () async {
    final rootOverride = File('${fixture.path}/pubspec_overrides.yaml');
    final appOverride = File('${fixture.path}/confapp/pubspec_overrides.yaml');
    final originalRoot = await rootOverride.readAsString();
    final originalApp = await appOverride.readAsString();
    final result = await generate();
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(await rootOverride.readAsString(), originalRoot);
    expect(await appOverride.readAsString(), originalApp);
    final manifest = jsonDecode(
      await File('${fixture.path}/output/pubspec.yaml').readAsString(),
    ) as Map<String, dynamic>;
    expect(manifest, isNot(contains('resolution')));
    final dependencies = manifest['dependencies'] as Map<String, dynamic>;
    final rootDependency = dependencies['rohd_hcl'] as Map<String, dynamic>;
    final localDependency =
        dependencies['local_dependency'] as Map<String, dynamic>;
    expect(rootDependency['path'], fixture.path);
    expect(
      localDependency['path'],
      Directory('${fixture.path}/local dependency#1').path,
    );
    final overrides = manifest['dependency_overrides'] as Map<String, dynamic>;
    final rohdOverride = overrides['rohd'] as Map<String, dynamic>;
    final viewerOverride = overrides['viewer'] as Map<String, dynamic>;
    final gitOverride = overrides['local_git'] as Map<String, dynamic>;
    expect(overrides, isNot(contains('ignored_root_override')));
    expect(
      rohdOverride['path'],
      fixture.parent.uri.resolve('local-rohd').toFilePath(),
    );
    expect(
      viewerOverride['path'],
      fixture.parent.uri.resolve('local-viewer').toFilePath(),
    );
    expect(
      gitOverride['git'],
      fixture.parent.uri.resolve('local-git').toFilePath(),
    );
    expect(
      (manifest['flutter'] as Map<String, dynamic>)['assets'],
      ['assets/icon.png', 'assets/rohd_src/', 'assets/rohd_src/nested/'],
    );
  });

  test('rejects duplicate workspace overrides', () async {
    await File('${fixture.path}/confapp/pubspec_overrides.yaml')
        .writeAsString('dependency_overrides:\n  rohd: any\n');
    final result = await generate();
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('Dependency rohd is overridden twice'));
  });
}
