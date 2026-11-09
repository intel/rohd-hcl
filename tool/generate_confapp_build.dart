// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// generate_confapp_build.dart
// Generates the standalone Confapp build manifest.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

Map<String, dynamic> readYaml(File file) {
  final value = loadYaml(file.readAsStringSync());
  if (value is! YamlMap) {
    throw FormatException('Expected a YAML mapping in ${file.path}');
  }
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

void rebasePaths(Map<String, dynamic> dependencies, Directory base) {
  String absolutePath(String path) =>
      base.uri.resolveUri(Uri.file(path)).toFilePath();

  for (final dependency in dependencies.values) {
    if (dependency is! Map<String, dynamic>) {
      continue;
    }
    final path = dependency['path'];
    if (path is String) {
      dependency['path'] = absolutePath(path);
    }
    final git = dependency['git'];
    if (git is Map<String, dynamic>) {
      final url = git['url'];
      if (url is String && (url.startsWith('./') || url.startsWith('../'))) {
        git['url'] = absolutePath(url);
      }
    } else if (git is String &&
        (git.startsWith('./') || git.startsWith('../'))) {
      dependency['git'] = absolutePath(git);
    }
  }
}

Map<String, dynamic> overridesFor(Directory directory) {
  final manifest =
      readYaml(File.fromUri(directory.uri.resolve('pubspec.yaml')));
  final overridesFile =
      File.fromUri(directory.uri.resolve('pubspec_overrides.yaml'));
  final overrides = overridesFile.existsSync()
      ? readYaml(overridesFile)
      : <String, dynamic>{};
  final result = (overrides.containsKey('dependency_overrides')
          ? overrides['dependency_overrides']
          : manifest['dependency_overrides']) ??
      <String, dynamic>{};
  if (result is! Map<String, dynamic>) {
    throw FormatException('Invalid dependency_overrides in ${directory.path}');
  }
  rebasePaths(result, directory);
  return result;
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart tool/generate_confapp_build.dart <build-dir>');
    exitCode = 2;
    return;
  }

  final root = File.fromUri(Platform.script).parent.parent.absolute;
  final app = Directory.fromUri(root.uri.resolve('confapp/'));
  final build = Directory(args.single).absolute;
  final manifest = readYaml(File.fromUri(app.uri.resolve('pubspec.yaml')))
    ..remove('resolution')
    ..remove('workspace');
  for (final key in ['dependencies', 'dev_dependencies']) {
    final dependencies = manifest[key];
    if (dependencies is! Map<String, dynamic>) {
      throw FormatException('Invalid $key in ${app.path}/pubspec.yaml');
    }
    rebasePaths(dependencies, app);
  }
  final dependencies = manifest['dependencies'] as Map<String, dynamic>;
  dependencies['rohd_hcl'] = {'path': root.path};

  final overrides = overridesFor(root);
  for (final entry in overridesFor(app).entries) {
    if (overrides.containsKey(entry.key)) {
      throw StateError('Dependency ${entry.key} is overridden twice.');
    }
    overrides[entry.key] = entry.value;
  }
  if (overrides.isEmpty) {
    manifest.remove('dependency_overrides');
  } else {
    manifest['dependency_overrides'] = overrides;
  }

  final flutter = manifest['flutter'] as Map<String, dynamic>;
  final assets = flutter['assets'] as List<dynamic>;
  final sourceAssets = Directory.fromUri(build.uri.resolve('assets/rohd_src/'));
  final directories = sourceAssets
      .listSync(recursive: true)
      .whereType<Directory>()
      .map((directory) => Uri.decodeComponent(directory.uri
          .toString()
          .substring(sourceAssets.uri.toString().length)))
      .toList()
    ..sort();
  assets
    ..add('assets/rohd_src/')
    ..addAll(directories.map((directory) => 'assets/rohd_src/$directory'));

  File.fromUri(build.uri.resolve('pubspec.yaml')).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
}
