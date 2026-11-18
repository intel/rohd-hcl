// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_sparse_to_dense.dart
// Configurator for boolean sparse-to-dense scatter.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Configures a boolean sparse-to-dense scatter.
class SparseToDenseConfigurator extends Configurator {
  /// Number of index/valid input pairs.
  final IntConfigKnob inputCountKnob = PositiveIntConfigKnob(value: 4);

  /// Width of each input index.
  final IntConfigKnob indexWidthKnob = PositiveIntConfigKnob(value: 3);

  /// Width of the dense output.
  final IntConfigKnob outputWidthKnob = PositiveIntConfigKnob(value: 8);

  @override
  ComponentCategory get category => ComponentCategory.bitOperations;

  @override
  String get subcategory => 'selection';

  @override
  String get name => 'Sparse to Dense';

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Input Count': inputCountKnob,
        'Index Width': indexWidthKnob,
        'Output Width': outputWidthKnob,
      };

  @override
  Module createModule() => SparseToDense(
        List.generate(inputCountKnob.value,
            (i) => Logic(name: 'index$i', width: indexWidthKnob.value)),
        List.generate(inputCountKnob.value, (i) => Logic(name: 'valid$i')),
        outputWidth: outputWidthKnob.value,
      );
}
