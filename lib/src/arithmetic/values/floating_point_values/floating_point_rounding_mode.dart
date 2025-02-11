//TODO: header

/// Floating Point Rounding Modes
enum FloatingPointRoundingMode {
  /// Truncate the result, no rounding
  truncate,

  /// Round to nearest, ties to even
  roundNearestEven,

  /// Round to nearest, tieas away from zero
  roundNearestTiesAway,

  /// Round toward zero
  roundTowardsZero,

  /// Round toward +infinity
  roundTowardsInfinity,

  /// Round toward -infinity
  roundTowardsNegativeInfinity
}
