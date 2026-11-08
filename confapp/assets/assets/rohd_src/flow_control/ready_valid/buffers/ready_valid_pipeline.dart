// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_pipeline.dart
// Registered ready/valid pipeline stages.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A pipeline of homogeneous registered or fall-through ready/valid stages.
///
/// Each stage owns a capacity-derived upstream ready response and an
/// irrevocable downstream offer. A registered pipeline has [depth] cycles of
/// empty-pipeline latency; a fall-through pipeline bypasses when all its
/// stages are empty.
/// {@category Memory}
class ReadyValidElasticPipeline<LogicType extends Logic> extends Module
    implements ReadyValidStorageStatus {
  /// Number of one-entry stages in the pipeline.
  final int depth;

  @override
  int get capacity => depth;

  /// Number of items retained in the pipeline stages.
  @override
  Logic get occupancy => output('occupancy');

  /// High when no item is retained in a pipeline stage.
  @override
  Logic get empty => output('empty');

  /// High when every pipeline stage retains an item.
  @override
  Logic get full => output('full');

  /// Whether each stage uses an empty-stage combinational bypass.
  final bool fallThrough;

  /// Upstream interface accepted by the pipeline.
  late final ReadyValidInterface<LogicType> upstream;

  /// Downstream interface driven by the pipeline.
  late final IrrevocableReadyValidInterface<LogicType> downstream;

  /// Module clock.
  @protected
  late final Logic clk;

  /// Module reset.
  @protected
  late final Logic reset;

  /// Creates a pipeline of registered or fall-through stages.
  ReadyValidElasticPipeline(
      {required Logic clk,
      required Logic reset,
      required ReadyValidInterface<LogicType> upstream,
      required ReadyValidInterface<LogicType> downstream,
      required this.depth,
      this.fallThrough = false,
      String name = 'ready_valid_pipeline'})
      : super(
            definitionName: 'ReadyValidElasticPipeline_D${depth}_'
                '${fallThrough ? 'F' : 'R'}_${upstream.data.name}',
            name: name) {
    if (depth < 1) {
      throw ArgumentError.value(depth, 'depth', 'Must be at least one.');
    }

    this.clk = addInput('clk', clk);
    this.reset = addInput('reset', reset);
    this.upstream = addPairInterfacePorts(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    this.downstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface<LogicType>(downstream.data.cloneTyped()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );
    final occupancyWidth = max(1, (depth + 1).log2Ceil);
    addOutput('occupancy', width: occupancyWidth);
    addOutput('empty');
    addOutput('full');

    var stageUpstream = this.upstream;
    for (var index = 0; index < depth; index++) {
      final lastStage = index == depth - 1;
      final stageDownstream = lastStage
          ? this.downstream
          : ReadyValidInterface<LogicType>(upstream.data.cloneTyped());
      if (fallThrough) {
        ReadyValidFallThroughBuffer<LogicType>(
            clk: this.clk,
            reset: this.reset,
            upstream: stageUpstream,
            downstream: stageDownstream,
            name: '${name}_stage_$index');
      } else {
        ReadyValidRegister<LogicType>(
            clk: this.clk,
            reset: this.reset,
            upstream: stageUpstream,
            downstream: stageDownstream,
            name: '${name}_stage_$index');
      }
      stageUpstream = stageDownstream;
    }

    final inputAccepted = this.upstream.accepted;
    final outputAccepted = this.downstream.accepted;
    final inputOnlyAccepted =
        (inputAccepted & ~outputAccepted).named('${name}_input_only_accepted');
    final outputOnlyAccepted =
        (~inputAccepted & outputAccepted).named('${name}_output_only_accepted');
    empty <= occupancy.eq(0);
    full <= occupancy.eq(depth);
    Sequential(this.clk, reset: this.reset, resetValues: {
      occupancy: 0
    }, [
      If(inputOnlyAccepted, then: [occupancy < occupancy + 1]),
      If(outputOnlyAccepted, then: [occupancy < occupancy - 1]),
    ]);
  }
}
