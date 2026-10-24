// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// extrema.dart
// Implementation of finding extremas (max or min) of signals.
//
// 2024 September 16
// Author: Roberto Torres <roberto.torres@intel.com>
//

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// A candidate keeps its original index alongside its typed payload.
class _IndexedCandidate<T extends Logic> extends LogicStructure {
  T get payload => elements[0] as T;
  Logic get index => elements[1];

  _IndexedCandidate(T schema, int indexWidth, {String? name})
      : super([
          schema.cloneTyped(name: 'payload'),
          Logic(name: 'index', width: indexWidth),
        ], name: name ?? 'candidate');

  @override
  _IndexedCandidate<T> clone({String? name}) =>
      _IndexedCandidate(payload, index.width, name: name ?? this.name);
}

/// Determines the extrema (maximum or minimum) of typed payloads.
class Extrema<T extends Logic> extends Module {
  /// The [index] of the extrema.
  Logic get index => output('index');

  /// The [val] of the extrema.
  T get val => output('val') as T;

  /// The combinational depth of the balanced indexed reduction tree.
  late final int treeDepth;

  /// Finds an extrema of [signals], preserving the selected payload type [T].
  /// Plain [Logic] inputs may differ in width and are zero-extended.
  /// Structured inputs must have matching layouts.
  ///
  /// If [max] is `true`, will find maximum value, else will find minimum.
  ///
  /// [radix] controls the maximum number of candidates compared by each
  /// balanced reduction node. Equal candidates preserve the earliest index.
  /// [isLessThan] defaults to the payload's [Logic.lt] comparison. Supply it
  /// to compare record keys while transporting complete records. Use
  /// `Extrema<Logic>` for scalar constant inputs.
  ///
  /// Outputs the [index] and [val] of the extrema in the list of [signals].
  Extrema(
    List<T> signals, {
    bool max = true,
    int radix = 2,
    Logic Function(T a, T b)? isLessThan,
    super.name = 'extrema',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              'Extrema_W${signals.map((signal) => signal.width).join('_')}_'
                  '${max ? "Max" : "Min"}_R$radix',
        ) {
    if (signals.isEmpty) {
      throw RohdHclException('List cannot be empty.');
    }
    if (signals.any((s) => s is LogicStructure || s is LogicEnum) &&
        signals.any((s) => !sameDeclaredPayloadShape(signals.first, s))) {
      throw RohdHclException('Extrema payload layouts must match.');
    }
    final logics = [
      for (var i = 0; i < signals.length; i++)
        addTypedInput('signal$i', signals[i])
    ];

    // Find the max width of all inputs.
    var maxWidth = 0;
    for (var i = 0; i < logics.length; i++) {
      if (logics[i].width > maxWidth) {
        maxWidth = logics[i].width;
      }
    }

    final unsigned = StaticOrRuntimeParameter.ofDynamic(false);
    for (var i = 0; i < logics.length; i++) {
      if (logics[i].width < maxWidth) {
        logics[i] = ReductionTree.alignInput(logics[i], maxWidth, unsigned);
      }
    }

    final indexWidth = widthFor(logics.length);
    final compare = isLessThan ?? (T a, T b) => a.lt(b);
    final tree = ReductionTreeGenerator<_IndexedCandidate<T>, Logic>(
      [
        for (var i = 0; i < logics.length; i++)
          _IndexedCandidate(logics[i], indexWidth)
            ..payload.gets(logics[i])
            ..index.gets(Const(i, width: indexWidth)),
      ],
      (inputs, {depth = 0, control, name = 'extrema'}) =>
          inputs.reduce((current, candidate) {
        final selectCandidate = max
            ? compare(current.payload, candidate.payload)
            : compare(candidate.payload, current.payload);
        return mux<_IndexedCandidate<T>>(selectCandidate, candidate, current,
            outputGenerator: current.clone);
      }),
      radix: radix,
    );
    treeDepth = tree.depth;
    addOutput('index', width: indexWidth) <= tree.out.index;
    addTypedOutput('val', tree.out.payload.cloneTyped) <= tree.out.payload;
  }
}
