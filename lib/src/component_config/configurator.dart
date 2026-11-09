// Copyright (C) 2023-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// configurator.dart
// Implementation of a `Configurator` for configuring components.
//
// 2023 December 5

import 'dart:convert';

import 'package:rohd/rohd.dart';
// ROHD does not expose the sanitizer required for generated names publicly.
// ignore: implementation_imports
import 'package:rohd/src/utilities/sanitizer.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Stable top-level categories used by the component catalog.
enum ComponentCategory {
  /// Numeric arithmetic and floating-point components.
  arithmetic('arithmetic', 'Arithmetic'),

  /// Binary-field and GF(2) components.
  binaryMath('binary_math', 'Binary Math'),

  /// Bit-level search, population-count, and shifting components.
  bitOperations('bit_operations', 'Bit Operations'),

  /// Clock generation, gating, synchronization, and event components.
  clocking('clocking', 'Clocking'),

  /// Selection, ordering, reduction, layout, and serialization components.
  dataflow('dataflow', 'Dataflow'),

  /// Representation and encoding conversion components.
  encodings('encodings', 'Encodings'),

  /// Error detection, correction, and protection components.
  errorControl('error_control', 'Error Control'),

  /// Arbitration, buffering, routing, and transport components.
  flowControl('flow_control', 'Flow Control'),

  /// Inference-specific compute and tensor movement components.
  inference('inference', 'Inference'),

  /// Topology-aware interconnect components.
  interconnect('interconnect', 'Interconnect'),

  /// Standard protocol interface components.
  interfaces('interfaces', 'Interfaces'),

  /// Storage, memory access, and memory-model components.
  memory('memory', 'Memory'),

  /// Simulation-only models.
  models('models', 'Models'),

  /// Components that have not yet been assigned to the catalog taxonomy.
  other('other', 'Other');

  /// The stable taxonomy identifier.
  final String id;

  /// The user-facing category label.
  final String label;

  const ComponentCategory(this.id, this.label);
}

/// An object that enables a consisten API for configuring a [Module] and
/// performing common tasks with it.
abstract class Configurator {
  /// The taxonomy category for this configurable component.
  ComponentCategory get category => ComponentCategory.other;

  /// The taxonomy subcategory for this configurable component.
  String get subcategory => 'uncategorized';

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

    return mod.dumpSystemVerilog();
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
    if (decoded['name'] != name) {
      throw RohdHclException('Expect name to be the same.');
    }

    for (final decodedKnob in (decoded['knobs'] as Map).entries) {
      if (!knobs.containsKey(decodedKnob.key)) {
        throw RohdHclException('Expect name to be the same.');
      }
      knobs[decodedKnob.key]!
          .loadJson(decodedKnob.value as Map<String, dynamic>);
    }
  }
}
