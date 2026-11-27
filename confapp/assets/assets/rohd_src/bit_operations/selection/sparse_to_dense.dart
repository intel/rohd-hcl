// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sparse_to_dense.dart
// Combinational boolean sparse-to-dense scatter.
//
// 2026 November 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/dataflow/reduction/reduction_tree.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Scatters valid unsigned binary indices into a boolean bit vector.
///
/// `indices` must be nonempty and have equal, positive widths; `valids`
/// contains one single-bit valid for each index. [outputWidth] is positive.
/// An in-range index sets its corresponding bit, and collisions are ORed.
/// Indices greater than or equal to [outputWidth] are ignored.
///
/// Each contribution is `({outputWidth{1'b0}} | 1) << index`, masked by
/// replicated valid, then OR-reduced. Thus an X or Z in an index makes that
/// entire contribution X; valid 0 masks it to zero. An X or Z valid produces
/// X at a known selected bit and zero elsewhere. OR with a known 1 resolves a
/// collision to 1. This is ordinary four-state shift, AND and OR behavior,
/// not a wildcard interpretation of unknown indices.
///
/// Decoder width is bounded by [outputWidth], not `2^indexWidth`.
/// {@category Bit Operations}
class SparseToDense extends Module {
  /// The boolean dense bit vector, with width [outputWidth].
  Logic get out => output('out');

  /// Number of bits in [out].
  final int outputWidth;

  /// Common width of each unsigned index.
  int get indexWidth => input('index0').width;

  /// Number of index/valid pairs.
  final int inputCount;

  /// Creates a combinational scatter for [indices] and their [valids].
  SparseToDense(
    List<Logic> indices,
    List<Logic> valids, {
    required this.outputWidth,
    super.name = 'sparse_to_dense',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  })  : inputCount = indices.length,
        super(
          definitionName: definitionName ??
              'SparseToDense_N${indices.length}_I'
                  '${indices.isEmpty ? 0 : indices.first.width}_O$outputWidth',
        ) {
    if (indices.isEmpty) {
      throw RohdHclException('SparseToDense requires at least one index.');
    }
    if (outputWidth <= 0) {
      throw RohdHclException('SparseToDense outputWidth must be positive.');
    }
    if (valids.length != indices.length) {
      throw RohdHclException('SparseToDense requires one valid per index.');
    }
    final width = indices.first.width;
    if (width <= 0 || indices.any((index) => index.width != width)) {
      throw RohdHclException(
          'SparseToDense indices must have equal, positive widths.');
    }
    if (valids.any((valid) => valid.width != 1)) {
      throw RohdHclException('SparseToDense valids must be single-bit.');
    }

    final terms = [
      for (var i = 0; i < inputCount; i++)
        (Const(1, width: outputWidth) <<
                addInput('index$i', indices[i], width: width)) &
            addInput('valid$i', valids[i]).replicate(outputWidth),
    ];
    final tree = ReductionTree<Logic, Logic>(
      terms,
      (inputs, {depth = 0, control, name = ''}) =>
          inputs.reduce((a, b) => a | b),
      definitionName: 'SparseToDenseOr_N${inputCount}_O$outputWidth',
    );
    addOutput('out', width: outputWidth) <= tree.out;
  }
}
