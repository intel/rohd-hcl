// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_parallel_prefix_operations.dart
// Configurator for documented unary parallel-prefix operations.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Available unary parallel-prefix operations.
enum ParallelPrefixOperation {
  /// Compute a prefix OR scan.
  orScan,

  /// Find the lowest asserted bit as a one-hot value.
  priorityFinder,

  /// Increment a word.
  increment,

  /// Decrement a word.
  decrement,
}

/// A [Configurator] for unary parallel-prefix operations.
class ParallelPrefixOperationConfigurator extends Configurator {
  static final Map<
      Type,
      ParallelPrefix Function(
        List<Logic> inputs,
        Logic Function(Logic lhs, Logic rhs) operation,
      )> _treeGenerators = {
    Ripple: Ripple.new,
    Sklansky: Sklansky.new,
    KoggeStone: KoggeStone.new,
    BrentKung: BrentKung.new,
  };

  /// Input width.
  final IntConfigKnob widthKnob = IntConfigKnob(value: 8);

  /// Operation to instantiate.
  final ChoiceConfigKnob<ParallelPrefixOperation> operationKnob =
      ChoiceConfigKnob(
    ParallelPrefixOperation.values,
    value: ParallelPrefixOperation.orScan,
    choiceLabels: const {
      ParallelPrefixOperation.orScan: 'OR Scan',
      ParallelPrefixOperation.priorityFinder: 'Priority Finder',
      ParallelPrefixOperation.increment: 'Increment',
      ParallelPrefixOperation.decrement: 'Decrement',
    },
  );

  /// Prefix-tree shape used by the operation.
  final ChoiceConfigKnob<Type> treeKnob = ChoiceConfigKnob(
    _treeGenerators.keys.toList(),
    value: KoggeStone,
    choiceLabels: const {
      Ripple: 'Ripple',
      Sklansky: 'Sklansky',
      KoggeStone: 'KoggeStone',
      BrentKung: 'BrentKung',
    },
  );

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Width': widthKnob,
    'Operation': operationKnob,
    'Prefix Tree': treeKnob,
  });

  @override
  Module createModule() {
    final input = Logic(width: widthKnob.value);
    final treeGenerator = _treeGenerators[treeKnob.value]!;
    return switch (operationKnob.value) {
      ParallelPrefixOperation.orScan =>
        ParallelPrefixOrScan(input, ppGen: treeGenerator),
      ParallelPrefixOperation.priorityFinder =>
        ParallelPrefixPriorityFinder(input, ppGen: treeGenerator),
      ParallelPrefixOperation.increment =>
        ParallelPrefixIncr(input, ppGen: treeGenerator),
      ParallelPrefixOperation.decrement =>
        ParallelPrefixDecr(input, ppGen: treeGenerator),
    };
  }

  @override
  String get name => 'Parallel Prefix Operation';
}
