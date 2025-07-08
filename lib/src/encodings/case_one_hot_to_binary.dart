// Copyright (C) 2023-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// case_one_hot_to_binary.dart
// Implementation of one hot codec from one hot to binary via case statements
//
// 2023 February 24
// Author: Desmond Kirkpatrick

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Decodes a one-hot number into binary using a case block.
class CaseOneHotToBinary extends OneHotToBinary {
  /// Constructs a [Module] which decodes a one-hot number [onehot] into a 2s
  /// complement number [binary] by encoding the position of the '1' using a
  /// [Case] block.
  ///
  /// It is not recommended to use this for very large-width [onehot]s since it
  /// will create many [CaseItem]s. If the width is more than ~8, try using the
  /// [TreeOneHotToBinary]. The implementation does not support widths exceeding
  /// the maximum width of an `int`.
  CaseOneHotToBinary(super.onehot,
      {super.generateError = false,
      super.name = 'one_hot_to_binary',
      super.definitionName})
      : super.base() {
    if (onehot.width >= 32) {
      throw RohdHclException('Should not be used for large widths.');
    }
    Combinational([
      Case(onehot, conditionalType: ConditionalType.unique, [
        for (var i = 0; i < onehot.width; i++)
          CaseItem(
            Const(BigInt.from(1) << i, width: onehot.width),
            [
              binary < Const(i, width: binary.width),
              if (generateError) error! < 0,
            ],
          )
      ], defaultItem: [
        binary < Const(0, width: binary.width),
        if (generateError) error! < 1,
      ])
    ]);
  }
}
