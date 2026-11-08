// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// behavioral_systemc_hierarchy.dart
// Explicit behavioral-model substitution in SystemC hierarchies.
//
// 2026 November 7
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/memory/behavioral/behavioral_model.dart';

/// Selects a module whose portable implementation should replace its RTL.
typedef BehavioralSystemCSelector = bool Function(Module module);

/// Generates a two-state SystemC hierarchy with explicit behavioral leaves.
///
/// Every selected module must expose a portable model with exactly matching
/// input and output names and widths. Unselected modules use ROHD's normal
/// SystemC synthesizer and its normal unsupported-module checks.
BehavioralSystemCHierarchy generateBehavioralSystemCHierarchy(
  Module top, {
  required BehavioralSystemCSelector select,
  SystemCUnknownOutputPolicy unknownOutputs = SystemCUnknownOutputPolicy.error,
}) {
  final synthesizer = _BehavioralSystemCSynthesizer(select, unknownOutputs);
  final builder = SynthBuilder(top, synthesizer);
  final topClassName = builder.instanceTypeOf(top);
  if (topClassName == null) {
    throw UnsupportedError('Top module ${top.uniqueInstanceName} does not '
        'produce a SystemC definition.');
  }
  return BehavioralSystemCHierarchy._(
    topClassName,
    '#include <systemc.h>\n'
    '${builder.getSynthFileContents().map((file) => file.contents).join('\n')}',
  );
}

/// Generated SystemC source and the actual class name of its top module.
final class BehavioralSystemCHierarchy {
  /// Uniquified top-level SystemC class name.
  final String topClassName;

  /// Definitions in dependency order, suitable for inclusion in a testbench.
  final String source;

  const BehavioralSystemCHierarchy._(this.topClassName, this.source);
}

class _BehavioralSystemCSynthesizer extends SystemCSynthesizer {
  final BehavioralSystemCSelector select;
  final SystemCUnknownOutputPolicy unknownOutputs;
  final Map<Module, bool> _selections = {};
  final Map<Module, BehavioralModel> _selected = {};

  _BehavioralSystemCSynthesizer(this.select, this.unknownOutputs);

  BehavioralModel? _model(Module module) {
    if (!_selections.putIfAbsent(module, () => select(module))) {
      return null;
    }
    return _selected.putIfAbsent(module, () {
      if (module is! BehavioralModelProvider) {
        throw UnsupportedError('Selected module ${module.uniqueInstanceName} '
            'does not provide a behavioral SystemC model.');
      }
      final model = (module as BehavioralModelProvider).behavioralModel;
      if (model == null) {
        throw UnsupportedError('Selected module ${module.uniqueInstanceName} '
            'does not provide a behavioral SystemC model.');
      }
      bool matches(Map<String, int> expected, Map<String, Logic> actual) =>
          expected.length == actual.length &&
          expected.entries.every((entry) =>
              actual[entry.key] != null &&
              actual[entry.key]!.width == entry.value);
      if (module.inOuts.isNotEmpty ||
          !matches(model.description.inputPorts, module.inputs) ||
          !matches(model.description.outputPorts, module.outputs)) {
        throw StateError('Behavioral SystemC ports do not match '
            '${module.uniqueInstanceName}.');
      }
      return model;
    });
  }

  @override
  bool generatesDefinition(Module module) =>
      _model(module) != null || super.generatesDefinition(module);

  @override
  SynthesisResult synthesize(
      Module module, String Function(Module) getInstanceTypeOfModule) {
    final model = _model(module);
    if (model == null) {
      return super.synthesize(module, getInstanceTypeOfModule);
    }
    return _BehavioralSystemCResult(
        module,
        getInstanceTypeOfModule,
        model,
        SystemCModelOptions(
            portType: SystemCModelPortType.twoState,
            unknownOutputs: unknownOutputs));
  }
}

class _BehavioralSystemCResult extends SynthesisResult {
  final BehavioralModel model;
  final SystemCModelOptions options;
  late final String _identity =
      model.generateSystemC(className: 'BehavioralModel', options: options);

  _BehavioralSystemCResult(
      super.module, super.getInstanceTypeOfModule, this.model, this.options);

  @override
  bool matchesImplementation(SynthesisResult other) =>
      other is _BehavioralSystemCResult && other._identity == _identity;

  @override
  int get matchHashCode => _identity.hashCode;

  @override
  List<SynthFileContents> toSynthFileContents() => [
        SynthFileContents(
          name: instanceTypeName,
          description: 'Behavioral SystemC module for $instanceTypeName',
          contents: model.generateSystemC(
              className: instanceTypeName, options: options),
        )
      ];
}
