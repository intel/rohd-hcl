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
  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'prefix-networks';

  static final Map<Type, ParallelPrefixGenerator<Logic>> _treeGenerators = {
    Ripple: Ripple.new,
    Sklansky: Sklansky.new,
    KoggeStone: KoggeStone.new,
    BrentKung: BrentKung.new,
  };

  /// Input width.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

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

/// Configures a directional inclusive bitwise prefix scan.
class ParallelPrefixScanConfigurator extends Configurator {
  /// Input width.
  final IntConfigKnob widthKnob = PositiveIntConfigKnob(value: 8);

  /// Bitwise scan operation.
  final ChoiceConfigKnob<PrefixScanOperation> operationKnob = ChoiceConfigKnob(
    PrefixScanOperation.values,
    value: PrefixScanOperation.or,
  );

  /// Direction in which input bits are accumulated.
  final ChoiceConfigKnob<PrefixScanDirection> directionKnob = ChoiceConfigKnob(
    PrefixScanDirection.values,
    value: PrefixScanDirection.lowToHigh,
  );

  /// Prefix-tree topology.
  final ChoiceConfigKnob<Type> treeKnob = ChoiceConfigKnob(
    ParallelPrefixOperationConfigurator._treeGenerators.keys.toList(),
    value: KoggeStone,
    choiceLabels: const {
      Ripple: 'Ripple',
      Sklansky: 'Sklansky',
      KoggeStone: 'KoggeStone',
      BrentKung: 'BrentKung',
    },
  );

  @override
  ComponentCategory get category => ComponentCategory.arithmetic;

  @override
  String get subcategory => 'prefix-networks';

  @override
  String get name => 'Parallel Prefix Scan';

  @override
  Map<String, ConfigKnob<dynamic>> get knobs => {
        'Width': widthKnob,
        'Operation': operationKnob,
        'Direction': directionKnob,
        'Prefix Tree': treeKnob,
      };

  @override
  Module createModule() => ParallelPrefixScan(
        Logic(name: 'input', width: widthKnob.value),
        operation: operationKnob.value,
        direction: directionKnob.value,
        ppGen: ParallelPrefixOperationConfigurator
            ._treeGenerators[treeKnob.value]!,
      );
}
