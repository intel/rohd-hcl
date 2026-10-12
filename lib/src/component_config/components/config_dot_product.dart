// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_dot_product.dart
// Configurator for integer dot products.
//
// 2026 October 11
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Available dot-product implementations.
enum DotProductImplementation {
  /// Instantiate one selected multiplier per lane and reduce the results.
  general,

  /// Fuse all lanes into one compression tree.
  compressionTree,
}

/// A [Configurator] for documented dot-product implementations.
class DotProductConfigurator extends Configurator {
  /// Number of products to accumulate.
  final IntConfigKnob laneCountKnob = IntConfigKnob(value: 4);

  /// Width of every multiplicand.
  final IntConfigKnob multiplicandWidthKnob = IntConfigKnob(value: 8);

  /// Width of every multiplier.
  final IntConfigKnob multiplierWidthKnob = IntConfigKnob(value: 8);

  /// Dot-product implementation to instantiate.
  final ChoiceConfigKnob<DotProductImplementation> implementationKnob =
      ChoiceConfigKnob(
    DotProductImplementation.values,
    value: DotProductImplementation.general,
    choiceLabels: const {
      DotProductImplementation.general: 'General',
      DotProductImplementation.compressionTree: 'Compression Tree',
    },
  );

  /// Booth radix for compression-tree multiplication.
  final ChoiceConfigKnob<int> productRadixKnob = ChoiceConfigKnob(
    [2, 4, 8, 16],
    value: 4,
  );

  /// Radix of the general implementation's reduction tree.
  final IntConfigKnob reductionRadixKnob = IntConfigKnob(value: 2);

  /// Multiplicand signedness selection.
  final StaticOrRuntimeBoolKnob signedMultiplicandKnob =
      StaticOrRuntimeBoolKnob();

  /// Multiplier signedness selection.
  final StaticOrRuntimeBoolKnob signedMultiplierKnob =
      StaticOrRuntimeBoolKnob();

  /// Multiplier implementation used by the general dot product.
  final MultiplierSelectKnob multiplierSelectKnob = MultiplierSelectKnob(
      allowSigned: false, allowPipelining: true, name: 'Lane Multiplier');

  /// Adder implementation used by the dot product.
  final AdderSelectKnob adderSelectKnob = AdderSelectKnob();

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Lane Count': laneCountKnob,
    'Multiplicand Width': multiplicandWidthKnob,
    'Multiplier Width': multiplierWidthKnob,
    'Implementation': implementationKnob,
    'Product Radix': productRadixKnob,
    if (implementationKnob.value == DotProductImplementation.general)
      'Reduction Tree Radix': reductionRadixKnob,
    'Multiplicand Signedness': signedMultiplicandKnob,
    'Multiplier Signedness': signedMultiplierKnob,
    if (implementationKnob.value == DotProductImplementation.general)
      'Lane Multiplier': multiplierSelectKnob,
    'Final Adder': adderSelectKnob,
  });

  @override
  Module createModule() {
    final multiplicands = List<Logic>.generate(
        laneCountKnob.value,
        (index) => Logic(
            name: 'multiplicand_$index', width: multiplicandWidthKnob.value));
    final multipliers = List<Logic>.generate(
        laneCountKnob.value,
        (index) =>
            Logic(name: 'multiplier_$index', width: multiplierWidthKnob.value));
    final signedMultiplicand =
        signedMultiplicandKnob.resolve('signedMultiplicand');
    final signedMultiplier = signedMultiplierKnob.resolve('signedMultiplier');
    Adder adderGen(Logic a, Logic b, {Logic? carryIn}) => adderSelectKnob
        .selectedAdder()(a, b, carryIn: carryIn, name: 'dot_product_add');

    Multiplier multiplierGen(
      Logic a,
      Logic b, {
      Logic? clk,
      Logic? reset,
      Logic? enable,
      dynamic signedMultiplicand,
      dynamic signedMultiplier,
    }) =>
        multiplierSelectKnob.selectedMultiplier(
            signedMultiplicand: signedMultiplicand,
            signedMultiplier: signedMultiplier)(
          a,
          b,
          clk: clk,
          reset: reset,
          enable: enable,
          name: 'dot_product_multiply',
        );

    if (implementationKnob.value == DotProductImplementation.compressionTree) {
      if (multiplicandWidthKnob.value != multiplierWidthKnob.value) {
        throw RohdHclException(
            'The compression-tree dot product requires equal operand widths.');
      }
      return CompressionTreeDotProduct(
        multiplicands,
        multipliers,
        signedMultiplicand: signedMultiplicand,
        signedMultiplier: signedMultiplier,
        productRadix: productRadixKnob.value,
        adderGen: adderGen,
      );
    }

    return GeneralDotProduct(
      multiplicands,
      multipliers,
      signedMultiplicand: signedMultiplicand,
      signedMultiplier: signedMultiplier,
      treeRadix: reductionRadixKnob.value,
      multiplierGen: multiplierGen,
      adderGen: (a, b, {carryIn, name = 'dot_product_add'}) =>
          adderSelectKnob.selectedAdder()(a, b, carryIn: carryIn, name: name),
    );
  }

  @override
  String get name => 'Dot Product';
}
