// Copyright (C) 2025-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_rounding.dart
// Floating-point rounding support.
//
// 2025 January 28 2025
// Author: Desmond A. Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/values/floating_point_values/floating_point_rounding_mode.dart';

/// Determines whether discarded floating-point bits require an increment.
class FloatingPointRounder {
  /// Whether the retained value should be incremented.
  Logic get doRound => _doRound;

  /// Whether any discarded bit is nonzero.
  Logic get inexact => _inexact;

  late final Logic _doRound;
  late final Logic _inexact;

  /// Determines rounding for [inp], retaining bits from [lsb] upward.
  ///
  /// [extraSticky] includes discarded information no longer present in [inp].
  /// [sign] is required for the directed rounding modes.
  FloatingPointRounder(Logic inp, int lsb,
      {required FloatingPointRoundingMode roundingMode,
      Logic? sign,
      Logic? extraSticky}) {
    if (lsb < 0 || lsb >= inp.width) {
      throw RangeError.range(lsb, 0, inp.width - 1, 'lsb');
    }
    _configure(
        retainedLsb: inp[lsb],
        guard: (lsb > 0) ? inp[lsb - 1] : Const(0),
        roundBit: (lsb > 1) ? inp[lsb - 2] : Const(0),
        sticky: (lsb > 2) ? inp.getRange(0, lsb - 2).or() : Const(0),
        extraSticky: extraSticky,
        roundingMode: roundingMode,
        sign: sign);
  }

  /// Determines rounding from explicit retained and discarded-bit fields.
  ///
  /// [roundBit] and [sticky] default to zero for datapaths that collapse or do
  /// not generate those positions. [extraSticky] includes discarded
  /// information from an earlier alignment or normalization operation.
  FloatingPointRounder.fromGRS(
      {required Logic retainedLsb,
      required Logic guard,
      required FloatingPointRoundingMode roundingMode,
      Logic? roundBit,
      Logic? sticky,
      Logic? extraSticky,
      Logic? sign}) {
    _configure(
        retainedLsb: retainedLsb,
        guard: guard,
        roundBit: roundBit ?? Const(0),
        sticky: sticky ?? Const(0),
        extraSticky: extraSticky,
        roundingMode: roundingMode,
        sign: sign);
  }

  void _configure(
      {required Logic retainedLsb,
      required Logic guard,
      required Logic roundBit,
      required Logic sticky,
      required FloatingPointRoundingMode roundingMode,
      Logic? sign,
      Logic? extraSticky}) {
    for (final field in [
      retainedLsb,
      guard,
      roundBit,
      sticky,
      if (extraSticky != null) extraSticky
    ]) {
      if (field.width != 1) {
        throw ArgumentError.value(field, 'rounding field', 'must be 1 bit');
      }
    }
    if (sign == null &&
        (roundingMode == FloatingPointRoundingMode.roundTowardsInfinity ||
            roundingMode ==
                FloatingPointRoundingMode.roundTowardsNegativeInfinity)) {
      throw ArgumentError.value(
          sign, 'sign', 'is required for directed rounding');
    }

    final combinedSticky = sticky | (extraSticky ?? Const(0));
    _inexact = (guard | roundBit | combinedSticky).named('inexact');
    _doRound = switch (roundingMode) {
      FloatingPointRoundingMode.truncate ||
      FloatingPointRoundingMode.roundTowardsZero =>
        Const(0),
      FloatingPointRoundingMode.roundNearestEven =>
        guard & (retainedLsb | roundBit | combinedSticky),
      FloatingPointRoundingMode.roundNearestTiesAway => guard,
      FloatingPointRoundingMode.roundTowardsInfinity => ~sign! & _inexact,
      FloatingPointRoundingMode.roundTowardsNegativeInfinity =>
        sign! & _inexact,
    }
        .named('doRound');
  }
}

/// Determines whether rounding-nearest-even requires an increment.
class RoundRNE extends FloatingPointRounder {
  /// Determines RNE rounding for [inp], retaining bits from [lsb] upward.
  RoundRNE(super.inp, super.lsb)
      : super(roundingMode: FloatingPointRoundingMode.roundNearestEven);
}
