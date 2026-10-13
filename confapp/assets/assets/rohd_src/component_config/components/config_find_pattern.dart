// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_find_pattern.dart
// Configurator for pattern searching.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FindPattern].
class FindPatternConfigurator extends Configurator {
  /// Width of the bus being searched.
  final IntConfigKnob busWidthKnob = IntConfigKnob(value: 8);

  /// Width of the pattern input.
  final IntConfigKnob patternWidthKnob = IntConfigKnob(value: 2);

  /// Whether the search starts from the least-significant end of the bus.
  final ToggleConfigKnob fromStartKnob = ToggleConfigKnob(value: true);

  /// Whether to generate an input that selects the Nth occurrence.
  final ToggleConfigKnob includeOccurrenceKnob = ToggleConfigKnob(value: false);

  /// Width of the optional Nth-occurrence input.
  final IntConfigKnob occurrenceWidthKnob = IntConfigKnob(value: 3);

  /// Whether to generate an error output when the pattern is not found.
  final ToggleConfigKnob generateErrorKnob = ToggleConfigKnob(value: false);

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => UnmodifiableMapView({
        'Bus Width': busWidthKnob,
        'Pattern Width': patternWidthKnob,
        'Search From Start': fromStartKnob,
        'Generate Nth Occurrence Input': includeOccurrenceKnob,
        if (includeOccurrenceKnob.value)
          'Nth Occurrence Input Width': occurrenceWidthKnob,
        'Generate Error': generateErrorKnob,
      });

  @override
  Module createModule() => FindPattern(
        Logic(width: busWidthKnob.value),
        Logic(width: patternWidthKnob.value),
        fromStart: fromStartKnob.value,
        n: includeOccurrenceKnob.value
            ? Logic(width: occurrenceWidthKnob.value)
            : null,
        generateError: generateErrorKnob.value,
      );

  @override
  String get name => 'Find Pattern';
}
