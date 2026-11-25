// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// attention_architecture_metrics.dart
// Static traffic model for fixed-point attention architecture comparisons.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';

/// Static numeric-traffic model for one bounded fixed-point attention request.
///
/// The register-captured architecture transfers the complete query, key, and
/// value tensors with its command. The scratchpad-backed architecture transfers
/// only the query with the command and reads one independently packed key and
/// value row per sequence position.
/// {@category Inference}
@immutable
class FixedPointAttentionTrafficModel {
  /// Number of physical key/value positions.
  final int sequenceLength;

  /// Number of query/key lanes.
  final int headDimension;

  /// Number of value/output lanes.
  final int valueDimension;

  /// Width of each query/key element.
  final int elementWidth;

  /// Width of each value element.
  final int valueWidth;

  /// Width of each avoided materialized score.
  final int scoreWidth;

  /// Creates a validated attention traffic model.
  const FixedPointAttentionTrafficModel({
    required this.sequenceLength,
    required this.headDimension,
    required this.valueDimension,
    required this.elementWidth,
    required this.valueWidth,
    required this.scoreWidth,
  }) : assert(
          sequenceLength > 0 &&
              headDimension > 0 &&
              valueDimension > 0 &&
              elementWidth > 0 &&
              valueWidth > 0 &&
              scoreWidth > 0,
          'Attention traffic dimensions and widths must be positive.',
        );

  /// Packed query bytes transferred with either command.
  int get queryBytes => _bytesForBits(headDimension * elementWidth);

  /// Bytes in one independently packed key row.
  int get keyRowBytes => _bytesForBits(headDimension * elementWidth);

  /// Bytes in one independently packed value row.
  int get valueRowBytes => _bytesForBits(valueDimension * valueWidth);

  /// Numeric command bytes for the register-captured architecture.
  int get registerCapturedCommandBytes => _bytesForBits(
        headDimension * elementWidth +
            sequenceLength * headDimension * elementWidth +
            sequenceLength * valueDimension * valueWidth,
      );

  /// Numeric command bytes for the scratchpad-backed architecture.
  int get scratchpadCommandBytes => queryBytes;

  /// Scratchpad bytes read for all physical KV rows.
  int get scratchpadReadBytes => sequenceLength * (keyRowBytes + valueRowBytes);

  /// Total numeric movement visible to the scratchpad-backed engine.
  int get scratchpadTotalBytes => scratchpadCommandBytes + scratchpadReadBytes;

  /// Command-ingress reduction from moving KV tensors into scratchpads.
  int get commandByteReduction =>
      registerCapturedCommandBytes - scratchpadCommandBytes;

  /// Maximum avoided score-write bytes when every position is active.
  int get maximumAvoidedScoreWriteBytes =>
      sequenceLength * _bytesForBits(scoreWidth);

  static int _bytesForBits(int bits) => (bits + 7) ~/ 8;
}
