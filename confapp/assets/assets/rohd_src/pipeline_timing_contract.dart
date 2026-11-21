// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pipeline_timing_contract.dart
// Static timing and scheduling contract for fixed-latency pipelines.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';

/// Describes how a fixed-latency pipeline can be scheduled.
///
/// The contract is protocol-neutral. It describes direct scheduled use,
/// valid-only wrapping, or transport adapters without embedding ready/valid or
/// credit signals in the datapath.
@immutable
class PipelineTimingContract {
  /// Number of advancing cycles from input sampling to output visibility.
  final int latency;

  /// Minimum number of advancing cycles between successive input samples.
  final int initiationInterval;

  /// Stalling behavior supported by the pipeline.
  final PipelineStallability stallability;

  /// Whether the pipeline carries explicit bubbles independently of its data.
  final bool acceptsBubbles;

  /// Whether the pipeline can discard all in-flight work without reset.
  final bool supportsFlush;

  /// Maximum operations that can be in flight simultaneously.
  final int maximumInFlight;

  /// Creates a validated fixed-pipeline timing contract.
  const PipelineTimingContract({
    required this.latency,
    required this.initiationInterval,
    required this.stallability,
    required this.acceptsBubbles,
    required this.supportsFlush,
    required this.maximumInFlight,
  })  : assert(latency >= 0, 'Latency must not be negative.'),
        assert(
            initiationInterval >= 1, 'Initiation interval must be positive.'),
        assert(
            maximumInFlight >= 1, 'Maximum in-flight count must be positive.'),
        assert(
            maximumInFlight >=
                (latency + initiationInterval - 1) ~/ initiationInterval,
            'Maximum in-flight count cannot retain all launched operations.');

  /// Returns the minimum capacity needed to retain every result when each
  /// sampled input eventually produces one result.
  int get minimumResultCapacity => maximumInFlight;

  @override
  bool operator ==(Object other) =>
      other is PipelineTimingContract &&
      latency == other.latency &&
      initiationInterval == other.initiationInterval &&
      stallability == other.stallability &&
      acceptsBubbles == other.acceptsBubbles &&
      supportsFlush == other.supportsFlush &&
      maximumInFlight == other.maximumInFlight;

  @override
  int get hashCode => Object.hash(
        latency,
        initiationInterval,
        stallability,
        acceptsBubbles,
        supportsFlush,
        maximumInFlight,
      );

  @override
  String toString() => 'PipelineTimingContract('
      'latency: $latency, '
      'initiationInterval: $initiationInterval, '
      'stallability: $stallability, '
      'acceptsBubbles: $acceptsBubbles, '
      'supportsFlush: $supportsFlush, '
      'maximumInFlight: $maximumInFlight)';
}

/// Defines whether and how a fixed-latency pipeline can pause.
enum PipelineStallability {
  /// The pipeline advances every clock and cannot be paused.
  none,

  /// One control signal advances or pauses every stage atomically.
  globalAdvance,

  /// Individual stages can independently retain work.
  perStageElastic,
}
