// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_classification.dart
// Floating-point classification and ordered comparison.
//
// 2026 November 8
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point/explicit_j_bit_canonicalization.dart';
import 'package:rohd_hcl/src/arithmetic/signals/floating_point_logics/floating_point_logic.dart';

String _formatIdentity(FloatingPoint value) =>
    'E${value.exponent.width}_M${value.mantissa.width}_'
    'I${value.supportsInfinities ? 1 : 0}_'
    'S${value.supportsSignalingNaNs ? 1 : 0}_'
    'Z${value.subNormalAsZero ? 1 : 0}';

void _requireSupportedFormat(FloatingPoint value, bool alignExplicitJBit) {
  if (value.explicitJBit && !alignExplicitJBit) {
    throw ArgumentError('Explicit J-bit formats require alignExplicitJBit.');
  }
}

/// Classifies a floating-point encoding without changing its bit pattern.
///
/// With `alignExplicitJBit`, explicit-J-bit inputs are classified by their
/// numerical value after canonicalization. Subnormals are reported as such
/// even when the format is configured to treat them as zero in arithmetic.
/// Explicit-J-bit alignment requires an exponent width of at least two bits.
/// {@category Arithmetic}
class FloatingPointClassifier extends Module {
  /// Input sign bit.
  Logic get sign => output('sign');

  /// Whether the input is zero.
  Logic get zero => output('zero');

  /// Whether the input is a nonzero subnormal.
  Logic get subnormal => output('subnormal');

  /// Whether the input is a finite normal value.
  Logic get normal => output('normal');

  /// Whether the input is an infinity.
  Logic get infinity => output('infinity');

  /// Whether the input is a quiet NaN.
  Logic get quietNaN => output('quietNaN');

  /// Whether the input is a signaling NaN.
  Logic get signalingNaN => output('signalingNaN');

  /// Creates a classifier, optionally canonicalizing explicit-J-bit inputs.
  FloatingPointClassifier(
    FloatingPoint value, {
    bool alignExplicitJBit = false,
    super.name = 'floating_point_classifier',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              'FloatingPointClassifier_${_formatIdentity(value)}'
                  '${value.explicitJBit ? '_J1' : ''}',
        ) {
    _requireSupportedFormat(value, alignExplicitJBit);
    value = addTypedInput('value', value);
    if (value.explicitJBit) {
      value = canonicalizeExplicitJBit(value);
    }
    final exponentZero = ~value.exponent.or();
    final mantissaNonzero = value.mantissa.or();
    final isSubnormal = exponentZero & mantissaNonzero;
    final isZero = value.isAZero;
    final isInfinity = value.isAnInfinity;
    final isNaN = value.isNaN;
    addOutput('sign') <= value.sign;
    addOutput('zero') <= isZero;
    addOutput('subnormal') <= isSubnormal;
    addOutput('normal') <= ~(isZero | isSubnormal | isInfinity | isNaN);
    addOutput('infinity') <= isInfinity;
    addOutput('quietNaN') <= value.isQuietNaN;
    addOutput('signalingNaN') <= value.isSignalingNaN;
  }
}

/// Compares two values in the same floating-point format.
///
/// NaNs produce [unordered] and no ordered result. Positive and negative zero
/// compare equal. Subnormal inputs are treated as zero when the format's
/// `subNormalAsZero` option is enabled. Explicit-J-bit inputs require
/// `alignExplicitJBit` and are canonicalized before comparison and flushing.
/// {@category Arithmetic}
class FloatingPointComparator extends Module {
  /// True when the first operand is less than the second.
  Logic get less => output('less');

  /// True when the operands compare equal.
  Logic get equal => output('equal');

  /// True when the first operand is greater than the second.
  Logic get greater => output('greater');

  /// True when either operand is NaN.
  Logic get unordered => output('unordered');

  /// Creates a comparator for two matching formats.
  FloatingPointComparator(
    FloatingPoint a,
    FloatingPoint b, {
    bool alignExplicitJBit = false,
    super.name = 'floating_point_comparator',
    super.reserveName,
    super.reserveDefinitionName,
    String? definitionName,
  }) : super(
          definitionName: definitionName ??
              'FloatingPointComparator_${_formatIdentity(a)}'
                  '${a.explicitJBit ? '_J1' : ''}',
        ) {
    _requireSupportedFormat(a, alignExplicitJBit);
    _requireSupportedFormat(b, alignExplicitJBit);
    if (a.exponent.width != b.exponent.width ||
        a.mantissa.width != b.mantissa.width ||
        a.explicitJBit != b.explicitJBit ||
        a.subNormalAsZero != b.subNormalAsZero ||
        a.supportsInfinities != b.supportsInfinities ||
        a.supportsSignalingNaNs != b.supportsSignalingNaNs) {
      throw ArgumentError('Floating-point operand formats must match.');
    }
    a = addTypedInput('a', a);
    b = addTypedInput('b', b);
    if (a.explicitJBit) {
      a = canonicalizeExplicitJBit(a);
      b = canonicalizeExplicitJBit(b);
    }
    final resolvedA = a.resolveSubNormalAsZero();
    final resolvedB = b.resolveSubNormalAsZero();
    addOutput('unordered') <= a.isNaN | b.isNaN;
    addOutput('equal') <= resolvedA.eq(resolvedB);
    addOutput('less') <= resolvedA.lt(resolvedB);
    addOutput('greater') <= resolvedA.gt(resolvedB);
  }
}
