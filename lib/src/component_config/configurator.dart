// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// configurator.dart
// Implementation of a `Configurator` for configuring components.
//
// 2023 December 5

import 'dart:convert';

import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/sanitizer.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An object that enables a consisten API for configuring a [Module] and
/// performing common tasks with it.
abstract class Configurator {
  /// The [name] of this [Configurator].
  String get name;

  /// A version of the [name] which has been sanitized to meet SystemVerilog
  /// variable naming requirements.
  String get sanitaryName => Sanitizer.sanitizeSV(name);

  /// A mapping from configuration names to [ConfigKnob]s that can be used
  /// to configure this component.
  Map<String, ConfigKnob<dynamic>> get knobs;

  /// Generates SystemVerilog for the module as configured.
  Future<String> generateSV() async {
    final mod = createModule();

    await mod.build();

    return mod.generateSynth();
  }

  /// Creates a [Module] instance as configured.
  Module createModule();

  /// Serializes the configuration information into a JSON structure.
  String toJson({bool pretty = false}) =>
      JsonEncoder.withIndent(pretty ? '  ' : null).convert({
        'name': name,
        'knobs': {
          for (final knob in knobs.entries) knob.key: knob.value.toJson(),
        },
      });

  /// Loads the configuration from a serialized JSON representation.
  void loadJson(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    assert(decoded['name'] == name, 'Expect name to be the same.');

    for (final decodedKnob in (decoded['knobs'] as Map).entries) {
      assert(knobs.containsKey(decodedKnob.key),
          'Expect knobs in JSON to exist in configurator.');

      knobs[decodedKnob.key]!
          .loadJson(decodedKnob.value as Map<String, dynamic>);
    }
  }
}
