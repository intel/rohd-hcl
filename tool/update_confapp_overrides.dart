// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// update_confapp_overrides.dart
// Updates selected dependency overrides while preserving other settings.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

Map<String, dynamic> readMap(String content, String description) {
  final value = loadYaml(content);
  if (value == null) {
    return {};
  }
  if (value is! YamlMap) {
    throw FormatException('Expected a YAML mapping in $description');
  }
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

class OverrideFile {
  final File file;
  final String? original;
  final String initial;
  final YamlEditor editor;
  final Map<String, dynamic> manifest;

  factory OverrideFile(Directory directory) {
    final file = File.fromUri(directory.uri.resolve('pubspec_overrides.yaml'));
    final original = file.existsSync() ? file.readAsStringSync() : null;
    final manifestFile = File.fromUri(directory.uri.resolve('pubspec.yaml'));
    final manifest =
        readMap(manifestFile.readAsStringSync(), manifestFile.path);
    final initial =
        original == null || original.trim().isEmpty ? '{}\n' : original;
    return OverrideFile._(
        file, original, initial, YamlEditor(initial), manifest);
  }

  OverrideFile._(
      this.file, this.original, this.initial, this.editor, this.manifest);

  Map<String, dynamic> get document => readMap(editor.toString(), file.path);

  Map<String, dynamic> get dependencies {
    final current = document;
    final value = current.containsKey('dependency_overrides')
        ? current['dependency_overrides']
        : manifest['dependency_overrides'];
    if (value == null) {
      return {};
    }
    if (value is! Map<String, dynamic>) {
      throw FormatException('Invalid dependency_overrides in ${file.path}');
    }
    return Map<String, dynamic>.from(value);
  }

  void removeSelected(Set<String> selected) {
    final current = document;
    final overrides = dependencies;
    final matches = selected.where(overrides.containsKey).toList();
    if (matches.isEmpty) {
      return;
    }
    if (!current.containsKey('dependency_overrides') ||
        current['dependency_overrides'] == null) {
      matches.forEach(overrides.remove);
      editor.update(['dependency_overrides'], overrides);
    } else {
      for (final name in matches) {
        editor.remove(['dependency_overrides', name]);
      }
    }
  }

  void setDependency(String name, Object value) {
    final current = document;
    if (!current.containsKey('dependency_overrides') ||
        current['dependency_overrides'] == null) {
      editor.update(['dependency_overrides'], dependencies);
    }
    editor.update(['dependency_overrides', name], value);
  }

  void write() {
    final result = editor.toString();
    if (result == initial) {
      return;
    }
    if (original != null) {
      var backup = File('${file.path}.disabled');
      var suffix = 1;
      while (backup.existsSync()) {
        backup = File('${file.path}.disabled.$suffix');
        suffix++;
      }
      file.copySync(backup.path);
      stdout.writeln('Backed up ${file.path} to ${backup.path}.');
    }
    file.writeAsStringSync(result);
    stdout.writeln('Updated ${file.path}.');
  }
}

void main(List<String> args) {
  if (args.length < 6 || (args.length - 1) % 5 != 0) {
    throw ArgumentError(
        'Expected a repository path and dependency selections.');
  }

  final root = Directory(args.first).absolute;
  final app = Directory.fromUri(root.uri.resolve('confapp/'));
  final rootOverrides = OverrideFile(root);
  final appOverrides = OverrideFile(app);
  final selected = <String>{};
  final replacements = <String, Object>{};

  for (var index = 1; index < args.length; index += 5) {
    final name = args[index];
    final source = args[index + 1];
    final url = args[index + 2];
    final ref = args[index + 3];
    final path = args[index + 4];
    if (!selected.add(name)) {
      throw ArgumentError('Dependency $name was selected twice.');
    }
    switch (source) {
      case 'hosted':
        break;
      case 'git':
        replacements[name] = {
          'git': {
            'url': url,
            'ref': ref,
            if (path.isNotEmpty) 'path': path,
          }
        };
      case 'local':
        replacements[name] = {'path': path};
      default:
        throw ArgumentError('Unsupported dependency source: $source');
    }
  }

  rootOverrides.removeSelected(selected);
  appOverrides.removeSelected(selected.difference(replacements.keys.toSet()));
  for (final entry in replacements.entries) {
    appOverrides.setDependency(entry.key, entry.value);
  }
  rootOverrides.write();
  appOverrides.write();
}
