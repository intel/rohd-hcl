// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// typed_static_permutation.dart
// Compile-time typed-array permutation hardware.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/dataflow/layout/layout_shape.dart';
import 'package:rohd_hcl/src/dataflow/layout/permutation_descriptor.dart';
import 'package:rohd_hcl/src/exceptions.dart';
import 'package:rohd_hcl/src/interfaces/payload_shape.dart';

/// Statically permutes typed array elements while preserving their structure.
///
/// [descriptor] maps each row-major output element to one row-major input
/// element. Input and output arrays may have different shapes as long as they
/// contain the same number of equally wide typed elements.
/// {@category Dataflow}
class TypedStaticPermutation<TLogic extends Logic, TValue> extends Module {
  /// Compile-time output-to-source mapping.
  final PermutationDescriptor descriptor;

  /// Input row-major shape.
  final LayoutShape inputShape;

  /// Output row-major shape.
  final LayoutShape outputShape;

  /// Permuted typed array.
  late final TypedLogicArray<TLogic, TValue> result;

  /// Creates static typed-element wiring for [descriptor].
  TypedStaticPermutation(
    TypedLogicArray<TLogic, TValue> dataIn, {
    required TypedLogicArray<TLogic, TValue> outputPrototype,
    required this.descriptor,
    super.name = 'typed_static_permutation',
  })  : inputShape = LayoutShape(dataIn.dimensions),
        outputShape = LayoutShape(outputPrototype.dimensions),
        super(
          definitionName: 'TypedStaticPermutation_'
              '${payloadShapesIdentity([dataIn, outputPrototype])}_'
              'P${descriptor.configurationSignature}',
        ) {
    if (inputShape.elementCount != outputShape.elementCount ||
        descriptor.length != inputShape.elementCount) {
      throw RohdHclException(
        'Typed permutation shapes and descriptor must contain the same '
        'number of elements.',
      );
    }
    if (dataIn.elementWidth != outputPrototype.elementWidth) {
      throw PortWidthMismatchException.equalWidth(dataIn, outputPrototype);
    }
    if (!identical(dataIn.valueCodec, outputPrototype.valueCodec)) {
      throw RohdHclException('Typed permutation value codecs must match.');
    }
    for (var index = 0; index < descriptor.length; index++) {
      if (!compatiblePayloadConnection(
          dataIn.arrayElements[descriptor.sourceIndex(index)],
          outputPrototype.arrayElements[index],
          ignoreConstantNames: true)) {
        throw RohdHclException(
            'Typed permutation source and destination payloads must match.');
      }
    }

    final localData =
        addTypedInput<TypedLogicArray<TLogic, TValue>>('dataIn', dataIn);
    result = addTypedPayloadOutput(this, 'result', outputPrototype);
    final localResult = result;
    for (var outputIndex = 0; outputIndex < descriptor.length; outputIndex++) {
      localResult.arrayElements[outputIndex] <=
          localData.arrayElements[descriptor.sourceIndex(outputIndex)];
    }
  }
}
