// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// bitwise_mux.dart
// Per-bit selection between two equal-width inputs.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Selects each output bit independently among N inputs.
///
/// `selects` and `inputs` have the same length N, and all have the same width
/// W. Bit `j` of [out] is the OR of `inputs[i][j] & selects[i][j]` over all
/// `i`. Each bit is driven by one input when the selects are one-hot for that
/// bit, which is the intended use. If several selects are high for a bit, the
/// result is the bitwise OR of those inputs. [Mux] selects whole words with a
/// single-bit select, while this module lets each bit choose its own source.
/// {@category Bit Operations}
class BitwiseMux extends Module {
  /// The per-bit selected output.
  Logic get out => output('out');

  /// Creates per-bit selection hardware among [inputs], controlled by
  /// [selects].
  BitwiseMux(
    List<Logic> selects,
    List<Logic> inputs, {
    super.name = 'bitwise_mux',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              'BitwiseMux_N${inputs.length}_W'
                  '${inputs.isEmpty ? 0 : inputs.first.width}',
        ) {
    if (inputs.isEmpty) {
      throw RohdHclException('BitwiseMux requires at least one input.');
    }
    if (selects.length != inputs.length) {
      throw RohdHclException(
        'BitwiseMux needs one select per input, got ${selects.length} '
        'selects for ${inputs.length} inputs.',
      );
    }
    final width = inputs.first.width;
    for (var i = 0; i < inputs.length; i++) {
      if (inputs[i].width != width || selects[i].width != width) {
        throw RohdHclException(
          'BitwiseMux selects and inputs must all have width $width, got '
          'select $i width ${selects[i].width} and input $i width '
          '${inputs[i].width}.',
        );
      }
    }

    final addedSelects = [
      for (var i = 0; i < selects.length; i++)
        addInput('select$i', selects[i], width: width),
    ];
    final addedInputs = [
      for (var i = 0; i < inputs.length; i++)
        addInput('input$i', inputs[i], width: width),
    ];

    final terms = [
      for (var i = 0; i < addedInputs.length; i++)
        addedInputs[i] & addedSelects[i],
    ];
    addOutput('out', width: width) <= terms.reduce((acc, t) => acc | t);
  }
}
