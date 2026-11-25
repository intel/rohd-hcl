// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// tensor_strided_address.dart
// Random-access strided tensor address calculation.
//
// 2026 November 23
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/multiply_accumulate/dotproduct.dart';
import 'package:rohd_hcl/src/inference/inference_multiplier_functor.dart';

/// Computes an unsigned random-access strided tensor address.
///
/// The full result is `baseAddress + sum(indices[i] * strides[i])`, with
/// sufficient width for all products and carries. [address] is the low
/// [addressWidth] bits; [overflow] indicates nonzero discarded bits. No
/// coordinate bounds, alignment, or memory-transaction checks are performed.
/// {@category Inference}
class TensorStridedAddress extends Module {
  /// Width of the narrowed [address].
  final int addressWidth;

  /// Full-precision address, before narrowing.
  Logic get fullAddress => output('fullAddress');

  /// Low [addressWidth] bits of the full address.
  Logic get address => output('address');

  /// High when the full address does not fit in [addressWidth] bits.
  Logic get overflow => output('overflow');

  /// Constructs a combinational address calculation.
  ///
  /// [indices] and [strides] must have the same nonzero length. Operands may
  /// have different widths and are interpreted as unsigned values.
  TensorStridedAddress({
    required Logic baseAddress,
    required List<Logic> indices,
    required List<Logic> strides,
    required this.addressWidth,
    InferenceMultiplierFunctor multiplierImplementation =
        nativeInferenceMultiplierFunctor,
    super.name = 'tensor_strided_address',
  }) : super(
          definitionName: 'TensorStridedAddress_'
              'B${baseAddress.width}_A${addressWidth}_'
              'I${indices.map((signal) => signal.width).join("_")}_'
              'S${strides.map((signal) => signal.width).join("_")}_'
              '${multiplierImplementation.identity}',
        ) {
    if (indices.isEmpty || indices.length != strides.length) {
      throw ArgumentError(
          'Provide the same nonzero number of indices and strides.');
    }
    if (addressWidth < 1) {
      throw ArgumentError.value(
          addressWidth, 'addressWidth', 'Must be positive.');
    }
    baseAddress =
        addInput('baseAddress', baseAddress, width: baseAddress.width);
    final indexWidth = indices.map((signal) => signal.width).reduce(max);
    final strideWidth = strides.map((signal) => signal.width).reduce(max);
    final localIndices = [
      for (var i = 0; i < indices.length; i++)
        addInput('index_$i', indices[i], width: indices[i].width)
            .zeroExtend(indexWidth),
    ];
    final localStrides = [
      for (var i = 0; i < strides.length; i++)
        addInput('stride_$i', strides[i], width: strides[i].width)
            .zeroExtend(strideWidth),
    ];
    final offset = GeneralDotProduct(
      localIndices,
      localStrides,
      multiplierGen: multiplierImplementation.call,
      multiplierIdentity: multiplierImplementation.identity,
      name: '${name}_offset',
    ).product;
    final calculationWidth = max(offset.width, baseAddress.width) + 1;
    final fullWidth = max(calculationWidth, addressWidth);
    final fullAddress =
        offset.zeroExtend(fullWidth) + baseAddress.zeroExtend(fullWidth);
    addOutput('fullAddress', width: fullWidth) <= fullAddress;
    addOutput('address', width: addressWidth) <=
        fullAddress.getRange(0, addressWidth);
    addOutput('overflow') <=
        (fullWidth > addressWidth
            ? fullAddress.getRange(addressWidth).or()
            : Const(0));
  }
}
