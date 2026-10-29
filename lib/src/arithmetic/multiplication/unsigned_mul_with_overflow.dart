// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// unsigned_mul_with_overflow.dart
// Unsigned multiplication that reports overflow out of a fixed-width product.
//
// 2026 October
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Multiplies two unsigned values into a [product] of [productWidth] bits and
/// reports whether the true product did not fit in [productWidth] bits.
///
/// The [productWidth] defaults to the sum of the operand widths, which can
/// never overflow.
class UnsignedMulWithOverflow extends Module {
  /// The [productWidth]-bit truncated product.
  Logic get product => output('product');

  /// High when the true product needs more than [productWidth] bits.
  Logic get overflow => output('overflow');

  /// The width of [product].
  final int productWidth;

  /// Constructs an [UnsignedMulWithOverflow] of [a] and [b].
  UnsignedMulWithOverflow(Logic a, Logic b,
      {int? productWidth,
      super.name = 'unsigned_mul_with_overflow',
      super.reserveName,
      super.reserveDefinitionName,
      String? definitionName})
      : productWidth = productWidth ?? a.width + b.width,
        super(
            definitionName: definitionName ??
                'UnsignedMulWithOverflow_A${a.width}_B${b.width}'
                    '_P${productWidth ?? a.width + b.width}') {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    final product = addOutput('product', width: this.productWidth);
    final overflow = addOutput('overflow');

    final fullWidth = a.width + b.width;
    final wideProduct = a.zeroExtend(fullWidth) * b.zeroExtend(fullWidth);
    final full = wideProduct.slice(fullWidth - 1, 0);
    if (this.productWidth >= fullWidth) {
      product <= full.zeroExtend(this.productWidth);
      overflow <= Const(0);
    } else {
      product <= full.slice(this.productWidth - 1, 0);
      overflow <= full.slice(fullWidth - 1, this.productWidth).or();
    }
  }
}
