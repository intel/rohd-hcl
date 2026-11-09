// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_iterative_divider.dart
// Ready/valid shell for a variable-latency iterative divider.
//
// 2026 September 22
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/division_and_roots/iterative_divider_engine.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/buffers/ready_valid_fall_through_buffer.dart';
import 'package:rohd_hcl/src/flow_control/ready_valid/transport/ready_valid_interface.dart';

/// Describes one signed or unsigned integer division command.
/// {@category Arithmetic}
class DivisionRequest extends LogicStructure {
  /// Numerator of the operation.
  Logic get dividend => elements[0];

  /// Denominator of the operation.
  Logic get divisor => elements[1];

  /// Selects signed division when high.
  Logic get isSigned => elements[2];

  /// Width of both operands.
  final int dataWidth;

  /// Creates a division command with equally wide operands.
  DivisionRequest({required this.dataWidth, String? name})
      : super(
          [
            Logic(name: 'dividend', width: dataWidth),
            Logic(name: 'divisor', width: dataWidth),
            Logic(name: 'isSigned'),
          ],
          name: name ?? 'divisionRequest',
        );

  DivisionRequest._clone(DivisionRequest original, {String? name})
      : dataWidth = original.dataWidth,
        super(
          original.elements
              .map((element) => element.clone(name: element.name))
              .toList(),
          name: name ?? original.name,
        );

  @override
  DivisionRequest clone({String? name}) =>
      DivisionRequest._clone(this, name: name);
}

/// Describes one completed integer division result.
/// {@category Arithmetic}
class DivisionResult extends LogicStructure {
  /// Integer quotient.
  Logic get quotient => elements[0];

  /// Integer remainder.
  Logic get remainder => elements[1];

  /// Indicates that the divisor was zero.
  Logic get divZero => elements[2];

  /// Width of both numeric results.
  final int dataWidth;

  /// Creates a division result with equally wide numeric fields.
  DivisionResult({required this.dataWidth, String? name})
      : super(
          [
            Logic(name: 'quotient', width: dataWidth),
            Logic(name: 'remainder', width: dataWidth),
            Logic(name: 'divZero'),
          ],
          name: name ?? 'divisionResult',
        );

  DivisionResult._clone(DivisionResult original, {String? name})
      : dataWidth = original.dataWidth,
        super(
          original.elements
              .map((element) => element.clone(name: element.name))
              .toList(),
          name: name ?? original.name,
        );

  @override
  DivisionResult clone({String? name}) =>
      DivisionResult._clone(this, name: name);
}

/// Exposes an iterative divider as ready/valid command and retained-result channels.
///
/// At most one command is in flight. The divider accepts a command only while
/// idle and holds the result valid and stable until the result channel accepts
/// it. A fall-through buffer retains the direct [IterativeDividerEngine]'s
/// completion pulse when the result channel stalls.
/// {@category Arithmetic}
class ReadyValidIterativeDivider extends Module {
  /// Width of the request operands and result fields.
  final int dataWidth;

  late final ReadyValidInterface<DivisionRequest> _upstream;
  late final IrrevocableReadyValidInterface<DivisionResult> _downstream;

  /// Creates a ready/valid shell for an iterative divider.
  ReadyValidIterativeDivider({
    required Logic clk,
    required Logic reset,
    required ReadyValidInterface<DivisionRequest> upstream,
    required ReadyValidInterface<DivisionResult> downstream,
    String name = 'ready_valid_iterative_divider',
  })  : dataWidth = upstream.data.dataWidth,
        super(
          definitionName:
              'ReadyValidIterativeDivider_W${upstream.data.dataWidth}',
          name: name,
        ) {
    if (upstream.data.dataWidth != downstream.data.dataWidth) {
      throw ArgumentError('Request and result widths must match.');
    }
    upstream.requireProviderComposableWith(ReadyValidContract.validThenReady,
        consumerName: '$name command');
    downstream.requireConsumerComposableWith(ReadyValidContract.irrevocable,
        providerName: name);

    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    _upstream = addPairInterfacePorts(upstream, PairRole.consumer,
        uniquify: (original) => 'upstream_$original');
    _downstream = addPairInterfaceFrom(
      IrrevocableReadyValidInterface<DivisionResult>(downstream.data.clone()),
      downstream,
      PairRole.provider,
      uniquify: (original) => 'downstream_$original',
    );

    final start = Logic(name: 'start');
    final engine = IterativeDividerEngine(
      clk: clk,
      reset: reset,
      start: start,
      dividend: _upstream.data.dividend,
      divisor: _upstream.data.divisor,
      isSigned: _upstream.data.isSigned,
      name: '${name}_core',
    );
    final result = ReadyValidInterface(DivisionResult(dataWidth: dataWidth));
    result.valid <= engine.done;
    result.data.quotient <= engine.quotient;
    result.data.remainder <= engine.remainder;
    result.data.divZero <= engine.divZero;
    final buffer = ReadyValidFallThroughBuffer<DivisionResult>(
      clk: clk,
      reset: reset,
      upstream: result,
      downstream: _downstream,
      name: '${name}_result_buffer',
    );
    _upstream.ready <= ~engine.busy & ~buffer.occupied;
    start <= _upstream.valid & _upstream.ready;
  }
}
