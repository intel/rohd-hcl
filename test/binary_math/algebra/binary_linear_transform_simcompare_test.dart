// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// binary_linear_transform_simcompare_test.dart
// Functional and generated RTL tests for binary linear transforms.
//
// 2026 October 9
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

@TestOn('vm')
library;

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('sparse affine transform matches descriptor and generated RTL',
      () async {
    final matrix = BinaryMatrix(
      [
        BigInt.zero,
        BigInt.one,
        BigInt.from(11),
        BigInt.from(15),
      ],
      columnCount: 4,
    );
    final transform = BinaryLinearTransform(
      Logic(width: 4),
      matrix: matrix,
      affineOffset: BigInt.from(5),
      radix: 3,
    );
    await transform.build();

    final vectors = [
      for (var input = 0; input < 16; input++)
        Vector(
          {'data_in': input},
          {
            'result':
                (matrix.multiplyVector(BigInt.from(input)) ^ BigInt.from(5))
          },
        ),
    ];

    await SimCompare.checkFunctionalVector(transform, vectors);
    SimCompare.checkIverilogVector(transform, vectors);
  });

  test('identity transform preserves its input', () async {
    final transform = BinaryLinearTransform(
      Logic(width: 5),
      matrix: BinaryMatrix.identity(5),
    );
    await transform.build();

    final vectors = [
      for (final input in [0, 1, 3, 17, 31])
        Vector({'data_in': input}, {'result': input}),
    ];

    await SimCompare.checkFunctionalVector(transform, vectors);
    SimCompare.checkIverilogVector(transform, vectors);
  });

  test('rejects incompatible input and affine widths', () {
    expect(
      () => BinaryLinearTransform(
        Logic(width: 3),
        matrix: BinaryMatrix.identity(2),
      ),
      throwsA(isA<PortWidthMismatchException>()),
    );
    expect(
      () => BinaryLinearTransform(
        Logic(width: 2),
        matrix: BinaryMatrix.identity(2),
        affineOffset: BigInt.from(4),
      ),
      throwsA(isA<RohdHclException>()),
    );
  });
}
