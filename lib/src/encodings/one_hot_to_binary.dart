// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// one_hot_to_binary.dart
// Abstract definition of one hot codec for one hot to binary
//
// 2023 February 24
// Author: Desmond Kirkpatrick

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Decodes a one-hot number into binary using a case block.
abstract class OneHotToBinary extends Module {
  /// The [binary] decoded result.
  Logic get binary => output('binary');

  /// Whether there was an [error] in getting the result.
  ///
  /// Only exists if [generateError] is `true`.
  Logic? get error => tryOutput('error');

  /// If `true`, then the [error] output will be generated.
  final bool generateError;

  /// By default, creates an instance of a [CaseOneHotToBinary] for smaller
  /// widths and a [TreeOneHotToBinary] for larger widths.
  factory OneHotToBinary(Logic onehot,
      {bool generateError = false, String name = 'one_hot_to_binary'}) {
    final isSmall = onehot.width <= 8;

    if (!isSmall && generateError) {
      throw RohdHclException(
          'Tree implementation does not generate error signal.');
    }

    return isSmall
        ? CaseOneHotToBinary(onehot, generateError: generateError, name: name)
        : TreeOneHotToBinary(onehot, name: name);
  }

  /// The [input] of this instance.
  ///
  /// Should only be used by implementations, since it uses an [input].
  @protected
  Logic get onehot => input('onehot');

  /// Constructs a [Module] which decodes a one-hot number [onehot] into a 2s
  /// complement number [binary] by encoding the position of the '1'.
  OneHotToBinary.base(Logic onehot,
      {this.generateError = false, super.name = 'one_hot_to_binary'}) {
    onehot = addInput('onehot', onehot, width: onehot.width);
    addOutput('binary', width: max(log2Ceil(onehot.width), 1));

    if (generateError) {
      addOutput('error');
    }
  }
}
