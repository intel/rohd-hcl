// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// prbs_configuration.dart
// Immutable PRBS sequence configurations.
//
// 2026 September 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd_hcl/src/binary_math/algebra/binary_polynomial.dart';
import 'package:rohd_hcl/src/binary_math/prbs/prbs_standard.dart';
import 'package:rohd_hcl/src/binary_math/recurrence/lfsr_descriptor.dart';
import 'package:rohd_hcl/src/exceptions.dart';

/// Configures a pseudorandom binary sequence and its non-zero seed.
///
/// The sequence follows [LfsrDescriptor]'s right-shifting Fibonacci convention.
/// {@category Binary Math}
@immutable
class PrbsConfiguration {
  /// The sequence's LFSR descriptor.
  final LfsrDescriptor lfsrDescriptor;

  /// The non-zero initial LFSR state.
  final BigInt seed;

  /// Creates a custom PRBS configuration.
  PrbsConfiguration({
    required BinaryPolynomial polynomial,
    BigInt? seed,
  })  : lfsrDescriptor = LfsrDescriptor(polynomial),
        seed = seed ?? ((BigInt.one << polynomial.degree) - BigInt.one) {
    if (this.seed <= BigInt.zero ||
        this.seed >= (BigInt.one << lfsrDescriptor.width)) {
      throw RohdHclException('PRBS seed ${this.seed} must be non-zero and fit '
          'in ${lfsrDescriptor.width} bits.');
    }
  }

  /// Creates a configuration for a cataloged [standard].
  factory PrbsConfiguration.standard(
    PrbsStandard standard, {
    BigInt? seed,
  }) =>
      PrbsConfiguration(polynomial: standard.polynomial, seed: seed);

  /// The sequence register width.
  int get width => lfsrDescriptor.width;

  /// A deterministic signature suitable for generated definition names.
  String get configurationSignature =>
      '${lfsrDescriptor.configurationSignature}_${seed.toRadixString(16)}';

  @override
  bool operator ==(Object other) =>
      other is PrbsConfiguration &&
      lfsrDescriptor == other.lfsrDescriptor &&
      seed == other.seed;

  @override
  int get hashCode => Object.hash(lfsrDescriptor, seed);
}
