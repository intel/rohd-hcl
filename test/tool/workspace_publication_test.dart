// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// workspace_publication_test.dart
// Tests workspace configuration and package publication behavior.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final repository = Directory.current;
  late Directory fixture;

  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('hcl_publication_test_');
  });

  tearDown(() async {
    await fixture.delete(recursive: true);
  });

  test('workspace membership is local, not in the package manifest', () async {
    final manifest =
        loadYaml(await File('pubspec.yaml').readAsString()) as YamlMap;
    final workspace =
        loadYaml(await File('pubspec_overrides.yaml').readAsString())
            as YamlMap;
    final confapp =
        loadYaml(await File('confapp/pubspec.yaml').readAsString()) as YamlMap;

    expect(manifest, isNot(contains('workspace')));
    expect(workspace['workspace'], ['confapp']);
    expect(confapp['resolution'], 'workspace');

    final result = await Process.run(
        Platform.resolvedExecutable, ['pub', 'workspace', 'list']);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('rohd_hcl'));
    expect(result.stdout, contains('confapp'));
  });

  test('dependency configuration preserves unrelated existing overrides',
      () async {
    await Directory('${fixture.path}/tool').create();
    await Directory('${fixture.path}/confapp').create();
    await Directory('${fixture.path}/.dart_tool').create();
    await File('tool/confapp_dev_mode.sh')
        .copy('${fixture.path}/tool/confapp_dev_mode.sh');
    await File('tool/update_confapp_overrides.dart')
        .copy('${fixture.path}/tool/update_confapp_overrides.dart');
    await File('.dart_tool/package_config.json')
        .copy('${fixture.path}/.dart_tool/package_config.json');
    await File('pubspec.yaml').copy('${fixture.path}/pubspec.yaml');
    await File('confapp/pubspec.yaml')
        .copy('${fixture.path}/confapp/pubspec.yaml');
    final workspaceFile = File('${fixture.path}/pubspec_overrides.yaml');
    await workspaceFile.writeAsString('''
# Keep the local workspace.
workspace:
  - confapp
dependency_overrides:
  rohd:
    path: /old/root-rohd
  custom_root: ^1.0.0
''');
    final original = await workspaceFile.readAsString();
    final appOverride = File('${fixture.path}/confapp/pubspec_overrides.yaml');
    await appOverride.writeAsString('''
# Keep the app's unrelated settings.
resolution: workspace
dependency_overrides:
  rohd:
    path: /old/app-rohd
  rohd_hierarchy: ^0.1.1
  custom_app: ^2.0.0
''');
    final originalApp = await appOverride.readAsString();

    Future<ProcessResult> configure(List<String> args) => Process.run(
          'bash',
          ['${fixture.path}/tool/confapp_dev_mode.sh', ...args],
        );

    final configured = await configure(['configure-group', 'rohd', 'git']);
    expect(configured.exitCode, 0, reason: '${configured.stderr}');
    final rootContent = await workspaceFile.readAsString();
    expect(rootContent, contains('# Keep the local workspace.'));
    final rootYaml = loadYaml(rootContent) as YamlMap;
    expect(rootYaml['workspace'], ['confapp']);
    expect(rootYaml['dependency_overrides'] as YamlMap, {
      'custom_root': '^1.0.0',
    });
    expect(
        await File('${workspaceFile.path}.disabled').readAsString(), original);
    expect(
        await File('${appOverride.path}.disabled').readAsString(), originalApp);

    final content = loadYaml(await appOverride.readAsString()) as YamlMap;
    final dependencies = content['dependency_overrides'] as YamlMap;
    expect(content['resolution'], 'workspace');
    expect(await appOverride.readAsString(), contains('# Keep the app'));
    expect((dependencies['rohd'] as YamlMap)['git'], isNotNull);
    expect(dependencies['rohd_hierarchy'], '^0.1.1');
    expect(dependencies['custom_app'], '^2.0.0');

    final beforeSchematic = await appOverride.readAsString();
    final schematic =
        await configure(['configure-group', 'schematic', 'hosted']);
    expect(schematic.exitCode, 0, reason: '${schematic.stderr}');
    expect(await workspaceFile.readAsString(), rootContent);
    expect(await appOverride.readAsString(), beforeSchematic);

    final reset = await configure(['manifest']);
    expect(reset.exitCode, 0, reason: '${reset.stderr}');
    expect(await workspaceFile.readAsString(), rootContent);
    final afterReset = loadYaml(await appOverride.readAsString()) as YamlMap;
    expect(afterReset['resolution'], 'workspace');
    expect(afterReset['dependency_overrides'], {'custom_app': '^2.0.0'});
    expect(File('${appOverride.path}.disabled.1').existsSync(), isTrue);
  });

  test('selected inline overrides are shadowed without losing other entries',
      () async {
    await Directory('${fixture.path}/tool').create();
    await Directory('${fixture.path}/confapp').create();
    await Directory('${fixture.path}/.dart_tool').create();
    await File('tool/confapp_dev_mode.sh')
        .copy('${fixture.path}/tool/confapp_dev_mode.sh');
    await File('tool/update_confapp_overrides.dart')
        .copy('${fixture.path}/tool/update_confapp_overrides.dart');
    await File('.dart_tool/package_config.json')
        .copy('${fixture.path}/.dart_tool/package_config.json');
    await File('${fixture.path}/pubspec.yaml').writeAsString('''
name: rohd_hcl
dependency_overrides:
  rohd: ^0.7.0
  root_custom: ^1.0.0
''');
    await File('${fixture.path}/pubspec_overrides.yaml')
        .writeAsString('workspace:\n  - confapp\n');
    await File('${fixture.path}/confapp/pubspec.yaml').writeAsString('''
name: confapp
resolution: workspace
dependency_overrides:
  app_custom: ^2.0.0
''');

    final result = await Process.run('bash', [
      '${fixture.path}/tool/confapp_dev_mode.sh',
      'configure',
      'rohd',
      'git',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final root = loadYaml(
            await File('${fixture.path}/pubspec_overrides.yaml').readAsString())
        as YamlMap;
    final app = loadYaml(
        await File('${fixture.path}/confapp/pubspec_overrides.yaml')
            .readAsString()) as YamlMap;
    expect(root['workspace'], ['confapp']);
    expect(root['dependency_overrides'], {'root_custom': '^1.0.0'});
    final appDependencies = app['dependency_overrides'] as YamlMap;
    expect(appDependencies['app_custom'], '^2.0.0');
    expect((appDependencies['rohd'] as YamlMap)['git'], isNotNull);

    await File('${fixture.path}/pubspec_overrides.yaml').writeAsString('''
workspace:
  - confapp
dependency_overrides:
  rohd: ^0.7.0
''');
    final reset = await Process.run('bash', [
      '${fixture.path}/tool/confapp_dev_mode.sh',
      'configure',
      'rohd',
      'hosted',
    ]);
    expect(reset.exitCode, 0, reason: '${reset.stderr}');
    final resetRoot = loadYaml(
            await File('${fixture.path}/pubspec_overrides.yaml').readAsString())
        as YamlMap;
    expect(resetRoot['workspace'], ['confapp']);
    expect(resetRoot['dependency_overrides'], isEmpty);
  });

  test('a consumer resolves and tests without the Confapp directory', () async {
    final package = Directory('${fixture.path}/package');
    final consumer = Directory('${fixture.path}/consumer');
    await Directory('${package.path}/lib').create(recursive: true);
    await Directory('${consumer.path}/test').create(recursive: true);
    await File('${repository.path}/pubspec.yaml')
        .copy('${package.path}/pubspec.yaml');
    final library = Directory('${repository.path}/lib');
    await for (final entry in library.list(recursive: true)) {
      if (entry is File) {
        final destination = File(
            '${package.path}/lib${entry.path.substring(library.path.length)}');
        await destination.parent.create(recursive: true);
        await entry.copy(destination.path);
      }
    }
    await File('${consumer.path}/pubspec.yaml').writeAsString(jsonEncode({
      'name': 'hcl_consumer_fixture',
      'publish_to': 'none',
      'environment': {'sdk': '>=3.6.0 <4.0.0'},
      'dependencies': {
        'rohd_hcl': {'path': package.path},
      },
      'dev_dependencies': {'test': '^1.25.0'},
    }));
    await File('${consumer.path}/test/consumer_test.dart').writeAsString('''
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';
void main() {
  test('loads the package', () => expect(EdgeDetector, isNotNull));
}
''');

    for (final args in [
      ['pub', 'get', '--offline'],
      ['pub', 'deps'],
      ['test'],
    ]) {
      final result = await Process.run(
        Platform.resolvedExecutable,
        args,
        workingDirectory: consumer.path,
      );
      expect(result.exitCode, 0,
          reason: '${args.join(' ')}: ${result.stdout}\n${result.stderr}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
